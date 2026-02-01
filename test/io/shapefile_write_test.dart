import 'dart:io';
import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    // Create a temporary directory for test files
    tempDir = Directory.systemTemp.createTempSync('shapekit_test_');
  });

  tearDown(() {
    // Clean up temporary files
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Shapefile Writing', () {
    test('writes a simple point shapefile', () {
      final filePath = '${tempDir.path}/test_points.shp';
      final shapefile = Shapefile();

      final records = [Point(126.9780, 37.5665), Point(129.0756, 35.1796)];

      shapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 126.9780,
        minY: 35.1796,
        maxX: 129.0756,
        maxY: 37.5665,
      );

      // Verify files were created
      expect(File(filePath).existsSync(), isTrue);
      expect(File('${tempDir.path}/test_points.shx').existsSync(), isTrue);
    });

    test('writes a shapefile with attributes', () {
      final filePath = '${tempDir.path}/test_with_attrs.shp';
      final shapefile = Shapefile();

      final records = [Point(0.0, 0.0), Point(10.0, 10.0)];

      final fields = [DbaseField.fieldC('NAME', 50), DbaseField.fieldN('VALUE', 10)];

      final attributes = [
        ['Point A', 100],
        ['Point B', 200],
      ];

      shapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      // Verify all files were created
      expect(File(filePath).existsSync(), isTrue);
      expect(File('${tempDir.path}/test_with_attrs.shx').existsSync(), isTrue);
      expect(File('${tempDir.path}/test_with_attrs.dbf').existsSync(), isTrue);
    });

    test('writes a polyline shapefile', () {
      final filePath = '${tempDir.path}/test_polyline.shp';
      final shapefile = Shapefile();

      final records = [
        Polyline(
          bounds: Bounds(0.0, 0.0, 10.0, 10.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0)],
        ),
      ];

      shapefile.writeComplete(filePath, ShapeType.shapePOLYLINE, records, minX: 0.0, minY: 0.0, maxX: 10.0, maxY: 10.0);

      expect(File(filePath).existsSync(), isTrue);
    });

    test('writes a polygon shapefile', () {
      final filePath = '${tempDir.path}/test_polygon.shp';
      final shapefile = Shapefile();

      final records = [
        Polygon(
          bounds: Bounds(0.0, 0.0, 10.0, 10.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 10.0), Point(0.0, 0.0)],
        ),
      ];

      shapefile.writeComplete(filePath, ShapeType.shapePOLYGON, records, minX: 0.0, minY: 0.0, maxX: 10.0, maxY: 10.0);

      expect(File(filePath).existsSync(), isTrue);
    });

    test('writes multiple records', () {
      final filePath = '${tempDir.path}/test_multiple.shp';
      final shapefile = Shapefile();

      final records = List.generate(100, (i) => Point(i.toDouble(), i.toDouble()));

      shapefile.writeComplete(filePath, ShapeType.shapePOINT, records, minX: 0.0, minY: 0.0, maxX: 99.0, maxY: 99.0);

      expect(File(filePath).existsSync(), isTrue);
    });

    test('writes shapefile with Z values', () {
      final filePath = '${tempDir.path}/test_pointz.shp';
      final shapefile = Shapefile();

      final records = [PointZ(126.9780, 37.5665, 42.5, 123.4), PointZ(129.0756, 35.1796, 50.0, 200.0)];

      shapefile.writeComplete(
        filePath,
        ShapeType.shapePOINTZ,
        records,
        minX: 126.9780,
        minY: 35.1796,
        maxX: 129.0756,
        maxY: 37.5665,
        minZ: 42.5,
        maxZ: 50.0,
        minM: 123.4,
        maxM: 200.0,
      );

      expect(File(filePath).existsSync(), isTrue);
    });

    test('handles empty records list', () {
      final filePath = '${tempDir.path}/test_empty.shp';
      final shapefile = Shapefile();

      shapefile.writeComplete(filePath, ShapeType.shapePOINT, [], minX: 0.0, minY: 0.0, maxX: 0.0, maxY: 0.0);

      expect(File(filePath).existsSync(), isTrue);
    });

    test('writes a multipoint shapefile', () {
      final filePath = '${tempDir.path}/test_multipoint.shp';
      final shapefile = Shapefile();

      final records = [
        MultiPoint(points: [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0)], bounds: Bounds(0.0, 0.0, 10.0, 10.0)),
        MultiPoint(points: [Point(20.0, 20.0), Point(25.0, 25.0)], bounds: Bounds(20.0, 20.0, 25.0, 25.0)),
      ];

      shapefile.writeComplete(
        filePath,
        ShapeType.shapeMULTIPOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 25.0,
        maxY: 25.0,
      );

      expect(File(filePath).existsSync(), isTrue);
      expect(File('${tempDir.path}/test_multipoint.shx').existsSync(), isTrue);
    });

    test('writes a multipointM shapefile', () {
      final filePath = '${tempDir.path}/test_multipointm.shp';
      final shapefile = Shapefile();

      final records = [
        MultiPointM(
          points: [Point(0.0, 0.0), Point(10.0, 10.0)],
          arrayM: [1.0, 2.0],
          bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 1.0, 2.0),
        ),
      ];

      shapefile.writeComplete(
        filePath,
        ShapeType.shapeMULTIPOINTM,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        minM: 1.0,
        maxM: 2.0,
      );

      expect(File(filePath).existsSync(), isTrue);
    });

    test('writes a multipointZ shapefile', () {
      final filePath = '${tempDir.path}/test_multipointz.shp';
      final shapefile = Shapefile();

      final records = [
        MultiPointZ(
          points: [Point(0.0, 0.0), Point(10.0, 10.0)],
          arrayZ: [100.0, 200.0],
          arrayM: [1.0, 2.0],
          bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 1.0, 2.0, 100.0, 200.0),
        ),
      ];

      shapefile.writeComplete(
        filePath,
        ShapeType.shapeMULTIPOINTZ,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        minZ: 100.0,
        maxZ: 200.0,
        minM: 1.0,
        maxM: 2.0,
      );

      expect(File(filePath).existsSync(), isTrue);
    });
  });

  group('Shapefile Writing - Step by Step', () {
    test('writes shapefile using step-by-step API', () {
      final filePath = '${tempDir.path}/test_stepbystep.shp';
      final shapefile = Shapefile();

      shapefile.setHeaderType(ShapeType.shapePOINT);
      shapefile.setHeaderBound(0.0, 0.0, 10.0, 10.0);
      shapefile.setRecords([Point(5.0, 5.0)]);

      shapefile.write(filePath);

      expect(File(filePath).existsSync(), isTrue);
    });

    test('writes shapefile with attributes using step-by-step API', () {
      final filePath = '${tempDir.path}/test_stepbystep_attrs.shp';
      final shapefile = Shapefile();

      shapefile.setHeaderType(ShapeType.shapePOINT);
      shapefile.setHeaderBound(0.0, 0.0, 10.0, 10.0);
      shapefile.setRecords([Point(5.0, 5.0)]);
      shapefile.setAttributeField([DbaseField.fieldC('NAME', 50)]);
      shapefile.setAttributeRecord([
        ['Test Point'],
      ]);

      shapefile.write(filePath);

      expect(File('${tempDir.path}/test_stepbystep_attrs.dbf').existsSync(), isTrue);
    });
  });

  group('File Cleanup', () {
    test('close() releases file handles', () {
      final filePath = '${tempDir.path}/test_close.shp';
      final shapefile = Shapefile();

      shapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        [Point(0.0, 0.0)],
        minX: 0.0,
        minY: 0.0,
        maxX: 0.0,
        maxY: 0.0,
      );

      shapefile.close();

      // Should be able to delete files after closing
      expect(() => File(filePath).deleteSync(), returnsNormally);
    });

    test('dispose() releases resources', () {
      final shapefile = Shapefile();

      shapefile.setHeaderType(ShapeType.shapePOINT);
      shapefile.setRecords([Point(0.0, 0.0)]);

      expect(() => shapefile.dispose(), returnsNormally);
    });
  });
}
