import 'package:shapekit/src/domain/entities/geometry/record.dart';

/// Simple geometry categorization for convenience
///
/// For full type safety, use pattern matching on [Record] subclasses:
/// ```dart
/// if (feature.geometry is Point) { ... }
/// if (feature.geometry is Polyline) { ... }
/// if (feature.geometry is Polygon) { ... }
/// ```
enum GeometryType { point, line, polygon, unknown }

/// Extension with factory methods to convert from various type representations
extension GeometryTypeExtension on GeometryType {
  /// Convert from [ShapeType]
  static GeometryType fromShapeType(ShapeType type) {
    if (type.isPointType()) return GeometryType.point;
    if (type.isLineType()) return GeometryType.line;
    if (type.isPolygonType()) return GeometryType.polygon;
    return GeometryType.unknown;
  }

  /// Convert from ISO WKB geometry type code
  static GeometryType fromWkbType(int wkbType) {
    switch (wkbType) {
      case 1: // Point
      case 4: // MultiPoint
        return GeometryType.point;
      case 2: // LineString
      case 5: // MultiLineString
        return GeometryType.line;
      case 3: // Polygon
      case 6: // MultiPolygon
        return GeometryType.polygon;
      default:
        return GeometryType.unknown;
    }
  }

  /// Convert from string (e.g., "POINT", "LINESTRING", "POLYGON")
  static GeometryType fromString(String type) {
    final upper = type.toUpperCase();
    if (upper.contains('POINT')) return GeometryType.point;
    if (upper.contains('LINE')) return GeometryType.line;
    if (upper.contains('POLYGON')) return GeometryType.polygon;
    return GeometryType.unknown;
  }
}
