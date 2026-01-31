# shapekit

A comprehensive Dart library for reading and writing ESRI Shapefiles with support for all 13 geometry types.

[![pub package](https://img.shields.io/pub/v/shapekit.svg)](https://pub.dev/packages/shapekit)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-yellow.svg)](https://www.buymeacoffee.com/sylwesterjarosz)

## Features

- ✅ **Complete Shapefile Support** - Read and write .shp, .shx, .dbf, and .prj files
- ✅ **All 13 Geometry Types** - Point, PointM, PointZ, Polyline, PolylineM, PolylineZ, Polygon, PolygonM, PolygonZ, MultiPoint, MultiPointM, MultiPointZ, and MultiPatch
- ✅ **Attribute Support** - Full dBASE III+ (.dbf) file support for feature attributes
- ✅ **Projection Support** - Read projection information from .prj files
- ✅ **Korean Text Support** - CP949 encoding for Korean text in attributes
- ✅ **UTF-8 Support** - Modern UTF-8 encoding support
- ✅ **Type-Safe** - Strongly typed geometry classes with immutable data structures
- ✅ **Clean Architecture** - Well-organized codebase following clean architecture principles

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  shapekit: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### Reading a Shapefile

```dart
import 'package:shapekit/shapekit.dart';

void main() {
  final shapefile = Shapefile();
  
  if (shapefile.reader('path/to/file.shp')) {
    print('Loaded ${shapefile.records.length} records');
    
    // Access geometry
    for (final record in shapefile.records) {
      if (record is Point) {
        print('Point: ${record.x}, ${record.y}');
      } else if (record is Polyline) {
        print('Polyline with ${record.numPoints} points');
      } else if (record is Polygon) {
        print('Polygon with ${record.numParts} parts');
      }
    }
    
    // Access attributes (if .dbf file exists)
    for (int i = 0; i < shapefile.attributeRecords.length; i++) {
      print('Record $i attributes: ${shapefile.attributeRecords[i]}');
    }
    
    // Access projection (if .prj file exists)
    print('Projection: ${shapefile.projectionType}');
  }
}
```

### Writing a Shapefile

```dart
import 'package:shapekit/shapekit.dart';

void main() {
  final shapefile = Shapefile();
  
  // Create point records
  final records = [
    Point(126.9780, 37.5665),  // Seoul
    Point(129.0756, 35.1796),  // Busan
  ];
  
  // Create attribute fields
  final fields = [
    DbaseField.fieldC('NAME', 50),
    DbaseField.fieldN('POPULATION', 10),
  ];
  
  // Create attribute records
  final attributes = [
    ['Seoul', 9776000],
    ['Busan', 3413000],
  ];
  
  // Write shapefile
  shapefile.writerEntirety(
    'cities.shp',
    ShapeType.shapePOINT,
    records,
    minX: 126.9780,
    minY: 35.1796,
    maxX: 129.0756,
    maxY: 37.5665,
    attributeFields: fields,
    attributeRecords: attributes,
  );
  
  print('Shapefile created successfully!');
}
```

## Supported Geometry Types

| Geometry Type | Class | Description |
|--------------|-------|-------------|
| Point | `Point` | Single point (X, Y) |
| PointM | `PointM` | Point with measure value (X, Y, M) |
| PointZ | `PointZ` | Point with Z and M values (X, Y, Z, M) |
| Polyline | `Polyline` | Line or multi-line (parts, points) |
| PolylineM | `PolylineM` | Polyline with measure values |
| PolylineZ | `PolylineZ` | Polyline with Z and M values |
| Polygon | `Polygon` | Polygon or multi-polygon (parts, points) |
| PolygonM | `PolygonM` | Polygon with measure values |
| PolygonZ | `PolygonZ` | Polygon with Z and M values |
| MultiPoint | `MultiPoint` | Collection of points |
| MultiPointM | `MultiPointM` | MultiPoint with measure values |
| MultiPointZ | `MultiPointZ` | MultiPoint with Z and M values |
| MultiPatch | `MultiPatch` | 3D surface (experimental) |

## Text Encoding

The library supports multiple text encodings for attribute data:

```dart
// UTF-8 encoding (default, recommended)
final shapefile = Shapefile(isUtf8: true);

// CP949 encoding (for Korean legacy data)
final shapefile = Shapefile(isCp949: true);

// ASCII encoding (when both flags are false)
final shapefile = Shapefile();
```

## Attribute Field Types

When working with dBASE attributes, use these field types:

```dart
// Character field (text)
DbaseField.fieldC('NAME', 50)  // name, max length

// Date field
DbaseField.fieldD('DATE')  // name only

// Logical field (boolean)
DbaseField.fieldL('ACTIVE')  // name only

// Numeric field (integer)
DbaseField.fieldN('COUNT', 10)  // name, total digits

// Numeric field (floating point)
DbaseField.fieldNF('AREA', 20, 8)  // name, total digits, decimal places
```

## Limitations

- **No coordinate transformation** - The library reads projection information but does not transform coordinates
- **Synchronous I/O** - All file operations are synchronous (blocking)
- **No streaming** - Entire files are loaded into memory

## Error Handling

The library uses typed exceptions for error handling:

```dart
try {
  final shapefile = Shapefile();
  shapefile.reader('data.shp');
} on FileNotFoundException catch (e) {
  print('File not found: ${e.filePath}');
} on InvalidHeaderException catch (e) {
  print('Invalid shapefile header: ${e.message}');
} on CorruptedDataException catch (e) {
  print('Corrupted data: ${e.details}');
} on ShapefileException catch (e) {
  print('Shapefile error: $e');
}
```

**Exception Types:**
- `FileNotFoundException` - File not found or cannot be accessed
- `InvalidHeaderException` - Invalid file header
- `InvalidFormatException` - Invalid file format
- `CorruptedDataException` - Corrupted record data
- `UnsupportedTypeException` - Unsupported geometry type
- `ShapefileIOException` - File I/O error

## Support

If you find this library helpful, consider supporting its development! ☕️

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-yellow.svg?style=for-the-badge&logo=buy-me-a-coffee)](https://www.buymeacoffee.com/sylwesterjarosz)

Your support helps me:
- 🐛 Fix bugs faster
- ✨ Add new features and projections
- 📚 Improve documentation
- 🚀 Build more GIS tools for the community

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## References

- [ESRI Shapefile Technical Description](https://www.esri.com/content/dam/esrisites/sitecore-archive/Files/Pdfs/library/whitepapers/pdfs/shapefile.pdf)
- [dBASE File Format](http://www.dbase.com/Knowledgebase/INT/db7_file_fmt.htm)

## Acknowledgments

This library is based on the [shapefile-kr](https://github.com/michael-kim-korea/shapefile-kr) repository by [@michael-kim-korea](https://github.com/michael-kim-korea).
