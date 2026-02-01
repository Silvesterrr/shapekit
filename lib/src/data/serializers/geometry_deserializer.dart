import 'dart:typed_data';

import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/geometry/polyline.dart';
import 'package:shapekit/src/domain/entities/geometry/polygon.dart';
import 'package:shapekit/src/domain/entities/shapefile_bounds.dart';

/// Deserializes shapefile binary data into geometry domain entities
///
/// This data layer class converts binary data from shapefile format into
/// geometry objects (Point, Polyline, Polygon, etc.) according to the ESRI
/// Shapefile Technical Description.
///
/// Part of the clean architecture data layer - handles deserialization from
/// the shapefile file format to domain entities.
///
/// All methods follow the same pattern:
/// - Take ByteData and offset position
/// - Parse the binary data according to shapefile specification
/// - Return the appropriate geometry entity
class GeometryDeserializer {
  // Shapefile binary format constants
  static const int lenInteger = 4;
  static const int lenDouble = 8;
  static const int lenPoint = 16;

  // ========== Private Helper Methods ==========

  /// Reads a bounding box (32 bytes: minX, minY, maxX, maxY)
  static Bounds _readBounds(ByteData data, int offset) {
    final minX = data.getFloat64(offset, Endian.little);
    final minY = data.getFloat64(offset + 8, Endian.little);
    final maxX = data.getFloat64(offset + 16, Endian.little);
    final maxY = data.getFloat64(offset + 24, Endian.little);
    return Bounds(minX, minY, maxX, maxY);
  }

  /// Reads a parts array (NumParts * 4 bytes)
  ///
  /// Each part is an integer index into the points array
  /// Returns the parts list
  static List<int> _readParts(ByteData data, int offset, int numParts) {
    final parts = <int>[];
    for (int i = 0; i < numParts; i++) {
      parts.add(data.getInt32(offset + i * lenInteger, Endian.little));
    }
    return parts;
  }

  /// Reads XY points array (NumPoints * 16 bytes)
  ///
  /// Each point is 2 doubles (x, y)
  /// Returns the points list
  static List<Point> _readPoints(ByteData data, int offset, int numPoints) {
    final points = <Point>[];
    for (int i = 0; i < numPoints; i++) {
      final posPoint = offset + i * lenPoint;
      final x = data.getFloat64(posPoint, Endian.little);
      final y = data.getFloat64(posPoint + 8, Endian.little);
      points.add(Point(x, y));
    }
    return points;
  }

  /// Reads M range and array (2 doubles for range + NumPoints doubles for array)
  ///
  /// Format: minM, maxM, followed by M values for each point
  /// Returns a record with (minM, maxM, arrayM)
  static ({double minM, double maxM, List<double> arrayM}) _readMValues(ByteData data, int offset, int numPoints) {
    final minM = data.getFloat64(offset, Endian.little);
    final maxM = data.getFloat64(offset + lenDouble, Endian.little);

    final arrayStart = offset + 2 * lenDouble;
    final arrayM = <double>[];
    for (int i = 0; i < numPoints; i++) {
      arrayM.add(data.getFloat64(arrayStart + i * lenDouble, Endian.little));
    }

    return (minM: minM, maxM: maxM, arrayM: arrayM);
  }

  /// Reads Z range and array (2 doubles for range + NumPoints doubles for array)
  ///
  /// Format: minZ, maxZ, followed by Z values for each point
  /// Returns a record with (minZ, maxZ, arrayZ)
  static ({double minZ, double maxZ, List<double> arrayZ}) _readZValues(ByteData data, int offset, int numPoints) {
    final minZ = data.getFloat64(offset, Endian.little);
    final maxZ = data.getFloat64(offset + lenDouble, Endian.little);

    final arrayStart = offset + 2 * lenDouble;
    final arrayZ = <double>[];
    for (int i = 0; i < numPoints; i++) {
      arrayZ.add(data.getFloat64(arrayStart + i * lenDouble, Endian.little));
    }

    return (minZ: minZ, maxZ: maxZ, arrayZ: arrayZ);
  }

  // ========== Point Geometry Readers ==========

  /// Reads a Point geometry from binary data
  ///
  /// Binary format (20 bytes):
  /// - Bytes 0-3: Shape Type (1)
  /// - Bytes 4-11: X coordinate (double)
  /// - Bytes 12-19: Y coordinate (double)
  static Point readPoint(ByteData data, int offset) {
    // Skip shape type at offset + 0
    double x = data.getFloat64(offset + 4, Endian.little);
    double y = data.getFloat64(offset + 12, Endian.little);

    return Point(x, y);
  }

  /// Reads a PointM geometry from binary data
  ///
  /// Binary format (28 bytes):
  /// - Bytes 0-3: Shape Type (21)
  /// - Bytes 4-11: X coordinate (double)
  /// - Bytes 12-19: Y coordinate (double)
  /// - Bytes 20-27: M value (double)
  static PointM readPointM(ByteData data, int offset) {
    double x = data.getFloat64(offset + 4, Endian.little);
    double y = data.getFloat64(offset + 12, Endian.little);
    double m = data.getFloat64(offset + 20, Endian.little);
    return PointM(x, y, m);
  }

