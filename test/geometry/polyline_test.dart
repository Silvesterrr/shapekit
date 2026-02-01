import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';

void main() {
  group('Polyline', () {
    test('creates a polyline with single part', () {
      final points = [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0)];

      final polyline = Polyline(bounds: Bounds(0.0, 0.0, 10.0, 10.0), parts: [0], points: points);

      expect(polyline.minX, equals(0.0));
      expect(polyline.minY, equals(0.0));
      expect(polyline.maxX, equals(10.0));
      expect(polyline.maxY, equals(10.0));
      expect(polyline.numParts, equals(1));
      expect(polyline.numPoints, equals(3));
      expect(polyline.type, equals(ShapeType.shapePOLYLINE));
    });

    test('creates a polyline with multiple parts', () {
      final points = [Point(0.0, 0.0), Point(5.0, 5.0), Point(10.0, 10.0), Point(0.0, 10.0), Point(10.0, 0.0)];

      final polyline = Polyline(
        bounds: Bounds(0.0, 0.0, 10.0, 10.0),
        parts: [0, 3], // Two parts: first starts at 0, second at 3
        points: points,
      );

      expect(polyline.numParts, equals(2));
      expect(polyline.numPoints, equals(5));
      expect(polyline.parts, equals([0, 3]));
    });

    test('parts and points are immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final polyline = Polyline(bounds: Bounds(0.0, 0.0, 10.0, 10.0), parts: [0], points: points);

      expect(() => polyline.parts.add(1), throwsUnsupportedError);
      expect(() => polyline.points.add(Point(5.0, 5.0)), throwsUnsupportedError);
    });

    test('toList returns correct structure', () {
      final points = [Point(1.0, 2.0), Point(3.0, 4.0)];
      final polyline = Polyline(bounds: Bounds(1.0, 2.0, 3.0, 4.0), parts: [0], points: points);

      final list = polyline.toList();
      expect(list[0], equals(1.0)); // minX
      expect(list[1], equals(2.0)); // minY
      expect(list[2], equals(3.0)); // maxX
      expect(list[3], equals(4.0)); // maxY
      expect(list[4], equals([0])); // parts
      expect(list[5], isA<List>()); // points
    });

    test('handles complex multi-part polyline', () {
      final points = List.generate(20, (i) => Point(i.toDouble(), i.toDouble()));
      final polyline = Polyline(
        bounds: Bounds(0.0, 0.0, 19.0, 19.0),
        parts: [0, 5, 10, 15], // Four parts
        points: points,
      );

      expect(polyline.numParts, equals(4));
      expect(polyline.numPoints, equals(20));
    });

    test('toString returns formatted string', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final polyline = Polyline(bounds: Bounds(0.0, 0.0, 10.0, 10.0), parts: [0], points: points);

      final str = polyline.toString();
      expect(str, contains('0.0'));
      expect(str, contains('10.0'));
    });
  });

  group('PolylineM', () {
    test('creates a polyline with measure values', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayM = [0.0, 14.142]; // Distance along line

      final polyline = PolylineM(
        bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 0.0, 14.142),
        parts: [0],
        points: points,
        arrayM: arrayM,
      );

      expect(polyline.minM, equals(0.0));
      expect(polyline.maxM, equals(14.142));
      expect(polyline.arrayM, equals([0.0, 14.142]));
      expect(polyline.type, equals(ShapeType.shapePOLYLINEM));
    });

    test('arrayM is immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayM = [0.0, 10.0];

      final polyline = PolylineM(
        bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 0.0, 10.0),
        parts: [0],
        points: points,
        arrayM: arrayM,
      );

      expect(() => polyline.arrayM?.add(5.0), throwsUnsupportedError);
    });

    test('toList includes M values', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayM = [0.0, 10.0];

      final polyline = PolylineM(
        bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 0.0, 10.0),
        parts: [0],
        points: points,
        arrayM: arrayM,
      );

      final list = polyline.toList();
      // Structure: minX, minY, maxX, maxY, parts, points, minM, maxM, arrayM
      expect(list.length, equals(9));
      expect(list[0], equals(0.0)); // minX
      expect(list[1], equals(0.0)); // minY
      expect(list[2], equals(10.0)); // maxX
      expect(list[3], equals(10.0)); // maxY
      expect(list[4], equals([0])); // parts
      expect(list[5], isA<List>()); // points array
      expect(list[6], equals(0.0)); // minM
      expect(list[7], equals(10.0)); // maxM
      expect(list[8], equals([0.0, 10.0])); // arrayM
    });
  });

  group('PolylineZ', () {
    test('creates a polyline with Z and M values', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayZ = [100.0, 200.0]; // Elevation
      final arrayM = [0.0, 14.142]; // Distance

      final polyline = PolylineZ(
        bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 100.0, 200.0, 0.0, 14.142),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
      );

      expect(polyline.minZ, equals(100.0));
      expect(polyline.maxZ, equals(200.0));
      expect(polyline.minM, equals(0.0));
      expect(polyline.maxM, equals(14.142));
      expect(polyline.arrayZ, equals([100.0, 200.0]));
      expect(polyline.arrayM, equals([0.0, 14.142]));
      expect(polyline.type, equals(ShapeType.shapePOLYLINEZ));
    });

    test('arrayZ and arrayM are immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayZ = [100.0, 200.0];
      final arrayM = [0.0, 10.0];

      final polyline = PolylineZ(
        bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 100.0, 200.0, 0.0, 10.0),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
      );

      expect(() => polyline.arrayZ.add(150.0), throwsUnsupportedError);
      expect(() => polyline.arrayM?.add(5.0), throwsUnsupportedError);
    });

    test('handles elevation profile', () {
      // Simulate a hiking trail with elevation changes
      final points = [Point(0.0, 0.0), Point(1.0, 1.0), Point(2.0, 2.0), Point(3.0, 3.0)];
      final arrayZ = [100.0, 150.0, 120.0, 180.0]; // Elevation in meters
      final arrayM = [0.0, 1.414, 2.828, 4.242]; // Distance in km

      final polyline = PolylineZ(
        bounds: BoundsZ(0.0, 0.0, 3.0, 3.0, 100.0, 180.0, 0.0, 4.242),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
      );

      expect(polyline.numPoints, equals(4));
      expect(polyline.arrayZ.length, equals(4));
      expect(polyline.arrayM?.length, equals(4));
    });

    test('toList includes Z and M values', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayZ = [100.0, 200.0];
      final arrayM = [0.0, 10.0];

      final polyline = PolylineZ(
        bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 100.0, 200.0, 0.0, 10.0),
        parts: [0],
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
      );

      final list = polyline.toList();
      // Structure: minX, minY, maxX, maxY, parts, points, minM, maxM, arrayM, minZ, maxZ, arrayZ
      expect(list.length, equals(12));
      expect(list[0], equals(0.0)); // minX
      expect(list[1], equals(0.0)); // minY
      expect(list[2], equals(10.0)); // maxX
      expect(list[3], equals(10.0)); // maxY
      expect(list[6], equals(100.0)); // minZ
      expect(list[7], equals(200.0)); // maxZ
      expect(list[9], equals(0.0)); // minM
      expect(list[10], equals(10.0)); // maxM
    });
  });
}
