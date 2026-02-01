import 'dart:io';

import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart';

/// Supported projection types for shapefiles
///
/// Currently supports WGS84 and Polish CS2000 coordinate systems.
/// Additional projections can be added by extending this enum.
///
/// Note: This library only reads projection information from .prj files.
/// Coordinate transformation between projections is not currently supported.
enum ShapeProjectionType {
  wgs84('WGS84', '4326'),
  cs2000Zone5('CS2000_zone5', '2176'),
  cs2000Zone6('CS2000_zone6', '2177'),
  cs2000Zone7('CS2000_zone7', '2178'),
  cs2000Zone8('CS2000_zone8', '2179'),
  none('None', '');

  const ShapeProjectionType(this.name, this.epsgCode);

  final String name;
  final String epsgCode;
}

/// Handles reading projection information from .prj files
class CShapeProjectionFile {
  CShapeProjectionFile();

  File? _filePRJ;
  String? _fNamePRJ;

  RandomAccessFile? _rafPRJ;

  ShapeProjectionType projectionType = ShapeProjectionType.none;

  /// Reads and parses the projection file
  ///
  /// Throws [ShapefileIOException] if the file cannot be opened or read.
  void readPrj() {
    if (_filePRJ != null) close();

    try {
      _filePRJ = File(_fNamePRJ!);
      _rafPRJ = _filePRJ!.openSync();
    } catch (e) {
      throw ShapefileIOException('Error opening/reading PRJ file', filePath: _fNamePRJ, details: e.toString());
    }

    final prjFileContent = _filePRJ!.readAsStringSync();

    final matches = RegExp(r'AUTHORITY\["EPSG","(\d+)"\]').allMatches(prjFileContent);
    final epsg = matches.isNotEmpty
        ? matches.last.group(1) ?? ShapeProjectionType.wgs84.epsgCode
        : ShapeProjectionType.wgs84.epsgCode;

    for (final type in ShapeProjectionType.values) {
      if (type.epsgCode.contains(epsg)) {
        projectionType = type;
        break;
      }
    }
  }

  /// Reads a projection file
  ///
  /// Parameters:
  /// - [prjFile]: Path to the .prj file
  ///
  /// Throws [ShapefileIOException] if the file cannot be read.
  ///
  /// Example:
  /// ```dart
  /// final prj = CShapeProjectionFile();
  /// prj.read('data.prj');
  /// print('Projection: ${prj.projectionType.name}');
  /// ```
  void read(String prjFile) {
    try {
      open(prjFile);
      readPrj();
    } finally {
      close();
    }
  }

  void open(String prjFile) {
    close();
    _fNamePRJ = prjFile;
  }

  void close() {
    _filePRJ = null;
    _rafPRJ?.closeSync();
    _rafPRJ = null;
  }

  void dispose() {
    projectionType = ShapeProjectionType.none;
    close();
  }
}
