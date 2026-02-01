import 'dart:io';
import 'dart:typed_data';

import 'package:shapekit/src/domain/entities/shapefile_bounds.dart';
import 'package:shapekit/src/data/repositories/projection_repository.dart';
import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart';

import 'package:shapekit/src/data/repositories/dbase_repository.dart';
import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/entities/geometry/point.dart';
import 'package:shapekit/src/domain/entities/geometry/polygon.dart';
import 'package:shapekit/src/domain/entities/geometry/polyline.dart';
import 'package:shapekit/src/data/models/shapefile_header.dart';
import 'package:shapekit/src/data/models/shapefile_offset.dart';
import 'package:shapekit/src/data/serializers/geometry_deserializer.dart';
import 'package:shapekit/src/data/serializers/geometry_serializer.dart';
import 'package:shapekit/src/domain/entities/dbase_field.dart';

/// Main class for reading and writing ESRI Shapefiles
///
/// This class handles reading and writing of shapefile format files including:
/// - .shp (geometry data)
/// - .shx (index data)
/// - .dbf (attribute data)
/// - .prj (projection data)
///
/// ## Usage
///
/// ### Reading a shapefile:
/// ```dart
/// final shapefile = Shapefile();
/// try {
///   shapefile.read('path/to/file.shp');
///   print('Loaded ${shapefile.records.length} records');
///   for (final record in shapefile.records) {
///     if (record is Point) {
///       print('Point: ${record.x}, ${record.y}');
///     }
///   }
/// } on ShapefileException catch (e) {
///   print('Error: ${e.message}');
/// }
/// ```
///
/// ### Writing a shapefile:
/// ```dart
/// final shapefile = Shapefile();
/// shapefile.writeComplete(
///   'output.shp',
///   ShapeType.shapePOINT,
///   [Point(10.0, 20.0), Point(30.0, 40.0)],
///   minX: 10.0, minY: 20.0, maxX: 30.0, maxY: 40.0,
/// );
/// ```
///
/// ## Text Encoding
///
/// The library supports multiple text encodings for attribute data:
/// - [isUtf8] = true: Use UTF-8 encoding (recommended for modern data)
/// - [isCp949] = true: Use CP949 encoding (for Korean legacy data)
/// - Both false: Use ASCII encoding
///
/// Note: Only one encoding flag should be set to true at a time.
///
/// Throws [ShapefileException] and its subclasses on errors.
class Shapefile {
  /// Creates a new Shapefile instance
  ///
  /// Parameters:
  /// - [isUtf8]: If true, use UTF-8 encoding for text fields (default: false)
  /// - [isCp949]: If true, use CP949 encoding for Korean text (default: false)
  ///
  /// Note: If both [isUtf8] and [isCp949] are false, ASCII encoding is used.
  /// Only one encoding should be enabled at a time.
  Shapefile({this.isUtf8 = false, this.isCp949 = false});

  static const lenWord = 2;
  static const lenInteger = 4;
  static const lenDouble = 8;
  static const lenPoint = 16;
  static const lenHeader = 100;
  static const lenRecordHeader = 8;

  int lenMaxBuffer = 65535 * 128;

  bool isUtf8;
  bool isCp949;

  String? _fNameSHX;
  File? _fileSHX;
  RandomAccessFile? _rafSHX;

  String? _fNameSHP;
  File? _fileSHP;
  RandomAccessFile? _rafSHP;

  String? _fNameDBF;

  String? _fNamePRJ;

  final headerSHX = ShapeHeader();
  final headerSHP = ShapeHeader();

  DbaseFile? _dbase;

  CShapeProjectionFile? _prj;

  List<ShapeOffset> offsets = [];
  List<Record> records = [];

  List<DbaseField> get attributeFields => _dbase == null ? [] : _dbase!.fields;
  List<List<dynamic>> get attributeRecords => _dbase == null ? [] : _dbase!.records;

  ShapeProjectionType get projectionType => _prj?.projectionType ?? ShapeProjectionType.none;

  void open(String shpFile) {
    close();
    String name = shpFile.substring(0, shpFile.lastIndexOf('.'));
    _fNameSHX = '$name.shx';
    _fNameSHP = '$name.shp';
    _fNameDBF = '$name.dbf';
    _fNamePRJ = '$name.prj';
  }

