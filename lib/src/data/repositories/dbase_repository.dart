import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cp949_codec/cp949_codec.dart';

import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart';

import 'package:shapekit/src/domain/entities/dbase_field.dart';

class DbaseFile {
  DbaseFile({this.isUtf8 = false, this.isCp949 = false});

  bool isUtf8;
  bool isCp949;

  static const lenMaxBuffer = 65535;
  static const lenDbaseHeader = 32;
  static const lenDesc = 32;
  static const dbaseIIIPlusNoMeno = 0x03;

  String? _fNameDBF;

  // String get fileName => _fNameDBF??'';
  // set fileName(String name) => _fNameDBF = name;

  File? _fileDBF;
  RandomAccessFile? _rafDBF;

  // Number of records in the database file
  int _recordCount = 0;

  // Number of bytes in the header
  int _headerLength = 0;

  // Number of bytes in the record
  int _recordLength = 0;

  // Total file length
  // ignore: unused_field
  int _fileLength = -1;

  List<DbaseField> fields = [];
  List<List<dynamic>> records = [];

  void open(String dbfFile) {
    close();
    _fNameDBF = dbfFile;
  }

  bool readDBF() {
    if (null != _fileDBF) close();
    // ignore: unused_local_variable
    int filePosition = 0;

    Uint8List? bufferDBF;
    try {
      _fileDBF = File(_fNameDBF!);
      _rafDBF = _fileDBF!.openSync();
      // _fileLength = _rafDBF!.lengthSync();
      bufferDBF = _rafDBF!.readSync(lenDbaseHeader);
      filePosition += lenDbaseHeader;
      // debugPrint('file length $_fileLength, file position: $filePosition');
    } catch (e) {
      throw ShapefileIOException(
        'Error opening/reading DBF file',
        filePath: _fNameDBF,
        details: e.toString(),
      );
    }

    ByteData dataDBF = ByteData.sublistView(bufferDBF);

    // 0x03 FoxBASE+/Dbase III plus, no memo
    // 0x83 FoxBASE+/dBASE III PLUS, w/ memo
    int type = dataDBF.getUint8(0);
    if (type != dbaseIIIPlusNoMeno) {
      throw InvalidFormatException(
        'DBF file version not supported',
        filePath: _fNameDBF,
        details: 'Expected version $dbaseIIIPlusNoMeno, got $type',
      );
    }

    // The year value in the dBASE header must be the year since 1900.
    // int year = dataDBF.getUint8(1);
    // int month = dataDBF.getUint8(2);
    // int day = dataDBF.getUint8(3);

    // Number of records in the database file
    _recordCount = dataDBF.getUint32(4, Endian.little);
    // Number of bytes in the header
    _headerLength = dataDBF.getUint16(8, Endian.little);
    // Number of bytes in the record
    _recordLength = dataDBF.getUint16(10, Endian.little);

    _fileLength = _headerLength + _recordCount * _recordLength + 1;
    // debugPrint('Type:$type Date:$YY/$MM/$DD - $_recordCount, $_headerLength, $_recordLength');

    bufferDBF = null;
    int descriptorLength = _headerLength - lenDbaseHeader;
    try {
      bufferDBF = _rafDBF!.readSync(descriptorLength);
      filePosition += descriptorLength;
      // debugPrint('file position $filePosition');
    } catch (e) {
      throw ShapefileIOException(
        'Error reading DBF file header',
        filePath: _fNameDBF,
        details: e.toString(),
      );
    }
    dataDBF = ByteData.sublistView(bufferDBF);

    int pos = 0;
    while (pos < descriptorLength) {
      var field = DbaseField();
      var name = dataDBF.buffer
          .asUint8List(pos, 11)
          .where((e) => e != 0)
          .toList();

      String fieldName = isCp949
          ? cp949.decode(name, allowInvalid: true)
          : isUtf8
          ? utf8.decode(name, allowMalformed: true)
          : String.fromCharCodes(name);

      field.name = fieldName;

      field.type = String.fromCharCode(dataDBF.getUint8(pos + 11));
      field.length = dataDBF.getUint8(pos + 16);
      field.decimalCount = dataDBF.getUint8(pos + 17);
      field.id = dataDBF.getUint8(pos + 20);
      field.flag = dataDBF.getUint8(pos + 23);
      fields.add(field);
      // debugPrint('${field.name}, ${field.type}, ${field.fieldLength}, ${field.fieldCount}, ${field.id}, ${field.flag}');

      // var description = dataDBF.buffer.asUint8List(pos, LEN_DESCRIPTOR);
      // debugPrint('$description');

      pos += lenDesc;
      // debugPrint('position:$pos');
      // 0x0d It is an error to use it in lowercase letters. I don't know why.
      if (0x0D == dataDBF.getUint8(pos)) {
        pos++;
        break;
      }
    }
    // debugPrint('pos $pos, fields $fields');

    int totalCount = 0; //, totalPosition = filePosition;
    while (totalCount < _recordCount) {
      int length = 0, count = 0;
      for (var n = totalCount; n < _recordCount; ++n) {
        if ((length + _recordLength) > lenMaxBuffer) {
          break;
        }
        count++;
        length += _recordLength;
      }
      // debugPrint('record length : $count, $length');

      bufferDBF = null;
      try {
        bufferDBF = _rafDBF!.readSync(length);
        filePosition += length;
        // debugPrint('file position: $filePosition');
      } catch (e) {
        throw CorruptedDataException(
          'Error reading DBF file records',
          filePath: _fNameDBF,
          details: 'Record ${records.length}: $e',
        );
      }
      dataDBF = ByteData.sublistView(bufferDBF);
      int pos = 0;
      for (var n = 0; n < count; ++n) {
        int offset = 0;
        List<dynamic> record = [];
        // int code = dataDBF.getUint8(pos);
        // Checking the end of the file. In the current code, there is no need to check because it is checked with count.
        // (code == 0x1A) // end of record
        // Notifies that a record has been deleted. Rarely used.
        // (code == 0x2A) // record delete
        // It is available because the record has not been deleted.
        // (code == 0x20) // record not delete (enable use)
        // debugPrint('$n, $code');
        offset++;
        for (var field in fields) {
          var data = dataDBF.buffer.asUint8List(pos + offset, field.length);
          // debugPrint('$field, $data');
          switch (field.type) {
            // All OEM code page characters.
            case 'C': // Character
              // debugPrint('$data, ${utf8.decode(data)}');
              // String dataC = utf8.decode(data).trim();
              //   var name = data.where((e) => e != 0).toList();

              String dataC = isCp949
                  ? cp949.decode(data, allowInvalid: true)
                  : isUtf8
                  ? utf8.decode(data, allowMalformed: true)
                  : String.fromCharCodes(data);
              dataC = dataC.replaceAll(RegExp('\\0'), '').trim();
              record.add(dataC);
              break;
            // Numbers and a character to separate month, day, and year
            // (stored internally as 8 digits in YYYYMMDD format)
            case 'D':
              String dataD = String.fromCharCodes(data);
              if (dataD == '00000000' ||
                  dataD.trim().isEmpty ||
                  dataD == '        ') {
                record.add(
                  DateTime.parse('0000-01-01'),
                ); // Add null for empty/zero dates
              } else if (dataD.length == 8) {
                String yy = dataD.substring(0, 4);
                String mm = dataD.substring(4, 6);
                String dd = dataD.substring(6, 8);
                // debugPrint('read: $yy:$mm:$dd');
                record.add(DateTime.parse('$yy-$mm-$dd'));
              } else {
                throw CorruptedDataException(
                  'Invalid date format in DBF field',
                  filePath: _fNameDBF,
                  details: 'Field type D error: $dataD',
                );
              }
              break;
            case 'F':
              // String dataF = utf8.decode(data).trim();
              String dataF = String.fromCharCodes(
                data,
              ).replaceAll(RegExp('\\0'), '').trim();
              record.add(double.parse(dataF));
              break;
            case 'N':
              // String dataN = utf8.decode(data).trim();
              String dataN = String.fromCharCodes(
                data,
              ).replaceAll(RegExp(r'[^\d.-]'), '');
              // debugPrint('$field, $data, $dataN');
              if (0 < dataN.indexOf('-')) {
                if (0 < field.decimalCount) {
                  record.add(0.0);
                } else {
                  record.add(0);
                }
              } else {
                if (0 < field.decimalCount) {
                  record.add(dataN.isEmpty ? 0.0 : double.parse(dataN));
                } else {
                  record.add(dataN.isEmpty ? 0 : int.parse(dataN));
                }
              }
              break;
            //  ? Y y N n T t F f (? when not initialized).
            case 'L':
              if ('T' == String.fromCharCode(data[0])) {
                record.add(true);
              } else {
                record.add(false);
              }
              break;
            // case 'M':
            //   break;
            default:
              throw UnsupportedTypeException(
                'DBF field type ${field.type}',
                filePath: _fNameDBF,
              );
          }
          offset += field.length;
        }
        records.add(record);

        pos += offset;
        // totalPosition += offset;
        // if (n < 3) {
        //   debugPrint('index:${totalCount + n}, $record');
        //   debugPrint('$offset, $pos, $totalPosition');
        // }
      }
      totalCount += count;
      // debugPrint('total count: $totalCount, total position $totalPosition');
    }
    // last end of file (0x1A)
    filePosition++;

    // debugPrint('file position: $filePosition / $_fileLength');
    return true;
  }

