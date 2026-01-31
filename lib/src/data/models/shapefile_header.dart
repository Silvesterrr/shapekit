import 'package:shapekit/src/domain/entities/shapefile_bounds.dart';
import 'package:shapekit/src/domain/entities/geometry/record.dart';

/// Represents the header of a shapefile (.shp or .shx file)
///
/// The shapefile header is 100 bytes and contains metadata about the shapefile:
/// - File code and version for validation
/// - Geometry type (Point, Polyline, Polygon, etc.)
/// - Bounding box (min/max X, Y, Z, M values)
/// - File length in 16-bit words
///
/// Reference: ESRI Shapefile Technical Description
class ShapeHeader {
  /// Expected file code for valid shapefiles (9994)
  static const expectedFileCode = 9994;

  /// Expected version for dBASE III+ format (1000)
  static const expectedVersion = 1000;

  // Big-endian fields
  /// File code, should be 9994 for valid shapefiles
  int fileCode = 0;

  /// File length in 16-bit words (multiply by 2 for bytes)
  int length = 0;

  // Little-endian fields
  /// Shapefile version, should be 1000
  int version = 0;

  /// Geometry type stored in this shapefile
  ShapeType type = ShapeType.shapeUNDEFINED;

  Bounds bounds = const Bounds.zero();

  /// File length in bytes (calculated from [length])
  int fileLength = 0;

  /// Validates that the file code matches the expected value
  ///
  /// Returns an error message if invalid, empty string if valid
  String checkCode() {
    if (fileCode != expectedFileCode) {
      return 'Wrong magic number, expected $expectedFileCode, got $fileCode';
    }
    return '';
  }

  /// Validates that the version matches the expected value
  ///
  /// Returns an error message if invalid, empty string if valid
  String checkVersion() {
    if (version != expectedVersion) {
      return 'Wrong version, expected $expectedVersion, got $version';
    }
    return '';
  }

  /// Sets the bounding box for the shapefile
  ///
  /// Parameters:
  /// - [newBounds]: Bounding box (required)
  void setBound(Bounds newBounds) => bounds = newBounds;

  @override
  String toString() => '{$type, $length, $bounds}';
}