  /// Reads a PointZ geometry from binary data
  ///
  /// Binary format (36 bytes):
  /// - Bytes 0-3: Shape Type (11)
  /// - Bytes 4-11: X coordinate (double)
  /// - Bytes 12-19: Y coordinate (double)
  /// - Bytes 20-27: Z value (double)
  /// - Bytes 28-35: M value (double)
  static PointZ readPointZ(ByteData data, int offset) {
    double x = data.getFloat64(offset + 4, Endian.little);
    double y = data.getFloat64(offset + 12, Endian.little);
    double z = data.getFloat64(offset + 20, Endian.little);
    double m = data.getFloat64(offset + 28, Endian.little);
    return PointZ(x, y, z, m);
  }

  // ========== Polyline Geometry Readers ==========

  /// Reads a Polyline geometry from binary data
  ///
  /// Binary format:
  /// - Bytes 0-3: Shape Type (3)
  /// - Bytes 4-35: Bounding Box (4 doubles: minX, minY, maxX, maxY)
  /// - Bytes 36-39: NumParts (int)
  /// - Bytes 40-43: NumPoints (int)
  /// - Bytes 44+: Parts array (NumParts ints)
  /// - Bytes X+: Points array (NumPoints * 16 bytes)
  static Polyline readPolyline(ByteData data, int offset) {
    final bounds = _readBounds(data, offset + 4);
    final numParts = data.getInt32(offset + 36, Endian.little);
    final numPoints = data.getInt32(offset + 40, Endian.little);

    final parts = _readParts(data, offset + 44, numParts);
    final points = _readPoints(data, offset + 44 + numParts * lenInteger, numPoints);

    return Polyline(bounds: bounds, parts: parts, points: points);
  }

  /// Reads a PolylineM geometry from binary data
  ///
  /// Same as Polyline plus:
  /// - M range (2 doubles: minM, maxM)
  /// - M array (NumPoints doubles)
  static PolylineM readPolylineM(ByteData data, int offset) {
    final baseBounds = _readBounds(data, offset + 4);
    final numParts = data.getInt32(offset + 36, Endian.little);
    final numPoints = data.getInt32(offset + 40, Endian.little);

    final parts = _readParts(data, offset + 44, numParts);
    final posPointStart = offset + 44 + numParts * lenInteger;
    final points = _readPoints(data, posPointStart, numPoints);

    // Read M values
    final posMMin = posPointStart + numPoints * lenPoint;
    final mValues = _readMValues(data, posMMin, numPoints);

    final bounds = BoundsM(
      baseBounds.minX,
      baseBounds.minY,
      baseBounds.maxX,
      baseBounds.maxY,
      mValues.minM,
      mValues.maxM,
    );

    return PolylineM(bounds: bounds, parts: parts, points: points, arrayM: mValues.arrayM);
  }

  /// Reads a PolylineZ geometry from binary data
  ///
  /// Same as Polyline plus:
  /// - Z range (2 doubles: minZ, maxZ)
  /// - Z array (NumPoints doubles)
  /// - M range (2 doubles: minM, maxM) - optional
  /// - M array (NumPoints doubles) - optional
  static PolylineZ readPolylineZ(ByteData data, int offset) {
    final baseBounds = _readBounds(data, offset + 4);
    final numParts = data.getInt32(offset + 36, Endian.little);
    final numPoints = data.getInt32(offset + 40, Endian.little);

    final parts = _readParts(data, offset + 44, numParts);
    final posPointStart = offset + 44 + numParts * lenInteger;
    final points = _readPoints(data, posPointStart, numPoints);

    // Read Z values
    final posZMin = posPointStart + numPoints * lenPoint;
    final zValues = _readZValues(data, posZMin, numPoints);

    // Read M values (optional)
    final posMMin = posZMin + 2 * lenDouble + numPoints * lenDouble;
    final mValues = _readMValues(data, posMMin, numPoints);

    final bounds = BoundsZ(
      baseBounds.minX,
      baseBounds.minY,
      baseBounds.maxX,
      baseBounds.maxY,
      mValues.minM,
      mValues.maxM,
      zValues.minZ,
      zValues.maxZ,
    );

    return PolylineZ(bounds: bounds, parts: parts, points: points, arrayM: mValues.arrayM, arrayZ: zValues.arrayZ);
  }

  // ========== Polygon Geometry Readers ==========

  /// Reads a Polygon geometry from binary data
  ///
  /// Polygon has the same binary format as Polyline
  static Polygon readPolygon(ByteData data, int offset) {
    final bounds = _readBounds(data, offset + 4);
    final numParts = data.getInt32(offset + 36, Endian.little);
    final numPoints = data.getInt32(offset + 40, Endian.little);

    final parts = _readParts(data, offset + 44, numParts);
    final points = _readPoints(data, offset + 44 + numParts * lenInteger, numPoints);

    return Polygon(bounds: bounds, parts: parts, points: points);
  }

