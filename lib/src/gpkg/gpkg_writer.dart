import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/entities/geometry/envelope.dart';
import 'package:shapekit/src/gpkg/types/column_info.dart';
import 'package:shapekit/src/gpkg/codec/wkb_encoder.dart';

String _safeId(String name) {
  return name.replaceAll('.', '_').replaceAll('"', '').replaceAll('\x00', '');
}

/// Creates and writes GeoPackage files.
///
/// Provides static methods to initialize a new GeoPackage, add feature tables,
/// and open streaming writers for bulk row insertion.
class GpkgWriter {
  /// Initializes a new GeoPackage file at [path].
  ///
  /// Creates the required GPKG metadata tables (`gpkg_spatial_ref_sys`,
  /// `gpkg_contents`, `gpkg_geometry_columns`) and inserts the EPSG:4326 row.
  static void initialize(String path) {
    final db = sqlite3.sqlite3.open(path);
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS gpkg_spatial_ref_sys (
          srs_name TEXT NOT NULL,
          srs_id INTEGER PRIMARY KEY,
          organization TEXT NOT NULL,
          organization_coordsys_id INTEGER NOT NULL,
          definition TEXT NOT NULL
        )
      ''');

      // Insert EPSG:4326 if not present
      final count =
          db.select("SELECT COUNT(*) as cnt FROM gpkg_spatial_ref_sys WHERE srs_id = 4326").first['cnt'] as int;
      if (count == 0) {
        db.execute("INSERT INTO gpkg_spatial_ref_sys VALUES (?, ?, ?, ?, ?)", [
          'WGS 84',
          4326,
          'EPSG',
          4326,
          'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]]',
        ]);
      }

      db.execute('''
        CREATE TABLE IF NOT EXISTS gpkg_contents (
          table_name TEXT NOT NULL PRIMARY KEY,
          data_type TEXT NOT NULL,
          identifier TEXT UNIQUE,
          description TEXT,
          last_change DATETIME NOT NULL,
          min_x DOUBLE,
          min_y DOUBLE,
          max_x DOUBLE,
          max_y DOUBLE,
          srs_id INTEGER
        )
      ''');

      db.execute('''
        CREATE TABLE IF NOT EXISTS gpkg_geometry_columns (
          table_name TEXT NOT NULL,
          column_name TEXT NOT NULL,
          geometry_type_name TEXT NOT NULL,
          srs_id INTEGER NOT NULL,
          z TINYINT NOT NULL,
          m TINYINT NOT NULL,
          PRIMARY KEY (table_name, column_name)
        )
      ''');
    } finally {
      db.dispose();
    }
  }

  /// Adds a feature table to an already-initialized GeoPackage.
  ///
  /// Creates the table with `fid INTEGER PRIMARY KEY`, [geomColumn] `BLOB NOT NULL`,
  /// and any additional [columns] from the explicit schema. Inserts metadata into
  /// `gpkg_contents` and `gpkg_geometry_columns`.
  ///
  /// All identifiers are sanitized before SQL interpolation to prevent injection.
  static void addFeatureTable(
    String path,
    String tableName, {
    String geomColumn = 'geom',
    String geomType = 'GEOMETRY',
    int srsId = 4326,
    Envelope bounds = const Envelope(-180, -90, 180, 90),
    List<ColumnDef>? columns,
  }) {
    final safeTable = _safeId(tableName);
    final safeGeom = _safeId(geomColumn);
    final db = sqlite3.sqlite3.open(path);
    try {
      final colDefs = columns != null && columns.isNotEmpty
          ? ', ${columns.map((c) => '"${_safeId(c.name)}" ${c.sqlType}').join(', ')}'
          : '';
      db.execute(
        'CREATE TABLE IF NOT EXISTS "$safeTable" '
        '(fid INTEGER PRIMARY KEY, "$safeGeom" BLOB NOT NULL$colDefs)',
      );
      db.execute("INSERT INTO gpkg_contents VALUES (?, ?, ?, ?, datetime('now'), ?, ?, ?, ?, ?)", [
        tableName,
        'features',
        tableName,
        null,
        bounds.minX,
        bounds.minY,
        bounds.maxX,
        bounds.maxY,
        srsId,
      ]);
      db.execute('INSERT INTO gpkg_geometry_columns VALUES (?, ?, ?, ?, ?, ?)', [
        tableName,
        geomColumn,
        geomType,
        srsId,
        0,
        0,
      ]);
    } finally {
      db.dispose();
    }
  }

  /// Opens a [GpkgTableWriter] for streaming row inserts into [tableName].
  ///
  /// The table must already exist (call [addFeatureTable] first).
  static GpkgTableWriter openTableWriter(String path, String tableName, {String geomColumn = 'geom'}) {
    return GpkgTableWriter._(path, tableName, geomColumn);
  }
}

/// Streaming writer for bulk row insertion into a GeoPackage feature table.
///
/// Batches rows in transactions of 1000 for performance. Schema must be defined
/// upfront via [GpkgWriter.addFeatureTable] — no auto-migration. Keys that do not
/// match existing columns will cause a SQLite error (fail fast).
class GpkgTableWriter {
  final sqlite3.Database _db;
  final String _tableName;
  final String _geomColumn;
  sqlite3.PreparedStatement? _insertStmt;
  String? _insertSql;
  int _batchCount = 0;

  GpkgTableWriter._(String path, String tableName, String geomColumn)
    : _db = sqlite3.sqlite3.open(path),
      _tableName = _safeId(tableName),
      _geomColumn = _safeId(geomColumn) {
    _db.execute('BEGIN TRANSACTION');
  }

  /// Inserts one row with a geometry blob and optional property columns.
  ///
  /// Property keys are sanitized. Values are coerced to SQLite-compatible types.
  /// Keys not present in the table schema will cause a SQLite error.
  void writeRow(List<int> geomBlob, Map<String, dynamic> properties) {
    final coerced = <String, dynamic>{};
    for (final e in properties.entries) {
      coerced[_safeId(e.key)] = _coerceValue(e.value);
    }

    final keys = coerced.keys.toList(growable: false);

    final sql = _buildInsertSql(keys);
    if (sql != _insertSql) {
      _insertStmt?.dispose();
      _insertSql = sql;
      _insertStmt = _db.prepare(sql);
    }

    final params = <Object?>[geomBlob];
    params.addAll(coerced.values);
    _insertStmt!.execute(params);

    _batchCount++;
    if (_batchCount >= 1000) {
      _db.execute('COMMIT');
      _db.execute('BEGIN TRANSACTION');
      _batchCount = 0;
    }
  }

  /// Write a feature with typed geometry.
  ///
  /// Encodes the geometry to WKB internally and writes with properties.
  void writeFeature(Record geometry, Map<String, dynamic> properties) {
    final blob = WkbEncoder.encode(geometry);
    writeRow(blob, properties);
  }

  /// Flushes remaining rows, commits transaction, and closes the database.
  Future<void> close() async {
    _db.execute('COMMIT');
    _insertStmt?.dispose();
    _db.dispose();
  }

  String _buildInsertSql(Iterable<String> propKeys) {
    if (propKeys.isEmpty) {
      return 'INSERT INTO "$_tableName" ("$_geomColumn") VALUES (?)';
    }
    final cols = '"$_geomColumn", ${propKeys.map((k) => '"${_safeId(k)}"').join(', ')}';
    final placeholders = List.filled(1 + propKeys.length, '?').join(', ');
    return 'INSERT INTO "$_tableName" ($cols) VALUES ($placeholders)';
  }

  static Object? _coerceValue(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is bool || value is int || value is num || value is String || value is List<int>) {
      return value;
    }
    return value.toString();
  }
}
