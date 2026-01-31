import 'dart:typed_data';

import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/geometry/polyline.dart';
import 'package:shapekit/src/domain/entities/geometry/polygon.dart';

/// Serializes geometry domain entities to shapefile binary format
///
/// This data layer class converts geometry objects (Point, Polyline, Polygon, etc.)
/// into binary data according to the ESRI Shapefile Technical Description.
///
/// Part of the clean architecture data layer - handles serialization of domain
/// entities to the shapefile file format.
///
/// All methods follow the same pattern:
/// - Take ByteData, offset position, and geometry entity
/// - Serialize the geometry to binary format per shapefile specification
/// - Return the number of bytes written
class GeometrySerializer {
  // Shapefile binary format constants
  static const int lenInteger = 4;
  static const int lenDouble = 8;
  static const int lenPoint = 16;

  // ========== Private Helper Methods ==========

  /// Writes a bounding box (32 bytes: minX, minY, maxX, maxY)
  static void _writeBounds(ByteData data, int offset, double minX, double minY, double maxX, double maxY) {
    data.setFloat64(offset, minX, Endian.little);
    data.setFloat64(offset + 8, minY, Endian.little);
    data.setFloat64(offset + 16, maxX, Endian.little);
    data.setFloat64(offset + 24, maxY, Endian.little);
  }

  /// Writes a parts array (NumParts * 4 bytes)
  ///
  /// Each part is an integer index into the points array
  static void _writeParts(ByteData data, int offset, List<int> parts) {
    for (int i = 0; i < parts.length; i++) {
      data.setInt32(offset + i * lenInteger, parts[i], Endian.little);
    }
  }

  /// Writes XY points array (NumPoints * 16 bytes)
  ///
  /// Each point is 2 doubles (x, y)
  static void _writePoints(ByteData data, int offset, List<Point> points) {
    for (int i = 0; i < points.length; i++) {
      final posPoint = offset + i * lenPoint;
      data.setFloat64(posPoint, points[i].x, Endian.little);
      data.setFloat64(posPoint + 8, points[i].y, Endian.little);
    }
  }

  /// Writes M range and array (2 doubles for range + NumPoints doubles for array)
  ///
  /// Format: minM, maxM, followed by M values for each point
  /// Returns the number of bytes written
  static int _writeMValues(ByteData data, int offset, double minM, double maxM, List<double> arrayM) {
    data.setFloat64(offset, minM, Endian.little);
    data.setFloat64(offset + lenDouble, maxM, Endian.little);

    final arrayStart = offset + 2 * lenDouble;
    for (int i = 0; i < arrayM.length; i++) {
      data.setFloat64(arrayStart + i * lenDouble, arrayM[i], Endian.little);
    }

    return 2 * lenDouble + arrayM.length * lenDouble;
  }

  /// Writes Z range and array (2 doubles for range + NumPoints doubles for array)
  ///
  /// Format: minZ, maxZ, followed by Z values for each point
  /// Returns the number of bytes written
  static int _writeZValues(ByteData data, int offset, double minZ, double maxZ, List<double> arrayZ) {
    data.setFloat64(offset, minZ, Endian.little);
    data.setFloat64(offset + lenDouble, maxZ, Endian.little);

    final arrayStart = offset + 2 * lenDouble;
    for (int i = 0; i < arrayZ.length; i++) {
      data.setFloat64(arrayStart + i * lenDouble, arrayZ[i], Endian.little);
    }

    return 2 * lenDouble + arrayZ.length * lenDouble;
  }

  // ========== Point Geometry Writers ==========

  /// Writes a Point geometry to binary data
  ///
  /// Binary format (20 bytes):
  /// - Bytes 0-3: Shape Type (1)
  /// - Bytes 4-11: X coordinate (double)
  /// - Bytes 12-19: Y coordinate (double)
  static int writePoint(ByteData data, int offset, Point point, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    data.setFloat64(offset + 4, point.x, Endian.little);
    data.setFloat64(offset + 12, point.y, Endian.little);
    return 20;
  }

  /// Writes a PointM geometry to binary data
  ///
  /// Binary format (28 bytes):
  /// - Bytes 0-3: Shape Type (21)
  /// - Bytes 4-11: X coordinate (double)
  /// - Bytes 12-19: Y coordinate (double)
  /// - Bytes 20-27: M value (double)
  static int writePointM(ByteData data, int offset, PointM point, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    data.setFloat64(offset + 4, point.x, Endian.little);
    data.setFloat64(offset + 12, point.y, Endian.little);
    data.setFloat64(offset + 20, point.m, Endian.little);
    return 28;
  }

