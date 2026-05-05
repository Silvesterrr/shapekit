import 'dart:io';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:shapekit/src/gpkg/gpkg_reader.dart';
import 'package:shapekit/src/gpkg/gpkg_writer.dart';
import 'package:shapekit/src/gpkg/types/column_info.dart';
import 'package:shapekit/src/gpkg/codec/wkb_encoder.dart';
import 'package:shapekit/src/gpkg/spatial_index.dart';

void main() {
  group('GpkgWriter', () {
    late String testDbPath;

    setUp(() {
      testDbPath = 'test_gpkg_${DateTime.now().millisecondsSinceEpoch}.gpkg';
    });

    tearDown(() {
      if (File(testDbPath).existsSync()) {
        File(testDbPath).deleteSync();
      }
    });

    test('initialize creates a valid GeoPackage', () {
      GpkgWriter.initialize(testDbPath);

      final conn = GpkgReader.open(testDbPath);
      expect(conn.listFeatureTables(), isEmpty);
      conn.close();
    });

    test('addFeatureTable + 50 rows -> featureCount == 50', () {
      GpkgWriter.initialize(testDbPath);
      GpkgWriter.addFeatureTable(testDbPath, 'points', geomType: 'POINT');

      final writer = GpkgWriter.openTableWriter(testDbPath, 'points');
      for (int i = 0; i < 50; i++) {
        final blob = WkbEncoder.encodePoint(i.toDouble(), i.toDouble());
        writer.writeRow(blob, {});
      }
      writer.close();

      final conn = GpkgReader.open(testDbPath);
      expect(conn.countFeatures('points'), equals(50));
      conn.close();
    });

    test('writeRow with properties -> survive roundtrip', () {
      GpkgWriter.initialize(testDbPath);
      GpkgWriter.addFeatureTable(testDbPath, 'test', geomType: 'POINT', columns: [
        ColumnDef.text('name'),
        ColumnDef.text('value'),
      ]);

      final writer = GpkgWriter.openTableWriter(testDbPath, 'test');
      writer.writeRow(
        WkbEncoder.encodePoint(0, 0),
        {'name': 'test', 'value': '42'},
      );
      writer.close();

      final db = sqlite3.sqlite3.open(testDbPath);
      final stmt = db.prepare('SELECT name, value FROM test');
      final row = stmt.select([]).first;
      expect(row['name'], equals('test'));
      expect(row['value'], equals('42'));
      stmt.dispose();
      db.dispose();
    });

    test('100 points -> SpatialIndex.build -> R-Tree COUNT == 100', () async {
      GpkgWriter.initialize(testDbPath);
      GpkgWriter.addFeatureTable(testDbPath, 'points', geomType: 'POINT');

      final writer = GpkgWriter.openTableWriter(testDbPath, 'points');
      for (int i = 0; i < 100; i++) {
        writer.writeRow(WkbEncoder.encodePoint(i.toDouble(), i.toDouble()), {});
      }
      writer.close();

      await SpatialIndex.build(testDbPath, 'points');

      final db = sqlite3.sqlite3.open(testDbPath);
      final stmt = db.prepare('SELECT COUNT(*) as cnt FROM rtree_points_geom');
      final row = stmt.select([]).first;
      expect(row['cnt'], equals(100));
      stmt.dispose();
      db.dispose();
    });
  });
}
