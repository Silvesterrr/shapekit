import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:shapekit/src/gpkg/spatial_index.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('SpatialIndex', () {
    late String testDbPath;

    setUp(() {
      testDbPath = 'test_gpkg_spatial_${DateTime.now().millisecondsSinceEpoch}.gpkg';
    });

    tearDown(() {
      if (File(testDbPath).existsSync()) {
        File(testDbPath).deleteSync();
      }
    });

    test('build creates R-Tree index', () async {
      _createTestDb(testDbPath, featureCount: 50).dispose();

      expect(SpatialIndex.exists(testDbPath, 'features'), isFalse);
      await SpatialIndex.build(testDbPath, 'features');
      expect(SpatialIndex.exists(testDbPath, 'features'), isTrue);

      final db = sqlite3.open(testDbPath);
      try {
        final row = db.select('SELECT COUNT(*) as cnt FROM rtree_features_geom').first;
        expect(row['cnt'], equals(50));
      } finally {
        db.dispose();
      }
    });

    test('build is no-op when index already populated', () async {
      _createTestDb(testDbPath, featureCount: 20).dispose();

      await SpatialIndex.build(testDbPath, 'features');
      await SpatialIndex.build(testDbPath, 'features');

      final db = sqlite3.open(testDbPath);
      try {
        final row = db.select('SELECT COUNT(*) as cnt FROM rtree_features_geom').first;
        expect(row['cnt'], equals(20));
      } finally {
        db.dispose();
      }
    });

    test('exists returns false when no index', () {
      _createTestDb(testDbPath, featureCount: 0).dispose();
      expect(SpatialIndex.exists(testDbPath, 'features'), isFalse);
    });

    test('build works with no-envelope blobs (fallback to decode)', () async {
      _createTestDbNoEnvelope(testDbPath, featureCount: 10).dispose();

      await SpatialIndex.build(testDbPath, 'features');

      final db = sqlite3.open(testDbPath);
      try {
        final row = db.select('SELECT COUNT(*) as cnt FROM rtree_features_geom').first;
        expect(row['cnt'], equals(10));
      } finally {
        db.dispose();
      }
    });
  });
}

Database _createTestDb(String path, {int featureCount = 10}) {
  final db = sqlite3.open(path);

  db.execute('''
    CREATE TABLE features (
      id INTEGER PRIMARY KEY,
      geom BLOB NOT NULL
    )
  ''');

  final stmt = db.prepare('INSERT INTO features (geom) VALUES (?)');

  for (int i = 0; i < featureCount; i++) {
    final x = i * 1.0;
    final y = i * 1.0;
    stmt.execute([_createGpkgPoint(x, y)]);
  }

  stmt.dispose();
  return db;
}

Uint8List _createGpkgPoint(double x, double y) {
  final totalSize = 8 + 32 + 21; // header + XY envelope + WKB
  final buf = ByteData(totalSize);

  buf.setUint8(0, 0x47);
  buf.setUint8(1, 0x50);
  buf.setUint8(2, 0x00);
  buf.setUint8(3, 0x03); // little-endian + XY envelope (indicator=1)
  buf.setInt32(4, 4326, Endian.little);

  // Envelope: minX, maxX, minY, maxY
  buf.setFloat64(8, x - 0.5, Endian.little);
  buf.setFloat64(16, x + 0.5, Endian.little);
  buf.setFloat64(24, y - 0.5, Endian.little);
  buf.setFloat64(32, y + 0.5, Endian.little);

  // ISO WKB Point
  buf.setUint8(40, 0x01);
  buf.setUint32(41, 1, Endian.little);
  buf.setFloat64(45, x, Endian.little);
  buf.setFloat64(53, y, Endian.little);

  return buf.buffer.asUint8List();
}

Uint8List _createGpkgPointNoEnvelope(double x, double y) {
  final buf = ByteData(29); // 8 header (no envelope) + 21 WKB

  buf.setUint8(0, 0x47);
  buf.setUint8(1, 0x50);
  buf.setUint8(2, 0x00);
  buf.setUint8(3, 0x01); // little-endian, no envelope (indicator=0)
  buf.setInt32(4, 4326, Endian.little);

  // ISO WKB Point
  buf.setUint8(8, 0x01);
  buf.setUint32(9, 1, Endian.little);
  buf.setFloat64(13, x, Endian.little);
  buf.setFloat64(21, y, Endian.little);

  return buf.buffer.asUint8List();
}

Database _createTestDbNoEnvelope(String path, {int featureCount = 10}) {
  final db = sqlite3.open(path);

  db.execute('''
    CREATE TABLE features (
      id INTEGER PRIMARY KEY,
      geom BLOB NOT NULL
    )
  ''');

  final stmt = db.prepare('INSERT INTO features (geom) VALUES (?)');

  for (int i = 0; i < featureCount; i++) {
    stmt.execute([_createGpkgPointNoEnvelope(i * 1.0, i * 2.0)]);
  }

  stmt.dispose();
  return db;
}