  /// Writes a PointZ geometry to binary data
  ///
  /// Binary format (36 bytes):
  /// - Bytes 0-3: Shape Type (11)
  /// - Bytes 4-11: X coordinate (double)
  /// - Bytes 12-19: Y coordinate (double)
  /// - Bytes 20-27: Z value (double)
  /// - Bytes 28-35: M value (double)
  static int writePointZ(ByteData data, int offset, PointZ point, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    data.setFloat64(offset + 4, point.x, Endian.little);
    data.setFloat64(offset + 12, point.y, Endian.little);
    data.setFloat64(offset + 20, point.z, Endian.little);
    data.setFloat64(offset + 28, point.m, Endian.little);
    return 36;
  }

  // ========== Polyline Geometry Writers ==========

  /// Writes a Polyline geometry to binary data
  ///
  /// Binary format:
  /// - Bytes 0-3: Shape Type (3)
  /// - Bytes 4-35: Bounding Box (4 doubles: minX, minY, maxX, maxY)
  /// - Bytes 36-39: NumParts (int)
  /// - Bytes 40-43: NumPoints (int)
  /// - Bytes 44+: Parts array (NumParts ints)
  /// - Bytes X+: Points array (NumPoints * 16 bytes)
  static int writePolyline(ByteData data, int offset, Polyline polyline, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, polyline.minX, polyline.minY, polyline.maxX, polyline.maxY);
    data.setInt32(offset + 36, polyline.numParts, Endian.little);
    data.setInt32(offset + 40, polyline.numPoints, Endian.little);

    int pos = offset + 44;
    _writeParts(data, pos, polyline.parts);
    pos += polyline.numParts * lenInteger;
    _writePoints(data, pos, polyline.points);
    pos += polyline.numPoints * lenPoint;

