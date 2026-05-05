import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/geometry/polyline.dart';
import 'package:shapekit/src/domain/entities/geometry/polygon.dart';
import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/gpkg/types/geometry_type.dart';

/// A decoded GeoPackage feature with typed geometry and optional attributes
///
/// Unifies the GeoPackage API with the Shapefile API by reusing
/// the same domain entities ([Point], [Polyline], [Polygon]).
class GeoFeature {
  /// Feature ID (rowid from GeoPackage table)
  final int fid;

  /// Typed geometry — reuses Shapefile domain entities
  final Record geometry;

  /// Optional attribute values from GeoPackage columns
  final Map<String, dynamic> attributes;

  const GeoFeature({required this.fid, required this.geometry, this.attributes = const {}});

  /// Convenience getter for geometry category
  GeometryType get type => GeometryTypeExtension.fromShapeType(geometry.type);

  bool get isPoint => geometry is Point;
  bool get isLine => geometry is Polyline && geometry is! Polygon;
  bool get isPolygon => geometry is Polygon;
}
