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

      shapefile.writerEntirety(
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

      shapefile.writerEntirety(
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

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOLYLINE,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
      );

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

      shapefile.writerEntirety(filePath, ShapeType.shapePOLYGON, records, minX: 0.0, minY: 0.0, maxX: 10.0, maxY: 10.0);

      expect(File(filePath).existsSync(), isTrue);
    });

    test('writes multiple records', () {
      final filePath = '${tempDir.path}/test_multiple.shp';
      final shapefile = Shapefile();

      final records = List.generate(100, (i) => Point(i.toDouble(), i.toDouble()));

      shapefile.writerEntirety(filePath, ShapeType.shapePOINT, records, minX: 0.0, minY: 0.0, maxX: 99.0, maxY: 99.0);

      expect(File(filePath).existsSync(), isTrue);
    });

    test('writes shapefile with Z values', () {
      final filePath = '${tempDir.path}/test_pointz.shp';
      final shapefile = Shapefile();

      final records = [PointZ(126.9780, 37.5665, 42.5, 123.4), PointZ(129.0756, 35.1796, 50.0, 200.0)];

      shapefile.writerEntirety(
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

      shapefile.writerEntirety(filePath, ShapeType.shapePOINT, [], minX: 0.0, minY: 0.0, maxX: 0.0, maxY: 0.0);

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

      final result = shapefile.writer(filePath);

      expect(result, isTrue);
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

      final result = shapefile.writer(filePath);

      expect(result, isTrue);
      expect(File('${tempDir.path}/test_stepbystep_attrs.dbf').existsSync(), isTrue);
    });
  });

  group('File Cleanup', () {
    test('close() releases file handles', () {
      final filePath = '${tempDir.path}/test_close.shp';
      final shapefile = Shapefile();

      shapefile.writerEntirety(
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
