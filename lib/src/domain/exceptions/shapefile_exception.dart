/// Exception types for shapefile operations
enum ShapefileErrorType {
  /// File not found or cannot be accessed
  fileNotFound,

  /// Invalid file format or corrupted data
  invalidFormat,

  /// Unsupported geometry type
  unsupportedType,

  /// File header validation failed
  invalidHeader,

  /// Bounding box not set or invalid
  invalidBounds,

  /// Record data is corrupted
  corruptedData,

  /// File I/O error
  ioError,
}

/// Base exception class for shapefile operations
class ShapefileException implements Exception {
  /// Creates a shapefile exception
  const ShapefileException(this.message, {this.filePath, required this.type, this.details});

  /// Error message describing what went wrong
  final String message;

  /// Path to the file that caused the error (if applicable)
  final String? filePath;

  /// Type of error that occurred
  final ShapefileErrorType type;

  /// Additional details about the error
  final String? details;

  @override
  String toString() {
    final buffer = StringBuffer('ShapefileException: $message');
    if (filePath != null) {
      buffer.write(' (file: $filePath)');
    }
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a file cannot be found or accessed
class FileNotFoundException extends ShapefileException {
  /// Creates a file not found exception
  const FileNotFoundException(String filePath)
    : super('File not found or cannot be accessed', filePath: filePath, type: ShapefileErrorType.fileNotFound);
}

/// Exception thrown when file format is invalid
class InvalidFormatException extends ShapefileException {
  /// Creates an invalid format exception
  const InvalidFormatException(super.message, {super.filePath, super.details})
    : super(type: ShapefileErrorType.invalidFormat);
}

/// Exception thrown when geometry type is not supported
class UnsupportedTypeException extends ShapefileException {
  /// Creates an unsupported type exception
  const UnsupportedTypeException(String geometryType, {String? filePath})
    : super('Unsupported geometry type: $geometryType', filePath: filePath, type: ShapefileErrorType.unsupportedType);
}

/// Exception thrown when file header is invalid
class InvalidHeaderException extends ShapefileException {
  /// Creates an invalid header exception
  const InvalidHeaderException(super.message, {super.filePath, super.details})
    : super(type: ShapefileErrorType.invalidHeader);
}

/// Exception thrown when bounding box is invalid
class InvalidBoundsException extends ShapefileException {
  /// Creates an invalid bounds exception
  const InvalidBoundsException(super.message, {super.filePath}) : super(type: ShapefileErrorType.invalidBounds);
}

/// Exception thrown when record data is corrupted
class CorruptedDataException extends ShapefileException {
  /// Creates a corrupted data exception
  const CorruptedDataException(super.message, {super.filePath, super.details})
    : super(type: ShapefileErrorType.corruptedData);
}

/// Exception thrown when I/O operation fails
class ShapefileIOException extends ShapefileException {
  /// Creates an I/O exception
  const ShapefileIOException(super.message, {super.filePath, super.details}) : super(type: ShapefileErrorType.ioError);
}
