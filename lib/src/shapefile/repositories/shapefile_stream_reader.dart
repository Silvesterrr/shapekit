import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cp949_codec/cp949_codec.dart';
import 'package:shapekit/src/domain/entities/dbase_field.dart';
import 'package:shapekit/src/domain/entities/geometry/envelope.dart';
import 'package:shapekit/src/domain/entities/geometry/record.dart';
import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart';
import 'package:shapekit/src/shapefile/models/shapefile_header.dart';
import 'package:shapekit/src/shapefile/models/shapefile_offset.dart';
import 'package:shapekit/src/shapefile/repositories/projection_repository.dart';
import 'package:shapekit/src/shapefile/repositories/shapefile_repository.dart';
import 'package:shapekit/src/shapefile/serializers/geometry_deserializer.dart';

class ShapefileFeature {
  final Record geometry;
  final Map<String, dynamic> attributes;
  final int index;
  final Envelope? bounds;

  const ShapefileFeature({required this.geometry, required this.attributes, required this.index, this.bounds});
}

class ShapefileStreamReader {
  final String path;
  final bool isUtf8;
  final bool isCp949;
  final List<ShapeOffset> _offsets;
  final List<DbaseField> fields;
  final int recordCount;
  final ShapeType shapeType;
  final Envelope bounds;
  final int? projection;

  ShapefileStreamReader._({
    required this.path,
    required this.isUtf8,
    required this.isCp949,
    required List<ShapeOffset> offsets,
    required this.fields,
    required this.recordCount,
    required this.shapeType,
    required this.bounds,
    required this.projection,
  }) : _offsets = offsets;

  static ShapefileStreamReader open(String path, {bool isUtf8 = true, bool isCp949 = false}) {
    final shpBase = path.substring(0, path.lastIndexOf('.'));
    final shxPath = '$shpBase.shx';
    final dbfPath = '$shpBase.dbf';
    final prjPath = '$shpBase.prj';

    final shx = _readShx(shxPath);
    final shpHeader = _readShpHeader(path);
    final dbfHeader = File(dbfPath).existsSync()
        ? _readDbfHeader(dbfPath, isUtf8: isUtf8, isCp949: isCp949)
        : const _DbfHeader(fields: [], recordCount: 0, headerLength: 0, recordLength: 0);

    int? epsg;
    if (File(prjPath).existsSync()) {
      final prj = CShapeProjectionFile();
      try {
        prj.read(prjPath);
        epsg = prj.epsgCode;
      } catch (_) {
        epsg = null;
      }
    }

    return ShapefileStreamReader._(
      path: path,
      isUtf8: isUtf8,
      isCp949: isCp949,
      offsets: shx.offsets,
      fields: dbfHeader.fields,
      recordCount: shx.offsets.length,
      shapeType: shpHeader.type,
      bounds: shpHeader.bounds,
      projection: epsg,
    );
  }

  Stream<ShapefileFeature> features() async* {
    final shpBase = path.substring(0, path.lastIndexOf('.'));
    final dbfPath = '$shpBase.dbf';
    final shp = File(path).openSync();
    final dbf = File(dbfPath).existsSync() ? File(dbfPath).openSync() : null;
    final dbfHeader = dbf == null
        ? const _DbfHeader(fields: [], recordCount: 0, headerLength: 0, recordLength: 0)
        : _readDbfHeader(dbfPath, isUtf8: isUtf8, isCp949: isCp949);

    try {
      for (var i = 0; i < _offsets.length; i++) {
        final offset = _offsets[i];
        shp.setPositionSync(offset.offset + Shapefile.lenRecordHeader);
        final bytes = shp.readSync(offset.length);
        final data = ByteData.sublistView(bytes);
        final geometry = _readGeometry(data, 0, shapeType, offset.length);
        final attributes = dbf == null
            ? <String, dynamic>{}
            : _readDbfRecord(dbf, dbfHeader, i, isUtf8: isUtf8, isCp949: isCp949);

        yield ShapefileFeature(geometry: geometry, attributes: attributes, index: i, bounds: _geometryBounds(geometry));
      }
    } finally {
      shp.closeSync();
      dbf?.closeSync();
    }
  }

