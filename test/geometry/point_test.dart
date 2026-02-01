import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';

void main() {
  group('Point', () {
    test('creates a 2D point with correct coordinates', () {
      final point = Point(126.9780, 37.5665);

      expect(point.x, equals(126.9780));
      expect(point.y, equals(37.5665));
      expect(point.type, equals(ShapeType.shapePOINT));
    });

    test('toList returns correct coordinate array', () {
      final point = Point(10.5, 20.3);
      final list = point.toList();

      expect(list, equals([10.5, 20.3]));
    });

    test('toString returns formatted string', () {
      final point = Point(1.0, 2.0);
      expect(point.toString(), equals('{1.0, 2.0}'));
    });

    test('handles negative coordinates', () {
      final point = Point(-122.4194, -37.7749);

      expect(point.x, equals(-122.4194));
      expect(point.y, equals(-37.7749));
    });

    test('handles zero coordinates', () {
      final point = Point(0.0, 0.0);

      expect(point.x, equals(0.0));
      expect(point.y, equals(0.0));
    });

    test('handles very large coordinates', () {
      final point = Point(180.0, 90.0);

      expect(point.x, equals(180.0));
      expect(point.y, equals(90.0));
    });
  });

  group('PointM', () {
    test('creates a point with measure value', () {
      final point = PointM(126.9780, 37.5665, 42.5);

      expect(point.x, equals(126.9780));
      expect(point.y, equals(37.5665));
      expect(point.m, equals(42.5));
      expect(point.type, equals(ShapeType.shapePOINTM));
    });

    test('toList includes measure value', () {
      final point = PointM(10.5, 20.3, 100.0);
      final list = point.toList();

      expect(list, equals([10.5, 20.3, 100.0]));
    });

    test('toString includes measure value', () {
      final point = PointM(1.0, 2.0, 3.0);
      expect(point.toString(), equals('{1.0, 2.0, 3.0}'));
    });

    test('handles negative measure values', () {
      final point = PointM(10.0, 20.0, -5.0);
      expect(point.m, equals(-5.0));
    });

    test('handles zero measure value', () {
      final point = PointM(10.0, 20.0, 0.0);
      expect(point.m, equals(0.0));
    });
  });

  group('PointZ', () {
    test('creates a 3D point with Z and M values', () {
      final point = PointZ(126.9780, 37.5665, 123.4, 42.5);

      expect(point.x, equals(126.9780));
      expect(point.y, equals(37.5665));
      expect(point.m, equals(42.5));
      expect(point.z, equals(123.4));
      expect(point.type, equals(ShapeType.shapePOINTZ));
    });

    test('toList includes Z and M values', () {
      final point = PointZ(10.5, 20.3, 40.0, 30.0);
      final list = point.toList();

      expect(list, equals([10.5, 20.3, 30.0, 40.0]));
    });

    test('toString includes all values', () {
      final point = PointZ(1.0, 2.0, 4.0, 3.0);
      expect(point.toString(), equals('{1.0, 2.0, 4.0, 3.0}'));
    });

    test('handles negative Z values (below sea level)', () {
      final point = PointZ(10.0, 20.0, -50.0, 30.0);
      expect(point.z, equals(-50.0));
    });

    test('handles zero elevation', () {
      final point = PointZ(10.0, 20.0, 0.0, 0.0);
      expect(point.z, equals(0.0));
    });

    test('handles high elevation values', () {
      final point = PointZ(86.9250, 27.9881, 8848.86, 0.0); // Mt. Everest
      expect(point.z, equals(8848.86));
    });
  });

  group('MultiPoint', () {
    test('creates a multipoint with correct bounds', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0), Point(5.0, 5.0)];

      final multiPoint = MultiPoint(points: points, bounds: Bounds(0.0, 0.0, 10.0, 10.0));

      expect(multiPoint.minX, equals(0.0));
      expect(multiPoint.minY, equals(0.0));
      expect(multiPoint.maxX, equals(10.0));
      expect(multiPoint.maxY, equals(10.0));
      expect(multiPoint.numPoints, equals(3));
      expect(multiPoint.type, equals(ShapeType.shapeMULTIPOINT));
    });

    test('points are immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final multiPoint = MultiPoint(points: points, bounds: Bounds(0.0, 0.0, 10.0, 10.0));

      expect(() => multiPoint.points.add(Point(5.0, 5.0)), throwsUnsupportedError);
    });

    test('toList returns correct structure', () {
      final points = [Point(1.0, 2.0), Point(3.0, 4.0)];
      final multiPoint = MultiPoint(points: points, bounds: Bounds(1.0, 2.0, 3.0, 4.0));

      final list = multiPoint.toList();
      expect(list[0], equals(1.0)); // minX
      expect(list[1], equals(2.0)); // minY
      expect(list[2], equals(3.0)); // maxX
      expect(list[3], equals(4.0)); // maxY
      expect(list[4], isA<List>());
    });

    test('handles single point', () {
      final points = [Point(5.0, 5.0)];
      final multiPoint = MultiPoint(points: points, bounds: Bounds(5.0, 5.0, 5.0, 5.0));

      expect(multiPoint.numPoints, equals(1));
    });

    test('handles many points', () {
      final points = List.generate(100, (i) => Point(i.toDouble(), i.toDouble()));
      final multiPoint = MultiPoint(points: points, bounds: Bounds(0.0, 0.0, 99.0, 99.0));

      expect(multiPoint.numPoints, equals(100));
    });
  });

  group('MultiPointM', () {
    test('creates a multipoint with M values', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayM = [1.0, 2.0];

      final multiPoint = MultiPointM(points: points, arrayM: arrayM, bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 1.0, 2.0));

      expect(multiPoint.minM, equals(1.0));
      expect(multiPoint.maxM, equals(2.0));
      expect(multiPoint.arrayM, equals([1.0, 2.0]));
      expect(multiPoint.type, equals(ShapeType.shapeMULTIPOINTM));
    });

    test('arrayM is immutable', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayM = [1.0, 2.0];

      final multiPoint = MultiPointM(points: points, arrayM: arrayM, bounds: BoundsM(0.0, 0.0, 10.0, 10.0, 1.0, 2.0));

      expect(() => multiPoint.arrayM.add(3.0), throwsUnsupportedError);
    });
  });

  group('MultiPointZ', () {
    test('creates a multipoint with Z and M values', () {
      final points = [Point(0.0, 0.0), Point(10.0, 10.0)];
      final arrayZ = [100.0, 200.0];
      final arrayM = [1.0, 2.0];

      final multiPoint = MultiPointZ(
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
        bounds: BoundsZ(0.0, 0.0, 10.0, 10.0, 1.0, 2.0, 100.0, 200.0),
      );

      expect(multiPoint.minZ, equals(100.0));
      expect(multiPoint.maxZ, equals(200.0));
      expect(multiPoint.minM, equals(1.0));
      expect(multiPoint.maxM, equals(2.0));
      expect(multiPoint.arrayZ, equals([100.0, 200.0]));
      expect(multiPoint.arrayM, equals([1.0, 2.0]));
      expect(multiPoint.type, equals(ShapeType.shapeMULTIPOINTZ));
    });

    test('arrayZ is immutable', () {
      final points = [Point(0.0, 0.0)];
      final arrayZ = [100.0];
      final arrayM = [1.0];

      final multiPoint = MultiPointZ(
        points: points,
        arrayZ: arrayZ,
        arrayM: arrayM,
        bounds: BoundsZ(0.0, 0.0, 0.0, 0.0, 100.0, 100.0, 1.0, 1.0),
      );

      expect(() => multiPoint.arrayZ.add(200.0), throwsUnsupportedError);
    });
  });
}
