import 'dart:typed_data';
import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/geometry/polyline.dart';
import 'package:shapekit/src/domain/entities/geometry/polygon.dart';
import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/entities/geometry/envelope.dart';

/// Decodes GeoPackage WKB (GPKG-WKB) geometries into flat Float32List coordinates.
///
/// GeoPackage stores geometries in GeoPackage Binary Format which wraps
/// ISO WKB with a header containing magic bytes, flags, SRS ID, and optional
/// envelope. This class strips the GPKG header and parses the ISO WKB payload.
class WkbDecoder {
  /// ISO WKB geometry type constants
  static const int _wkbPoint = 1;
  static const int _wkbLineString = 2;
  static const int _wkbPolygon = 3;
  static const int _wkbMultiPoint = 4;
  static const int _wkbMultiLineString = 5;
  static const int _wkbMultiPolygon = 6;

  /// Strip Z (+1000), M (+2000), ZM (+3000) offsets to get the base 2D type.
  static int _baseType(int t) {
    if (t > 3000) return t - 3000; // ZM
    if (t > 2000) return t - 2000; // M
    if (t > 1000) return t - 1000; // Z
    return t;
  }

  /// Returns true if the WKB type has Z coordinates.
  static bool _hasZ(int t) => (t > 1000 && t < 2000) || t > 3000;

  /// Returns true if the WKB type has M coordinates.
  static bool _hasM(int t) => (t > 2000 && t < 3000) || t > 3000;

  /// Byte stride per coordinate tuple: 16 (XY), 24 (XYZ/XYM), 32 (XYZM).
  static int _pointStride(int t) {
    final z = _hasZ(t);
    final m = _hasM(t);
    if (z && m) return 32;
    if (z || m) return 24;
    return 16;
  }

  /// Decode a GPKG-WKB blob into flat [x1,y1, x2,y2, ...] coordinates.
  ///
  /// Returns null if the blob is too short or cannot be parsed.
  /// For polygons, only the outer ring is returned (holes are skipped).
  /// For multi-geometries, all sub-geometries are concatenated.
  static Float32List? decode(Uint8List gpkgWkb) {
    if (gpkgWkb.length < 8) return null;

    // Check GPKG magic
    if (gpkgWkb[0] != 0x47 || gpkgWkb[1] != 0x50) return null;

    final flags = gpkgWkb[3];

    // Check empty geometry flag (bit 5)
    if ((flags & 0x20) != 0) return Float32List(0);

    final headerSize = _gpkgHeaderSize(gpkgWkb);
    if (headerSize >= gpkgWkb.length) return null;

    final data = ByteData.sublistView(gpkgWkb);
    return _parseWkb(data, headerSize);
  }