  /// Reads the SHX index file
  ///
  /// Throws [FileNotFoundException] if file not specified.
  /// Throws [ShapefileIOException] on read errors.
  /// Throws [InvalidHeaderException] if file format is invalid.
  void readSHX() {
    if (_fNameSHX == null) {
      throw const FileNotFoundException('SHX file not specified');
    }

    Uint8List? bufferSHX;
    try {
      _fileSHX = File(_fNameSHX!);
      bufferSHX = _fileSHX?.readAsBytesSync();
    } catch (e) {
      throw ShapefileIOException('Error opening/reading SHX file', filePath: _fNameSHX, details: e.toString());
    }

    int pos = 0;
    if (null != bufferSHX) {
      String errText = '';
      ByteData dataSHX = ByteData.sublistView(bufferSHX);

      headerSHX.fileCode = dataSHX.getInt32(0, Endian.big);

      errText = headerSHX.checkCode();
      if (errText.isNotEmpty) {
        throw InvalidHeaderException(
          errText,
          filePath: _fNameSHX,
          details: 'Expected file code ${ShapeHeader.expectedFileCode}, got ${headerSHX.fileCode}',
        );
      }
      // skip position 20
      headerSHX.length = dataSHX.getInt32(24, Endian.big);
      headerSHX.version = dataSHX.getInt32(28, Endian.little);
      errText = headerSHX.checkVersion();
      if (errText.isNotEmpty) {
        throw InvalidHeaderException(
          errText,
          filePath: _fNameSHX,
          details: 'Expected version ${ShapeHeader.expectedVersion}, got ${headerSHX.version}',
        );
      }
      headerSHX.type = ShapeType.toType(dataSHX.getInt32(32, Endian.little));
      final minX = dataSHX.getFloat64(36, Endian.little);
      final minY = dataSHX.getFloat64(44, Endian.little);
      final maxX = dataSHX.getFloat64(52, Endian.little);
      final maxY = dataSHX.getFloat64(60, Endian.little);

      final minZ = dataSHX.getFloat64(68, Endian.little);
      final maxZ = dataSHX.getFloat64(76, Endian.little);
      final minM = dataSHX.getFloat64(84, Endian.little);
      final maxM = dataSHX.getFloat64(92, Endian.little);
      headerSHX.bounds = BoundsZ(minX, minY, maxX, maxY, minZ, maxZ, minM, maxM);

      headerSHX.fileLength = headerSHX.length * lenWord;
      int fieldCount = (headerSHX.fileLength - lenHeader) ~/ lenRecordHeader;

      // debugPrint('header ${headerSHX.fileLength}, $fieldCount');

      pos += lenHeader;
      for (int n = 0; n < fieldCount; ++n) {
        int offset = dataSHX.getInt32(pos, Endian.big) * lenWord;
        int content = dataSHX.getInt32(pos + 4, Endian.big) * lenWord;
        offsets.add(ShapeOffset(offset, content));
        pos += lenRecordHeader;
      }
    }
    // debugPrint('SHX file position: $pos / ${headerSHX.fileLength}');
  }

  /// Reads the SHP geometry file
  ///
  /// Throws [FileNotFoundException] if file not specified.
  /// Throws [ShapefileIOException] on read errors.
  /// Throws [InvalidHeaderException] if file format is invalid.
  /// Throws [CorruptedDataException] if record data is invalid.
  /// Throws [UnsupportedTypeException] if geometry type is not supported.
  void readSHP() {
    if (_fNameSHP == null) {
      throw const FileNotFoundException('SHP file not specified');
    }

    // ignore: unused_local_variable
    int workPosition = 0;
    // ignore: unused_local_variable
    int filePosition = 0;

    Uint8List? bufferSHP;
    try {
      _fileSHP = File(_fNameSHP!);
      _rafSHP = _fileSHP!.openSync();
      bufferSHP = _rafSHP!.readSync(lenHeader);
      filePosition += lenHeader;
      // debugPrint('file position: $filePosition');
    } catch (e) {
      throw ShapefileIOException('Error opening/reading SHP file', filePath: _fNameSHP, details: e.toString());
    }

    ByteData dataSHP = ByteData.sublistView(bufferSHP);

    headerSHP.fileCode = dataSHP.getInt32(0, Endian.big);
    // skip position 20
    headerSHP.length = dataSHP.getInt32(24, Endian.big);
    headerSHP.version = dataSHP.getInt32(28, Endian.little);
    headerSHP.type = ShapeType.toType(dataSHP.getInt32(32, Endian.little));
    final minX = dataSHP.getFloat64(36, Endian.little);
    final minY = dataSHP.getFloat64(44, Endian.little);
    final maxX = dataSHP.getFloat64(52, Endian.little);
    final maxY = dataSHP.getFloat64(60, Endian.little);

    final minZ = dataSHP.getFloat64(68, Endian.little);
    final maxZ = dataSHP.getFloat64(76, Endian.little);
    final minM = dataSHP.getFloat64(84, Endian.little);
    final maxM = dataSHP.getFloat64(92, Endian.little);
    headerSHP.bounds = BoundsZ(minX, minY, maxX, maxY, minZ, maxZ, minM, maxM);

    headerSHP.fileLength = headerSHP.length * lenWord;

    // debugPrint('header ${headerSHP.fileCode}, ${headerSHP.version}, ${offsets.length} ');

    String errText = headerSHP.checkCode();
    if (errText.isNotEmpty) {
      throw InvalidHeaderException(
        errText,
        filePath: _fNameSHP,
        details: 'Expected file code ${ShapeHeader.expectedFileCode}, got ${headerSHP.fileCode}',
      );
    }
    errText = headerSHP.checkVersion();
    if (errText.isNotEmpty) {
      throw InvalidHeaderException(
        errText,
        filePath: _fNameSHP,
        details: 'Expected version ${ShapeHeader.expectedVersion}, got ${headerSHP.version}',
      );
    }
    workPosition += lenHeader;

    int totalCount = 0;
    while (totalCount < offsets.length) {
      int length = 0, count = 0;
      for (var n = totalCount; n < offsets.length; ++n) {
        // debugPrint('record : $n, ${offsets[n].length}');
        int fieldLength = (lenRecordHeader + offsets[n].length);
        if ((length + fieldLength) > lenMaxBuffer) {
          if (0 == count) {
            lenMaxBuffer = fieldLength;
          } else {
            break;
          }
        }
        count++;
        length += fieldLength;
      }
      //debugPrint('record length : $count, $length');

      bufferSHP = null;
      try {
        bufferSHP = _rafSHP!.readSync(length);
        filePosition += length;
        // debugPrint('file position: $filePosition');
      } catch (e) {
        throw CorruptedDataException(
          'Error reading SHP file record data',
          filePath: _fNameSHP,
          details: 'Record ${records.length}, position $workPosition: $e',
        );
      }
      dataSHP = ByteData.sublistView(bufferSHP);
      int pos = 0;
      for (var n = 0; n < count; ++n) {
        // int offset = dataSHP.getInt32(pos, Endian.big);
        // int content = dataSHP.getInt32(pos + 4, Endian.big) * LEN_WORD;
        // if (n < 2) {
        //   debugPrint('record header: ${totalCount+n}, $offset, $content');
        // }
        pos += lenRecordHeader;
        workPosition += lenRecordHeader;

        // Parse geometry using GeometryDeserializer
        switch (headerSHP.type) {
          case ShapeType.shapePOINT:
            records.add(GeometryDeserializer.readPoint(dataSHP, pos));
            break;
          case ShapeType.shapePOINTM:
            records.add(GeometryDeserializer.readPointM(dataSHP, pos));
            break;
          case ShapeType.shapePOINTZ:
            records.add(GeometryDeserializer.readPointZ(dataSHP, pos));
            break;
          case ShapeType.shapePOLYLINE:
            records.add(GeometryDeserializer.readPolyline(dataSHP, pos));
            break;
          case ShapeType.shapePOLYLINEM:
            records.add(
              GeometryDeserializer.readPolylineM(dataSHP, pos, contentLength: offsets[totalCount + n].length),
            );
            break;
          case ShapeType.shapePOLYLINEZ:
            records.add(
              GeometryDeserializer.readPolylineZ(dataSHP, pos, contentLength: offsets[totalCount + n].length),
            );
            break;
          case ShapeType.shapePOLYGON:
            records.add(GeometryDeserializer.readPolygon(dataSHP, pos));
            break;
          case ShapeType.shapePOLYGONM:
            records.add(GeometryDeserializer.readPolygonM(dataSHP, pos, contentLength: offsets[totalCount + n].length));
            break;
          case ShapeType.shapePOLYGONZ:
            records.add(GeometryDeserializer.readPolygonZ(dataSHP, pos, contentLength: offsets[totalCount + n].length));
            break;
          case ShapeType.shapeMULTIPOINT:
            records.add(GeometryDeserializer.readMultiPoint(dataSHP, pos));
            break;
          case ShapeType.shapeMULTIPOINTM:
            records.add(
              GeometryDeserializer.readMultiPointM(dataSHP, pos, contentLength: offsets[totalCount + n].length),
            );
            break;
          case ShapeType.shapeMULTIPOINTZ:
            records.add(
              GeometryDeserializer.readMultiPointZ(dataSHP, pos, contentLength: offsets[totalCount + n].length),
            );
            break;
          default:
            throw UnsupportedTypeException(headerSHP.type.toString(), filePath: _fNameSHP);
        }
        pos += offsets[totalCount + n].length;
        workPosition += offsets[totalCount + n].length;
        // if (n < 2) {
        //   debugPrint('record data: ${totalCount+n}, ${records.last}');
        // }
      }
      totalCount += count;
      // debugPrint('next: $totalCount, $count');
    }
    // debugPrint('SHP file position: $workPosition / ${headerSHP.fileLength}');
  }

