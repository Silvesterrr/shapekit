import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';

void main() {
  group('WkbEncoder', () {
    test('encodePoint -> decode roundtrip preserves coords', () {
      final blob = WkbEncoder.encodePoint(10.5, 20.3);
      final coords = WkbDecoder.decode(blob)!;
      expect(coords.length, equals(2));
      expect(coords[0], closeTo(10.5, 0.001));
      expect(coords[1], closeTo(20.3, 0.001));
    });

    test('encodeLineString(3 points) -> decode verifies 6 coords', () {
      final points = [(0.0, 0.0), (10.0, 10.0), (20.0, 20.0)];
      final blob = WkbEncoder.encodeLineString(points);
      final coords = WkbDecoder.decode(blob)!;
      expect(coords.length, equals(6));
      expect(coords[0], closeTo(0.0, 0.001));
      expect(coords[1], closeTo(0.0, 0.001));
      expect(coords[4], closeTo(20.0, 0.001));
      expect(coords[5], closeTo(20.0, 0.001));
    });

    test('encodePolygon(4 points, not closed) -> auto-closes to 5 points', () {
      final ring = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)];
      final blob = WkbEncoder.encodePolygon(ring);
      final coords = WkbDecoder.decode(blob)!;
      expect(coords.length, equals(10)); // 5 points x 2
      // First point repeated at end
      expect(coords[8], closeTo(0.0, 0.001));
      expect(coords[9], closeTo(0.0, 0.001));
    });

    test('encodePolygon(5 points, already closed) -> no duplicate', () {
      final ring = [
        (0.0, 0.0),
        (10.0, 0.0),
        (10.0, 10.0),
        (0.0, 10.0),
        (0.0, 0.0),
      ];
      final blob = WkbEncoder.encodePolygon(ring);
      final coords = WkbDecoder.decode(blob)!;
      expect(coords.length, equals(10)); // 5 points x 2, no extra
    });

    test('encoded blob starts with GPKG magic bytes', () {
      final blob = WkbEncoder.encodePoint(0, 0);
      expect(blob[0], equals(0x47));
      expect(blob[1], equals(0x50));
    });
  });
}
