import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/entities/geometry/polyline.dart';

class Polygon extends Polyline {
  Polygon({required super.bounds, required super.parts, required super.points})
    : super.protected(type: ShapeType.shapePOLYGON);
}

class PolygonM extends PolylineM {
  PolygonM({required super.bounds, required super.parts, required super.points, super.arrayM})
    : super.protected(type: ShapeType.shapePOLYGONM);
}

class PolygonZ extends PolylineZ {
  PolygonZ({required super.bounds, required super.parts, required super.points, required super.arrayZ, super.arrayM})
    : super.protected(type: ShapeType.shapePOLYGONZ);
}

class MultiPatch extends PolylineZ {
  MultiPatch({
    required super.bounds,
    required super.parts,
    required super.points,
    required super.arrayZ,
    super.arrayM,
    required List<int> partTypes,
  }) : partTypes = List.unmodifiable(partTypes),
       super.protected(type: ShapeType.shapeMULTIPATCH);

  final List<int> partTypes;

  @override
  List<Object> toList() => [...super.toList(), partTypes];

  @override
  String toString() {
    final mPart = hasM ? '\n$minM, $maxM, $arrayM' : '';
    return '{($minX, $minY, $maxX, $maxY)\n$numParts, $parts, $partTypes\n$numPoints, $points\n$minZ, $maxZ, $arrayZ$mPart}';
  }
}

/// Extension providing ring and hole utilities for [Polygon] geometries.
extension PolygonHolesExtension on Polygon {
  /// Extract the outer ring (first part) as a list of Points.
  List<Point> get outerRing {
    if (parts.isEmpty || points.isEmpty) return [];
    final endIdx = parts.length > 1 ? parts[1] : points.length;
    return points.sublist(0, endIdx);
  }

  /// Extract all interior rings (holes) as lists of Points.
  List<List<Point>> get holes {
    if (parts.length <= 1) return [];
    final result = <List<Point>>[];
    for (int i = 1; i < parts.length; i++) {
      final startIdx = parts[i];
      final endIdx = i + 1 < parts.length ? parts[i + 1] : points.length;
      result.add(points.sublist(startIdx, endIdx));
    }
    return result;
  }

  /// Check if this polygon has interior rings (holes).
  bool get hasHoles => parts.length > 1;

  /// Get the number of rings (1 outer + n holes).
  int get ringCount => parts.length;

  /// Get a specific ring by index (0 = outer, 1+ = holes).
  List<Point> getRing(int index) {
    if (index < 0 || index >= parts.length) return [];
    final startIdx = parts[index];
    final endIdx = index + 1 < parts.length ? parts[index + 1] : points.length;
    return points.sublist(startIdx, endIdx);
  }
}

/// Extension providing ring and hole utilities for [PolygonM] geometries.
extension PolygonMHolesExtension on PolygonM {
  /// Extract the outer ring (first part) as a list of Points.
  List<Point> get outerRing {
    if (parts.isEmpty || points.isEmpty) return [];
    final endIdx = parts.length > 1 ? parts[1] : points.length;
    return points.sublist(0, endIdx);
  }

  /// Extract all interior rings (holes) as lists of Points.
  List<List<Point>> get holes {
    if (parts.length <= 1) return [];
    final result = <List<Point>>[];
    for (int i = 1; i < parts.length; i++) {
      final startIdx = parts[i];
      final endIdx = i + 1 < parts.length ? parts[i + 1] : points.length;
      result.add(points.sublist(startIdx, endIdx));
    }
    return result;
  }

  /// Check if this polygon has interior rings (holes).
  bool get hasHoles => parts.length > 1;

  /// Get the number of rings (1 outer + n holes).
  int get ringCount => parts.length;
}

/// Extension providing ring and hole utilities for [PolygonZ] geometries.
extension PolygonZHolesExtension on PolygonZ {
  /// Extract the outer ring (first part) as a list of Points.
  List<Point> get outerRing {
    if (parts.isEmpty || points.isEmpty) return [];
    final endIdx = parts.length > 1 ? parts[1] : points.length;
    return points.sublist(0, endIdx);
  }

  /// Extract all interior rings (holes) as lists of Points.
  List<List<Point>> get holes {
    if (parts.length <= 1) return [];
    final result = <List<Point>>[];
    for (int i = 1; i < parts.length; i++) {
      final startIdx = parts[i];
      final endIdx = i + 1 < parts.length ? parts[i + 1] : points.length;
      result.add(points.sublist(startIdx, endIdx));
    }
    return result;
  }

  /// Check if this polygon has interior rings (holes).
  bool get hasHoles => parts.length > 1;

  /// Get the number of rings (1 outer + n holes).
  int get ringCount => parts.length;
}
