import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:shapekit/src/gpkg/codec/wkb_decoder.dart';

void main() {
  group('WkbDecoder', () {
    test('decodes GPKG-WKB Point (little-endian, no envelope)', () {
      final blob = _createGpkgPoint(10.5, 20.3, withEnvelope: false);
      final coords = WkbDecoder.decode(blob);

      expect(coords, isNotNull);
      expect(coords!.length, equals(2));
      expect(coords[0], closeTo(10.5, 0.001));
      expect(coords[1], closeTo(20.3, 0.001));
    });

    test('decodes GPKG-WKB Point with XY envelope', () {
      final blob = _createGpkgPoint(10.5, 20.3, withEnvelope: true);
      final coords = WkbDecoder.decode(blob);

      expect(coords, isNotNull);
      expect(coords!.length, equals(2));
      expect(coords[0], closeTo(10.5, 0.001));
      expect(coords[1], closeTo(20.3, 0.001));
    });

    test('decodes GPKG-WKB LineString', () {
      final blob = _createGpkgLineString([
        (1.0, 2.0),
        (3.0, 4.0),
        (5.0, 6.0),
      ]);
      final coords = WkbDecoder.decode(blob);

      expect(coords, isNotNull);
      expect(coords!.length, equals(6)); // 3 points × 2
      expect(coords[0], closeTo(1.0, 0.001));
      expect(coords[1], closeTo(2.0, 0.001));
      expect(coords[4], closeTo(5.0, 0.001));
      expect(coords[5], closeTo(6.0, 0.001));
    });

    test('decodes GPKG-WKB Polygon (outer ring only)', () {
      final blob = _createGpkgPolygon([
        (0.0, 0.0),
        (10.0, 0.0),
        (10.0, 10.0),
        (0.0, 10.0),
        (0.0, 0.0),
      ]);
      final coords = WkbDecoder.decode(blob);

      expect(coords, isNotNull);
      expect(coords!.length, equals(10)); // 5 points × 2
      expect(coords[0], closeTo(0.0, 0.001));
      expect(coords[8], closeTo(0.0, 0.001));
    });

    test('decodes big-endian WKB', () {
      final blob = _createGpkgPointBigEndian(10.5, 20.3);
      final coords = WkbDecoder.decode(blob);

      expect(coords, isNotNull);
      expect(coords!.length, equals(2));
      expect(coords[0], closeTo(10.5, 0.001));
      expect(coords[1], closeTo(20.3, 0.001));
    });

    test('returns null for too-short blob', () {
      expect(WkbDecoder.decode(Uint8List.fromList([0x47, 0x50])), isNull);
    });

    test('returns empty for empty geometry flag', () {
      final bytes = ByteData(8);
      bytes.setUint8(0, 0x47);
      bytes.setUint8(1, 0x50);
      bytes.setUint8(2, 0x00);
      bytes.setUint8(3, 0x21); // empty geometry flag (bit 5 set)
      bytes.setInt32(4, 4326, Endian.little);

      final coords = WkbDecoder.decode(bytes.buffer.asUint8List());
      expect(coords, isNotNull);
      expect(coords!.length, equals(0));
    });

    test('extractEnvelope returns envelope from GPKG header', () {
      final blob = _createGpkgPoint(10.5, 20.3, withEnvelope: true);
      final env = WkbDecoder.extractEnvelope(blob);

      expect(env, isNotNull);
      expect(env!.minX, closeTo(9.5, 0.001));
      expect(env.maxX, closeTo(11.5, 0.001));
      expect(env.minY, closeTo(19.3, 0.001));
      expect(env.maxY, closeTo(21.3, 0.001));
    });

    group('upgradeEnvelope', () {
      test('adds 32-byte envelope to blob with no envelope', () {
        final original = _createGpkgPoint(10.0, 20.0, withEnvelope: false);
        final upgraded = WkbDecoder.upgradeEnvelope(original);

        expect(upgraded, isNotNull);
        expect(upgraded!.length, equals(original.length + 32));
      });

      test('upgraded blob has envelope indicator = 1 in flags', () {
        final original = _createGpkgPoint(10.0, 20.0, withEnvelope: false);
        final upgraded = WkbDecoder.upgradeEnvelope(original)!;

        final flags = upgraded[3];
        expect((flags >> 1) & 0x07, equals(1)); // XY envelope
      });

      test('upgraded blob preserves magic, version, srs_id', () {
        final original = _createGpkgPoint(10.0, 20.0, withEnvelope: false);
        final upgraded = WkbDecoder.upgradeEnvelope(original)!;

        expect(upgraded[0], equals(0x47)); // 'G'
        expect(upgraded[1], equals(0x50)); // 'P'
        expect(upgraded[2], equals(original[2])); // version
        // srs_id bytes 4-7
        for (int i = 4; i < 8; i++) {
          expect(upgraded[i], equals(original[i]));
        }
      });

      test('extractEnvelope on upgraded blob matches coordinate bounds', () {
        final lineString = _createGpkgLineString([(1.0, 2.0), (5.0, 10.0), (3.0, 6.0)]);
        final upgraded = WkbDecoder.upgradeEnvelope(lineString)!;
        final env = WkbDecoder.extractEnvelope(upgraded);

        expect(env, isNotNull);
        expect(env!.minX, closeTo(1.0, 0.001));
        expect(env.maxX, closeTo(5.0, 0.001));
        expect(env.minY, closeTo(2.0, 0.001));
        expect(env.maxY, closeTo(10.0, 0.001));
      });

      test('WKB payload is preserved after upgrade', () {
        final original = _createGpkgPoint(10.0, 20.0, withEnvelope: false);
        final upgraded = WkbDecoder.upgradeEnvelope(original)!;

        // Original WKB starts at offset 8; upgraded WKB starts at offset 40 (8 + 32).
        expect(upgraded.length - 40, equals(original.length - 8));
        for (int i = 0; i < original.length - 8; i++) {
          expect(upgraded[40 + i], equals(original[8 + i]));
        }
      });

      test('returns same instance when envelope already present', () {
        final withEnv = _createGpkgPoint(10.0, 20.0, withEnvelope: true);
        final result = WkbDecoder.upgradeEnvelope(withEnv);
        expect(identical(result, withEnv), isTrue);
      });

      test('returns same instance for empty geometry', () {
        final emptyBlob = () {
          final bytes = ByteData(8);
          bytes.setUint8(0, 0x47);
          bytes.setUint8(1, 0x50);
          bytes.setUint8(2, 0x00);
          bytes.setUint8(3, 0x21); // empty geometry flag (bit 5 set)
          bytes.setInt32(4, 4326, Endian.little);
          return bytes.buffer.asUint8List();
        }();
        final result = WkbDecoder.upgradeEnvelope(emptyBlob);
        expect(identical(result, emptyBlob), isTrue);
      });

      test('returns null for too-short blob', () {
        expect(WkbDecoder.upgradeEnvelope(Uint8List.fromList([0x47, 0x50])), isNull);
      });

      test('returns null for wrong magic bytes', () {
        final bad = Uint8List(21);
        bad[0] = 0x00;
        bad[1] = 0x00;
        expect(WkbDecoder.upgradeEnvelope(bad), isNull);
      });
    });
  });
}

