import 'dart:typed_data';
import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/geometry/polyline.dart';
import 'package:shapekit/src/domain/entities/geometry/polygon.dart';
import 'package:shapekit/src/domain/entities/geometry/record.dart';

/// Encodes coordinates into GPKG-WKB blobs (inverse of [WkbDecoder]).
///
/// GeoPackage Binary Format: 8-byte header (magic, version, flags, srs_id)
/// followed by ISO WKB payload (byte order, geometry type, coordinates).
class WkbEncoder {
  static const int _wkbPoint = 1;
  static const int _wkbLineString = 2;
  static const int _wkbPolygon = 3;

  /// Encodes a point into a GPKG-WKB blob.
  static Uint8List encodePoint(double x, double y, {int srsId = 4326}) {
    // GPKG header (8) + ISO WKB: byte_order(1) + type(4) + x(8) + y(8) = 21
    final buf = BytesBuilder();
    _writeGpkgHeader(buf, srsId);
    _writeWkbPoint(buf, x, y);
    return buf.toBytes();
  }

  /// Encodes a line string into a GPKG-WKB blob.
  static Uint8List encodeLineString(List<(double x, double y)> points, {int srsId = 4326}) {
    final buf = BytesBuilder();
    _writeGpkgHeader(buf, srsId);

    // ISO WKB: byte_order(1) + type(4) + numPoints(4) + coords
    final wkb = ByteData(9 + points.length * 16);
    wkb.setUint8(0, 0x01); // little-endian
    wkb.setUint32(1, _wkbLineString, Endian.little);
    wkb.setUint32(5, points.length, Endian.little);
    for (int i = 0; i < points.length; i++) {
      final offset = 9 + i * 16;
      wkb.setFloat64(offset, points[i].$1, Endian.little);
      wkb.setFloat64(offset + 8, points[i].$2, Endian.little);
    }
    buf.add(wkb.buffer.asUint8List());

    return buf.toBytes();
  }

  /// Encodes a polygon (outer ring) into a GPKG-WKB blob.
  ///
  /// Auto-closes the ring if the first and last points differ.
  static Uint8List encodePolygon(List<(double x, double y)> ring, {int srsId = 4326}) {
    final closed = _ensureClosed(ring);

    final buf = BytesBuilder();
    _writeGpkgHeader(buf, srsId);

    // ISO WKB: byte_order(1) + type(4) + numRings(4) + numPoints(4) + coords
    final wkb = ByteData(13 + closed.length * 16);
    wkb.setUint8(0, 0x01); // little-endian
    wkb.setUint32(1, _wkbPolygon, Endian.little);
    wkb.setUint32(5, 1, Endian.little); // 1 ring (outer only)
    wkb.setUint32(9, closed.length, Endian.little);
    for (int i = 0; i < closed.length; i++) {
      final offset = 13 + i * 16;
      wkb.setFloat64(offset, closed[i].$1, Endian.little);
      wkb.setFloat64(offset + 8, closed[i].$2, Endian.little);
    }
    buf.add(wkb.buffer.asUint8List());

    return buf.toBytes();
  }

  static void _writeGpkgHeader(BytesBuilder buf, int srsId) {
    final header = ByteData(8);
    header.setUint8(0, 0x47); // 'G'
    header.setUint8(1, 0x50); // 'P'
    header.setUint8(2, 0x00); // version
    header.setUint8(3, 0x01); // flags: LE, no envelope
    header.setInt32(4, srsId, Endian.little);
    buf.add(header.buffer.asUint8List());
  }

  static void _writeWkbPoint(BytesBuilder buf, double x, double y) {
    final wkb = ByteData(21);
    wkb.setUint8(0, 0x01); // little-endian
    wkb.setUint32(1, _wkbPoint, Endian.little);
    wkb.setFloat64(5, x, Endian.little);
    wkb.setFloat64(13, y, Endian.little);
    buf.add(wkb.buffer.asUint8List());
  }

  static List<(double, double)> _ensureClosed(List<(double, double)> ring) {
    if (ring.length < 3) return ring;
    final first = ring.first;
    final last = ring.last;
    if (first.$1 == last.$1 && first.$2 == last.$2) return ring;
    return [...ring, first];
  }

  /// Encode any [Record] geometry to GPKG-WKB
  ///
  /// Dispatches to the appropriate encoder based on runtime type.
  /// For [Polyline] and [Polygon], only the first part is encoded.
  static Uint8List encode(Record geometry, {int srsId = 4326}) {
    if (geometry is Polygon) {
      return _encodePolygonRecord(geometry, srsId: srsId);
    } else if (geometry is Polyline) {
      return _encodePolylineRecord(geometry, srsId: srsId);
    } else if (geometry is MultiPoint) {
      return _encodeMultiPointRecord(geometry, srsId: srsId);
    } else if (geometry is Point) {
      return encodePoint(geometry.x, geometry.y, srsId: srsId);
    }
    throw ArgumentError('Unsupported geometry type: ${geometry.type}');
  }