  static _ShxData _readShx(String path) {
    final bytes = File(path).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    final fileCode = data.getInt32(0, Endian.big);
    if (fileCode != ShapeHeader.expectedFileCode) {
      throw InvalidHeaderException('Invalid SHX file code', filePath: path);
    }

    final fileLength = data.getInt32(24, Endian.big) * Shapefile.lenWord;
    final offsets = <ShapeOffset>[];
    var pos = Shapefile.lenHeader;
    while (pos + Shapefile.lenRecordHeader <= fileLength && pos + Shapefile.lenRecordHeader <= bytes.length) {
      offsets.add(
        ShapeOffset(
          data.getInt32(pos, Endian.big) * Shapefile.lenWord,
          data.getInt32(pos + 4, Endian.big) * Shapefile.lenWord,
        ),
      );
      pos += Shapefile.lenRecordHeader;
    }
    return _ShxData(offsets);
  }

  static _ShpHeaderData _readShpHeader(String path) {
    final raf = File(path).openSync();
    try {
      final bytes = raf.readSync(Shapefile.lenHeader);
      final data = ByteData.sublistView(bytes);
      final fileCode = data.getInt32(0, Endian.big);
      if (fileCode != ShapeHeader.expectedFileCode) {
        throw InvalidHeaderException('Invalid SHP file code', filePath: path);
      }
      final version = data.getInt32(28, Endian.little);
      if (version != ShapeHeader.expectedVersion) {
        throw InvalidHeaderException('Invalid SHP version', filePath: path);
      }
      return _ShpHeaderData(
        ShapeType.toType(data.getInt32(32, Endian.little)),
        Envelope(
          data.getFloat64(36, Endian.little),
          data.getFloat64(44, Endian.little),
          data.getFloat64(52, Endian.little),
          data.getFloat64(60, Endian.little),
        ),
      );
    } finally {
      raf.closeSync();
    }
  }

  static Record _readGeometry(ByteData data, int offset, ShapeType type, int contentLength) {
    switch (type) {
      case ShapeType.shapePOINT:
        return GeometryDeserializer.readPoint(data, offset);
      case ShapeType.shapePOINTM:
        return GeometryDeserializer.readPointM(data, offset);
      case ShapeType.shapePOINTZ:
        return GeometryDeserializer.readPointZ(data, offset);
      case ShapeType.shapePOLYLINE:
        return GeometryDeserializer.readPolyline(data, offset);
      case ShapeType.shapePOLYLINEM:
        return GeometryDeserializer.readPolylineM(data, offset, contentLength: contentLength);
      case ShapeType.shapePOLYLINEZ:
        return GeometryDeserializer.readPolylineZ(data, offset, contentLength: contentLength);
      case ShapeType.shapePOLYGON:
        return GeometryDeserializer.readPolygon(data, offset);
      case ShapeType.shapePOLYGONM:
        return GeometryDeserializer.readPolygonM(data, offset, contentLength: contentLength);
      case ShapeType.shapePOLYGONZ:
        return GeometryDeserializer.readPolygonZ(data, offset, contentLength: contentLength);
      case ShapeType.shapeMULTIPOINT:
        return GeometryDeserializer.readMultiPoint(data, offset);
      case ShapeType.shapeMULTIPOINTM:
        return GeometryDeserializer.readMultiPointM(data, offset, contentLength: contentLength);
      case ShapeType.shapeMULTIPOINTZ:
        return GeometryDeserializer.readMultiPointZ(data, offset, contentLength: contentLength);
      default:
        throw UnsupportedTypeException(type.toString(), filePath: '');
    }
  }