/// Create a GPKG-WKB Point blob.
Uint8List _createGpkgPoint(double x, double y, {bool withEnvelope = false}) {
  final envelopeSize = withEnvelope ? 32 : 0;
  final totalSize = 8 + envelopeSize + 21; // header + envelope + WKB
  final bytes = ByteData(totalSize);

  // GPKG header
  bytes.setUint8(0, 0x47); // 'G'
  bytes.setUint8(1, 0x50); // 'P'
  bytes.setUint8(2, 0x00); // version
  final flags = withEnvelope ? 0x03 : 0x01; // bit0=LE, bits1-3=envelope indicator
  bytes.setUint8(3, flags);
  bytes.setInt32(4, 4326, Endian.little);

  int offset = 8;

  if (withEnvelope) {
    // Write envelope: minX, maxX, minY, maxY
    bytes.setFloat64(offset, x - 1.0, Endian.little);
    offset += 8;
    bytes.setFloat64(offset, x + 1.0, Endian.little);
    offset += 8;
    bytes.setFloat64(offset, y - 1.0, Endian.little);
    offset += 8;
    bytes.setFloat64(offset, y + 1.0, Endian.little);
    offset += 8;
  }

  // ISO WKB Point
  bytes.setUint8(offset, 0x01);
  bytes.setUint32(offset + 1, 1, Endian.little);
  bytes.setFloat64(offset + 5, x, Endian.little);
  bytes.setFloat64(offset + 13, y, Endian.little);

  return bytes.buffer.asUint8List();
}

