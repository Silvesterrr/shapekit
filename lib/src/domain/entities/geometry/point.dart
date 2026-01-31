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
  Point(this.x, this.y) {
    type = ShapeType.shapePOINT;
  }

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
  PointM(super.x, super.y, this.m) {
    type = ShapeType.shapePOINTM;
  }

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
  /// - [m]: Measure value
  /// - [z]: Z coordinate (elevation)
  PointZ(super.x, super.y, super.m, this.z) {
    type = ShapeType.shapePOINTZ;
  }

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
      maxY = bounds.maxY {
    type = ShapeType.shapeMULTIPOINT;
  }

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

class MultiPointM extends MultiPoint {
  MultiPointM({required super.points, required List<double> arrayM, required BoundsM super.bounds})
    : arrayM = List.unmodifiable(arrayM),
      minM = bounds.minM,
      maxM = bounds.maxM {
    type = ShapeType.shapeMULTIPOINTM;
  }

  final double minM;
  final double maxM;
  final List<double> arrayM;

  @override
  List<Object> toList() => [...super.toList(), minM, maxM, arrayM];

  @override
  String toString() => '{($minX, $minY, $maxX, $maxY), $numPoints, $points, $minM, $maxM, $arrayM}';
}

class MultiPointZ extends MultiPointM {
  MultiPointZ({
    required super.points,
    required super.arrayM,
    required List<double> arrayZ,
    required BoundsZ super.bounds,
  }) : arrayZ = List.unmodifiable(arrayZ),
       minZ = bounds.minZ,
       maxZ = bounds.maxZ {
    type = ShapeType.shapeMULTIPOINTZ;
  }

  final double minZ;
  final double maxZ;
  final List<double> arrayZ;

  @override
  List<Object> toList() => [...super.toList(), minZ, maxZ, arrayZ];

  @override
  String toString() => '{($minX, $minY, $maxX, $maxY), $numPoints, $points, $minM, $maxZ, $arrayZ, $maxM, $arrayM}';
}
