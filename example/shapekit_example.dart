import 'package:shapekit/shapekit.dart';

void main() {
  // Example 1: Writing a shapefile
  writeShapefileExample();

  // Example 2: Reading a shapefile
  readShapefileExample();
}

/// Example: Create and write a new shapefile with points
void writeShapefileExample() {
  print('=== Writing Shapefile Example ===\n');

  final shapefile = Shapefile();

  // Create point records for major cities
  final records = [
    Point(126.9780, 37.5665), // Seoul
    Point(129.0756, 35.1796), // Busan
    Point(126.7052, 37.4563), // Incheon
    Point(127.3845, 36.3504), // Daejeon
  ];

  // Define attribute fields
  final fields = [
    DbaseField.fieldC('NAME', 50), // City name (text)
    DbaseField.fieldN('POPULATION', 10), // Population (integer)
    DbaseField.fieldNF('AREA', 10, 2), // Area in km² (float)
    DbaseField.fieldL('CAPITAL'), // Is capital? (boolean)
  ];

  // Create attribute records matching the points
  final attributes = [
    ['Seoul', 9776000, 605.21, true],
    ['Busan', 3413000, 770.07, false],
    ['Incheon', 2954000, 1062.60, false],
    ['Daejeon', 1475000, 539.98, false],
  ];

  // Write the shapefile with all components
  shapefile.writerEntirety(
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

  print('✓ Created cities.shp with ${records.length} points');
  print('✓ Included .shp, .shx, and .dbf files\n');
}

/// Example: Read an existing shapefile
void readShapefileExample() {
  print('=== Reading Shapefile Example ===\n');

  final shapefile = Shapefile();

  // Read the shapefile (automatically reads .shp, .shx, .dbf, and .prj if available)
  if (shapefile.reader('cities.shp')) {
    print('✓ Successfully loaded shapefile');
    print('  Records: ${shapefile.records.length}');
    print('  Attributes: ${shapefile.attributeRecords.length}\n');

    // Iterate through geometry records
    print('Geometry Data:');
    for (var i = 0; i < shapefile.records.length; i++) {
      final record = shapefile.records[i];

      if (record is Point) {
        print('  Point $i: (${record.x}, ${record.y})');
      } else if (record is Polyline) {
        print(
          '  Polyline $i: ${record.numParts} parts, ${record.numPoints} points',
        );
      } else if (record is Polygon) {
        print(
          '  Polygon $i: ${record.numParts} parts, ${record.numPoints} points',
        );
      }
    }

    // Display attribute data
    if (shapefile.attributeRecords.isNotEmpty) {
      print('\nAttribute Data:');
      for (var i = 0; i < shapefile.attributeRecords.length; i++) {
        final attrs = shapefile.attributeRecords[i];
        print('  Record $i: $attrs');
      }
    }

    // Display field definitions
    if (shapefile.attributeFields.isNotEmpty) {
      print('\nField Definitions:');
      for (final field in shapefile.attributeFields) {
        print('  ${field.name} (${field.type}): length=${field.fieldLength}');
      }
    }

    // Display projection info if available
    if (shapefile.projectionType != ShapeProjectionType.none) {
      print('\nProjection: ${shapefile.projectionType}');
    }

    // Clean up
    shapefile.dispose();
  } else {
    print('✗ Failed to read shapefile');
  }
}

/// Example: Working with different geometry types
void advancedGeometryExample() {
  print('=== Advanced Geometry Example ===\n');

  // Example with Polyline (roads, rivers, etc.)
  final polylineShapefile = Shapefile();
  final polylineRecords = [
    Polyline(
      bounds: Bounds(0, 0, 10, 10), // minX, minY, maxX, maxY
      parts: [0, 3], // Two parts: first starts at index 0, second at index 3
      points: [
        Point(0, 0),
        Point(5, 5),
        Point(10, 10),
        Point(0, 10),
        Point(10, 0),
      ],
    ),
  ];

  polylineShapefile.writerEntirety(
    'roads.shp',
    ShapeType.shapePOLYLINE,
    polylineRecords,
    minX: 0,
    minY: 0,
    maxX: 10,
    maxY: 10,
  );

  print('✓ Created roads.shp with polyline geometry');

  // Example with Polygon (boundaries, parcels, etc.)
  final polygonShapefile = Shapefile();
  final polygonRecords = [
    Polygon(
      bounds: Bounds(0, 0, 10, 10), // minX, minY, maxX, maxY
      parts: [0], // One part
      points: [
        Point(0, 0),
        Point(10, 0),
        Point(10, 10),
        Point(0, 10),
        Point(0, 0), // Close the polygon
      ],
    ),
  ];

  polygonShapefile.writerEntirety(
    'parcels.shp',
    ShapeType.shapePOLYGON,
    polygonRecords,
    minX: 0,
    minY: 0,
    maxX: 10,
    maxY: 10,
  );

  print('✓ Created parcels.shp with polygon geometry\n');
}

/// Example: Working with Korean text (CP949 encoding)
void koreanTextExample() {
  print('=== Korean Text Example ===\n');

  // Create shapefile with CP949 encoding for Korean text
  final shapefile = Shapefile(isCp949: true);

  final records = [Point(126.9780, 37.5665)];

  final fields = [
    DbaseField.fieldC('NAME_KR', 50), // Korean name
    DbaseField.fieldC('NAME_EN', 50), // English name
  ];

  final attributes = [
    ['서울', 'Seoul'],
  ];

  shapefile.writerEntirety(
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

  print('✓ Created cities_kr.shp with Korean text (CP949 encoding)\n');
}

/// Example: Error handling
void errorHandlingExample() {
  print('=== Error Handling Example ===\n');

  try {
    final shapefile = Shapefile();
    shapefile.reader('nonexistent.shp');
  } on FileNotFoundException catch (e) {
    print('✗ File not found: ${e.filePath}');
  } on InvalidHeaderException catch (e) {
    print('✗ Invalid header: ${e.message}');
  } on CorruptedDataException catch (e) {
    print('✗ Corrupted data: ${e.details}');
  } on ShapefileException catch (e) {
    print('✗ Shapefile error: $e');
  }

  print('');
}