  /// Reads the PRJ projection file if it exists
  ///
  /// Does nothing if the file doesn't exist.
  /// Throws [ShapefileIOException] if file exists but cannot be read.
  void readPRJ() {
    if (_fNamePRJ == null) return;
    if (!File(_fNamePRJ!).existsSync()) return;

    _prj = CShapeProjectionFile();
    try {
      _prj!.open(_fNamePRJ!);
      _prj!.readPrj();
    } finally {
      _prj!.close();
    }
    // debugPrint('projectionType: ${_prj!.projectionType}');
  }

  /// Reads the DBF attribute file if it exists
  ///
  /// Does nothing if the file doesn't exist.
  /// Throws [ShapefileIOException] if file exists but cannot be read.
  /// Throws [CorruptedDataException] if record data is invalid.
  void readDBF() {
    if (_fNameDBF == null) return;
    if (!File(_fNameDBF!).existsSync()) return;

    _dbase = DbaseFile(isUtf8: isUtf8, isCp949: isCp949);
    try {
      _dbase!.open(_fNameDBF!);
      _dbase!.readDBF();
    } finally {
      _dbase!.close();
    }
  }

  /// Writes the SHX index file
  ///
  /// Throws [FileNotFoundException] if file not specified.
  /// Throws [ShapefileIOException] on write errors.
  void writeSHX() {
    if (_fNameSHX == null) {
      throw const FileNotFoundException('SHX file not specified for writing');
    }

    // ignore: unused_local_variable
    int filePosition = 0;

    Uint8List? bufferSHX;
    bufferSHX = Uint8List(lenHeader);
    ByteData dataSHX = ByteData.sublistView(bufferSHX);

    headerSHX.fileCode = ShapeHeader.expectedFileCode;
    dataSHX.setInt32(0, headerSHX.fileCode, Endian.big);
    // skip position 20
    headerSHX.fileLength = lenHeader + offsets.length * lenRecordHeader;
    headerSHX.length = headerSHX.fileLength ~/ lenWord;

    dataSHX.setInt32(24, headerSHX.length, Endian.big);
    headerSHX.version = ShapeHeader.expectedVersion;
    dataSHX.setInt32(28, headerSHX.version, Endian.little);

    dataSHX.setInt32(32, headerSHX.type.id, Endian.little);

    dataSHX.setFloat64(36, headerSHX.bounds.minX, Endian.little);
    dataSHX.setFloat64(44, headerSHX.bounds.minY, Endian.little);
    dataSHX.setFloat64(52, headerSHX.bounds.maxX, Endian.little);
    dataSHX.setFloat64(60, headerSHX.bounds.maxY, Endian.little);

    dataSHX.setFloat64(68, headerSHX.bounds is BoundsZ ? (headerSHX.bounds as BoundsZ).minZ : 0.0, Endian.little);
    dataSHX.setFloat64(76, headerSHX.bounds is BoundsZ ? (headerSHX.bounds as BoundsZ).maxZ : 0.0, Endian.little);
    dataSHX.setFloat64(
      84,
      headerSHX.bounds is BoundsM ? (headerSHX.bounds as BoundsM).minM ?? 0.0 : 0.0,
      Endian.little,
    );
    dataSHX.setFloat64(
      92,
      headerSHX.bounds is BoundsM ? (headerSHX.bounds as BoundsM).maxM ?? 0.0 : 0.0,
      Endian.little,
    );

    // debugPrint('header $headerSHX');

    try {
      _fileSHX = File(_fNameSHX!);
      _rafSHX = _fileSHX!.openSync(mode: FileMode.write);
      _rafSHX!.writeFromSync(bufferSHX);
      filePosition += lenHeader;
    } catch (e) {
      throw ShapefileIOException('Error opening/saving SHX file', filePath: _fNameSHX, details: e.toString());
    }

    bufferSHX = Uint8List(lenMaxBuffer);
    dataSHX = ByteData.sublistView(bufferSHX);

    int pos = 0;
    int totalCount = 0;
    while (totalCount < offsets.length) {
      int length = 0, count = 0;
      length = (offsets.length - totalCount) * lenRecordHeader;
      if (length > lenMaxBuffer) {
        count = lenMaxBuffer ~/ lenRecordHeader;
        length = lenRecordHeader * count;
      } else {
        count = length ~/ lenRecordHeader;
      }

      pos = 0;
      for (var n = 0; n < count; ++n) {
        var offset = offsets[totalCount + n];
        dataSHX.setInt32(pos, offset.offset ~/ lenWord, Endian.big);
        dataSHX.setInt32(pos + 4, offset.length ~/ lenWord, Endian.big);
        pos += lenRecordHeader;
        // if (n < 3) {
        //   debugPrint('$offset');
        // }
      }
      totalCount += count;

      try {
        _rafSHX!.writeFromSync(bufferSHX, 0, pos);
        filePosition += pos;
        // debugPrint('file position: $filePosition');
      } catch (e) {
        throw ShapefileIOException('Error saving SHX file', filePath: _fNameSHX, details: e.toString());
      }
    }
    // debugPrint('SHX file position: $filePosition / ${headerSHX.fileLength}');
  }

