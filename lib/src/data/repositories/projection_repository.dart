import 'dart:io';

import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart';

/// Handles reading projection information from .prj files
class CShapeProjectionFile {
  CShapeProjectionFile();

  File? _filePRJ;
  String? _fNamePRJ;

  RandomAccessFile? _rafPRJ;

  int? epsgCode;

  /// Reads and parses the projection file
  ///
  /// Throws [ShapefileIOException] if the file cannot be opened or read.
  void readPrj() {
    if (_filePRJ != null) close();

    try {
      _filePRJ = File(_fNamePRJ!);
      _rafPRJ = _filePRJ!.openSync();
    } catch (e) {
      throw ShapefileIOException('Error opening/reading PRJ file',
          filePath: _fNamePRJ, details: e.toString());
    }

    final prjFileContent = _filePRJ!.readAsStringSync();

    final matches = RegExp(r'AUTHORITY\["EPSG","(\d+)"\]').allMatches(prjFileContent);

    if (matches.isEmpty) {
      epsgCode = null;
      return;
    }

    final epsgStr = matches.last.group(1);
    epsgCode = epsgStr != null ? int.tryParse(epsgStr) : null;
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
  /// print('EPSG: ${prj.epsgCode}');
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
    epsgCode = null;
    close();
  }
}
