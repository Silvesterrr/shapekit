/// Represents a shapefile geometry type
///
/// Each shapefile can contain only one geometry type. The type determines
/// the structure of the geometry records in the file.
///
/// Type IDs follow the ESRI Shapefile specification:
/// - 0: Null shape
/// - 1, 11, 21: Point types
/// - 3, 13, 23: Polyline types
/// - 5, 15, 25: Polygon types
/// - 8, 18, 28: MultiPoint types
/// - 31: MultiPatch
///
/// The suffix indicates coordinate dimensions:
/// - No suffix: 2D (X, Y)
/// - Z suffix: 3D with Z coordinate (X, Y, Z, M)
/// - M suffix: 2D with measure value (X, Y, M)
class ShapeType {
  /// Unique identifier for this geometry type
  final int id;

  /// Human-readable name of the geometry type
  final String type;

  const ShapeType._(this.id, this.type);

  static const shapeNULL = ShapeType._(0, 'Null');
  static const shapePOINT = ShapeType._(1, 'Point');
  static const shapePOINTZ = ShapeType._(11, 'PointZ');
  static const shapePOINTM = ShapeType._(21, 'PointM');
  static const shapePOLYLINE = ShapeType._(3, 'PolyLine');
  static const shapePOLYLINEZ = ShapeType._(13, 'PolyLineZ');
  static const shapePOLYLINEM = ShapeType._(23, 'PolyLineM');
  static const shapePOLYGON = ShapeType._(5, 'Polygon');
  static const shapePOLYGONZ = ShapeType._(15, 'PolygonZ');
  static const shapePOLYGONM = ShapeType._(25, 'PolygonM');
  static const shapeMULTIPOINT = ShapeType._(8, 'MultiPoint');
  static const shapeMULTIPOINTZ = ShapeType._(18, 'MultiPointZ');
  static const shapeMULTIPOINTM = ShapeType._(28, 'MultiPointM');
  static const shapeMULTIPATCH = ShapeType._(31, 'MultiPatch');
  static const shapeUNDEFINED = ShapeType._(-1, 'Undefined');

  @override
  String toString() => type;

  /// Returns true if this is a Point-type geometry (Point, PointM, PointZ)
  bool isPointType() => id % 10 == 1;

  /// Returns true if this is a Polyline-type geometry (Polyline, PolylineM, PolylineZ)
  bool isLineType() => id % 10 == 3;

  /// Returns true if this is a Polygon-type geometry (Polygon, PolygonM, PolygonZ)
  bool isPolygonType() => id % 10 == 5;

  /// Returns true if this is a MultiPoint-type geometry (MultiPoint, MultiPointM, MultiPointZ)
  bool isMultiPointType() => id % 10 == 8;

  /// Converts a numeric type ID to a ShapeType constant
  ///
  /// Parameters:
  /// - [id]: The numeric type ID from the shapefile header
  ///
  /// Returns the corresponding ShapeType constant, or [shapeUNDEFINED] if unknown.
  static ShapeType toType(int id) {
    switch (id) {
      case 0:
        return shapeNULL;
      case 1:
        return shapePOINT;
      case 11:
        return shapePOINTZ;
      case 21:
        return shapePOINTM;
      case 3:
        return shapePOLYLINE;
      case 13:
        return shapePOLYLINEZ;
      case 23:
        return shapePOLYLINEM;
      case 5:
        return shapePOLYGON;
      case 15:
        return shapePOLYGONZ;
      case 25:
        return shapePOLYGONM;
      case 8:
        return shapeMULTIPOINT;
      case 18:
        return shapeMULTIPOINTZ;
      case 28:
        return shapeMULTIPOINTM;
      case 31:
        return shapeMULTIPATCH;
      default:
        return shapeUNDEFINED;
    }
  }
}

/// Base class for all shapefile geometry records
///
/// Each geometry record has a [type] that indicates what kind of geometry it represents.
/// Subclasses include Point, Polyline, Polygon, and their variants.
abstract class Record {
  /// The geometry type of this record
  final ShapeType type;

  const Record(this.type);
}
