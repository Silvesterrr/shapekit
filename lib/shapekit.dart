/// A comprehensive Dart library for reading and writing ESRI Shapefiles
/// and GeoPackage files with unified domain entities.
///
/// ## Shapefile Usage
///
/// ```dart
/// import 'package:shapekit/shapekit.dart';
///
/// final shapefile = Shapefile();
/// shapefile.read('path/to/file.shp');
/// for (final record in shapefile.records) {
///   if (record is Point) print('Point at ${record.x}, ${record.y}');
/// }
/// ```
///
/// ## GeoPackage Usage
///
/// ```dart
/// final conn = GpkgReader.open('path/to/file.gpkg');
/// await for (final batch in conn.queryFeatures(
///   table: 'layer',
///   bounds: Envelope(-10, 40, 10, 50),
/// )) {
///   for (final feature in batch.features) {
///     if (feature.geometry is Point) {
///       final p = feature.geometry as Point;
///       print('Point at ${p.x}, ${p.y}');
///     }
///   }
/// }
/// ```
library;

// Main shapefile API
export 'package:shapekit/src/shapefile/repositories/shapefile_repository.dart';
export 'package:shapekit/src/shapefile/repositories/shapefile_stream_reader.dart';

// Geometry types (unified domain entities)
export 'package:shapekit/src/domain/entities/geometry/record.dart' show ShapeType, Record;
export 'package:shapekit/src/domain/entities/geometry/point.dart';
export 'package:shapekit/src/domain/entities/geometry/polyline.dart';
export 'package:shapekit/src/domain/entities/geometry/polygon.dart';

// Models
export 'package:shapekit/src/domain/entities/geometry/envelope.dart' show Envelope, EnvelopeM, EnvelopeZ;
export 'package:shapekit/src/shapefile/models/shapefile_header.dart';
export 'package:shapekit/src/shapefile/models/shapefile_offset.dart';

// DBase file support (for attributes)
export 'package:shapekit/src/shapefile/repositories/dbase_repository.dart';
export 'package:shapekit/src/domain/entities/dbase_field.dart';

// Projection support
export 'package:shapekit/src/shapefile/repositories/projection_repository.dart';

// GeoPackage support
export 'package:shapekit/src/gpkg/gpkg_reader.dart' show GpkgReader;
export 'package:shapekit/src/gpkg/exceptions.dart' show GpkgException;
export 'package:shapekit/src/gpkg/types/raw_feature_batch.dart' show RawFeatureBatch;
export 'package:shapekit/src/gpkg/types/column_info.dart' show ColumnDef, ColumnInfo, FeatureTableMetadata, CrsInfo;
export 'package:shapekit/src/gpkg/codec/wkb_decoder.dart' show WkbDecoder;
export 'package:shapekit/src/gpkg/codec/wkb_encoder.dart' show WkbEncoder;
export 'package:shapekit/src/gpkg/spatial_index.dart' show SpatialIndex;
export 'package:shapekit/src/gpkg/gpkg_writer.dart' show GpkgWriter, GpkgTableWriter;

// High-level GeoPackage API (unified domain model)
export 'package:shapekit/src/gpkg/types/geometry_type.dart' show GeometryType, GeometryTypeExtension;
export 'package:shapekit/src/gpkg/types/geo_feature.dart' show GeoFeature;
export 'package:shapekit/src/gpkg/types/feature_batch.dart' show FeatureBatch;

// Exception types
export 'package:shapekit/src/domain/exceptions/shapefile_exception.dart';

// Extensions
export 'package:shapekit/src/shapefile/repositories/shapefile_repository_extensions.dart';
