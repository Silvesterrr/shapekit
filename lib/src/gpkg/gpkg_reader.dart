import 'dart:io';
import 'dart:typed_data';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:shapekit/src/domain/entities/geometry/envelope.dart';
import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart' show FileNotFoundException;
import 'package:shapekit/src/gpkg/exceptions.dart';
import 'package:shapekit/src/gpkg/types/raw_feature_batch.dart';
import 'package:shapekit/src/gpkg/types/column_info.dart';
import 'package:shapekit/src/gpkg/types/geo_feature.dart';
import 'package:shapekit/src/gpkg/types/feature_batch.dart';
import 'package:shapekit/src/gpkg/codec/wkb_decoder.dart';
import 'package:shapekit/src/gpkg/spatial_index.dart';
import 'package:shapekit/src/gpkg/sql_id.dart';

/// Represents a connection to a GeoPackage file
///
/// GeoPackage is a SQLite database with additional standardized tables
/// for geometries, feature layers, and spatial metadata.
///
/// This class manages the SQLite connection lifecycle and provides
/// access to feature data via spatial queries.
class GpkgReader {
  late final sqlite3.Database _db;
  final String path;
  bool _isClosed = false;
  final Map<String, List<ColumnInfo>> _columnCache = {};

  GpkgReader._(this.path);

  /// Opens a GeoPackage file.
  ///
  /// When [readOnly] is true (default), opens via SQLite's `immutable=1` URI
  /// flag — no journal/WAL files, no file locking, safe for concurrent reads
  /// from multiple isolates. The caller is responsible for ensuring the file
  /// is not modified while open in this mode.
  ///
  /// When [readOnly] is false, opens read/write — used by [GpkgImport] when
  /// building R-Tree indices on the freshly-copied app-storage file.
  ///
  /// Throws [FileNotFoundException] if file doesn't exist.
  /// Throws [SqliteException] if file is not a valid SQLite database.
  static GpkgReader open(String path, {bool readOnly = true}) {
    if (!File(path).existsSync()) {
      throw FileNotFoundException(path);
    }

    final conn = GpkgReader._(path);
    if (readOnly) {
      final uri = 'file:${Uri.encodeFull(path.replaceAll(r'\', '/'))}?immutable=1';
      conn._db = sqlite3.sqlite3.open(uri, uri: true);
    } else {
      conn._db = sqlite3.sqlite3.open(path);
    }

    try {
      conn._db.execute('SELECT table_name FROM gpkg_contents LIMIT 1;');
    } catch (e) {
      conn._db.dispose();
      throw GpkgException('File is not a valid GeoPackage: $e');
    }

    return conn;
  }

