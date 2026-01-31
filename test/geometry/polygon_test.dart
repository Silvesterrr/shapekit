import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';

void main() {
  group('Polygon', () {
    test('creates a simple polygon', () {
      final points = [
        Point(0.0, 0.0),
        Point(10.0, 0.0),
        Point(10.0, 10.0),
        Point(0.0, 10.0),
        Point(0.0, 0.0), // Close the ring
      ];

      final polygon = Polygon(bounds: Bounds(0.0, 0.0, 10.0, 10.0), parts: [0], points: points);

      expect(polygon.minX, equals(0.0));
      expect(polygon.minY, equals(0.0));
      expect(polygon.maxX, equals(10.0));
      expect(polygon.maxY, equals(10.0));
      expect(polygon.numParts, equals(1));
      expect(polygon.numPoints, equals(5));
      expect(polygon.type, equals(ShapeType.shapePOLYGON));
    });

    test('creates a polygon with hole (donut)', () {
      final points = [
        // Outer ring
        Point(0.0, 0.0),
        Point(10.0, 0.0),
        Point(10.0, 10.0),
        Point(0.0, 10.0),
        Point(0.0, 0.0),
        // Inner ring (hole)
        Point(3.0, 3.0),
        Point(7.0, 3.0),
        Point(7.0, 7.0),
        Point(3.0, 7.0),
        Point(3.0, 3.0),
      ];

      final polygon = Polygon(
        bounds: Bounds(0.0, 0.0, 10.0, 10.0),
        parts: [0, 5], // Outer ring starts at 0, inner ring at 5
        points: points,
      );

      expect(polygon.numParts, equals(2));
      expect(polygon.numPoints, equals(10));
    });

    test('creates a multi-polygon', () {
      final points = [
        // First polygon
        Point(0.0, 0.0),
        Point(5.0, 0.0),
        Point(5.0, 5.0),
        Point(0.0, 5.0),
        Point(0.0, 0.0),
        // Second polygon
        Point(10.0, 10.0),
        Point(15.0, 10.0),
        Point(15.0, 15.0),
        Point(10.0, 15.0),
        Point(10.0, 10.0),
      ];

      final polygon = Polygon(bounds: Bounds(0.0, 0.0, 15.0, 15.0), parts: [0, 5], points: points);

      expect(polygon.numParts, equals(2));
      expect(polygon.numPoints, equals(10));
    });

    test('parts and points are immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 0.0)];

      final polygon = Polygon(bounds: Bounds(0.0, 0.0, 10.0, 10.0), parts: [0], points: points);

      expect(() => polygon.parts.add(1), throwsUnsupportedError);
      expect(() => polygon.points.add(Point(5.0, 5.0)), throwsUnsupportedError);
    });

    test('handles triangle (minimum valid polygon)', () {
      final points = [Point(0.0, 0.0), Point(5.0, 0.0), Point(2.5, 5.0), Point(0.0, 0.0)];

      final polygon = Polygon(bounds: Bounds(0.0, 0.0, 5.0, 5.0), parts: [0], points: points);

      expect(polygon.numPoints, equals(4)); // 3 vertices + closing point
    });

    test('handles complex polygon with many vertices', () {
      // Create a circle approximation with 36 points
      final points = <Point>[];
      for (var i = 0; i <= 36; i++) {
        final angle = (i * 10) * 3.14159 / 180;
        points.add(Point(5 + 5 * cos(angle), 5 + 5 * sin(angle)));
      }

      final polygon = Polygon(bounds: Bounds(0.0, 0.0, 10.0, 10.0), parts: [0], points: points);

      expect(polygon.numPoints, equals(37));
    });
  });

  group('PolygonM', () {
    test('creates a polygon with measure values', () {
      final points = [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 10.0), Point(0.0, 0.0)];
      final arrayM = [0.0, 10.0, 20.0, 30.0, 40.0]; // Perimeter distance

      final polygon = PolygonM(
        bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 0.0, 40.0),
        parts: [0],
        points: points,
        arrayM: arrayM,
      );

      expect(polygon.minM, equals(0.0));
      expect(polygon.maxM, equals(40.0));
      expect(polygon.arrayM, equals([0.0, 10.0, 20.0, 30.0, 40.0]));
      expect(polygon.type, equals(ShapeType.shapePOLYGONM));
    });

    test('arrayM is immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 0.0)];
      final arrayM = [0.0, 10.0, 20.0, 30.0];

      final polygon = PolygonM(
        bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 0.0, 30.0),
        parts: [0],
        points: points,
        arrayM: arrayM,
      );

      expect(() => polygon.arrayM.add(40.0), throwsUnsupportedError);
    });
  });

  group('PolygonZ', () {
    test('creates a polygon with Z and M values', () {
      final points = [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 10.0), Point(0.0, 0.0)];
      final arrayZ = [100.0, 100.0, 150.0, 150.0, 100.0]; // Elevation
      final arrayM = [0.0, 10.0, 20.0, 30.0, 40.0]; // Distance

      final polygon = PolygonZ(
        bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 0.0, 40.0, 100.0, 150.0),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
      );

      expect(polygon.minZ, equals(100.0));
      expect(polygon.maxZ, equals(150.0));
      expect(polygon.minM, equals(0.0));
      expect(polygon.maxM, equals(40.0));
      expect(polygon.arrayZ.length, equals(5));
      expect(polygon.arrayM.length, equals(5));
      expect(polygon.type, equals(ShapeType.shapePOLYGONZ));
    });

    test('arrayZ and arrayM are immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 0.0), Point(0.0, 0.0)];
      final arrayZ = [100.0, 150.0, 100.0];
      final arrayM = [0.0, 10.0, 20.0];

      final polygon = PolygonZ(
        bounds: BoundsZ(0.0, 0.0, 10.0, 0.0, 0.0, 20.0, 100.0, 150.0),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
      );

      expect(() => polygon.arrayZ.add(125.0), throwsUnsupportedError);
      expect(() => polygon.arrayM.add(15.0), throwsUnsupportedError);
    });

    test('handles 3D building footprint', () {
      // Building with varying floor heights
      final points = [Point(0.0, 0.0), Point(20.0, 0.0), Point(20.0, 20.0), Point(0.0, 20.0), Point(0.0, 0.0)];
      final arrayZ = [0.0, 0.0, 50.0, 50.0, 0.0]; // Height in meters
      final arrayM = [0.0, 20.0, 40.0, 60.0, 80.0]; // Perimeter distance

      final polygon = PolygonZ(
        bounds: BoundsZ(0.0, 0.0, 20.0, 20.0, 0.0, 80.0, 0.0, 50.0),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
      );

      expect(polygon.numPoints, equals(5));
      expect(polygon.minZ, equals(0.0));
      expect(polygon.maxZ, equals(50.0));
    });
  });

  group('MultiPatch', () {
    test('creates a multipatch geometry', () {
      final points = [Point(0.0, 0.0), Point(10.0, 0.0), Point(10.0, 10.0), Point(0.0, 0.0)];
      final arrayZ = [0.0, 0.0, 10.0, 0.0];
      final arrayM = [0.0, 10.0, 20.0, 30.0];
      final partTypes = [0]; // Triangle strip

      final multiPatch = MultiPatch(
        bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 0.0, 30.0, 0.0, 10.0),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
        partTypes: partTypes,
      );

      expect(multiPatch.partTypes, equals([0]));
      expect(multiPatch.type, equals(ShapeType.shapeMULTIPATCH));
    });

    test('partTypes is immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 0.0), Point(0.0, 0.0)];
      final arrayZ = [0.0, 0.0, 10.0];
      final arrayM = [0.0, 10.0, 20.0];
      final partTypes = [0];

      final multiPatch = MultiPatch(
        bounds: BoundsZ(0.0, 0.0, 10.0, 0.0, 0.0, 20.0, 0.0, 10.0),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
        partTypes: partTypes,
      );

      expect(() => multiPatch.partTypes.add(1), throwsUnsupportedError);
    });

    test('toList includes partTypes', () {
      final points = [Point(0.0, 0.0), Point(10.0, 0.0), Point(0.0, 0.0)];
      final arrayZ = [0.0, 0.0, 10.0];
      final arrayM = [0.0, 10.0, 20.0];
      final partTypes = [0];

      final multiPatch = MultiPatch(
        bounds: BoundsZ(0.0, 0.0, 10.0, 0.0, 0.0, 20.0, 0.0, 10.0),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
        partTypes: partTypes,
      );

      final list = multiPatch.toList();
      expect(list.last, equals([0])); // partTypes should be last
    });
  });
}

// Helper function for cos (simplified)
double cos(double radians) {
  // Simple approximation for testing
  return (radians * radians / 2 - 1).abs();
}

// Helper function for sin (simplified)
double sin(double radians) {
  // Simple approximation for testing
  return radians - (radians * radians * radians / 6);
}
