import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/shapefile_bounds.dart';

class Polyline extends Record {
  Polyline({
    required Bounds bounds,
    required List<int> parts,
    required List<Point> points,
  })  : minX = bounds.minX,
        minY = bounds.minY,
        maxX = bounds.maxX,
        maxY = bounds.maxY,
        parts = List.unmodifiable(parts),
        points = List.unmodifiable(points) {
    type = ShapeType.shapePOLYLINE;
  }

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
        ]
      ];

  @override
  String toString() => '{($minX, $minY, $maxX, $maxY)\n$numParts, $parts\n$numPoints, $points}';
}

class PolylineM extends Polyline {
  PolylineM({
    required super.bounds,
    required super.parts,
    required super.points,
    required List<double> arrayM,
  })  : assert(bounds.minM != 0.0 || bounds.maxM != 0.0, 'PolylineM requires bounds with M values set'),
        minM = bounds.minM,
        maxM = bounds.maxM,
        arrayM = List.unmodifiable(arrayM) {
    type = ShapeType.shapePOLYLINEM;
  }

  final double minM;
  final double maxM;
  final List<double> arrayM;

  @override
  List<Object> toList() => [...super.toList(), minM, maxM, arrayM];

  @override
  String toString() => '{($minX, $minY, $maxX, $maxY)\n$numParts, $parts\n$numPoints, $points\n$minM, $maxM, $arrayM}';
}

class PolylineZ extends PolylineM {
  PolylineZ({
    required super.bounds,
    required super.parts,
    required super.points,
    required super.arrayM,
    required List<double> arrayZ,
  })  : assert(bounds.minZ != 0.0 || bounds.maxZ != 0.0, 'PolylineZ requires bounds with Z values set'),
        minZ = bounds.minZ,
        maxZ = bounds.maxZ,
        arrayZ = List.unmodifiable(arrayZ) {
    type = ShapeType.shapePOLYLINEZ;
  }

  final double minZ;
  final double maxZ;
  final List<double> arrayZ;

  @override
  List<Object> toList() => [...super.toList(), minZ, maxZ, arrayZ];

  @override
  String toString() =>
      '{($minX, $minY, $maxX, $maxY)\n$numParts, $parts\n$numPoints, $points\n$minZ, $maxZ, $arrayZ\n$minM, $maxM, $arrayM}';
}