  bool writeDBF() {
    if (null != _fileDBF) close();

    // ignore: unused_local_variable
    int filePosition = 0;

    Uint8List? bufferDBF;
    bufferDBF = Uint8List(lenDbaseHeader);
    ByteData dataDBF = ByteData.sublistView(bufferDBF);

    // 0x03 FoxBASE+/Dbase III plus, no memo
    // 0x83 FoxBASE+/dBASE III PLUS, w/ memo
    int type = dbaseIIIPlusNoMeno;
    dataDBF.setUint8(0, type);

    // The year value in the dBASE header must be the year since 1900.
    DateTime dt = DateTime.now();
    var yy = dt.year - 1900;
    var mm = dt.month;
    var dd = dt.day;
    dataDBF.setUint8(1, yy);
    dataDBF.setUint8(2, mm);
    dataDBF.setUint8(3, dd);

    // Number of records in the database file
    _recordCount = records.length;
    dataDBF.setUint32(4, _recordCount, Endian.little);
    // Number of bytes in the header
    int descriptorLength = lenDesc * fields.length + 1 /* end of descriptor */;
    _headerLength = lenDbaseHeader + descriptorLength;
    dataDBF.setUint16(8, _headerLength, Endian.little);
    // Number of bytes in the record
    _recordLength = 1; /* check byte (use / not use / end of record) */
    for (var field in fields) {
      _recordLength += field.length;
    }
    dataDBF.setUint16(10, _recordLength, Endian.little);

    _fileLength = _headerLength + _recordCount * _recordLength + 1;
    // debugPrint('Type:$type Date:$YY/$MM/$DD - $_recordCount, $_headerLength, $_recordLength');

    try {
      _fileDBF = File(_fNameDBF!);
      _rafDBF = _fileDBF!.openSync(mode: FileMode.write);
      _rafDBF!.writeFromSync(bufferDBF);
      filePosition += lenDbaseHeader;
      // debugPrint('file position: $filePosition');
    } catch (e) {
      throw ShapefileIOException(
        'Error opening/saving DBF file',
        filePath: _fNameDBF,
        details: e.toString(),
      );
    }

    bufferDBF = Uint8List(descriptorLength);
    dataDBF = ByteData.sublistView(bufferDBF);

    int pos = 0;
    for (var field in fields) {
      var name = dataDBF.buffer.asUint8List(pos, 11);
      var code = isCp949
          ? cp949.encode(field.name)
          : isUtf8
          ? utf8.encode(field.name)
          : field.name.codeUnits;
      name.setAll(0, code);
      name.fillRange(code.length, 11, 0x20);
      dataDBF.setUint8(pos + 11, field.type.codeUnitAt(0));
      dataDBF.setUint8(pos + 16, field.length);
      dataDBF.setUint8(pos + 17, field.decimalCount);
      dataDBF.setUint8(pos + 20, field.id);
      dataDBF.setUint8(pos + 23, field.flag);

      // var test = dataDBF.buffer.asUint8List(pos, LEN_DESCRIPTOR);
      // debugPrint('$test');

      pos += lenDesc;
    }
    // end of descriptor
    dataDBF.setUint8(pos, 0x0D);
    pos++;

    try {
      _rafDBF!.writeFromSync(bufferDBF, 0, pos);
      filePosition += pos;
      // debugPrint('file position: $filePosition');
    } catch (e) {
      throw ShapefileIOException(
        'Error saving DBF file',
        filePath: _fNameDBF,
        details: e.toString(),
      );
    }

    bufferDBF = Uint8List(lenMaxBuffer);
    dataDBF = ByteData.sublistView(bufferDBF);

    int totalCount = 0; //, totalPosition = filePosition;
    while (totalCount < _recordCount) {
      int length = 0, count = 0;
      for (var n = totalCount; n < _recordCount; ++n) {
        if ((length + _recordLength) > lenMaxBuffer) {
          break;
        }
        count++;
        length += _recordLength;
      }

      pos = 0;
      for (var n = 0; n < count; ++n) {
        int offset = 0;
        // record not delete (enable use) sign
        dataDBF.setUint8(pos + offset, 0x20);
        // record delete sign
        // dataDBF.setUint8(pos+offset, 0x2A);
        offset++;
        var list = records[totalCount + n];
        // debugPrint('${list}');
        for (var i = 0; i < fields.length; ++i) {
          var field = fields[i];
          var data = dataDBF.buffer.asUint8List(pos + offset, field.length);
          switch (field.type) {
            case 'C':
              // var dataC = utf8.encode(list[i]);
              var dataC = list[i] as String;

              // var code = utf8.encode(dataC);
              // debugPrint('$dataC - $code');

              var code = isCp949
                  ? cp949.encode(dataC)
                  : isUtf8
                  ? utf8.encode(dataC)
                  : dataC.codeUnits;
              data.setAll(0, code);
              data.fillRange(code.length, field.length, 0x20);
              break;
            case 'D':
              var dataD = list[i] as DateTime;
              String yy = dataD.year.toString();
              String mm = dataD.month.toString().padLeft(2, '0');
              String dd = dataD.day.toString().padLeft(2, '0');
              data.setAll(0, '$yy$mm$dd'.codeUnits);
              // debugPrint('write: $yy:$mm:$dd');
              break;
            case 'F':
              var dataF = (list[i] as double)
                  .toStringAsPrecision(field.decimalCount)
                  .padLeft(field.length, ' ');
              data.setAll(0, dataF.codeUnits);
              break;
            case 'N':
              if (list[i] is double) {
                String dataN = (list[i] as double)
                    .toStringAsPrecision(field.decimalCount)
                    .padLeft(field.length, ' ');
                data.setAll(0, dataN.codeUnits);
              } else {
                String dataN = list[i].toString().padLeft(field.length, ' ');
                data.setAll(0, dataN.codeUnits);
              }
              break;
            case 'L':
              if (list[i] as bool) {
                data.setAll(0, 'T'.codeUnits);
              } else {
                data.setAll(0, 'F'.codeUnits);
              }
              break;
            default:
              throw UnsupportedTypeException(
                'DBF field type ${field.type}',
                filePath: _fNameDBF,
              );
          }
          // debugPrint('data $data');
          offset += field.length;
        }
        // debugPrint('offset - $offset');
        pos += _recordLength;
      }
      totalCount += count;
      try {
        _rafDBF!.writeFromSync(bufferDBF, 0, pos);
        filePosition += pos;
        // debugPrint('file position: $filePosition');
      } catch (e) {
        throw ShapefileIOException(
          'Error saving DBF file records',
          filePath: _fNameDBF,
          details: e.toString(),
        );
      }
    }
    // end of record
    _rafDBF!.writeByteSync(0x1A);
    filePosition++;

    // debugPrint('file position: $filePosition / $_fileLength');
    return true;
  }