  /// Writes the SHP geometry file
  ///
  /// Throws [FileNotFoundException] if file not specified.
  /// Throws [ShapefileIOException] on write errors.
  /// Throws [InvalidHeaderException] if shape type not set.
  /// Throws [InvalidBoundsException] if bounds not set.
  /// Throws [UnsupportedTypeException] if geometry type is not supported.
  void writeSHP() {
    if (_fNameSHP == null) {
      throw const FileNotFoundException('SHP file not specified for writing');
    }
    if (headerSHP.length == 0) {
      analyze();
    }

    // ignore: unused_local_variable
    int workPosition = 0;
    // ignore: unused_local_variable
    int filePosition = 0;

    Uint8List? bufferSHP;
    bufferSHP = Uint8List(lenHeader);
    ByteData dataSHP = ByteData.sublistView(bufferSHP);

    headerSHP.fileCode = ShapeHeader.expectedFileCode;
    dataSHP.setInt32(0, headerSHP.fileCode, Endian.big);
    // skip position 20
    headerSHP.fileLength = headerSHP.length * lenWord;
    dataSHP.setInt32(24, headerSHP.length, Endian.big);
    headerSHP.version = ShapeHeader.expectedVersion;
    dataSHP.setInt32(28, headerSHP.version, Endian.little);

    dataSHP.setInt32(32, headerSHP.type.id, Endian.little);

    dataSHP.setFloat64(36, headerSHP.bounds.minX, Endian.little);
    dataSHP.setFloat64(44, headerSHP.bounds.minY, Endian.little);
    dataSHP.setFloat64(52, headerSHP.bounds.maxX, Endian.little);
    dataSHP.setFloat64(60, headerSHP.bounds.maxY, Endian.little);

    dataSHP.setFloat64(68, headerSHP.bounds is BoundsZ ? (headerSHP.bounds as BoundsZ).minZ : 0.0, Endian.little);
    dataSHP.setFloat64(76, headerSHP.bounds is BoundsZ ? (headerSHP.bounds as BoundsZ).maxZ : 0.0, Endian.little);
    dataSHP.setFloat64(
      84,
      headerSHP.bounds is BoundsM ? (headerSHP.bounds as BoundsM).minM ?? 0.0 : 0.0,
      Endian.little,
    );
    dataSHP.setFloat64(
      92,
      headerSHP.bounds is BoundsM ? (headerSHP.bounds as BoundsM).maxM ?? 0.0 : 0.0,
      Endian.little,
    );

    workPosition += lenHeader;

    try {
      _fileSHP = File(_fNameSHP!);
      _rafSHP = _fileSHP!.openSync(mode: FileMode.write);
      _rafSHP!.writeFromSync(bufferSHP);
      filePosition += lenHeader;
      // debugPrint('file position: $filePosition');
    } catch (e) {
      throw ShapefileIOException('Error opening/writing SHP file', filePath: _fNameSHP, details: e.toString());
    }

    // debugPrint('file length ${headerSHP.length}, ${headerSHP.fileLength}');

    bufferSHP = Uint8List(lenMaxBuffer);
    dataSHP = ByteData.sublistView(bufferSHP);

    int totalCount = 0;
    while (totalCount < offsets.length) {
      int length = 0, count = 0;
      for (var n = totalCount; n < offsets.length; ++n) {
        int fieldLength = (lenRecordHeader + offsets[n].length);
        if ((length + fieldLength) > lenMaxBuffer) {
          if (0 == count) {
            lenMaxBuffer = fieldLength;
          } else {
            break;
          }
        }
        count++;
        length += fieldLength;
      }
      // debugPrint('record length : $count, $length');

      int pos = 0;
      for (var n = 0; n < count; ++n) {
        ShapeOffset cOffset = offsets[totalCount + n];
        dataSHP.setInt32(pos, totalCount + n + 1 /* start 1 base */, Endian.big);
        dataSHP.setInt32(pos + 4, cOffset.length ~/ lenWord, Endian.big);
        pos += lenRecordHeader;
        workPosition += lenRecordHeader;
        // if (n < 2) {
        //   debugPrint('record offset ${totalCount+n}, $cOffset');
        // }
        var record = records[totalCount + n];

        // Serialize geometry using GeometrySerializer
        switch (headerSHP.type) {
          case ShapeType.shapePOINT:
            GeometrySerializer.writePoint(dataSHP, pos, record as Point, headerSHP.type.id);
            break;
          case ShapeType.shapePOINTM:
            GeometrySerializer.writePointM(dataSHP, pos, record as PointM, headerSHP.type.id);
            break;
          case ShapeType.shapePOINTZ:
            GeometrySerializer.writePointZ(dataSHP, pos, record as PointZ, headerSHP.type.id);
            break;
          case ShapeType.shapePOLYLINE:
            GeometrySerializer.writePolyline(dataSHP, pos, record as Polyline, headerSHP.type.id);
            break;
          case ShapeType.shapePOLYLINEM:
            GeometrySerializer.writePolylineM(dataSHP, pos, record as PolylineM, headerSHP.type.id);
            break;
          case ShapeType.shapePOLYLINEZ:
            GeometrySerializer.writePolylineZ(dataSHP, pos, record as PolylineZ, headerSHP.type.id);
            break;
          case ShapeType.shapePOLYGON:
            GeometrySerializer.writePolygon(dataSHP, pos, record as Polygon, headerSHP.type.id);
            break;
          case ShapeType.shapePOLYGONM:
            GeometrySerializer.writePolygonM(dataSHP, pos, record as PolygonM, headerSHP.type.id);
            break;
          case ShapeType.shapePOLYGONZ:
            GeometrySerializer.writePolygonZ(dataSHP, pos, record as PolygonZ, headerSHP.type.id);
            break;
          case ShapeType.shapeMULTIPOINT:
            GeometrySerializer.writeMultiPoint(dataSHP, pos, record as MultiPoint, headerSHP.type.id);
            break;
          case ShapeType.shapeMULTIPOINTM:
            GeometrySerializer.writeMultiPointM(dataSHP, pos, record as MultiPointM, headerSHP.type.id);
            break;
          case ShapeType.shapeMULTIPOINTZ:
            GeometrySerializer.writeMultiPointZ(dataSHP, pos, record as MultiPointZ, headerSHP.type.id);
            break;
          default:
            throw UnsupportedTypeException(headerSHP.type.toString(), filePath: _fNameSHP);
        }
        pos += cOffset.length;
        workPosition += cOffset.length;
        // if (n < 2) {
        //   debugPrint('record data: ${totalCount+n}, $record');
        // }
      }
      totalCount += count;

      try {
        _rafSHP!.writeFromSync(bufferSHP, 0, pos);
        filePosition += pos;
        // debugPrint('file position: $filePosition');
      } catch (e) {
        throw ShapefileIOException('Error saving SHP file', filePath: _fNameSHP, details: e.toString());
      }
    }
    // debugPrint('SHP file position: $workPosition / ${headerSHP.fileLength}');
  }

