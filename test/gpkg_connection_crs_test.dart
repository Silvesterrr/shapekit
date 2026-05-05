import 'dart:io';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:shapekit/src/gpkg/gpkg_reader.dart';
import 'package:shapekit/src/gpkg/gpkg_writer.dart';

void main() {
  group('GpkgReader CRS', () {
    late String testDbPath;

    setUp(() {
      testDbPath = 'test_gpkg_${DateTime.now().millisecondsSinceEpoch}.gpkg';
    });

    tearDown(() {
      if (File(testDbPath).existsSync()) {
        File(testDbPath).deleteSync();
      }
    });

    test('detectCrs on WGS84-only GPKG returns null', () {
      GpkgWriter.initialize(testDbPath);
      GpkgWriter.addFeatureTable(testDbPath, 'test', geomType: 'POINT', srsId: 4326);

      final conn = GpkgReader.open(testDbPath);
      expect(conn.detectCrs('test'), isNull);
      conn.close();
    });

    test('detectCrs on custom srsId returns CrsInfo', () {
      GpkgWriter.initialize(testDbPath);

      // Insert non-4326 SRS and a feature table using it
      final db = sqlite3.sqlite3.open(testDbPath);
      db.execute(
        'INSERT INTO gpkg_spatial_ref_sys VALUES (?, ?, ?, ?, ?)',
        ['EPSG:3857', 3857, 'EPSG', 3857, 'proj4def'],
      );
      db.execute(
        'INSERT INTO gpkg_geometry_columns VALUES (?, ?, ?, ?, ?, ?)',
        ['test_3857', 'geom', 'POINT', 3857, 0, 0],
      );
      db.execute(
        'CREATE TABLE test_3857 (fid INTEGER PRIMARY KEY, geom BLOB NOT NULL)',
      );
      db.execute(
        "INSERT INTO gpkg_contents VALUES (?, ?, ?, ?, datetime('now'), ?, ?, ?, ?, ?)",
        ['test_3857', 'features', null, null, null, null, null, null, 3857],
      );
      db.dispose();

      final conn = GpkgReader.open(testDbPath);
      final crs = conn.detectCrs('test_3857');
      expect(crs, isNotNull);
      expect(crs!.epsgCode, equals(3857));
      expect(crs.organization, equals('EPSG'));
      conn.close();
    });

    test('getGeometryTypes returns correct map', () {
      GpkgWriter.initialize(testDbPath);
      GpkgWriter.addFeatureTable(testDbPath, 'points', geomType: 'POINT');
      GpkgWriter.addFeatureTable(testDbPath, 'lines', geomType: 'LINESTRING');

      final conn = GpkgReader.open(testDbPath);
      final types = conn.getGeometryTypes();
      expect(types['points'], equals('POINT'));
      expect(types['lines'], equals('LINESTRING'));
      conn.close();
    });
  });
}