  /// Rewrite a GPKG-WKB blob to embed an XY envelope in the header.
  ///
  /// Returns the original blob unchanged if an envelope is already present
  /// (any indicator > 0). Returns null on malformed input or empty geometries
  /// where no coordinates can be sampled.
  ///
  /// Used by the import pipeline to preempt the slow full-WKB-decode fallback
  /// in [SpatialIndex.build]: after upgrade, every row's envelope can be read
  /// straight from the 32-byte header chunk.
  static Uint8List? upgradeEnvelope(Uint8List gpkgWkb) {
    if (gpkgWkb.length < 8) return null;
    if (gpkgWkb[0] != 0x47 || gpkgWkb[1] != 0x50) return null;

    final flags = gpkgWkb[3];
    final envelopeIndicator = (flags >> 1) & 0x07;

    if (envelopeIndicator > 0) return gpkgWkb;
    if ((flags & 0x20) != 0) return gpkgWkb; // Empty geometry — no envelope.

    final coords = decode(gpkgWkb);
    if (coords == null || coords.length < 2) return null;

    var minX = coords[0].toDouble();
    var maxX = minX;
    var minY = coords[1].toDouble();
    var maxY = minY;
    for (int i = 2; i < coords.length; i += 2) {
      final x = coords[i].toDouble();
      final y = coords[i + 1].toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final wkbPayloadLen = gpkgWkb.length - 8;
    final out = Uint8List(8 + 32 + wkbPayloadLen);

    out[0] = gpkgWkb[0];
    out[1] = gpkgWkb[1];
    out[2] = gpkgWkb[2];
    out[3] = (flags & ~0x0E) | 0x02; // Clear EC bits (1-3), set indicator=1.
    out[4] = gpkgWkb[4];
    out[5] = gpkgWkb[5];
    out[6] = gpkgWkb[6];
    out[7] = gpkgWkb[7];

    // TODO(envelope-endianness): respect flags bit 0 — all real-world GPKGs are little-endian, but spec allows big.
    final bd = ByteData.sublistView(out);
    bd.setFloat64(8, minX, Endian.little);
    bd.setFloat64(16, maxX, Endian.little);
    bd.setFloat64(24, minY, Endian.little);
    bd.setFloat64(32, maxY, Endian.little);

    out.setRange(40, 40 + wkbPayloadLen, gpkgWkb, 8);
    return out;
  }

  /// Extract the GPKG envelope from a GPKG-WKB blob.
  ///
  /// Returns null if the blob doesn't have a valid GPKG header.
  static ({double minX, double minY, double maxX, double maxY})? extractEnvelope(Uint8List gpkgWkb) {
    if (gpkgWkb.length < 8) return null;
    if (gpkgWkb[0] != 0x47 || gpkgWkb[1] != 0x50) return null;

    final flags = gpkgWkb[3];
    final envelopeIndicator = (flags >> 1) & 0x07;

    if (envelopeIndicator == 0) return null;

    // TODO(envelope-endianness): respect flags bit 0 — all real-world GPKGs are little-endian, but spec allows big.
    final data = ByteData.sublistView(gpkgWkb);
    // Envelope starts at offset 8
    final minX = data.getFloat64(8, Endian.little);
    final maxX = data.getFloat64(16, Endian.little);
    final minY = data.getFloat64(24, Endian.little);
    final maxY = data.getFloat64(32, Endian.little);

    return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  /// Calculate GPKG-WKB header size based on the envelope indicator.
  static int _gpkgHeaderSize(Uint8List bytes) {
    final flags = bytes[3];
    final envelopeIndicator = (flags >> 1) & 0x07;

    // Base header: magic(2) + version(1) + flags(1) + srs_id(4) = 8 bytes
    int size = 8;

    switch (envelopeIndicator) {
      case 0:
        break; // No envelope
      case 1:
        size += 32;
        break; // XY: 4 × float64
      case 2:
        size += 48;
        break; // XYZ: 6 × float64
      case 3:
        size += 48;
        break; // XYM: 6 × float64
      case 4:
        size += 64;
        break; // XYZM: 8 × float64
    }

    return size;
  }

  /// Parse ISO WKB payload starting at [offset].
  static Float32List? _parseWkb(ByteData data, int offset) {
    if (offset + 5 > data.lengthInBytes) return null;

    final byteOrder = data.getUint8(offset);
    final endian = byteOrder == 0x01 ? Endian.little : Endian.big;

    final geomType = data.getUint32(offset + 1, endian);
    final base = _baseType(geomType);
    final stride = _pointStride(geomType);

    switch (base) {
      case _wkbPoint:
        return _decodePoint(data, offset + 5, endian, stride: stride);
      case _wkbLineString:
        return _decodeLineString(data, offset + 5, endian, stride: stride);
      case _wkbPolygon:
        return _decodePolygonFlat(data, offset + 5, endian, stride: stride);
      case _wkbMultiPoint:
        return _decodeMultiPoint(data, offset + 5, endian, stride: stride);
      case _wkbMultiLineString:
        return _decodeMultiLineString(data, offset + 5, endian, stride: stride);
      case _wkbMultiPolygon:
        return _decodeMultiPolygonFlat(data, offset + 5, endian, stride: stride);
      default:
        return null;
    }
  }

  static Float32List _decodePoint(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + stride > data.lengthInBytes) return Float32List(0);

    final coords = Float32List(2);
    coords[0] = data.getFloat64(offset, endian).toDouble();
    coords[1] = data.getFloat64(offset + 8, endian).toDouble();
    return coords;
  }

  static Float32List _decodeLineString(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return Float32List(0);

    final numPoints = data.getUint32(offset, endian);
    offset += 4;

    if (numPoints == 0) return Float32List(0);
    if (offset + numPoints * stride > data.lengthInBytes) return Float32List(0);

    final coords = Float32List(numPoints * 2);
    for (int i = 0; i < numPoints; i++) {
      final pos = offset + i * stride;
      coords[i * 2] = data.getFloat64(pos, endian).toDouble();
      coords[i * 2 + 1] = data.getFloat64(pos + 8, endian).toDouble();
    }
    return coords;
  }

  /// Decode polygon — outer ring only (holes skipped).
  static Float32List _decodePolygonFlat(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return Float32List(0);

    final numRings = data.getUint32(offset, endian);
    offset += 4;

    if (numRings == 0) return Float32List(0);

    // Read first (outer) ring only
    return _decodeRing(data, offset, endian, stride: stride);
  }

  static Float32List _decodeRing(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return Float32List(0);

    final numPoints = data.getUint32(offset, endian);
    offset += 4;

    if (numPoints == 0) return Float32List(0);
    if (offset + numPoints * stride > data.lengthInBytes) return Float32List(0);

    final coords = Float32List(numPoints * 2);
    for (int i = 0; i < numPoints; i++) {
      final pos = offset + i * stride;
      coords[i * 2] = data.getFloat64(pos, endian).toDouble();
      coords[i * 2 + 1] = data.getFloat64(pos + 8, endian).toDouble();
    }
    return coords;
  }

  static Float32List _decodeMultiPoint(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return Float32List(0);

    final numGeoms = data.getUint32(offset, endian);
    offset += 4;

    final allCoords = <double>[];
    for (int i = 0; i < numGeoms; i++) {
      if (offset + 5 > data.lengthInBytes) break;

      final subOrder = data.getUint8(offset);
      final subEndian = subOrder == 0x01 ? Endian.little : Endian.big;
      final subType = data.getUint32(offset + 1, subEndian);
      offset += 5;

      if (_baseType(subType) == _wkbPoint) {
        final subStride = _pointStride(subType);
        final pt = _decodePoint(data, offset, subEndian, stride: subStride);
        for (int j = 0; j < pt.length; j++) {
          allCoords.add(pt[j]);
        }
        offset += subStride;
      }
    }

    final result = Float32List(allCoords.length);
    for (int i = 0; i < allCoords.length; i++) {
      result[i] = allCoords[i];
    }
    return result;
  }

  static Float32List _decodeMultiLineString(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return Float32List(0);

    final numGeoms = data.getUint32(offset, endian);
    offset += 4;

    final allCoords = <double>[];
    for (int i = 0; i < numGeoms; i++) {
      if (offset + 5 > data.lengthInBytes) break;

      final subOrder = data.getUint8(offset);
      final subEndian = subOrder == 0x01 ? Endian.little : Endian.big;
      final subType = data.getUint32(offset + 1, subEndian);
      offset += 5;

      if (_baseType(subType) == _wkbLineString) {
        final subStride = _pointStride(subType);
        final coords = _decodeLineString(data, offset, subEndian, stride: subStride);
        for (int j = 0; j < coords.length; j++) {
          allCoords.add(coords[j]);
        }
        // Advance past the linestring data: numPoints(4) + points
        if (offset + 4 <= data.lengthInBytes) {
          final nPts = data.getUint32(offset, subEndian);
          offset += 4 + nPts * subStride;
        }
      }
    }

    final result = Float32List(allCoords.length);
    for (int i = 0; i < allCoords.length; i++) {
      result[i] = allCoords[i];
    }
    return result;
  }

  // ─── Typed decode methods (return domain entities) ────────────────

  /// Decode a GPKG-WKB blob as a [Point] geometry
  static Point? decodePoint(Uint8List gpkgWkb) {
    if (gpkgWkb.length < 8) return null;
    if (gpkgWkb[0] != 0x47 || gpkgWkb[1] != 0x50) return null;

    final headerSize = _gpkgHeaderSize(gpkgWkb);
    if (headerSize >= gpkgWkb.length) return null;

    final data = ByteData.sublistView(gpkgWkb);
    if (headerSize + 21 > data.lengthInBytes) return null;

    final byteOrder = data.getUint8(headerSize);
    final endian = byteOrder == 0x01 ? Endian.little : Endian.big;
    final geomType = data.getUint32(headerSize + 1, endian);

    if (_baseType(geomType) != _wkbPoint) return null;

    final x = data.getFloat64(headerSize + 5, endian);
    final y = data.getFloat64(headerSize + 13, endian);
    return Point(x, y);
  }

  /// Decode a GPKG-WKB blob as a [Polyline] geometry
  static Polyline? decodePolyline(Uint8List gpkgWkb) {
    if (gpkgWkb.length < 8) return null;
    if (gpkgWkb[0] != 0x47 || gpkgWkb[1] != 0x50) return null;

    final headerSize = _gpkgHeaderSize(gpkgWkb);
    if (headerSize >= gpkgWkb.length) return null;

    final data = ByteData.sublistView(gpkgWkb);
    if (headerSize + 5 > data.lengthInBytes) return null;

    final byteOrder = data.getUint8(headerSize);
    final endian = byteOrder == 0x01 ? Endian.little : Endian.big;
    final geomType = data.getUint32(headerSize + 1, endian);
    final base = _baseType(geomType);
    final stride = _pointStride(geomType);

    if (base == _wkbLineString) {
      final points = _decodePointList(data, headerSize + 5, endian, stride: stride);
      if (points.isEmpty) return null;
      final bounds = _boundsFromPoints(points);
      return Polyline(bounds: bounds, parts: [0], points: points);
    }

    if (base == _wkbMultiLineString) {
      final result = _decodeMultiLineStringParts(data, headerSize + 5, endian, stride: stride);
      if (result.$1.isEmpty) return null;
      return Polyline(bounds: _boundsFromPoints(result.$1), parts: result.$2, points: result.$1);
    }

    return null;
  }

  /// Decode a GPKG-WKB blob as a [Polygon] geometry
  ///
  /// All rings (outer boundary + holes) are returned as separate parts.
  static Polygon? decodePolygon(Uint8List gpkgWkb) {
    if (gpkgWkb.length < 8) return null;
    if (gpkgWkb[0] != 0x47 || gpkgWkb[1] != 0x50) return null;

    final headerSize = _gpkgHeaderSize(gpkgWkb);
    if (headerSize >= gpkgWkb.length) return null;

    final data = ByteData.sublistView(gpkgWkb);
    if (headerSize + 5 > data.lengthInBytes) return null;

    final byteOrder = data.getUint8(headerSize);
    final endian = byteOrder == 0x01 ? Endian.little : Endian.big;
    final geomType = data.getUint32(headerSize + 1, endian);
    final base = _baseType(geomType);
    final stride = _pointStride(geomType);

    if (base == _wkbPolygon) {
      final result = _decodePolygonParts(data, headerSize + 5, endian, stride: stride);
      if (result.$1.isEmpty) return null;
      return Polygon(bounds: _boundsFromPoints(result.$1), parts: result.$2, points: result.$1);
    }

    if (base == _wkbMultiPolygon) {
      final result = _decodeMultiPolygonParts(data, headerSize + 5, endian, stride: stride);
      if (result.$1.isEmpty) return null;
      return Polygon(bounds: _boundsFromPoints(result.$1), parts: result.$2, points: result.$1);
    }

    return null;
  }

  /// Decode any geometry type and return the appropriate [Record] subclass
  static Record? decodeAsRecord(Uint8List gpkgWkb) {
    if (gpkgWkb.length < 8) return null;
    if (gpkgWkb[0] != 0x47 || gpkgWkb[1] != 0x50) return null;

    final headerSize = _gpkgHeaderSize(gpkgWkb);
    if (headerSize >= gpkgWkb.length) return null;

    final data = ByteData.sublistView(gpkgWkb);
    if (headerSize + 5 > data.lengthInBytes) return null;

    final byteOrder = data.getUint8(headerSize);
    final endian = byteOrder == 0x01 ? Endian.little : Endian.big;
    final geomType = data.getUint32(headerSize + 1, endian);

    switch (_baseType(geomType)) {
      case _wkbPoint:
        return decodePoint(gpkgWkb);
      case _wkbMultiPoint:
        return _decodeMultiPointRecord(data, headerSize + 5, endian, stride: _pointStride(geomType));
      case _wkbLineString:
      case _wkbMultiLineString:
        return decodePolyline(gpkgWkb);
      case _wkbPolygon:
      case _wkbMultiPolygon:
        return decodePolygon(gpkgWkb);
      default:
        return null;
    }
  }

  static MultiPoint? _decodeMultiPointRecord(ByteData data, int offset, Endian endian, {int stride = 16}) {
    final points = _decodeMultiPointList(data, offset, endian, stride: stride);
    if (points.isEmpty) return null;
    return MultiPoint(points: points, bounds: _boundsFromPoints(points));
  }

  // ─── Private typed helpers ────────────────────────────────────────

  static List<Point> _decodePointList(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return [];

    final numPoints = data.getUint32(offset, endian);
    offset += 4;

    if (numPoints == 0) return [];
    if (offset + numPoints * stride > data.lengthInBytes) return [];

    final points = <Point>[];
    for (int i = 0; i < numPoints; i++) {
      final pos = offset + i * stride;
      final x = data.getFloat64(pos, endian);
      final y = data.getFloat64(pos + 8, endian);
      points.add(Point(x, y));
    }
    return points;
  }

  static List<Point> _decodeMultiPointList(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return [];

    final numGeoms = data.getUint32(offset, endian);
    offset += 4;

    final points = <Point>[];
    for (int i = 0; i < numGeoms; i++) {
      if (offset + 5 > data.lengthInBytes) break;

      final subOrder = data.getUint8(offset);
      final subEndian = subOrder == 0x01 ? Endian.little : Endian.big;
      final subType = data.getUint32(offset + 1, subEndian);
      offset += 5;

      if (_baseType(subType) == _wkbPoint) {
        final subStride = _pointStride(subType);
        if (offset + subStride > data.lengthInBytes) break;
        final x = data.getFloat64(offset, subEndian);
        final y = data.getFloat64(offset + 8, subEndian);
        points.add(Point(x, y));
        offset += subStride;
      }
    }
    return points;
  }

  /// Returns (allPoints, partsIndices) for a MultiLineString
  static (List<Point>, List<int>) _decodeMultiLineStringParts(
    ByteData data,
    int offset,
    Endian endian, {
    int stride = 16,
  }) {
    if (offset + 4 > data.lengthInBytes) return ([], []);

    final numGeoms = data.getUint32(offset, endian);
    offset += 4;

    final allPoints = <Point>[];
    final parts = <int>[];

    for (int i = 0; i < numGeoms; i++) {
      if (offset + 5 > data.lengthInBytes) break;

      final subOrder = data.getUint8(offset);
      final subEndian = subOrder == 0x01 ? Endian.little : Endian.big;
      final subType = data.getUint32(offset + 1, subEndian);
      offset += 5;

      if (_baseType(subType) == _wkbLineString) {
        final subStride = _pointStride(subType);
        parts.add(allPoints.length);
        final pts = _decodePointList(data, offset, subEndian, stride: subStride);
        allPoints.addAll(pts);
        if (offset + 4 <= data.lengthInBytes) {
          final nPts = data.getUint32(offset, subEndian);
          offset += 4 + nPts * subStride;
        }
      }
    }
    return (allPoints, parts);
  }

  /// Returns (allPoints, partsIndices) for a Polygon — all rings (outer + holes) as parts.
  static (List<Point>, List<int>) _decodePolygonParts(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return ([], []);

    final numRings = data.getUint32(offset, endian);
    offset += 4;

    if (numRings == 0) return ([], []);

    final allPoints = <Point>[];
    final parts = <int>[];

    for (int r = 0; r < numRings; r++) {
      if (offset + 4 > data.lengthInBytes) break;

      final numPoints = data.getUint32(offset, endian);
      final ringOffset = offset + 4;

      parts.add(allPoints.length);
      for (int i = 0; i < numPoints; i++) {
        final pos = ringOffset + i * stride;
        if (pos + 16 > data.lengthInBytes) break;
        final x = data.getFloat64(pos, endian);
        final y = data.getFloat64(pos + 8, endian);
        allPoints.add(Point(x, y));
      }

      offset = ringOffset + numPoints * stride;
    }

    return (allPoints, parts);
  }

  /// Returns (allPoints, partsIndices) for a MultiPolygon — all rings (outer + holes) as parts.
  static (List<Point>, List<int>) _decodeMultiPolygonParts(
    ByteData data,
    int offset,
    Endian endian, {
    int stride = 16,
  }) {
    if (offset + 4 > data.lengthInBytes) return ([], []);

    final numGeoms = data.getUint32(offset, endian);
    offset += 4;

    final allPoints = <Point>[];
    final parts = <int>[];

    for (int i = 0; i < numGeoms; i++) {
      if (offset + 5 > data.lengthInBytes) break;

      final subOrder = data.getUint8(offset);
      final subEndian = subOrder == 0x01 ? Endian.little : Endian.big;
      final subType = data.getUint32(offset + 1, subEndian);
      offset += 5;

      if (_baseType(subType) == _wkbPolygon) {
        final subStride = _pointStride(subType);
        final result = _decodePolygonParts(data, offset, subEndian, stride: subStride);
        for (final p in result.$1) {
          allPoints.add(p);
        }
        for (final partIdx in result.$2) {
          parts.add(partIdx + allPoints.length - result.$1.length);
        }

        // Advance past polygon data
        if (offset + 4 <= data.lengthInBytes) {
          final numRings = data.getUint32(offset, subEndian);
          offset += 4;
          for (int r = 0; r < numRings; r++) {
            if (offset + 4 > data.lengthInBytes) break;
            final nPts = data.getUint32(offset, subEndian);
            offset += 4 + nPts * subStride;
          }
        }
      }
    }

    return (allPoints, parts);
  }

  static Envelope _boundsFromPoints(List<Point> points) {
    if (points.isEmpty) return const Envelope.zero();

    var minX = points[0].x, maxX = points[0].x;
    var minY = points[0].y, maxY = points[0].y;
    for (int i = 1; i < points.length; i++) {
      final x = points[i].x;
      final y = points[i].y;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return Envelope(minX, minY, maxX, maxY);
  }

  // ─── Legacy Float32List decode methods (unchanged) ────────────────

  static Float32List _decodeMultiPolygonFlat(ByteData data, int offset, Endian endian, {int stride = 16}) {
    if (offset + 4 > data.lengthInBytes) return Float32List(0);

    final numGeoms = data.getUint32(offset, endian);
    offset += 4;

    final allCoords = <double>[];
    for (int i = 0; i < numGeoms; i++) {
      if (offset + 5 > data.lengthInBytes) break;

      final subOrder = data.getUint8(offset);
      final subEndian = subOrder == 0x01 ? Endian.little : Endian.big;
      final subType = data.getUint32(offset + 1, subEndian);
      offset += 5;

      if (_baseType(subType) == _wkbPolygon) {
        final subStride = _pointStride(subType);
        final coords = _decodePolygonFlat(data, offset, subEndian, stride: subStride);
        for (int j = 0; j < coords.length; j++) {
          allCoords.add(coords[j]);
        }
        // Advance past the polygon data: numRings(4) + rings
        if (offset + 4 <= data.lengthInBytes) {
          final numRings = data.getUint32(offset, subEndian);
          offset += 4;
          for (int r = 0; r < numRings; r++) {
            if (offset + 4 > data.lengthInBytes) break;
            final nPts = data.getUint32(offset, subEndian);
            offset += 4 + nPts * subStride;
          }
        }
      }
    }

    final result = Float32List(allCoords.length);
    for (int i = 0; i < allCoords.length; i++) {
      result[i] = allCoords[i];
    }
    return result;
  }
}
