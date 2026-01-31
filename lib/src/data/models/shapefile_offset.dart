/// Represents the offset and length of a record in a shapefile
///
/// Each record in the .shp file has a corresponding entry in the .shx index file
/// that stores its byte offset and length. This allows for random access to records.
class ShapeOffset {
  /// Byte offset from the start of the .shp file
  final int offset;

  /// Length of the record in bytes
  final int length;

  /// Creates a new offset entry
  ///
  /// Parameters:
  /// - [offset]: Byte position where the record starts in the .shp file
  /// - [length]: Size of the record in bytes
  ShapeOffset(this.offset, this.length);

  @override
  String toString() => 'Offset(offset: $offset, length: $length)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShapeOffset && runtimeType == other.runtimeType && offset == other.offset && length == other.length;

  @override
  int get hashCode => offset.hashCode ^ length.hashCode;
}
