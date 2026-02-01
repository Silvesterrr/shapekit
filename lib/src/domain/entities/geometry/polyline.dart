import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/shapefile_bounds.dart';
import 'package:meta/meta.dart';

class Polyline extends Record {
  Polyline({required Bounds bounds, required List<int> parts, required List<Point> points})
    : minX = bounds.minX,
      minY = bounds.minY,
      maxX = bounds.maxX,
      maxY = bounds.maxY,
      parts = List.unmodifiable(parts),
      points = List.unmodifiable(points),
      super(ShapeType.shapePOLYLINE);

  // Internal constructor for subclasses
  @protected
  Polyline.protected({
    required Bounds bounds,
    required List<int> parts,
    required List<Point> points,
    required ShapeType type,
  }) : minX = bounds.minX,
       minY = bounds.minY,
       maxX = bounds.maxX,
       maxY = bounds.maxY,
       parts = List.unmodifiable(parts),
       points = List.unmodifiable(points),
       super(type);

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
  final List<int> parts;
  final List<Point> points;

  // Computed properties
  int get numParts => parts.length;
  int get numPoints => points.length;

  List<Object> toList() => [
    minX,
    minY,
    maxX,
    maxY,
    parts,
    [
      for (int i = 0; i < numPoints; ++i) [points[i].x, points[i].y],
    ],
  ];

  @override
  String toString() => '{($minX, $minY, $maxX, $maxY)\n$numParts, $parts\n$numPoints, $points}';
}

/// PolylineM has optional M values per ESRI spec
class PolylineM extends Polyline {
  PolylineM({required BoundsM bounds, required super.parts, required super.points, List<double>? arrayM})
    : minM = bounds.minM,
      maxM = bounds.maxM,
      arrayM = arrayM != null ? List.unmodifiable(arrayM) : null,
      super.protected(bounds: bounds, type: ShapeType.shapePOLYLINEM);

  // Internal constructor for subclasses
  @protected
  PolylineM.protected({
    required BoundsM bounds,
    required super.parts,
    required super.points,
    List<double>? arrayM,
    required super.type,
  }) : minM = bounds.minM,
       maxM = bounds.maxM,
       arrayM = arrayM != null ? List.unmodifiable(arrayM) : null,
       super.protected(bounds: bounds);

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
    final mPart = hasM ? '\n$minM, $maxM, $arrayM' : '';
    return '{($minX, $minY, $maxX, $maxY)\n$numParts, $parts\n$numPoints, $points$mPart}';
  }
}

/// PolylineZ has required Z values and optional M values per ESRI spec
class PolylineZ extends Polyline {
  PolylineZ({
    required BoundsZ bounds,
    required super.parts,
    required super.points,
    required List<double> arrayZ,
    List<double>? arrayM,
  }) : minZ = bounds.minZ,
       maxZ = bounds.maxZ,
       minM = bounds.minM,
       maxM = bounds.maxM,
       arrayZ = List.unmodifiable(arrayZ),
       arrayM = arrayM != null ? List.unmodifiable(arrayM) : null,
       super.protected(bounds: bounds, type: ShapeType.shapePOLYLINEZ);

  @protected
  PolylineZ.protected({
    required BoundsZ bounds,
    required super.parts,
    required super.points,
    required List<double> arrayZ,
    List<double>? arrayM,
    required super.type,
  }) : minZ = bounds.minZ,
       maxZ = bounds.maxZ,
       minM = bounds.minM,
       maxM = bounds.maxM,
       arrayZ = List.unmodifiable(arrayZ),
       arrayM = arrayM != null ? List.unmodifiable(arrayM) : null,
       super.protected(bounds: bounds);

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
    final mPart = hasM ? '\n$minM, $maxM, $arrayM' : '';
    return '{($minX, $minY, $maxX, $maxY)\n$numParts, $parts\n$numPoints, $points\n$minZ, $maxZ, $arrayZ$mPart}';
  }
}