  /// Reads a dBASE file
  ///
  /// Parameters:
  /// - [filename]: Path to the .dbf file
  ///
  /// Returns true if reading was successful, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final dbf = DbaseFile(isUtf8: true);
  /// if (dbf.reader('data.dbf')) {
  ///   print('Fields: ${dbf.fields.length}');
  ///   print('Records: ${dbf.records.length}');
  /// }
  /// ```
  bool reader(String filename) {
    open(filename);
    bool result = readDBF();
    close();
    return result;
  }

  /// Writes a dBASE file
  ///
  /// Parameters:
  /// - [filename]: Path to the output .dbf file
  ///
  /// Returns true if writing was successful, false otherwise.
  bool writer(String filename) {
    open(filename);
    bool result = writeDBF();
    close();
    return result;
  }

  /// Creates a complete dBASE file from scratch
  ///
  /// Parameters:
  /// - [filename]: Path to the output .dbf file
  /// - [fields]: List of field definitions
  /// - [records]: List of data records
  ///
  /// Returns true if the file was created successfully, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final dbf = DbaseFile(isUtf8: true);
  /// dbf.writerEntirety(
  ///   'output.dbf',
  ///   [DbaseField.fieldC('NAME', 50), DbaseField.fieldN('AGE', 3)],
  ///   [['Alice', 30], ['Bob', 25]],
  /// );
  /// ```
  bool writerEntirety(
    String filename,
    List<DbaseField> fields,
    List<List<dynamic>> records,
  ) {
    this.fields = fields;
    this.records = records;
    if (analysis()) {
      return writer(filename);
    }
    return false;
  }

