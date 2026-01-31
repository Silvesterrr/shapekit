/// A comprehensive Dart library for reading and writing ESRI Shapefiles.
///
/// Supports all 13 standard shapefile geometry types including:
/// - Point, PointM, PointZ
/// - Polyline, PolylineM, PolylineZ
/// - Polygon, PolygonM, PolygonZ
/// - MultiPoint, MultiPointM, MultiPointZ
///
/// ## Usage
///
/// ```dart
/// import 'package:shapekit/shapekit.dart';
///
/// // Read a shapefile
/// final shapefile = Shapefile();
/// shapefile.open('path/to/file.shp');
/// if (shapefile.reader('path/to/file.shp')) {
///   print('Records: ${shapefile.records.length}');
/// }
/// ```
library;

// Main shapefile API
export 'package:shapekit/src/data/repositories/shapefile_repository.dart';

// Geometry types
export 'package:shapekit/src/domain/entities/geometry/record.dart' show ShapeType, Record;
export 'package:shapekit/src/domain/entities/geometry/point.dart';
export 'package:shapekit/src/domain/entities/geometry/polyline.dart';
export 'package:shapekit/src/domain/entities/geometry/polygon.dart';

// Models that users might need
export 'package:shapekit/src/domain/entities/shapefile_bounds.dart';
export 'package:shapekit/src/data/models/shapefile_header.dart';
export 'package:shapekit/src/data/models/shapefile_offset.dart';

// DBase file support (for attributes)
export 'package:shapekit/src/data/repositories/dbase_repository.dart';
export 'package:shapekit/src/domain/entities/dbase_field.dart';

// Projection support
export 'package:shapekit/src/data/repositories/projection_repository.dart';

// Exception types
export 'package:shapekit/src/domain/exceptions/shapefile_exception.dart';

// Internal implementation (not exported):
// - geometry/geometry_reader.dart
// - geometry/geometry_writer.dart