/// Create a GPKG-WKB Point with big-endian WKB payload.
Uint8List _createGpkgPointBigEndian(double x, double y) {
  final bytes = ByteData(29);

  bytes.setUint8(0, 0x47);
  bytes.setUint8(1, 0x50);
  bytes.setUint8(2, 0x00);
  bytes.setUint8(3, 0x00); // big-endian, no envelope
  bytes.setInt32(4, 4326, Endian.big);

  // ISO WKB Point — big-endian
  bytes.setUint8(8, 0x00); // big-endian byte order
  bytes.setUint32(9, 1, Endian.big);
  bytes.setFloat64(13, x, Endian.big);
  bytes.setFloat64(21, y, Endian.big);

  return bytes.buffer.asUint8List();
}

/// Create a GPKG-WKB LineString blob.
Uint8List _createGpkgLineString(List<(double, double)> points) {
  final wkbSize = 1 + 4 + 4 + points.length * 16; // byteOrder + type + numPoints + coords
  final totalSize = 8 + wkbSize;
  final bytes = ByteData(totalSize);

  // GPKG header
  bytes.setUint8(0, 0x47);
  bytes.setUint8(1, 0x50);
  bytes.setUint8(2, 0x00);
  bytes.setUint8(3, 0x01); // little-endian, no envelope
  bytes.setInt32(4, 4326, Endian.little);

  // ISO WKB LineString
  bytes.setUint8(8, 0x01);
  bytes.setUint32(9, 2, Endian.little); // LineString
  bytes.setUint32(13, points.length, Endian.little);

  for (int i = 0; i < points.length; i++) {
    final offset = 17 + i * 16;
    bytes.setFloat64(offset, points[i].$1, Endian.little);
    bytes.setFloat64(offset + 8, points[i].$2, Endian.little);
  }

  return bytes.buffer.asUint8List();
}

/// Create a GPKG-WKB Polygon blob (1 ring).
Uint8List _createGpkgPolygon(List<(double, double)> points) {
  final wkbSize = 1 + 4 + 4 + 4 + points.length * 16;
  final totalSize = 8 + wkbSize;
  final bytes = ByteData(totalSize);

  // GPKG header
  bytes.setUint8(0, 0x47);
  bytes.setUint8(1, 0x50);
  bytes.setUint8(2, 0x00);
  bytes.setUint8(3, 0x01);
  bytes.setInt32(4, 4326, Endian.little);

  // ISO WKB Polygon
  bytes.setUint8(8, 0x01);
  bytes.setUint32(9, 3, Endian.little); // Polygon
  bytes.setUint32(13, 1, Endian.little); // 1 ring
  bytes.setUint32(17, points.length, Endian.little);

  for (int i = 0; i < points.length; i++) {
    final offset = 21 + i * 16;
    bytes.setFloat64(offset, points[i].$1, Endian.little);
    bytes.setFloat64(offset + 8, points[i].$2, Endian.little);
  }

  return bytes.buffer.asUint8List();
}