  /// Writes the DBF attribute file
  ///
  /// Does nothing if no DBF data is set.
  /// Throws [ShapefileIOException] on write errors.
  void writeDBF() {
    if (_fNameDBF == null) return;
    if (_dbase == null) return;

    try {
      _dbase!.open(_fNameDBF!);
      _dbase!.writeDBF();
    } finally {
      _dbase!.close();
    }
  }

  void close() {
    _fileSHX = null;
    _rafSHX?.closeSync();
    _rafSHX = null;

    _fileSHP = null;
    _rafSHP?.closeSync();
    _rafSHP = null;

    _dbase?.close();
  }

  void dispose() {
    offsets = [];
    records = [];
    close();
    _dbase?.dispose();
  }

  /// Reads a complete shapefile including all associated files
  ///
  /// Reads the .shp (geometry), .shx (index), and .dbf (attributes) files.
  /// The .prj (projection) file is also read if it exists.
  ///
  /// Parameters:
  /// - [shpFile]: Path to the .shp file (other files are auto-detected)
  ///
  /// Throws [FileNotFoundException] if required files are missing.
  /// Throws [ShapefileIOException] on read errors.
  /// Throws [InvalidHeaderException] if file format is invalid.
  /// Throws [CorruptedDataException] if record data is invalid.
  /// Throws [UnsupportedTypeException] if geometry type is not supported.
  ///
  /// Example:
  /// ```dart
  /// final shapefile = Shapefile();
  /// try {
  ///   shapefile.read('data.shp');
  ///   print('Loaded ${shapefile.records.length} records');
  /// } on ShapefileException catch (e) {
  ///   print('Error: ${e.message}');
  /// }
  /// ```
  void read(String shpFile) {
    try {
      open(shpFile);
      readSHX();
      readSHP();
      readDBF();
      readPRJ();
    } finally {
      close();
    }
  }