  /// Reads a PolygonM geometry from binary data
  ///
  /// Same format as PolylineM
  static PolygonM readPolygonM(ByteData data, int offset) {
    final baseBounds = _readBounds(data, offset + 4);
    final numParts = data.getInt32(offset + 36, Endian.little);
    final numPoints = data.getInt32(offset + 40, Endian.little);

    final parts = _readParts(data, offset + 44, numParts);
    final posPointStart = offset + 44 + numParts * lenInteger;
    final points = _readPoints(data, posPointStart, numPoints);

    // Read M values
    final posMMin = posPointStart + numPoints * lenPoint;
    final mValues = _readMValues(data, posMMin, numPoints);

    final bounds = BoundsM(
      baseBounds.minX,
      baseBounds.minY,
      baseBounds.maxX,
      baseBounds.maxY,
      mValues.minM,
      mValues.maxM,
    );

    return PolygonM(bounds: bounds, parts: parts, points: points, arrayM: mValues.arrayM);
  }

  /// Reads a PolygonZ geometry from binary data
  ///
  /// Same format as PolylineZ
  static PolygonZ readPolygonZ(ByteData data, int offset) {
    final baseBounds = _readBounds(data, offset + 4);
    final numParts = data.getInt32(offset + 36, Endian.little);
    final numPoints = data.getInt32(offset + 40, Endian.little);

    final parts = _readParts(data, offset + 44, numParts);
    final posPointStart = offset + 44 + numParts * lenInteger;
    final points = _readPoints(data, posPointStart, numPoints);

    // Read Z values
    final posZMin = posPointStart + numPoints * lenPoint;
    final zValues = _readZValues(data, posZMin, numPoints);

    // Read M values (optional)
    final posMMin = posZMin + 2 * lenDouble + numPoints * lenDouble;
    final mValues = _readMValues(data, posMMin, numPoints);

    final bounds = BoundsZ(
      baseBounds.minX,
      baseBounds.minY,
      baseBounds.maxX,
      baseBounds.maxY,
      mValues.minM,
      mValues.maxM,
      zValues.minZ,
      zValues.maxZ,
    );

    return PolygonZ(bounds: bounds, parts: parts, points: points, arrayM: mValues.arrayM, arrayZ: zValues.arrayZ);
  }

  // ========== MultiPoint Geometry Readers ==========

  /// Reads a MultiPoint geometry from binary data
  ///
  /// Binary format:
  /// - Bytes 0-3: Shape Type (8)
  /// - Bytes 4-35: Bounding Box (4 doubles)
  /// - Bytes 36-39: NumPoints (int)
  /// - Bytes 40+: Points array (NumPoints * 16 bytes)
  static MultiPoint readMultiPoint(ByteData data, int offset) {
    final bounds = _readBounds(data, offset + 4);
    final numPoints = data.getInt32(offset + 36, Endian.little);
    final points = _readPoints(data, offset + 40, numPoints);

    return MultiPoint(bounds: bounds, points: points);
  }

  /// Reads a MultiPointM geometry from binary data
  ///
  /// Same as MultiPoint plus M values
  static MultiPointM readMultiPointM(ByteData data, int offset) {
    final baseBounds = _readBounds(data, offset + 4);
    final numPoints = data.getInt32(offset + 36, Endian.little);

    final posPointStart = offset + 40;
    final points = _readPoints(data, posPointStart, numPoints);

    // Read M values
    final posMMin = posPointStart + numPoints * lenPoint;
    final mValues = _readMValues(data, posMMin, numPoints);

    final bounds = BoundsM(
      baseBounds.minX,
      baseBounds.minY,
      baseBounds.maxX,
      baseBounds.maxY,
      mValues.minM,
      mValues.maxM,
    );

    return MultiPointM(bounds: bounds, points: points, arrayM: mValues.arrayM);
  }

  /// Reads a MultiPointZ geometry from binary data
  ///
  /// Same as MultiPoint plus Z and M values
  static MultiPointZ readMultiPointZ(ByteData data, int offset) {
    final baseBounds = _readBounds(data, offset + 4);
    final numPoints = data.getInt32(offset + 36, Endian.little);

    final posPointStart = offset + 40;
    final points = _readPoints(data, posPointStart, numPoints);

    // Read Z values
    final posZMin = posPointStart + numPoints * lenPoint;
    final zValues = _readZValues(data, posZMin, numPoints);

    // Read M values (optional)
    final posMMin = posZMin + 2 * lenDouble + numPoints * lenDouble;
    final mValues = _readMValues(data, posMMin, numPoints);

    final bounds = BoundsZ(
      baseBounds.minX,
      baseBounds.minY,
      baseBounds.maxX,
      baseBounds.maxY,
      mValues.minM,
      mValues.maxM,
      zValues.minZ,
      zValues.maxZ,
    );

    return MultiPointZ(bounds: bounds, points: points, arrayZ: zValues.arrayZ, arrayM: mValues.arrayM);
  }
}
