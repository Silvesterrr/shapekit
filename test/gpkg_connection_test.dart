import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:shapekit/src/domain/entities/geometry/envelope.dart';
import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart' show FileNotFoundException;
import 'package:shapekit/src/gpkg/exceptions.dart' show GpkgException;
import 'package:shapekit/src/gpkg/gpkg_reader.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('GpkgReader', () {
    late String testDbPath;

    setUp(() {
      testDbPath = 'test_gpkg_${DateTime.now().millisecondsSinceEpoch}.gpkg';
    });

    tearDown(() {
      if (File(testDbPath).existsSync()) {
        File(testDbPath).deleteSync();
      }
    });

    test('can open a valid GeoPackage file', () {
      _createTestGeoPackage(testDbPath);

      final conn = GpkgReader.open(testDbPath);

      expect(conn.path, testDbPath);

      conn.close();
    });

    test('throws when opening non-existent file', () {
      expect(
        () => GpkgReader.open('nonexistent.gpkg'),
        throwsA(anyOf(isA<GpkgException>(), isA<FileNotFoundException>())),
      );
    });

    test('can list feature tables', () {
      _createTestGeoPackage(testDbPath, tableCount: 2);

      final conn = GpkgReader.open(testDbPath);
      final tables = conn.listFeatureTables();

      expect(tables, isNotEmpty);
      expect(tables.length, equals(2));
      expect(tables[0], startsWith('test_'));

      conn.close();
    });

    test('can get table metadata', () {
      _createTestGeoPackage(testDbPath);

      final conn = GpkgReader.open(testDbPath);
      final tables = conn.listFeatureTables();
      expect(tables, isNotEmpty);

      final metadata = conn.getTableMetadata(tables[0]);

      expect(metadata, isNotNull);
      expect(metadata!.tableName, tables[0]);
      expect(metadata.geometryColumn, 'geom');
      expect(metadata.bounds, equals(Envelope(-180, -90, 180, 90)));

      conn.close();
    });

    test('can stream features with selectCursor', () async {
      _createTestGeoPackage(testDbPath, featureCount: 100);

      final conn = GpkgReader.open(testDbPath);
      final tables = conn.listFeatureTables();
      expect(tables, isNotEmpty);

      final stream = conn.queryFeaturesInBounds(table: tables[0], bounds: Envelope(-180, -90, 180, 90), batchSize: 20);

      int totalFeatures = 0;
      int batchCount = 0;

      await for (final batch in stream) {
        expect(batch.fids, isNotEmpty);
        expect(batch.geoms.length, equals(batch.fids.length));
        expect(batch.generation, equals(0));

        totalFeatures += batch.fids.length;
        batchCount++;
      }

      expect(totalFeatures, equals(100));
      expect(batchCount, greaterThan(1));

      conn.close();
    });

    test('respects batchSize parameter', () async {
      _createTestGeoPackage(testDbPath, featureCount: 100);

      final conn = GpkgReader.open(testDbPath);
      final tables = conn.listFeatureTables();

      final stream = conn.queryFeaturesInBounds(table: tables[0], bounds: Envelope(-180, -90, 180, 90), batchSize: 25);

      await for (final batch in stream) {
        expect(batch.fids.length, lessThanOrEqualTo(25));
      }

      conn.close();
    });

    test('connection throws when already closed', () {
      _createTestGeoPackage(testDbPath);

      final conn = GpkgReader.open(testDbPath);
      conn.close();

      expect(() => conn.listFeatureTables(), throwsA(isA<GpkgException>()));
    });
  });
}

void _createTestGeoPackage(String path, {int tableCount = 1, int featureCount = 10}) {
  final db = sqlite3.open(path);

  try {
    db.execute('''
      CREATE TABLE gpkg_spatial_ref_sys (
        srs_id INTEGER PRIMARY KEY,
        organization TEXT,
        organization_coordsys_id INTEGER,
        definition TEXT
      );
    ''');

    db.execute('''
      INSERT INTO gpkg_spatial_ref_sys VALUES (
        4326, 'EPSG', 4326, 'WGS84'
      );
    ''');

    db.execute('''
      CREATE TABLE gpkg_contents (
        table_name TEXT PRIMARY KEY,
        data_type TEXT,
        identifier TEXT,
        description TEXT,
        last_change TEXT,
        min_x REAL,
        min_y REAL,
        max_x REAL,
        max_y REAL,
        srs_id INTEGER
      );
    ''');

    db.execute('''
      CREATE TABLE gpkg_geometry_columns (
        table_name TEXT,
        column_name TEXT,
        geometry_type_name TEXT,
        srs_id INTEGER,
        z INTEGER,
        m INTEGER,
        PRIMARY KEY (table_name, column_name)
      );
    ''');

    for (int t = 0; t < tableCount; t++) {
      final tableName = 'test_table_$t';

      db.execute('''
        CREATE TABLE $tableName (
          rowid INTEGER PRIMARY KEY,
          geom BLOB NOT NULL
        );
      ''');

      db.execute('''
        INSERT INTO gpkg_contents VALUES (
          '$tableName', 'features', '$tableName', 'Test table',
          datetime('now'), -180, -90, 180, 90, 4326
        );
      ''');

      db.execute('''
        INSERT INTO gpkg_geometry_columns VALUES (
          '$tableName', 'geom', 'POINT', 4326, 0, 0
        );
      ''');

      final insertStmt = db.prepare('INSERT INTO $tableName (geom) VALUES (?);');

      for (int i = 0; i < featureCount; i++) {
        final x = -180.0 + (i % 10) * 36.0;
        final y = -90.0 + (i ~/ 10) * 45.0;

        final wkbBytes = _createGpkgWkbPoint(x, y);
        insertStmt.execute([wkbBytes]);
      }

      insertStmt.dispose();
    }
  } finally {
    db.dispose();
  }
}

/// Create a valid GPKG-WKB Point blob (8-byte header + ISO WKB Point).
Uint8List _createGpkgWkbPoint(double x, double y) {
  final bytes = ByteData(29); // 8 header + 21 ISO WKB

  // GPKG header
  bytes.setUint8(0, 0x47); // 'G'
  bytes.setUint8(1, 0x50); // 'P'
  bytes.setUint8(2, 0x00); // version
  bytes.setUint8(3, 0x01); // flags: little-endian, no envelope
  bytes.setInt32(4, 4326, Endian.little); // SRS_ID

  // ISO WKB Point
  bytes.setUint8(8, 0x01); // byte order: little-endian
  bytes.setUint32(9, 1, Endian.little); // geometry type: Point
  bytes.setFloat64(13, x, Endian.little);
  bytes.setFloat64(21, y, Endian.little);

  return bytes.buffer.asUint8List();
}