  static Uint8List _encodePolylineRecord(Polyline polyline, {int srsId = 4326}) {
    if (polyline.points.isEmpty) return encodeLineString([], srsId: srsId);

    // Encode all parts as a single LineString for single-part,
    // or MultiLineString for multi-part
    if (polyline.parts.length <= 1) {
      final tuples = polyline.points.map((p) => (p.x, p.y)).toList();
      return encodeLineString(tuples, srsId: srsId);
    }

    // Multi-part: encode as MultiLineString
    final buf = BytesBuilder();
    _writeGpkgHeader(buf, srsId);

    final numParts = polyline.parts.length;
    final allTuples = <List<(double, double)>>[];
    for (int i = 0; i < numParts; i++) {
      final start = polyline.parts[i];
      final end = i + 1 < numParts ? polyline.parts[i + 1] : polyline.points.length;
      final part = polyline.points.sublist(start, end);
      allTuples.add(part.map((p) => (p.x, p.y)).toList());
    }

    // WKB MultiLineString
    final totalSize = 9 + allTuples.fold<int>(0, (sum, part) => sum + 9 + part.length * 16);
    final wkb = ByteData(totalSize);
    wkb.setUint8(0, 0x01);
    wkb.setUint32(1, _wkbLineString + 3000, Endian.little); // MultiLineString = 5
    wkb.setUint32(5, numParts, Endian.little);
    int offset = 9;
    for (final part in allTuples) {
      wkb.setUint8(offset, 0x01);
      wkb.setUint32(offset + 1, _wkbLineString, Endian.little);
      wkb.setUint32(offset + 5, part.length, Endian.little);
      offset += 9;
      for (final pt in part) {
        wkb.setFloat64(offset, pt.$1, Endian.little);
        wkb.setFloat64(offset + 8, pt.$2, Endian.little);
        offset += 16;
      }
    }
    buf.add(wkb.buffer.asUint8List());
    return buf.toBytes();
  }

  static Uint8List _encodePolygonRecord(Polygon polygon, {int srsId = 4326}) {
    if (polygon.points.isEmpty) return encodePolygon([], srsId: srsId);

    // Encode first part as a single polygon ring
    if (polygon.parts.isEmpty) {
      final tuples = polygon.points.map((p) => (p.x, p.y)).toList();
      return encodePolygon(tuples, srsId: srsId);
    }

    // Build all rings
    final rings = <List<(double, double)>>[];
    for (int i = 0; i < polygon.parts.length; i++) {
      final start = polygon.parts[i];
      final end = i + 1 < polygon.parts.length ? polygon.parts[i + 1] : polygon.points.length;
      final ring = polygon.points.sublist(start, end);
      rings.add(ring.map((p) => (p.x, p.y)).toList());
    }

    if (rings.length == 1) return encodePolygon(rings.first, srsId: srsId);

    // Multi-ring polygon
    final buf = BytesBuilder();
    _writeGpkgHeader(buf, srsId);

    int totalCoords = rings.fold(0, (sum, r) => sum + r.length);
    final wkb = ByteData(9 + rings.length * 4 + totalCoords * 16);
    wkb.setUint8(0, 0x01);
    wkb.setUint32(1, _wkbPolygon, Endian.little);
    wkb.setUint32(5, rings.length, Endian.little);
    int offset = 9;
    for (final ring in rings) {
      final closed = _ensureClosed(ring);
      wkb.setUint32(offset, closed.length, Endian.little);
      offset += 4;
      for (final pt in closed) {
        wkb.setFloat64(offset, pt.$1, Endian.little);
        wkb.setFloat64(offset + 8, pt.$2, Endian.little);
        offset += 16;
      }
    }
    buf.add(wkb.buffer.asUint8List());
    return buf.toBytes();
  }

  static Uint8List _encodeMultiPointRecord(MultiPoint multiPoint, {int srsId = 4326}) {
    if (multiPoint.points.isEmpty) return encodePoint(0, 0, srsId: srsId);
    if (multiPoint.points.length == 1) {
      return encodePoint(multiPoint.points.first.x, multiPoint.points.first.y, srsId: srsId);
    }

    final buf = BytesBuilder();
    _writeGpkgHeader(buf, srsId);

    final n = multiPoint.points.length;
    final wkb = ByteData(9 + n * 21);
    wkb.setUint8(0, 0x01);
    wkb.setUint32(1, 4, Endian.little); // MultiPoint
    wkb.setUint32(5, n, Endian.little);
    int offset = 9;
    for (final pt in multiPoint.points) {
      wkb.setUint8(offset, 0x01);
      wkb.setUint32(offset + 1, _wkbPoint, Endian.little);
      wkb.setFloat64(offset + 5, pt.x, Endian.little);
      wkb.setFloat64(offset + 13, pt.y, Endian.little);
      offset += 21;
    }
    buf.add(wkb.buffer.asUint8List());
    return buf.toBytes();
  }
}