  /// Writes the current shapefile data to files
  ///
  /// Writes modified shapefile data back to disk. Use this after reading
  /// a shapefile and modifying its records or attributes.
  ///
  /// Parameters:
  /// - [shpFile]: Path to the output .shp file
  ///
  /// Throws [InvalidHeaderException] if shape type not set.
  /// Throws [InvalidBoundsException] if bounds not set.
  /// Throws [ShapefileIOException] on write errors.
  /// Throws [UnsupportedTypeException] if geometry type is not supported.
  ///
  /// Note: This method requires that the shapefile structure has already
  /// been set up (via [read] or manual configuration).
  void write(String shpFile) {
    try {
      analyze();
      open(shpFile);
      writeSHX();
      writeSHP();
      writeDBF();
    } finally {
      close();
    }
  }

  /// Sets the shapefile geometry type
  ///
  /// Parameters:
  /// - [type]: The geometry type for all records in this shapefile
  void setHeaderType(ShapeType type) {
    headerSHX.type = type;
    headerSHP.type = type;
  }

  /// Sets the bounding box for the shapefile
  ///
  /// Parameters:
  /// - [minX], [minY]: Minimum X and Y coordinates
  /// - [maxX], [maxY]: Maximum X and Y coordinates
  /// - [minZ], [maxZ]: Optional minimum and maximum Z coordinates
  /// - [minM], [maxM]: Optional minimum and maximum M (measure) values
  void setHeaderBound(
    double minX,
    double minY,
    double maxX,
    double maxY, [
    double minZ = 0.0,
    double maxZ = 0.0,
    double minM = 0.0,
    double maxM = 0.0,
  ]) {
    // Create appropriate bounds type based on whether Z/M values are provided
    final Bounds bounds;
    if (minZ != 0.0 || maxZ != 0.0) {
      // If Z values are set, use BoundsZ (which includes M values)
      bounds = BoundsZ(minX, minY, maxX, maxY, minM, maxM, minZ, maxZ);
    } else if (minM != 0.0 || maxM != 0.0) {
      // If only M values are set, use BoundsM
      bounds = BoundsM(minX, minY, maxX, maxY, minM, maxM);
    } else {
      // No Z or M values, use basic Bounds
      bounds = Bounds(minX, minY, maxX, maxY);
    }

    headerSHX.bounds = bounds;
    headerSHP.bounds = bounds;
  }

  /// Sets the geometry records for this shapefile
  ///
  /// Parameters:
  /// - [records]: List of geometry records (Point, Polyline, Polygon, etc.)
  void setRecords(List<Record> records) {
    this.records = records;
  }

  /// Sets the attribute field definitions
  ///
  /// Parameters:
  /// - [list]: List of field definitions for the .dbf file
  void setAttributeField(List<DbaseField> list) {
    _dbase = _dbase ?? DbaseFile(isUtf8: isUtf8, isCp949: isCp949);
    _dbase?.fields = list;
  }

  /// Sets the attribute data records
  ///
  /// Parameters:
  /// - [list]: List of attribute records (one per geometry record)
  void setAttributeRecord(List<List<dynamic>> list) {
    _dbase = _dbase ?? DbaseFile(isUtf8: isUtf8, isCp949: isCp949);
    _dbase?.records = list;
  }

