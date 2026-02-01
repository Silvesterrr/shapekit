/// Represents the bounding box of a shapefile or geometry
///
/// A bounding box defines the spatial extent of geometric data using
/// minimum and maximum coordinates in each dimension.
///
/// ## Coordinate System
///
/// - X typically represents longitude (east-west)
/// - Y typically represents latitude (north-south)
/// - Z represents elevation or altitude (optional)
/// - M represents measure values like distance or time (optional)
///
/// ## Usage
///
/// ```dart
/// // 2D bounding box
/// final bounds2D = Bounds(126.0, 35.0, 130.0, 38.0);
///
/// // 3D bounding box with Z values
/// final bounds3D = Bounds(126.0, 35.0, 130.0, 38.0, 0.0, 1000.0);
///
/// // Full bounding box with Z and M values
/// final boundsFull = Bounds(126.0, 35.0, 130.0, 38.0, 0.0, 1000.0, 0.0, 100.0);
/// ```
class Bounds {
  /// Creates a bounding box with the specified coordinates
  ///
  /// Parameters are in order: minX, minY, maxX, maxY, [minZ], [maxZ], [minM], [maxM]
  ///
  /// All Z and M parameters default to 0.0 if not specified.
  const Bounds(this.minX, this.minY, this.maxX, this.maxY);

  /// Creates a zero-initialized bounding box
  ///
  /// All coordinates are set to 0.0.
  const Bounds.zero() : this(0.0, 0.0, 0.0, 0.0);

  /// Minimum X coordinate (longitude) in the dataset
  final double minX;

  /// Minimum Y coordinate (latitude) in the dataset
  final double minY;

  /// Maximum X coordinate (longitude) in the dataset
  final double maxX;

  /// Maximum Y coordinate (latitude) in the dataset
  final double maxY;

  @override
  String toString() => 'minX($minX), minY($minY), maxX($maxX), maxY($maxY)';
}

/// Bounding box with optional M (measure) values
///
/// M values are optional per ESRI spec.
class BoundsM extends Bounds {
  const BoundsM(super.minX, super.minY, super.maxX, super.maxY, [this.minM, this.maxM]);

  /// Minimum M value (optional - null if not present in shapefile)
  final double? minM;

  /// Maximum M value (optional - null if not present in shapefile)
  final double? maxM;

  /// Whether M values are present
  bool get hasM => minM != null && maxM != null;

  @override
  String toString() {
    final mPart = hasM ? ', minM($minM), maxM($maxM)' : '';
    return 'minX($minX), minY($minY), maxX($maxX), maxY($maxY)$mPart';
  }
}

/// Bounding box with Z coordinates and optional M values
///
/// Z values are always present. M values are optional per ESRI spec.
class BoundsZ extends Bounds {
  const BoundsZ(super.minX, super.minY, super.maxX, super.maxY, this.minZ, this.maxZ, [this.minM, this.maxM]);

  final double minZ;
  final double maxZ;

  /// Minimum M value (optional - null if not present in shapefile)
  final double? minM;

  /// Maximum M value (optional - null if not present in shapefile)
  final double? maxM;

  /// Whether M values are present
  bool get hasM => minM != null && maxM != null;

  @override
  String toString() {
    final mPart = hasM ? ', minM($minM), maxM($maxM)' : '';
    return 'minX($minX), minY($minY), maxX($maxX), maxY($maxY), minZ($minZ), maxZ($maxZ)$mPart';
  }
}