  bool analysis() {
    for (int n = 0; n < records.length; ++n) {
      var list = records[n];
      if (fields.length != list.length) {
        throw CorruptedDataException(
          'Field length and record length mismatch',
          filePath: _fNameDBF,
          details: 'Expected ${fields.length} fields, got ${list.length}',
        );
      }

      for (int i = 0; i < fields.length; ++i) {
        var field = fields[i];
        switch (field.type) {
          case 'C': // Character
            if (list[i] is! String) {
              throw CorruptedDataException(
                'Invalid data type for String field',
                filePath: _fNameDBF,
                details: 'C(String) field got ${list[i].runtimeType}',
              );
            }
            String data = list[i] as String;
            var len = isCp949
                ? cp949.encode(data).length
                : isUtf8
                ? utf8.encode(data).length
                : data.length;
            if (len >= field.length) {
              field.length = len + 1;
              // Length adjustment is necessary because problems occur when the field length is exceeded.
              // debugPrint('$n , $i - $len , ${field.fieldLength}');
            }
            break;
          case 'D':
            if (list[i] is! DateTime) {
              throw CorruptedDataException(
                'Invalid data type for DateTime field',
                filePath: _fNameDBF,
                details: 'D(DateTime) field got ${list[i].runtimeType}',
              );
            }
            break;
          case 'F':
            if (list[i] is! double) {
              throw CorruptedDataException(
                'Invalid data type for double field',
                filePath: _fNameDBF,
                details: 'F(double) field got ${list[i].runtimeType}',
              );
            }
            break;
          case 'N':
            if (list[i] is double) {
              if (0 == field.decimalCount) {
                throw CorruptedDataException(
                  'Invalid field configuration',
                  filePath: _fNameDBF,
                  details:
                      'For N(double) type, field count must be greater than 0',
                );
              }
            } else if (list[i] is! int) {
              throw CorruptedDataException(
                'Invalid data type for int field',
                filePath: _fNameDBF,
                details: 'N(int) field got ${list[i].runtimeType}',
              );
            }
            break;
          case 'L':
            if (list[i] is! bool) {
              throw CorruptedDataException(
                'Invalid data type for bool field',
                filePath: _fNameDBF,
                details: 'L(bool) field got ${list[i].runtimeType}',
              );
            }
            break;
          // case 'M':
          //   break;
          default:
            throw UnsupportedTypeException(
              'DBF field type ${field.type}',
              filePath: _fNameDBF,
            );
        }
      }
    }
    return true;
  }

  void close() {
    _fileDBF = null;
    _rafDBF?.close();
    _rafDBF = null;
    _recordCount = 0;
    _headerLength = 0;
    _recordLength = 0;
    _fileLength = -1;
  }

  void dispose() {
    fields = [];
    records = [];
    close();
  }
}