  /// Creates a complete shapefile from scratch
  ///
  /// This is the recommended method for creating new shapefiles.
  /// It handles all the necessary setup and validation automatically.
  ///
  /// Parameters:
  /// - [filename]: Path to the output .shp file
  /// - [type]: Geometry type for all records
  /// - [records]: List of geometry records
  /// - [minX], [minY], [maxX], [maxY]: Bounding box coordinates
  /// - [minZ], [maxZ]: Optional Z coordinate bounds
  /// - [minM], [maxM]: Optional measure value bounds
  /// - [attributeFields]: Optional list of attribute field definitions
  /// - [attributeRecords]: Optional list of attribute data records
  ///
  /// Throws [InvalidHeaderException] if shape type not set.
  /// Throws [InvalidBoundsException] if bounds not set.
  /// Throws [ShapefileIOException] on write errors.
  /// Throws [CorruptedDataException] if records don't match expected types.
  ///
  /// Example:
  /// ```dart
  /// final shapefile = Shapefile();
  /// shapefile.writeComplete(
  ///   'cities.shp',
  ///   ShapeType.shapePOINT,
  ///   [Point(126.97, 37.56), Point(129.07, 35.17)],
  ///   minX: 126.97, minY: 35.17,
  ///   maxX: 129.07, maxY: 37.56,
  ///   attributeFields: [DbaseField.fieldC('NAME', 50)],
  ///   attributeRecords: [['Seoul'], ['Busan']],
  /// );
  /// ```
  void writeComplete(
    String filename,
    ShapeType type,
    List<Record> records, {
    double minX = 0.0,
    double minY = 0.0,
    double maxX = 0.0,
    double maxY = 0.0,
    double minZ = 0.0,
    double maxZ = 0.0,
    double minM = 0.0,
    double maxM = 0.0,
    List<DbaseField>? attributeFields,
    List<List<dynamic>>? attributeRecords,
  }) {
    headerSHX.type = type;
    headerSHP.type = type;

    // Create appropriate bounds type based on whether Z/M values are provided
    final Bounds bounds;
    if (minZ != 0.0 || maxZ != 0.0) {
      // If Z values are set, use BoundsZ (which includes M values)
      bounds = BoundsZ(minX, minY, maxX, maxY, minM, maxM, minZ, maxZ);
    } else if (minM != 0.0 || maxM != 0.0) {
      // If only M values are set, use BoundsM
      bounds = BoundsM(minX, minY, maxX, maxY, minM, maxM);
    } else {
      // No Z or M values, use basic Bounds
      bounds = Bounds(minX, minY, maxX, maxY);
    }

    headerSHX.bounds = bounds;
    headerSHP.bounds = bounds;

    this.records = records;
    if (null != attributeFields && null != attributeRecords) {
      _dbase = _dbase ?? DbaseFile(isUtf8: isUtf8, isCp949: isCp949);
      _dbase!.fields = attributeFields;
      _dbase!.records = attributeRecords;
    } else {
      _dbase?.close();
      _dbase = null;
    }

    write(filename);
  }