  static _DbfHeader _readDbfHeader(String path, {required bool isUtf8, required bool isCp949}) {
    final raf = File(path).openSync();
    try {
      final header = raf.readSync(32);
      final data = ByteData.sublistView(header);
      final type = data.getUint8(0);
      if (type != 0x03) {
        throw InvalidFormatException('DBF file version not supported', filePath: path, details: 'Version $type');
      }

      final recordCount = data.getUint32(4, Endian.little);
      final headerLength = data.getUint16(8, Endian.little);
      final recordLength = data.getUint16(10, Endian.little);
      final descriptorLength = headerLength - 32;
      final descriptorBytes = raf.readSync(descriptorLength);
      final descriptor = ByteData.sublistView(descriptorBytes);

      final fields = <DbaseField>[];
      var pos = 0;
      while (pos < descriptorLength) {
        if (descriptor.getUint8(pos) == 0x0D) break;
        final rawName = descriptor.buffer.asUint8List(pos, 11).where((e) => e != 0).toList();
        final field = DbaseField()
          ..name = _decode(rawName, isUtf8: isUtf8, isCp949: isCp949).trim()
          ..type = String.fromCharCode(descriptor.getUint8(pos + 11))
          ..length = descriptor.getUint8(pos + 16)
          ..decimalCount = descriptor.getUint8(pos + 17)
          ..id = descriptor.getUint8(pos + 20)
          ..flag = descriptor.getUint8(pos + 23);
        fields.add(field);
        pos += 32;
      }

      return _DbfHeader(
        fields: fields,
        recordCount: recordCount,
        headerLength: headerLength,
        recordLength: recordLength,
      );
    } finally {
      raf.closeSync();
    }
  }

  static Map<String, dynamic> _readDbfRecord(
    RandomAccessFile dbf,
    _DbfHeader header,
    int index, {
    required bool isUtf8,
    required bool isCp949,
  }) {
    if (index >= header.recordCount) return {};

    dbf.setPositionSync(header.headerLength + index * header.recordLength);
    final bytes = dbf.readSync(header.recordLength);
    if (bytes.isEmpty || bytes[0] == 0x2A) return {};

    final result = <String, dynamic>{};
    var offset = 1;
    for (final field in header.fields) {
      final fieldBytes = bytes.sublist(offset, offset + field.length);
      result[field.name] = _decodeDbfValue(field, fieldBytes, isUtf8: isUtf8, isCp949: isCp949);
      offset += field.length;
    }
    return result;
  }

  static dynamic _decodeDbfValue(DbaseField field, List<int> data, {required bool isUtf8, required bool isCp949}) {
    switch (field.type) {
      case 'C':
        return _decode(data, isUtf8: isUtf8, isCp949: isCp949).replaceAll(RegExp('\\0'), '').trim();
      case 'D':
        final value = String.fromCharCodes(data).trim();
        if (value.length != 8 || value == '00000000') return null;
        return DateTime.tryParse('${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}');
      case 'F':
        final value = String.fromCharCodes(data).replaceAll(RegExp('\\0'), '').trim();
        return value.isEmpty ? 0.0 : double.parse(value);
      case 'N':
        final value = String.fromCharCodes(data).replaceAll(RegExp(r'[^\d.-]'), '');
        if (field.decimalCount > 0) return value.isEmpty ? 0.0 : double.parse(value);
        return value.isEmpty ? 0 : int.parse(value);
      case 'L':
        final value = String.fromCharCode(data.first).toUpperCase();
        return value == 'T' || value == 'Y';
      default:
        return String.fromCharCodes(data).trim();
    }
  }

  static String _decode(List<int> bytes, {required bool isUtf8, required bool isCp949}) {
    if (isCp949) return cp949.decode(bytes, allowInvalid: true);
    if (isUtf8) return utf8.decode(bytes, allowMalformed: true);
    return String.fromCharCodes(bytes);
  }

  static Envelope? _geometryBounds(Record geometry) {
    final dynamic g = geometry;
    try {
      final Object? b = g.bounds;
      if (b is Envelope) return b;
    } catch (_) {
      // Point-like geometries do not expose bounds.
    }
    try {
      final double x = g.x as double;
      final double y = g.y as double;
      return Envelope(x, y, x, y);
    } catch (_) {
      return null;
    }
  }
}

class _ShxData {
  final List<ShapeOffset> offsets;
  const _ShxData(this.offsets);
}

class _ShpHeaderData {
  final ShapeType type;
  final Envelope bounds;
  const _ShpHeaderData(this.type, this.bounds);
}

class _DbfHeader {
  final List<DbaseField> fields;
  final int recordCount;
  final int headerLength;
  final int recordLength;

  const _DbfHeader({
    required this.fields,
    required this.recordCount,
    required this.headerLength,
    required this.recordLength,
  });
}