    return pos - offset;
  }

  /// Writes a PolylineM geometry to binary data
  ///
  /// Same as Polyline plus:
  /// - M range (2 doubles: minM, maxM)
  /// - M array (NumPoints doubles)
  static int writePolylineM(ByteData data, int offset, PolylineM polyline, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, polyline.minX, polyline.minY, polyline.maxX, polyline.maxY);
    data.setInt32(offset + 36, polyline.numParts, Endian.little);
    data.setInt32(offset + 40, polyline.numPoints, Endian.little);

    int pos = offset + 44;
    _writeParts(data, pos, polyline.parts);
    pos += polyline.numParts * lenInteger;
    _writePoints(data, pos, polyline.points);
    pos += polyline.numPoints * lenPoint;
    pos += _writeMValues(data, pos, polyline.minM, polyline.maxM, polyline.arrayM);

    return pos - offset;
  }

  /// Writes a PolylineZ geometry to binary data
  ///
  /// Same as Polyline plus:
  /// - Z range (2 doubles: minZ, maxZ)
  /// - Z array (NumPoints doubles)
  /// - M range (2 doubles: minM, maxM)
  /// - M array (NumPoints doubles)
  static int writePolylineZ(ByteData data, int offset, PolylineZ polyline, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, polyline.minX, polyline.minY, polyline.maxX, polyline.maxY);
    data.setInt32(offset + 36, polyline.numParts, Endian.little);
    data.setInt32(offset + 40, polyline.numPoints, Endian.little);

    int pos = offset + 44;
    _writeParts(data, pos, polyline.parts);
    pos += polyline.numParts * lenInteger;
    _writePoints(data, pos, polyline.points);
    pos += polyline.numPoints * lenPoint;
    pos += _writeZValues(data, pos, polyline.minZ, polyline.maxZ, polyline.arrayZ);
    pos += _writeMValues(data, pos, polyline.minM, polyline.maxM, polyline.arrayM);

    return pos - offset;
  }

  // ========== Polygon Geometry Writers ==========

  /// Writes a Polygon geometry to binary data
  ///
  /// Polygon has the same binary format as Polyline
  static int writePolygon(ByteData data, int offset, Polygon polygon, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, polygon.minX, polygon.minY, polygon.maxX, polygon.maxY);
    data.setInt32(offset + 36, polygon.numParts, Endian.little);
    data.setInt32(offset + 40, polygon.numPoints, Endian.little);

    int pos = offset + 44;
    _writeParts(data, pos, polygon.parts);
    pos += polygon.numParts * lenInteger;
    _writePoints(data, pos, polygon.points);
    pos += polygon.numPoints * lenPoint;

    return pos - offset;
  }

  /// Writes a PolygonM geometry to binary data
  ///
  /// Same format as PolylineM
  static int writePolygonM(ByteData data, int offset, PolygonM polygon, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, polygon.minX, polygon.minY, polygon.maxX, polygon.maxY);
    data.setInt32(offset + 36, polygon.numParts, Endian.little);
    data.setInt32(offset + 40, polygon.numPoints, Endian.little);

    int pos = offset + 44;
    _writeParts(data, pos, polygon.parts);
    pos += polygon.numParts * lenInteger;
    _writePoints(data, pos, polygon.points);
    pos += polygon.numPoints * lenPoint;
    pos += _writeMValues(data, pos, polygon.minM, polygon.maxM, polygon.arrayM);

    return pos - offset;
  }

  /// Writes a PolygonZ geometry to binary data
  ///
  /// Same format as PolylineZ
  static int writePolygonZ(ByteData data, int offset, PolygonZ polygon, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, polygon.minX, polygon.minY, polygon.maxX, polygon.maxY);
    data.setInt32(offset + 36, polygon.numParts, Endian.little);
    data.setInt32(offset + 40, polygon.numPoints, Endian.little);

    int pos = offset + 44;
    _writeParts(data, pos, polygon.parts);
    pos += polygon.numParts * lenInteger;
    _writePoints(data, pos, polygon.points);
    pos += polygon.numPoints * lenPoint;
    pos += _writeZValues(data, pos, polygon.minZ, polygon.maxZ, polygon.arrayZ);
    pos += _writeMValues(data, pos, polygon.minM, polygon.maxM, polygon.arrayM);

    return pos - offset;
  }

  // ========== MultiPoint Geometry Writers ==========

  /// Writes a MultiPoint geometry to binary data
  ///
  /// Binary format:
  /// - Bytes 0-3: Shape Type (8)
  /// - Bytes 4-35: Bounding Box (4 doubles)
  /// - Bytes 36-39: NumPoints (int)
  /// - Bytes 40+: Points array (NumPoints * 16 bytes)
  static int writeMultiPoint(ByteData data, int offset, MultiPoint multiPoint, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, multiPoint.minX, multiPoint.minY, multiPoint.maxX, multiPoint.maxY);
    data.setInt32(offset + 36, multiPoint.numPoints, Endian.little);

    int pos = offset + 40;
    _writePoints(data, pos, multiPoint.points);
    pos += multiPoint.numPoints * lenPoint;

    return pos - offset;
  }

  /// Writes a MultiPointM geometry to binary data
  ///
  /// Same as MultiPoint plus M values
  static int writeMultiPointM(ByteData data, int offset, MultiPointM multiPoint, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, multiPoint.minX, multiPoint.minY, multiPoint.maxX, multiPoint.maxY);
    data.setInt32(offset + 36, multiPoint.numPoints, Endian.little);

    int pos = offset + 40;
    _writePoints(data, pos, multiPoint.points);
    pos += multiPoint.numPoints * lenPoint;
    pos += _writeMValues(data, pos, multiPoint.minM, multiPoint.maxM, multiPoint.arrayM);

    return pos - offset;
  }

  /// Writes a MultiPointZ geometry to binary data
  ///
  /// Same as MultiPoint plus Z and M values
  static int writeMultiPointZ(ByteData data, int offset, MultiPointZ multiPoint, int shapeTypeId) {
    data.setInt32(offset, shapeTypeId, Endian.little);
    _writeBounds(data, offset + 4, multiPoint.minX, multiPoint.minY, multiPoint.maxX, multiPoint.maxY);
    data.setInt32(offset + 36, multiPoint.numPoints, Endian.little);

    int pos = offset + 40;
    _writePoints(data, pos, multiPoint.points);
    pos += multiPoint.numPoints * lenPoint;
    pos += _writeZValues(data, pos, multiPoint.minZ, multiPoint.maxZ, multiPoint.arrayZ);
    pos += _writeMValues(data, pos, multiPoint.minM, multiPoint.maxM, multiPoint.arrayM);

    return pos - offset;
  }
}
