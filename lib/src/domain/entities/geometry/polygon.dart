import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/entities/geometry/polyline.dart';

class Polygon extends Polyline {
  Polygon({required super.bounds, required super.parts, required super.points})
    : super.protected(type: ShapeType.shapePOLYGON);
}

class PolygonM extends PolylineM {
  PolygonM({required super.bounds, required super.parts, required super.points, required super.arrayM})
    : super.protected(type: ShapeType.shapePOLYGONM);
}

class PolygonZ extends PolylineZ {
  PolygonZ({
    required super.bounds,
    required super.parts,
    required super.points,
    required super.arrayM,
    required super.arrayZ,
  }) : super.protected(type: ShapeType.shapePOLYGONZ);
}

class MultiPatch extends PolylineZ {
  MultiPatch({
    required super.bounds,
    required super.parts,
    required super.points,
    required super.arrayM,
    required super.arrayZ,
    required List<int> partTypes,
  }) : partTypes = List.unmodifiable(partTypes),
       super.protected(type: ShapeType.shapeMULTIPATCH);

  final List<int> partTypes;

  @override
  List<Object> toList() => [...super.toList(), partTypes];

  @override
  String toString() =>
      '{($minX, $minY, $maxX, $maxY)\n$numParts, $parts, $partTypes\n$numPoints, $points\n$minZ, $maxZ, $arrayZ\n$minM, $maxM, $arrayM}';
}
