import 'dart:io';
import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';

/// Integration tests that verify complete workflows
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

  group('End-to-End Workflows', () {
    test('complete point shapefile workflow', () {
      final filePath = '${tempDir.path}/cities.shp';

      // Step 1: Create shapefile with points and attributes
      final writeShapefile = Shapefile();

      final records = [
        Point(126.9780, 37.5665), // Seoul
        Point(129.0756, 35.1796), // Busan
        Point(126.7052, 37.4563), // Incheon
      ];

      final fields = [
        DbaseField.fieldC('NAME', 50),
        DbaseField.fieldN('POPULATION', 10),
        DbaseField.fieldNF('AREA', 10, 2),
      ];

      final attributes = [
        ['Seoul', 9776000, 605.21],
        ['Busan', 3413000, 770.07],
        ['Incheon', 2954000, 1062.60],
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 126.7052,
        minY: 35.1796,
        maxX: 129.0756,
        maxY: 37.5665,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      // Step 2: Verify files exist
      expect(File(filePath).existsSync(), isTrue);
      expect(File('${tempDir.path}/cities.shx').existsSync(), isTrue);
      expect(File('${tempDir.path}/cities.dbf').existsSync(), isTrue);

      // Step 3: Read shapefile back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      // Step 4: Verify geometry
      expect(readShapefile.records.length, equals(3));
      expect(readShapefile.records[0], isA<Point>());

      final seoul = readShapefile.records[0] as Point;
      expect(seoul.x, closeTo(126.9780, 0.0001));
      expect(seoul.y, closeTo(37.5665, 0.0001));

      // Step 5: Verify attributes
      expect(readShapefile.attributeRecords.length, equals(3));
      expect(readShapefile.attributeRecords[0][0].toString().trim(), equals('Seoul'));
      expect(readShapefile.attributeRecords[0][1], equals(9776000));
      expect(readShapefile.attributeRecords[0][2], closeTo(605.21, 0.01));

      // Step 6: Verify header
      expect(readShapefile.headerSHP.type, equals(ShapeType.shapePOINT));
      expect(readShapefile.headerSHP.bounds.minX, closeTo(126.7052, 0.0001));
      expect(readShapefile.headerSHP.bounds.maxY, closeTo(37.5665, 0.0001));

      // Step 7: Clean up
      readShapefile.dispose();
    });

    test('complete polyline shapefile workflow', () {
      final filePath = '${tempDir.path}/roads.shp';

      // Create a road network
      final writeShapefile = Shapefile();

      final records = [
        Polyline(
          bounds: Bounds(0.0, 0.0, 10.0, 10.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0)],
        ),
        Polyline(
          bounds: Bounds(0.0, 10.0, 10.0, 0.0),
          parts: [0],
          points: [Point(0.0, 10.0), Point(5.0, 5.0), Point(10.0, 0.0)],
        ),
      ];

      final fields = [DbaseField.fieldC('NAME', 50), DbaseField.fieldN('LANES', 2)];

      final attributes = [
        ['Main Street', 4],
        ['Oak Avenue', 2],
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOLYLINE,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      // Read and verify
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(2));
      expect(readShapefile.records[0], isA<Polyline>());

      final road1 = readShapefile.records[0] as Polyline;
      expect(road1.numPoints, equals(3));
      expect(road1.numParts, equals(1));

      expect(readShapefile.attributeRecords[0][0].toString().trim(), equals('Main Street'));
      expect(readShapefile.attributeRecords[0][1], equals(4));
    });

    test('complete polygon shapefile workflow', () {
      final filePath = '${tempDir.path}/parcels.shp';

      // Create land parcels
      final writeShapefile = Shapefile();

      final records = [
        Polygon(
          bounds: Bounds(0.0, 0.0, 10.0, 10.0),
          parts: [0],
          points: [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 10.0), Point(0.0, 0.0)],
        ),
      ];

      final fields = [
        DbaseField.fieldC('OWNER', 50),
        DbaseField.fieldNF('AREA_SQM', 12, 2),
        DbaseField.fieldL('DEVELOPED'),
      ];

      final attributes = [
        ['John Doe', 100.00, true],
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOLYGON,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      // Read and verify
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records[0], isA<Polygon>());

      final parcel = readShapefile.records[0] as Polygon;
      expect(parcel.numPoints, equals(5));

      expect(readShapefile.attributeRecords[0][0].toString().trim(), equals('John Doe'));
      expect(readShapefile.attributeRecords[0][1], closeTo(100.00, 0.01));
      expect(readShapefile.attributeRecords[0][2], isTrue);
    });

    test('modify and re-save shapefile', () {
      final filePath = '${tempDir.path}/modifiable.shp';

      // Create initial shapefile
      final shapefile1 = Shapefile();
      shapefile1.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        [Point(0.0, 0.0)],
        minX: 0.0,
        minY: 0.0,
        maxX: 0.0,
        maxY: 0.0,
        attributeFields: [DbaseField.fieldC('NAME', 50)],
        attributeRecords: [
          ['Original'],
        ],
      );

      // Read it
      final shapefile2 = Shapefile();
      shapefile2.read(filePath);

      expect(shapefile2.records.length, equals(1));

      // Modify and save to new file
      final newFilePath = '${tempDir.path}/modified.shp';
      shapefile2.setRecords([Point(0.0, 0.0), Point(10.0, 10.0)]);
      shapefile2.setAttributeRecord([
        ['Original'],
        ['New Point'],
      ]);

      shapefile2.write(newFilePath);

      // Read modified file
      final shapefile3 = Shapefile();
      shapefile3.read(newFilePath);

      expect(shapefile3.records.length, equals(2));
      expect(shapefile3.attributeRecords.length, equals(2));
    });

    test('large dataset workflow', () {
      final filePath = '${tempDir.path}/large.shp';

      // Create a large dataset
      final records = List.generate(1000, (i) => Point(i.toDouble(), i.toDouble()));

      final fields = [DbaseField.fieldN('ID', 10), DbaseField.fieldC('LABEL', 20)];

      final attributes = List.generate(1000, (i) => [i, 'Point_$i']);

      final writeShapefile = Shapefile();
      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 999.0,
        maxY: 999.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      // Read and verify
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      expect(readShapefile.records.length, equals(1000));
      expect(readShapefile.attributeRecords.length, equals(1000));

      // Spot check some records
      final point500 = readShapefile.records[500] as Point;
      expect(point500.x, closeTo(500.0, 0.0001));
      expect(readShapefile.attributeRecords[500][0], equals(500));
    });

    test('UTF-8 encoding workflow', () {
      final filePath = '${tempDir.path}/utf8.shp';

      final writeShapefile = Shapefile(isUtf8: true);

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        [Point(0.0, 0.0)],
        minX: 0.0,
        minY: 0.0,
        maxX: 0.0,
        maxY: 0.0,
        attributeFields: [DbaseField.fieldC('TEXT', 100)],
        attributeRecords: [
          ['Hello 世界'],
        ],
      );

      final readShapefile = Shapefile(isUtf8: true);
      readShapefile.read(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().contains('Hello'), isTrue);
    });

    test('Korean CP949 encoding workflow', () {
      final filePath = '${tempDir.path}/korean.shp';

      final writeShapefile = Shapefile(isCp949: true);

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapePOINT,
        [Point(126.9780, 37.5665)],
        minX: 126.9780,
        minY: 37.5665,
        maxX: 126.9780,
        maxY: 37.5665,
        attributeFields: [DbaseField.fieldC('CITY', 50)],
        attributeRecords: [
          ['서울'],
        ],
      );

      final readShapefile = Shapefile(isCp949: true);
      readShapefile.read(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().contains('서울'), isTrue);
    });

    test('complete multipoint shapefile workflow', () {
      final filePath = '${tempDir.path}/locations.shp';

      // Step 1: Create multipoint shapefile with attributes
      final writeShapefile = Shapefile();

      final records = [
        MultiPoint(
          points: [
            Point(126.9780, 37.5665), // Seoul
            Point(127.0276, 37.4979), // Gangnam
            Point(126.9784, 37.5796), // Bukhansan
          ],
          bounds: Bounds(126.9780, 37.4979, 127.0276, 37.5796),
        ),
        MultiPoint(
          points: [
            Point(129.0756, 35.1796), // Busan
            Point(129.0403, 35.1028), // Haeundae
          ],
          bounds: Bounds(129.0403, 35.1028, 129.0756, 35.1796),
        ),
      ];

      final fields = [DbaseField.fieldC('REGION', 50), DbaseField.fieldN('NUM_POINTS', 5)];

      final attributes = [
        ['Seoul Area', 3],
        ['Busan Area', 2],
      ];

      writeShapefile.writeComplete(
        filePath,
        ShapeType.shapeMULTIPOINT,
        records,
        minX: 126.9780,
        minY: 35.1028,
        maxX: 129.0756,
        maxY: 37.5796,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      // Step 2: Verify files exist
      expect(File(filePath).existsSync(), isTrue);
      expect(File('${tempDir.path}/locations.shx').existsSync(), isTrue);
      expect(File('${tempDir.path}/locations.dbf').existsSync(), isTrue);

      // Step 3: Read shapefile back
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      // Step 4: Verify geometry
      expect(readShapefile.records.length, equals(2));
      expect(readShapefile.records[0], isA<MultiPoint>());
      expect(readShapefile.records[1], isA<MultiPoint>());

      final seoul = readShapefile.records[0] as MultiPoint;
      expect(seoul.numPoints, equals(3));
      expect(seoul.points[0].x, closeTo(126.9780, 0.0001));
      expect(seoul.points[0].y, closeTo(37.5665, 0.0001));

      final busan = readShapefile.records[1] as MultiPoint;
      expect(busan.numPoints, equals(2));

      // Step 5: Verify attributes
      expect(readShapefile.attributeRecords.length, equals(2));
      expect(readShapefile.attributeRecords[0][0].toString().trim(), equals('Seoul Area'));
      expect(readShapefile.attributeRecords[0][1], equals(3));
      expect(readShapefile.attributeRecords[1][0].toString().trim(), equals('Busan Area'));
      expect(readShapefile.attributeRecords[1][1], equals(2));

      // Step 6: Verify header
      expect(readShapefile.headerSHP.type, equals(ShapeType.shapeMULTIPOINT));

      // Step 7: Clean up
      readShapefile.dispose();
    });
  });

  group('Real-World Scenarios', () {
    test('GIS analysis workflow - find points in bounds', () {
      final filePath = '${tempDir.path}/analysis.shp';

      // Create points across a region
      final records = [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0), Point(15.0, 15.0), Point(20.0, 20.0)];

      final shapefile = Shapefile();
      shapefile.writeComplete(filePath, ShapeType.shapePOINT, records, minX: 0.0, minY: 0.0, maxX: 20.0, maxY: 20.0);

      // Read and filter
      final readShapefile = Shapefile();
      readShapefile.read(filePath);

      // Find points within bounds (5, 5) to (15, 15)
      final filtered = readShapefile.records.where((record) {
        if (record is Point) {
          return record.x >= 5.0 && record.x <= 15.0 && record.y >= 5.0 && record.y <= 15.0;
        }
        return false;
      }).toList();

      expect(filtered.length, equals(3)); // Points at (5,5), (10,10), (15,15)
    });

    test('data migration workflow - convert between formats', () {
      final sourcePath = '${tempDir.path}/source.shp';
      final targetPath = '${tempDir.path}/target.shp';

      // Create source data
      final sourceShapefile = Shapefile();
      sourceShapefile.writeComplete(
        sourcePath,
        ShapeType.shapePOINT,
        [Point(0.0, 0.0), Point(10.0, 10.0)],
        minX: 0.0,
        minY: 0.0,
        maxX: 10.0,
        maxY: 10.0,
        attributeFields: [DbaseField.fieldC('OLD_NAME', 50)],
        attributeRecords: [
          ['A'],
          ['B'],
        ],
      );

      // Read source
      final migrationShapefile = Shapefile();
      migrationShapefile.read(sourcePath);

      // Transform data (rename field)
      final newFields = [DbaseField.fieldC('NEW_NAME', 50)];
      final newRecords = migrationShapefile.attributeRecords.map((record) => [record[0].toString().trim()]).toList();

      // Write to target
      migrationShapefile.setAttributeField(newFields);
      migrationShapefile.setAttributeRecord(newRecords);
      migrationShapefile.write(targetPath);

      // Verify migration
      final verifyShapefile = Shapefile();
      verifyShapefile.read(targetPath);

      expect(verifyShapefile.attributeFields[0].name, equals('NEW_NAME'));
      expect(verifyShapefile.records.length, equals(2));
    });
  });
}