  /// Analyzes records and prepares offsets for writing
  ///
  /// Throws [InvalidHeaderException] if shape type not set.
  /// Throws [InvalidBoundsException] if bounds not set.
  /// Throws [CorruptedDataException] if records don't match expected types.
  /// Throws [UnsupportedTypeException] if geometry type is not supported.
  void analyze() {
    if (headerSHP.type == ShapeType.shapeUNDEFINED) {
      throw InvalidHeaderException(
        'Shape file type is not set',
        filePath: _fNameSHP,
        details: 'Call setHeaderType() before analysis',
      );
    }
    if (headerSHP.bounds == const Bounds.zero()) {
      throw InvalidBoundsException('Bounds not set', filePath: _fNameSHP);
    }

    offsets = [];
    int pos = lenHeader;
    for (int n = 0; n < records.length; ++n) {
      int offset = pos;
      int length = 0;
      switch (headerSHP.type) {
        // Point types
        case ShapeType.shapePOINT:
          if (records[n] is! Point) {
            throw CorruptedDataException(
              'Data does not contain Point information',
              filePath: _fNameSHP,
              details: 'Record $n is not a Point',
            );
          }
          length = 4 + 8 + 8;
          pos += (lenRecordHeader + length);
          break;
        case ShapeType.shapePOINTM:
          if (records[n] is! PointM) {
            throw CorruptedDataException(
              'Data does not contain PointM information',
              filePath: _fNameSHP,
              details: 'Record $n is not a PointM',
            );
          }
          // ShapeType(4) + X(8) + Y(8) + M(8)
          length = 4 + 8 + 8 + 8;
          pos += (lenRecordHeader + length);
          break;
        case ShapeType.shapePOINTZ:
          if (records[n] is! PointZ) {
            throw CorruptedDataException(
              'Data does not contain PointZ information',
              filePath: _fNameSHP,
              details: 'Record $n is not a PointZ',
            );
          }
          // ShapeType(4) + X(8) + Y(8) + Z(8) + M(8)
          length = 4 + 8 + 8 + 8 + 8;
          pos += (lenRecordHeader + length);
          break;

        // Polyline types
        case ShapeType.shapePOLYLINE:
          if (records[n] is! Polyline) {
            throw CorruptedDataException(
              'Data does not contain Polyline information',
              filePath: _fNameSHP,
              details: 'Record $n is not a Polyline',
            );
          }
          final polyline = records[n] as Polyline;
          length = 4 + 32 + 4 + 4 + polyline.numParts * 4 + polyline.numPoints * 16;
          pos += (lenRecordHeader + length);
          break;
        case ShapeType.shapePOLYLINEM:
          if (records[n] is! PolylineM) {
            throw CorruptedDataException(
              'Data does not contain PolylineM information',
              filePath: _fNameSHP,
              details: 'Record $n is not a PolylineM',
            );
          }
          final polylineM = records[n] as PolylineM;
          // ShapeType(4) + Box(32) + NumParts(4) + NumPoints(4) + Parts + Points + optional M
          length = 4 + 32 + 4 + 4 + polylineM.numParts * 4 + polylineM.numPoints * 16;
          if (polylineM.hasM) {
            length += 16 + polylineM.numPoints * 8; // Mmin/Mmax(16) + Marray
          }
          pos += (lenRecordHeader + length);
          break;
        case ShapeType.shapePOLYLINEZ:
          if (records[n] is! PolylineZ) {
            throw CorruptedDataException(
              'Data does not contain PolylineZ information',
              filePath: _fNameSHP,
              details: 'Record $n is not a PolylineZ',
            );
          }
          final polylineZ = records[n] as PolylineZ;
          // ShapeType(4) + Box(32) + NumParts(4) + NumPoints(4) + Parts + Points + Zmin/Zmax(16) + Zarray + optional M
          length = 4 + 32 + 4 + 4 + polylineZ.numParts * 4 + polylineZ.numPoints * 16 + 16 + polylineZ.numPoints * 8;
          if (polylineZ.hasM) {
            length += 16 + polylineZ.numPoints * 8; // Mmin/Mmax(16) + Marray
          }
          pos += (lenRecordHeader + length);
          break;

        // Polygon types
        case ShapeType.shapePOLYGON:
          if (records[n] is! Polygon) {
            throw CorruptedDataException(
              'Data does not contain Polygon information',
              filePath: _fNameSHP,
              details: 'Record $n is not a Polygon',
            );
          }
          final polygon = records[n] as Polygon;
          length = 4 + 32 + 4 + 4 + polygon.numParts * 4 + polygon.numPoints * 16;
          pos += (lenRecordHeader + length);
          break;
        case ShapeType.shapePOLYGONM:
          if (records[n] is! PolygonM) {
            throw CorruptedDataException(
              'Data does not contain PolygonM information',
              filePath: _fNameSHP,
              details: 'Record $n is not a PolygonM',
            );
          }
          final polygonM = records[n] as PolygonM;
          // ShapeType(4) + Box(32) + NumParts(4) + NumPoints(4) + Parts + Points + optional M
          length = 4 + 32 + 4 + 4 + polygonM.numParts * 4 + polygonM.numPoints * 16;
          if (polygonM.hasM) {
            length += 16 + polygonM.numPoints * 8; // Mmin/Mmax(16) + Marray
          }
          pos += (lenRecordHeader + length);
          break;
        case ShapeType.shapePOLYGONZ:
          if (records[n] is! PolygonZ) {
            throw CorruptedDataException(
              'Data does not contain PolygonZ information',
              filePath: _fNameSHP,
              details: 'Record $n is not a PolygonZ',
            );
          }
          final polygonZ = records[n] as PolygonZ;
          // ShapeType(4) + Box(32) + NumParts(4) + NumPoints(4) + Parts + Points + Zmin/Zmax(16) + Zarray + optional M
          length = 4 + 32 + 4 + 4 + polygonZ.numParts * 4 + polygonZ.numPoints * 16 + 16 + polygonZ.numPoints * 8;
          if (polygonZ.hasM) {
            length += 16 + polygonZ.numPoints * 8; // Mmin/Mmax(16) + Marray
          }
          pos += (lenRecordHeader + length);
          break;

        // MultiPoint types
        case ShapeType.shapeMULTIPOINT:
          if (records[n] is! MultiPoint) {
            throw CorruptedDataException(
              'Data does not contain MultiPoint information',
              filePath: _fNameSHP,
              details: 'Record $n is not a MultiPoint',
            );
          }
          final multiPoint = records[n] as MultiPoint;
          // ShapeType(4) + Box(32) + NumPoints(4) + Points(NumPoints * 16)
          length = 4 + 32 + 4 + multiPoint.numPoints * 16;
          pos += (lenRecordHeader + length);
          break;
        case ShapeType.shapeMULTIPOINTM:
          if (records[n] is! MultiPointM) {
            throw CorruptedDataException(
              'Data does not contain MultiPointM information',
              filePath: _fNameSHP,
              details: 'Record $n is not a MultiPointM',
            );
          }
          final multiPointM = records[n] as MultiPointM;
          // ShapeType(4) + Box(32) + NumPoints(4) + Points + optional M
          length = 4 + 32 + 4 + multiPointM.numPoints * 16;
          if (multiPointM.hasM) {
            length += 16 + multiPointM.numPoints * 8; // Mmin/Mmax(16) + Marray
          }
          pos += (lenRecordHeader + length);
          break;
        case ShapeType.shapeMULTIPOINTZ:
          if (records[n] is! MultiPointZ) {
            throw CorruptedDataException(
              'Data does not contain MultiPointZ information',
              filePath: _fNameSHP,
              details: 'Record $n is not a MultiPointZ',
            );
          }
          final multiPointZ = records[n] as MultiPointZ;
          // ShapeType(4) + Box(32) + NumPoints(4) + Points + Zmin/Zmax(16) + Zarray + optional M
          length = 4 + 32 + 4 + multiPointZ.numPoints * 16 + 16 + multiPointZ.numPoints * 8;
          if (multiPointZ.hasM) {
            length += 16 + multiPointZ.numPoints * 8; // Mmin/Mmax(16) + Marray
          }
          pos += (lenRecordHeader + length);
          break;

        default:
          throw UnsupportedTypeException(headerSHP.type.toString(), filePath: _fNameSHP);
      }
      offsets.add(ShapeOffset(offset, length));
    }
    headerSHP.fileLength = pos;
    headerSHP.length = pos ~/ lenWord;

    if (_dbase != null) {
      _dbase!.analyze();
    }
  }
}
