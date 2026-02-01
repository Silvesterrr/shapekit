import 'package:meta/meta.dart';
import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/entities/shapefile_bounds.dart';

/// Represents a 2D point geometry (X, Y coordinates)
///
/// This is the simplest geometry type in shapefiles.
///
/// Example:
/// ```dart
/// final point = Point(126.9780, 37.5665);  // Seoul, South Korea
/// print('Longitude: ${point.x}, Latitude: ${point.y}');
/// ```
class Point extends Record {
  /// Creates a 2D point
  ///
  /// Parameters:
  /// - [x]: X coordinate (typically longitude)
  /// - [y]: Y coordinate (typically latitude)
  Point(this.x, this.y) : super(ShapeType.shapePOINT);

  /// Internal constructor for subclasses
  @protected
  const Point.protected(this.x, this.y, ShapeType type) : super(type);

  final double x;
  final double y;

  List<double> toList() => [x, y];

  @override
  String toString() => '{$x, $y}';
}

/// Represents a 2D point with measure value (X, Y, M coordinates)
///
/// The M value can represent any measured value like distance, time, or temperature.
///
/// Example:
/// ```dart
/// final pointM = PointM(126.9780, 37.5665, 42.5);  // Point with measure
/// ```
class PointM extends Point {
  /// Measure value associated with this point
  final double m;

  /// Creates a 2D point with measure
  ///
  /// Parameters:
  /// - [x]: X coordinate
  /// - [y]: Y coordinate
  /// - [m]: Measure value
  PointM(double x, double y, this.m) : super.protected(x, y, ShapeType.shapePOINTM);

  /// Internal constructor for subclasses
  @protected
  const PointM.protected(double x, double y, this.m, ShapeType type) : super.protected(x, y, type);

  @override
  List<double> toList() => [...super.toList(), m];

  @override
  String toString() => '{$x, $y, $m}';
}

/// Represents a 3D point with Z and M values (X, Y, Z, M coordinates)
///
/// The Z value typically represents elevation or altitude.
/// The M value can represent any measured value.
///
/// Example:
/// ```dart
/// final pointZ = PointZ(126.9780, 37.5665, 42.5, 123.4);  // Point with Z and M
/// ```
class PointZ extends PointM {
  /// Z coordinate (typically elevation)
  final double z;

  /// Creates a 3D point with Z and M values
  ///
  /// Parameters:
  /// - [x]: X coordinate
  /// - [y]: Y coordinate
  /// - [z]: Z coordinate (elevation)
  /// - [m]: Measure value
  PointZ(double x, double y, this.z, double m) : super.protected(x, y, m, ShapeType.shapePOINTZ);

  @override
  List<double> toList() => [...super.toList(), z];

  @override
  String toString() => '{$x, $y, $z, $m}';
}

class MultiPoint extends Record {
  MultiPoint({required List<Point> points, required Bounds bounds})
    : points = List.unmodifiable(points),
      minX = bounds.minX,
      minY = bounds.minY,
      maxX = bounds.maxX,
      maxY = bounds.maxY,
      super(ShapeType.shapeMULTIPOINT);

  @protected
  MultiPoint.protected({required List<Point> points, required Bounds bounds, required ShapeType type})
    : points = List.unmodifiable(points),
      minX = bounds.minX,
      minY = bounds.minY,
      maxX = bounds.maxX,
      maxY = bounds.maxY,
      super(type);

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
  final List<Point> points;

  // Computed property
  int get numPoints => points.length;

  List<Object> toList() => [
    minX,
    minY,
    maxX,
    maxY,
    [
      for (int i = 0; i < numPoints; ++i) [points[i].x, points[i].y],
    ],
  ];

  @override
  String toString() => '{($minX, $minY, $maxX, $maxY), $numPoints, $points}';
}

/// MultiPointM has optional M values per ESRI spec
class MultiPointM extends MultiPoint {
  MultiPointM({required super.points, List<double>? arrayM, required BoundsM super.bounds})
    : arrayM = arrayM != null ? List.unmodifiable(arrayM) : null,
      minM = bounds.minM,
      maxM = bounds.maxM,
      super.protected(type: ShapeType.shapeMULTIPOINTM);

  @protected
  MultiPointM.protected({
    required super.points,
    List<double>? arrayM,
    required BoundsM super.bounds,
    required super.type,
  }) : arrayM = arrayM != null ? List.unmodifiable(arrayM) : null,
       minM = bounds.minM,
       maxM = bounds.maxM,
       super.protected();

  final double? minM;
  final double? maxM;
  final List<double>? arrayM;

  /// Whether M values are present
  bool get hasM => arrayM != null;

  @override
  List<Object> toList() {
    final base = super.toList();
    if (hasM) {
      base.addAll([minM!, maxM!, arrayM!]);
    }
    return base;
  }

  @override
  String toString() {
    final mPart = hasM ? ', $minM, $maxM, $arrayM' : '';
    return '{($minX, $minY, $maxX, $maxY), $numPoints, $points$mPart}';
  }
}

/// MultiPointZ has required Z values and optional M values per ESRI spec
class MultiPointZ extends MultiPoint {
  MultiPointZ({required super.points, required List<double> arrayZ, required BoundsZ bounds, List<double>? arrayM})
    : arrayZ = List.unmodifiable(arrayZ),
      minZ = bounds.minZ,
      maxZ = bounds.maxZ,
      minM = bounds.minM,
      maxM = bounds.maxM,
      arrayM = arrayM != null ? List.unmodifiable(arrayM) : null,
      super.protected(bounds: bounds, type: ShapeType.shapeMULTIPOINTZ);

  final double minZ;
  final double maxZ;
  final List<double> arrayZ;

  final double? minM;
  final double? maxM;
  final List<double>? arrayM;

  /// Whether M values are present
  bool get hasM => arrayM != null;

  @override
  List<Object> toList() {
    final base = [...super.toList(), minZ, maxZ, arrayZ];
    if (hasM) {
      base.addAll([minM!, maxM!, arrayM!]);
    }
    return base;
  }

  @override
  String toString() {
    final mPart = hasM ? ', $minM, $maxM, $arrayM' : '';
    return '{($minX, $minY, $maxX, $maxY), $numPoints, $points, $minZ, $maxZ, $arrayZ$mPart}';
  }
}
