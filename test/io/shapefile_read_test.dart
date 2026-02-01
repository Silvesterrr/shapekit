import 'dart:io';
import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('shapekit_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Shapefile Reading', () {
    test('reads a point shapefile', () {
      // First, create a test shapefile
      final filePath = '${tempDir.path}/test_read_points.shp';
      final writeShapefile = Shapefile();

      final records = [Point(126.9780, 37.5665), Point(129.0756, 35.1796)];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 126.9780,
        minY: 35.1796,
        maxX: 129.0756,
        maxY: 37.5665,
      );

      // Now read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(2));
      expect(readShapefile.records[0], isA<Point>());
      expect(readShapefile.records[1], isA<Point>());

      final point1 = readShapefile.records[0] as Point;
      final point2 = readShapefile.records[1] as Point;

      expect(point1.x, closeTo(126.9780, 0.0001));
      expect(point1.y, closeTo(37.5665, 0.0001));
      expect(point2.x, closeTo(129.0756, 0.0001));
      expect(point2.y, closeTo(35.1796, 0.0001));
    });

    test('reads a shapefile with attributes', () {
      final filePath = '${tempDir.path}/test_read_attrs.shp';
      final writeShapefile = Shapefile();

      final records = [Point(0.0, 0.0), Point(10.0, 10.0)];

      final fields = [DbaseField.fieldC('NAME', 50), DbaseField.fieldN('VALUE', 10)];

      final attributes = [
        ['Point A', 100],
        ['Point B', 200],
      ];

      writeShapefile.writeComplete(
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

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.attributeFields.length, equals(2));
      expect(readShapefile.attributeRecords.length, equals(2));

      expect(readShapefile.attributeFields[0].name, equals('NAME'));
      expect(readShapefile.attributeFields[1].name, equals('VALUE'));

      expect(readShapefile.attributeRecords[0][0].toString().trim(), equals('Point A'));
      expect(readShapefile.attributeRecords[0][1], equals(100));
      expect(readShapefile.attributeRecords[1][0].toString().trim(), equals('Point B'));
      expect(readShapefile.attributeRecords[1][1], equals(200));
    });

    test('reads a polyline shapefile', () {
      final filePath = '${tempDir.path}/test_read_polyline.shp';
      final writeShapefile = Shapefile();

      final records = [
        Polyline(
          bounds: Bounds(0.0, 0.0, 10.0, 10.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0)],
        ),
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOLYLINE,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<Polyline>());

      final polyline = readShapefile.records[0] as Polyline;
      expect(polyline.numParts, equals(1));
      expect(polyline.numPoints, equals(3));
    });

    test('reads a polygon shapefile', () {
      final filePath = '${tempDir.path}/test_read_polygon.shp';
      final writeShapefile = Shapefile();

      final records = [
        Polygon(
          bounds: Bounds(0.0, 0.0, 10.0, 10.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 10.0), Point(0.0, 0.0)],
        ),
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOLYGON,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<Polygon>());

      final polygon = readShapefile.records[0] as Polygon;
      expect(polygon.numParts, equals(1));
      expect(polygon.numPoints, equals(5));
    });

    test('reads a polylineM shapefile', () {
      final filePath = '${tempDir.path}/test_read_polylinem.shp';
      final writeShapefile = Shapefile();

      final records = [
        PolylineM(
          bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 0.0, 14.142),
          parts: [0],
          points: [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0)],
          arrayM: [0.0, 7.071, 14.142],
        ),
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOLYLINEM,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        minM: 0.0,
        maxM: 14.142,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<PolylineM>());

      final polyline = readShapefile.records[0] as PolylineM;
      expect(polyline.numParts, equals(1));
      expect(polyline.numPoints, equals(3));
      expect(polyline.arrayM[0], closeTo(0.0, 0.0001));
      expect(polyline.arrayM[2], closeTo(14.142, 0.0001));
    });

    test('reads a polylineZ shapefile', () {
      final filePath = '${tempDir.path}/test_read_polylinez.shp';
      final writeShapefile = Shapefile();

      final records = [
        PolylineZ(
          bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 0.0, 14.142, 100.0, 200.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0)],
          arrayZ: [100.0, 150.0, 200.0],
          arrayM: [0.0, 7.071, 14.142],
        ),
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOLYLINEZ,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        minZ: 100.0,
        maxZ: 200.0,
        minM: 0.0,
        maxM: 14.142,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<PolylineZ>());

      final polyline = readShapefile.records[0] as PolylineZ;
      expect(polyline.numParts, equals(1));
      expect(polyline.numPoints, equals(3));
      expect(polyline.arrayZ[0], closeTo(100.0, 0.0001));
      expect(polyline.arrayZ[2], closeTo(200.0, 0.0001));
      expect(polyline.arrayM[0], closeTo(0.0, 0.0001));
    });

    test('reads a polygonM shapefile', () {
      final filePath = '${tempDir.path}/test_read_polygonm.shp';
      final writeShapefile = Shapefile();

      final records = [
        PolygonM(
          bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 0.0, 40.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 10.0), Point(0.0, 0.0)],
          arrayM: [0.0, 10.0, 20.0, 30.0, 40.0],
        ),
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOLYGONM,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        minM: 0.0,
        maxM: 40.0,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<PolygonM>());

      final polygon = readShapefile.records[0] as PolygonM;
      expect(polygon.numParts, equals(1));
      expect(polygon.numPoints, equals(5));
      expect(polygon.arrayM[0], closeTo(0.0, 0.0001));
      expect(polygon.arrayM[4], closeTo(40.0, 0.0001));
    });

    test('reads a polygonZ shapefile', () {
      final filePath = '${tempDir.path}/test_read_polygonz.shp';
      final writeShapefile = Shapefile();

      final records = [
        PolygonZ(
          bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 0.0, 40.0, 100.0, 150.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 10.0), Point(0.0, 0.0)],
          arrayZ: [100.0, 100.0, 150.0, 150.0, 100.0],
          arrayM: [0.0, 10.0, 20.0, 30.0, 40.0],
        ),
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOLYGONZ,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        minZ: 100.0,
        maxZ: 150.0,
        minM: 0.0,
        maxM: 40.0,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<PolygonZ>());

      final polygon = readShapefile.records[0] as PolygonZ;
      expect(polygon.numParts, equals(1));
      expect(polygon.numPoints, equals(5));
      expect(polygon.arrayZ[0], closeTo(100.0, 0.0001));
      expect(polygon.arrayZ[2], closeTo(150.0, 0.0001));
      expect(polygon.arrayM[4], closeTo(40.0, 0.0001));
    });

    test('reads shapefile with M values', () {
      final filePath = '${tempDir.path}/test_read_pointm.shp';
      final writeShapefile = Shapefile();

      final records = [PointM(126.9780, 37.5665, 123.4)];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINTM,
        records,
        minX: 126.9780,
        minY: 37.5665,
        maxX: 126.9780,
        maxY: 37.5665,
        minM: 123.4,
        maxM: 123.4,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records[0], isA<PointM>());

      final point = readShapefile.records[0] as PointM;
      expect(point.x, closeTo(126.9780, 0.0001));
      expect(point.y, closeTo(37.5665, 0.0001));
      expect(point.m, closeTo(123.4, 0.0001));
    });

    test('reads shapefile with Z values', () {
      final filePath = '${tempDir.path}/test_read_pointz.shp';
      final writeShapefile = Shapefile();

      final records = [PointZ(126.9780, 37.5665, 42.5, 123.4)];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINTZ,
        records,
        minX: 126.9780,
        minY: 37.5665,
        maxX: 126.9780,
        maxY: 37.5665,
        minZ: 42.5,
        maxZ: 42.5,
        minM: 123.4,
        maxM: 123.4,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records[0], isA<PointZ>());

      final point = readShapefile.records[0] as PointZ;
      expect(point.x, closeTo(126.9780, 0.0001));
      expect(point.y, closeTo(37.5665, 0.0001));
      expect(point.m, closeTo(123.4, 0.0001));
      expect(point.z, closeTo(42.5, 0.0001));
    });

    test('reads multiple records correctly', () {
      final filePath = '${tempDir.path}/test_read_multiple.shp';
      final writeShapefile = Shapefile();

      final records = List.generate(50, (i) => Point(i.toDouble(), i.toDouble()));

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 49.0,
        maxY: 49.0,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(50));

      for (var i = 0; i < 50; i++) {
        final point = readShapefile.records[i] as Point;
        expect(point.x, closeTo(i.toDouble(), 0.0001));
        expect(point.y, closeTo(i.toDouble(), 0.0001));
      }
    });

    test('throws exception for non-existent file', () {
      final readShapefile = Shapefile();

      expect(() => readShapefile.read('${tempDir.path}/nonexistent.shp'), throwsA(isA<ShapefileException>()));
    });

    test('reads a multipoint shapefile', () {
      final filePath = '${tempDir.path}/test_read_multipoint.shp';
      final writeShapefile = Shapefile();

      final records = [
        MultiPoint(points: [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0)], bounds: Bounds(0.0, 0.0, 10.0, 10.0)),
        MultiPoint(points: [Point(20.0, 20.0), Point(25.0, 25.0)], bounds: Bounds(20.0, 20.0, 25.0, 25.0)),
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapeMULTIPOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 25.0,
        maxY: 25.0,
      );

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(2));
      expect(readShapefile.records[0], isA<MultiPoint>());
      expect(readShapefile.records[1], isA<MultiPoint>());

      final mp1 = readShapefile.records[0] as MultiPoint;
      final mp2 = readShapefile.records[1] as MultiPoint;

      expect(mp1.numPoints, equals(3));
      expect(mp2.numPoints, equals(2));

      expect(mp1.points[0].x, closeTo(0.0, 0.0001));
      expect(mp1.points[1].x, closeTo(5.0, 0.0001));
      expect(mp1.points[2].x, closeTo(10.0, 0.0001));
    });

    test('reads a multipointM shapefile', () {
      final filePath = '${tempDir.path}/test_read_multipointm.shp';
      final writeShapefile = Shapefile();

      final records = [
        MultiPointM(
          points: [Point(0.0, 0.0), Point(10.0, 10.0)],
          arrayM: [1.0, 2.0],
          bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 1.0, 2.0),
        ),
      ];

      writeShapefile.writeComplete(
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

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<MultiPointM>());

      final mp = readShapefile.records[0] as MultiPointM;
      expect(mp.numPoints, equals(2));
      expect(mp.arrayM[0], closeTo(1.0, 0.0001));
      expect(mp.arrayM[1], closeTo(2.0, 0.0001));
    });

    test('reads a multipointZ shapefile', () {
      final filePath = '${tempDir.path}/test_read_multipointz.shp';
      final writeShapefile = Shapefile();

      final records = [
        MultiPointZ(
          points: [Point(0.0, 0.0), Point(10.0, 10.0)],
          arrayZ: [100.0, 200.0],
          arrayM: [1.0, 2.0],
          bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 1.0, 2.0, 100.0, 200.0),
        ),
      ];

      writeShapefile.writeComplete(
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

      // Read it back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<MultiPointZ>());

      final mp = readShapefile.records[0] as MultiPointZ;
      expect(mp.numPoints, equals(2));
      expect(mp.arrayZ[0], closeTo(100.0, 0.0001));
      expect(mp.arrayZ[1], closeTo(200.0, 0.0001));
      expect(mp.arrayM[0], closeTo(1.0, 0.0001));
      expect(mp.arrayM[1], closeTo(2.0, 0.0001));
    });

    test('reads header information correctly', () {
      final filePath = '${tempDir.path}/test_header.shp';
      final writeShapefile = Shapefile();

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        [Point(5.0, 10.0)],
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 20.0,
      );

      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.headerSHP.type, equals(ShapeType.shapePOINT));
      expect(readShapefile.headerSHP.bounds.minX, closeTo(0.0, 0.0001));
      expect(readShapefile.headerSHP.bounds.minY, closeTo(0.0, 0.0001));
      expect(readShapefile.headerSHP.bounds.maxX, closeTo(10.0, 0.0001));
      expect(readShapefile.headerSHP.bounds.maxY, closeTo(20.0, 0.0001));
    });
  });

  group('Shapefile Reading - Step by Step', () {
    test('reads using step-by-step API', () {
      final filePath = '${tempDir.path}/test_stepread.shp';

      // Create test file
      final writeShapefile = Shapefile();
      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        [Point(5.0, 5.0)],
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
      );

      // Read using step-by-step (open is an instance method)
      final readShapefile = Shapefile();
      readShapefile.open(filePath);
      readShapefile.readSHX();
      readShapefile.readSHP();

      expect(readShapefile.records.length, equals(1));
      expect(readShapefile.records[0], isA<Point>());

      readShapefile.close();
    });
  });
}