  /// Lists all feature tables in the GeoPackage
  ///
  /// Returns table names from `gpkg_contents` with data_type='features'.
  List<String> listFeatureTables() {
    _checkClosed();

    try {
      final stmt = _db.prepare('SELECT table_name FROM gpkg_contents WHERE data_type = ? ORDER BY table_name;');
      try {
        final tables = <String>[];
        for (final row in stmt.select(['features'])) {
          tables.add(row['table_name'] as String);
        }
        return tables;
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      throw GpkgException('Failed to list feature tables: $e');
    }
  }

  /// Gets metadata about a feature table
  ///
  /// Returns null if table doesn't exist.
  FeatureTableMetadata? getTableMetadata(String tableName) {
    _checkClosed();

    try {
      final contentStmt = _db.prepare(
        'SELECT identifier, description, min_x, min_y, max_x, max_y FROM gpkg_contents WHERE table_name = ?;',
      );
      Map<String, Object?>? contentRow;
      try {
        contentRow = contentStmt.select([tableName]).firstOrNull;
      } finally {
        contentStmt.dispose();
      }

      if (contentRow == null) return null;

      // Get geometry column info
      final geomStmt = _db.prepare(
        'SELECT column_name, geometry_type_name FROM gpkg_geometry_columns WHERE table_name = ?;',
      );
      Map<String, Object?>? geomRow;
      try {
        geomRow = geomStmt.select([tableName]).firstOrNull;
      } finally {
        geomStmt.dispose();
      }

      final geomCol = geomRow?['column_name'] as String? ?? 'geom';
      final attrCols = _getAttributeColumns(tableName, geomCol);

      final minX = (contentRow['min_x'] as num?)?.toDouble();
      final minY = (contentRow['min_y'] as num?)?.toDouble();
      final maxX = (contentRow['max_x'] as num?)?.toDouble();
      final maxY = (contentRow['max_y'] as num?)?.toDouble();
      final bounds = (minX != null && minY != null && maxX != null && maxY != null)
          ? Envelope(minX, minY, maxX, maxY)
          : null;
      return FeatureTableMetadata(
        tableName: tableName,
        identifier: contentRow['identifier'] as String?,
        description: contentRow['description'] as String?,
        geometryColumn: geomCol,
        geometryType: geomRow?['geometry_type_name'] as String? ?? 'GEOMETRY',
        bounds: bounds,
        attributeColumns: attrCols,
      );
    } catch (e) {
      throw GpkgException('Failed to get table metadata: $e');
    }
  }

  /// Queries features within a bounding box
  ///
  /// Returns a stream of [RawFeatureBatch] objects, each containing
  /// up to [batchSize] rows.
  ///
  /// The query uses R-Tree spatial index if available, otherwise falls
  /// back to full table scan with bbox filtering.
  Stream<RawFeatureBatch> queryFeaturesInBounds({
    required String table,
    required Envelope bounds,
    int batchSize = 1000,
    String? geometryColumn,
    int? maxFeatures,
    bool loadAttributes = false,
    List<String>? attributeColumns,
  }) async* {
    _checkClosed();

    // Resolve geometry column name
    final geomCol = geometryColumn ?? _getGeometryColumn(table);

    // Sanitize identifiers once — interpolated into SQL below inside double quotes.
    final safeTable = safeSqlId(table);
    final safeGeom = safeSqlId(geomCol);

    // Discover attribute columns if requested
    List<String>? columnsToSelect;
    if (loadAttributes) {
      final columnMetadata = _getAttributeColumns(table, geomCol);
      if (attributeColumns != null) {
        final validColumns = columnMetadata.map((c) => c.name).toSet();
        columnsToSelect = attributeColumns.where(validColumns.contains).toList();
      } else {
        columnsToSelect = columnMetadata.map((c) => c.name).toList();
      }
    }

    // Build SELECT clause
    final String selectClause;
    if (columnsToSelect == null || columnsToSelect.isEmpty) {
      selectClause = 'f.rowid as fid, f."$safeGeom" as geom';
    } else {
      final attrList = columnsToSelect.map((c) => 'f."${safeSqlId(c)}"').join(', ');
      selectClause = 'f.rowid as fid, f."$safeGeom" as geom, $attrList';
    }

    // Build R-Tree spatial query
    final safeRtreeTable = 'rtree_${safeTable}_$safeGeom';
    final hasRtree = SpatialIndex.exists(path, table, geomColumn: geomCol);

    final String query;
    final List<Object?> params;
    if (hasRtree) {
      query =
          '''
        SELECT $selectClause
        FROM "$safeTable" f
        WHERE f.rowid IN (
          SELECT id FROM "$safeRtreeTable"
          WHERE minx <= ? AND maxx >= ?
            AND miny <= ? AND maxy >= ?
        )
      ''';
      params = [bounds.maxX, bounds.minX, bounds.maxY, bounds.minY];
    } else {
      query = 'SELECT $selectClause FROM "$safeTable" f';
      params = const [];
    }

    final sqlite3.PreparedStatement stmt;
    try {
      stmt = _db.prepare(query);
    } catch (e) {
      throw GpkgException('Query prepare failed: $e');
    }

    // Critical: dispose [stmt] on EVERY exit path — stream cancellation,
    // exception, or normal completion. Without this, repeated viewport
    // queries leak prepared statements and eventually corrupt the connection
    // (cascade failures across other overlays sharing the worker isolate).
    try {
      final cursor = stmt.selectCursor(params);

      final fids = <int>[];
      final geoms = <Uint8List>[];
      final attrs = loadAttributes ? <Map<String, dynamic>>[] : null;
      var totalYielded = 0;

      while (cursor.moveNext()) {
        final row = cursor.current;
        fids.add(row['fid'] as int);
        geoms.add(row['geom'] as Uint8List);

        if (attrs != null && columnsToSelect != null) {
          final attrMap = <String, dynamic>{};
          for (final col in columnsToSelect) {
            attrMap[col] = row[col];
          }
          attrs.add(attrMap);
        }

        if (fids.length >= batchSize) {
          yield RawFeatureBatch(fids: fids.toList(), geoms: geoms.toList(), generation: 0, attributes: attrs?.toList());
          totalYielded += fids.length;
          fids.clear();
          geoms.clear();
          attrs?.clear();
          if (maxFeatures != null && totalYielded >= maxFeatures) break;
        }
      }

      if (fids.isNotEmpty && (maxFeatures == null || totalYielded < maxFeatures)) {
        yield RawFeatureBatch(fids: fids.toList(), geoms: geoms.toList(), generation: 0, attributes: attrs?.toList());
      }
    } finally {
      stmt.dispose();
    }
  }

  /// Detects the CRS of a specific feature table.
  ///
  /// Returns null if the table uses EPSG:4326 (WGS84) or no CRS info is found.
  CrsInfo? detectCrs(String table) {
    _checkClosed();
    try {
      final stmt = _db.prepare('''
        SELECT srs.srs_id, srs.organization, srs.organization_coordsys_id, srs.definition
        FROM gpkg_geometry_columns gc
        JOIN gpkg_spatial_ref_sys srs ON gc.srs_id = srs.srs_id
        WHERE gc.table_name = ? AND srs.srs_id != 4326
        LIMIT 1
      ''');
      try {
        final row = stmt.select([table]).firstOrNull;
        if (row == null) return null;
        return CrsInfo(
          srsId: row['srs_id'] as int,
          organization: row['organization'] as String?,
          epsgCode: row['organization_coordsys_id'] as int?,
          definition: row['definition'] as String?,
        );
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      throw GpkgException('Failed to detect CRS: $e');
    }
  }

  /// Returns a map of tableName → geometry_type_name for all feature tables.
  Map<String, String> getGeometryTypes() {
    _checkClosed();
    try {
      final stmt = _db.prepare('''
        SELECT table_name, geometry_type_name
        FROM gpkg_geometry_columns
      ''');
      try {
        final result = <String, String>{};
        for (final row in stmt.select([])) {
          result[row['table_name'] as String] = row['geometry_type_name'] as String;
        }
        return result;
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      throw GpkgException('Failed to get geometry types: $e');
    }
  }

  /// Queries features within bounds, returning typed [GeoFeature] objects
  ///
  /// Unlike [queryFeaturesInBounds] which returns raw WKB blobs,
  /// this method decodes geometries into domain entities
  /// for type-safe access.
  Stream<FeatureBatch> queryFeatures({
    required String table,
    required Envelope bounds,
    int batchSize = 1000,
    String? geometryColumn,
    int? maxFeatures,
    bool loadAttributes = false,
    List<String>? attributeColumns,
  }) async* {
    await for (final rawBatch in queryFeaturesInBounds(
      table: table,
      bounds: bounds,
      batchSize: batchSize,
      geometryColumn: geometryColumn,
      maxFeatures: maxFeatures,
      loadAttributes: loadAttributes,
      attributeColumns: attributeColumns,
    )) {
      final features = <GeoFeature>[];
      for (int i = 0; i < rawBatch.geoms.length; i++) {
        final geometry = WkbDecoder.decodeAsRecord(rawBatch.geoms[i]);
        if (geometry == null) continue;

        final attrs = rawBatch.attributes?[i] ?? const {};
        features.add(GeoFeature(fid: rawBatch.fids[i], geometry: geometry, attributes: attrs));
      }

      if (features.isNotEmpty) {
        yield FeatureBatch(features: features, generation: rawBatch.generation, tableName: table);
      }
    }
  }

  /// Queries every feature from a table without applying any spatial filter.
  ///
  /// Intended for full-table workflows like import/export, where the source
  /// GeoPackage may have stale bounds or an unhealthy source R-Tree.
  Stream<FeatureBatch> queryAllFeatures({
    required String table,
    int batchSize = 1000,
    String? geometryColumn,
    int? maxFeatures,
    bool loadAttributes = false,
    List<String>? attributeColumns,
  }) async* {
    _checkClosed();

    final geomCol = geometryColumn ?? _getGeometryColumn(table);
    final safeTable = safeSqlId(table);
    final safeGeom = safeSqlId(geomCol);

    List<String>? columnsToSelect;
    if (loadAttributes) {
      final columnMetadata = _getAttributeColumns(table, geomCol);
      if (attributeColumns != null) {
        final validColumns = columnMetadata.map((c) => c.name).toSet();
        columnsToSelect = attributeColumns.where(validColumns.contains).toList();
      } else {
        columnsToSelect = columnMetadata.map((c) => c.name).toList();
      }
    }

    final String selectClause;
    if (columnsToSelect == null || columnsToSelect.isEmpty) {
      selectClause = 'f.rowid as fid, f."$safeGeom" as geom';
    } else {
      final attrList = columnsToSelect.map((c) => 'f."${safeSqlId(c)}"').join(', ');
      selectClause = 'f.rowid as fid, f."$safeGeom" as geom, $attrList';
    }

    final sqlite3.PreparedStatement stmt;
    try {
      stmt = _db.prepare('SELECT $selectClause FROM "$safeTable" f');
    } catch (e) {
      throw GpkgException('Query prepare failed: $e');
    }

    try {
      final cursor = stmt.selectCursor(const []);

      final fids = <int>[];
      final geoms = <Uint8List>[];
      final attrs = loadAttributes ? <Map<String, dynamic>>[] : null;
      var totalYielded = 0;

      while (cursor.moveNext()) {
        final row = cursor.current;
        fids.add(row['fid'] as int);
        geoms.add(row['geom'] as Uint8List);

        if (attrs != null && columnsToSelect != null) {
          final attrMap = <String, dynamic>{};
          for (final col in columnsToSelect) {
            attrMap[col] = row[col];
          }
          attrs.add(attrMap);
        }

        if (fids.length >= batchSize) {
          final features = <GeoFeature>[];
          for (var i = 0; i < geoms.length; i++) {
            final geometry = WkbDecoder.decodeAsRecord(geoms[i]);
            if (geometry == null) continue;

            final featureAttrs = attrs?[i] ?? const <String, dynamic>{};
            features.add(GeoFeature(fid: fids[i], geometry: geometry, attributes: featureAttrs));
          }

          if (features.isNotEmpty) {
            yield FeatureBatch(features: features, generation: 0, tableName: table);
          }

          totalYielded += fids.length;
          fids.clear();
          geoms.clear();
          attrs?.clear();
          if (maxFeatures != null && totalYielded >= maxFeatures) break;
        }
      }

      if (fids.isNotEmpty && (maxFeatures == null || totalYielded < maxFeatures)) {
        final features = <GeoFeature>[];
        for (var i = 0; i < geoms.length; i++) {
          final geometry = WkbDecoder.decodeAsRecord(geoms[i]);
          if (geometry == null) continue;

          final featureAttrs = attrs?[i] ?? const <String, dynamic>{};
          features.add(GeoFeature(fid: fids[i], geometry: geometry, attributes: featureAttrs));
        }

        if (features.isNotEmpty) {
          yield FeatureBatch(features: features, generation: 0, tableName: table);
        }
      }
    } finally {
      stmt.dispose();
    }
  }

  /// Returns metadata for all feature tables in a single call
  Map<String, FeatureTableMetadata> getAllTableMetadata() {
    _checkClosed();
    final result = <String, FeatureTableMetadata>{};
    for (final table in listFeatureTables()) {
      final meta = getTableMetadata(table);
      if (meta != null) result[table] = meta;
    }
    return result;
  }

  /// Returns the row count for [tableName] via `SELECT COUNT(*)`.
  /// Returns -1 on error. Use when [FeatureTableMetadata.featureCount] is -1.
  int countFeatures(String tableName) {
    _checkClosed();
    return _getFeatureCount(tableName);
  }

  /// Closes the connection
  void close() {
    if (!_isClosed) {
      _db.dispose();
      _isClosed = true;
    }
  }

  void _checkClosed() {
    if (_isClosed) {
      throw GpkgException('Connection is closed');
    }
  }

  int _getFeatureCount(String tableName) {
    try {
      final stmt = _db.prepare('SELECT COUNT(*) as cnt FROM "${safeSqlId(tableName)}";');
      try {
        return stmt.select([]).first['cnt'] as int;
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      return -1;
    }
  }

  String _getGeometryColumn(String tableName) {
    try {
      final stmt = _db.prepare('SELECT column_name FROM gpkg_geometry_columns WHERE table_name = ?;');
      try {
        final row = stmt.select([tableName]).firstOrNull;
        return row?['column_name'] as String? ?? 'geom';
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      return 'geom';
    }
  }

  List<ColumnInfo> _getAttributeColumns(String tableName, String geomColumn) {
    return _columnCache.putIfAbsent(tableName, () {
      final stmt = _db.prepare('PRAGMA table_info("${safeSqlId(tableName)}")');
      try {
        final columns = <ColumnInfo>[];
        for (final row in stmt.select([])) {
          if ((row['pk'] as int) > 0) continue;
          final name = row['name'] as String;
          if (name == geomColumn) continue;
          columns.add(
            ColumnInfo(
              name: name,
              type: row['type'] as String?,
              notNull: (row['notnull'] as int) == 1,
              defaultValue: row['dflt_value'],
            ),
          );
        }
        return columns;
      } finally {
        stmt.dispose();
      }
    });
  }
}
