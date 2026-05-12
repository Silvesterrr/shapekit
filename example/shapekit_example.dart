import 'package:shapekit/shapekit.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run example/shapekit_example.dart <path_to_shp_file>');
    print('Or run without arguments to execute the built-in examples.\n');

    writeShapefileExample();
    readShapefileExample();
  } else {
    readShapefileFromPath(args.join(' '));
  }
}

void readShapefileFromPath(String path) {
  print('=== Reading Shapefile: $path ===\n');

  final shapefile = Shapefile();

  try {
    shapefile.read(path);

    print('Successfully loaded shapefile');
    print('  Records: ${shapefile.records.length}');
    print('  Attributes: ${shapefile.attributeRecords.length}\n');

    print('Geometry Data:');
    for (var i = 0; i < shapefile.records.length; i++) {
      final record = shapefile.records[i];

      if (record is Point) {
        print('  Point $i: (${record.x}, ${record.y})');
      } else if (record is Polyline) {
        print('  Polyline $i: ${record.numParts} parts, ${record.numPoints} points');
      } else if (record is Polygon) {
        print('  Polygon $i: ${record.numParts} parts, ${record.numPoints} points');
      }
    }

    if (shapefile.attributeRecords.isNotEmpty) {
      print('\nAttribute Data:');
      for (var i = 0; i < shapefile.attributeRecords.length; i++) {
        final attrs = shapefile.attributeRecords[i];
        print('  Record $i: $attrs');
      }
    }

    if (shapefile.attributeFields.isNotEmpty) {
      print('\nField Definitions:');
      for (final field in shapefile.attributeFields) {
        print('  ${field.name} (${field.type}): length=${field.length}');
      }
    }

    if (shapefile.epsgCode != null) {
      print('\nProjection EPSG: ${shapefile.epsgCode}');
    }
  } on ShapefileException catch (e) {
    print('Failed to read shapefile: $e');
  } finally {
    shapefile.dispose();
  }
}

void writeShapefileExample() {
  print('=== Writing Shapefile Example ===\n');

  final shapefile = Shapefile();

  final records = [
    Point(126.9780, 37.5665),
    Point(129.0756, 35.1796),
    Point(126.7052, 37.4563),
    Point(127.3845, 36.3504),
  ];

  final fields = [
    DbaseField.fieldC('NAME', 50),
    DbaseField.fieldN('POPULATION', 10),
    DbaseField.fieldNF('AREA', 10, 2),
    DbaseField.fieldL('CAPITAL'),
  ];

  final attributes = [
    ['Seoul', 9776000, 605.21, true],
    ['Busan', 3413000, 770.07, false],
    ['Incheon', 2954000, 1062.60, false],
    ['Daejeon', 1475000, 539.98, false],
  ];

  try {
    shapefile.writeComplete(
      'cities.shp',
      ShapeType.shapePOINT,
      records,
      minX: 126.7052,
      minY: 35.1796,
      maxX: 129.0756,
      maxY: 37.5665,
      attributeFields: fields,
      attributeRecords: attributes,
    );

    print('Created cities.shp with ${records.length} points');
    print('Included .shp, .shx, and .dbf files\n');
  } on ShapefileException catch (e) {
    print('Error writing shapefile: $e');
  }
}

void readShapefileExample() {
  print('=== Reading Shapefile Example ===\n');

  final shapefile = Shapefile();

  try {
    shapefile.read('cities.shp');

    print('Successfully loaded shapefile');
    print('  Records: ${shapefile.records.length}');
    print('  Attributes: ${shapefile.attributeRecords.length}\n');

    print('Geometry Data:');
    for (var i = 0; i < shapefile.records.length; i++) {
      final record = shapefile.records[i];

      if (record is Point) {
        print('  Point $i: (${record.x}, ${record.y})');
      } else if (record is Polyline) {
        print('  Polyline $i: ${record.numParts} parts, ${record.numPoints} points');
      } else if (record is Polygon) {
        print('  Polygon $i: ${record.numParts} parts, ${record.numPoints} points');
      }
    }

    if (shapefile.attributeRecords.isNotEmpty) {
      print('\nAttribute Data:');
      for (var i = 0; i < shapefile.attributeRecords.length; i++) {
        final attrs = shapefile.attributeRecords[i];
        print('  Record $i: $attrs');
      }
    }

    if (shapefile.attributeFields.isNotEmpty) {
      print('\nField Definitions:');
      for (final field in shapefile.attributeFields) {
        print('  ${field.name} (${field.type}): length=${field.length}');
      }
    }

    if (shapefile.epsgCode != null) {
      print('\nProjection EPSG: ${shapefile.epsgCode}');
    }
  } on ShapefileException catch (e) {
    print('Failed to read shapefile: $e');
  } finally {
    shapefile.dispose();
  }
}

void advancedGeometryExample() {
  print('=== Advanced Geometry Example ===\n');

  final polylineShapefile = Shapefile();
  final polylineRecords = [
    Polyline(
      bounds: Envelope(0, 0, 10, 10),
      parts: [0, 3],
      points: [Point(0, 0), Point(5, 5), Point(10, 10), Point(0, 10), Point(10, 0)],
    ),
  ];

  polylineShapefile.writeComplete(
    'roads.shp',
    ShapeType.shapePOLYLINE,
    polylineRecords,
    minX: 0,
    minY: 0,
    maxX: 10,
    maxY: 10,
  );

  print('Created roads.shp with polyline geometry');

  final polygonShapefile = Shapefile();
  final polygonRecords = [
    Polygon(
      bounds: Envelope(0, 0, 10, 10),
      parts: [0],
      points: [Point(0, 0), Point(10, 0), Point(10, 10), Point(0, 10), Point(0, 0)],
    ),
  ];

  polygonShapefile.writeComplete(
    'parcels.shp',
    ShapeType.shapePOLYGON,
    polygonRecords,
    minX: 0,
    minY: 0,
    maxX: 10,
    maxY: 10,
  );

  print('Created parcels.shp with polygon geometry\n');
}

void koreanTextExample() {
  print('=== Korean Text Example ===\n');

  final shapefile = Shapefile(isCp949: true);
  final records = [Point(126.9780, 37.5665)];
  final fields = [DbaseField.fieldC('NAME_KR', 50), DbaseField.fieldC('NAME_EN', 50)];
  final attributes = [
    ['Seoul', 'Seoul'],
  ];

  shapefile.writeComplete(
    'cities_kr.shp',
    ShapeType.shapePOINT,
    records,
    minX: 126.9780,
    minY: 37.5665,
    maxX: 126.9780,
    maxY: 37.5665,
    attributeFields: fields,
    attributeRecords: attributes,
  );

  print('Created cities_kr.shp with CP949 text data\n');
}

void errorHandlingExample() {
  print('=== Error Handling Example ===\n');

  try {
    final shapefile = Shapefile();
    shapefile.read('nonexistent.shp');
  } on FileNotFoundException catch (e) {
    print('File not found: ${e.path}');
  } on InvalidHeaderException catch (e) {
    print('Invalid header: ${e.message}');
  } on CorruptedDataException catch (e) {
    print('Corrupted data: ${e.details}');
  } on ShapefileException catch (e) {
    print('Shapefile error: $e');
  }

  print('');
}
