import 'dart:io';
import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('shapekit_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ShapefileIOException - Missing Files', () {
    test('thrown when reading non-existent shapefile', () {
      final shapefile = Shapefile();
      shapefile.open('${tempDir.path}/nonexistent.shp');

      expect(() => shapefile.readSHX(), throwsA(isA<ShapefileIOException>()));
    });

    test('contains correct file path', () {
      final shapefile = Shapefile();
      final path = '${tempDir.path}/missing.shp';
      shapefile.open(path);

      try {
        shapefile.readSHX();
        fail('Should have thrown ShapefileIOException');
      } on ShapefileIOException catch (e) {
        expect(e.filePath, contains('missing.shx'));
        expect(e.type, equals(ShapefileErrorType.ioError));
      }
    });

    test('has descriptive error message', () {
      final shapefile = Shapefile();
      shapefile.open('${tempDir.path}/missing.shp');

      try {
        shapefile.readSHX();
        fail('Should have thrown');
      } on ShapefileIOException catch (e) {
        expect(e.message, contains('Error opening/reading'));
        expect(e.toString(), contains('ShapefileException')); // toString uses base class name
      }
    });
  });

  group('InvalidHeaderException', () {
    test('thrown for corrupted shapefile header', () {
      // Create a file with invalid header
      final filePath = '${tempDir.path}/invalid.shp';
      final file = File(filePath);
      file.writeAsBytesSync([1, 2, 3, 4, 5]); // Invalid header

      final shapefile = Shapefile();
      shapefile.open(filePath);

      expect(() => shapefile.readSHX(), throwsA(isA<ShapefileException>()));
    });

    test('contains error details', () {
      final exception = InvalidHeaderException(
        'Invalid magic number',
        filePath: 'test.shp',
        details: 'Expected 9994, got 1234',
      );

      expect(exception.message, equals('Invalid magic number'));
      expect(exception.filePath, equals('test.shp'));
      expect(exception.details, equals('Expected 9994, got 1234'));
      expect(exception.type, equals(ShapefileErrorType.invalidHeader));
    });
  });

  group('InvalidFormatException', () {
    test('has correct error type', () {
      final exception = InvalidFormatException('Invalid file format', filePath: 'test.shp');

      expect(exception.type, equals(ShapefileErrorType.invalidFormat));
      expect(exception.message, equals('Invalid file format'));
    });

    test('includes optional details', () {
      final exception = InvalidFormatException('Invalid format', details: 'Unexpected byte sequence at offset 100');

      expect(exception.details, contains('offset 100'));
    });
  });

  group('UnsupportedTypeException', () {
    test('reports unsupported geometry type', () {
      final exception = UnsupportedTypeException('Unknown', filePath: 'test.shp');

      expect(exception.type, equals(ShapefileErrorType.unsupportedType));
      expect(exception.message, contains('Unknown'));
    });

    test('has descriptive message', () {
      final exception = UnsupportedTypeException('Type999');

      expect(exception.toString(), contains('Type999'));
      expect(exception.toString(), contains('Unsupported'));
    });
  });

  group('InvalidBoundsException', () {
    test('reports invalid bounds', () {
      final exception = InvalidBoundsException('Bounds not set', filePath: 'test.shp');

      expect(exception.type, equals(ShapefileErrorType.invalidBounds));
      expect(exception.message, equals('Bounds not set'));
    });
  });

  group('CorruptedDataException', () {
    test('reports corrupted record data', () {
      final exception = CorruptedDataException(
        'Record data corrupted',
        filePath: 'test.shp',
        details: 'Invalid point count at record 5',
      );

      expect(exception.type, equals(ShapefileErrorType.corruptedData));
      expect(exception.message, contains('corrupted'));
      expect(exception.details, contains('record 5'));
    });

    test('toString includes all information', () {
      final exception = CorruptedDataException('Data error', filePath: 'test.shp', details: 'Checksum mismatch');

      final str = exception.toString();
      expect(str, contains('Data error'));
      expect(str, contains('test.shp'));
      expect(str, contains('Checksum mismatch'));
    });
  });

  group('ShapefileIOException', () {
    test('reports I/O errors', () {
      final exception = ShapefileIOException('Failed to write file', filePath: 'test.shp', details: 'Disk full');

      expect(exception.type, equals(ShapefileErrorType.ioError));
      expect(exception.message, contains('write'));
    });
  });

  group('ShapefileException Base Class', () {
    test('can be caught as base exception', () {
      final exception = FileNotFoundException('test.shp');

      expect(exception, isA<ShapefileException>());
      expect(exception, isA<Exception>());
    });

    test('toString formats correctly without optional fields', () {
      final exception = ShapefileException('Generic error', type: ShapefileErrorType.invalidFormat);

      final str = exception.toString();
      expect(str, contains('Generic error'));
      expect(str, isNot(contains('file:')));
      expect(str, isNot(contains('Details:')));
    });

    test('toString includes all fields when present', () {
      final exception = ShapefileException(
        'Error message',
        filePath: 'test.shp',
        type: ShapefileErrorType.ioError,
        details: 'Additional info',
      );

      final str = exception.toString();
      expect(str, contains('Error message'));
      expect(str, contains('test.shp'));
      expect(str, contains('Additional info'));
    });
  });

  group('Error Handling Integration', () {
    test('read throws exception for missing file', () {
      final shapefile = Shapefile();

      expect(() => shapefile.read('${tempDir.path}/missing.shp'), throwsA(isA<ShapefileException>()));
    });

    test('write succeeds with valid configuration', () {
      final shapefile = Shapefile();

      shapefile.setHeaderType(ShapeType.shapePOINT);
      shapefile.setHeaderBound(0.0, 0.0, 10.0, 10.0);
      shapefile.setRecords([Point(5.0, 5.0)]);

      // This should succeed without throwing
      expect(() => shapefile.write('${tempDir.path}/test.shp'), returnsNormally);
    });

    test('multiple errors can be caught separately', () {
      var ioErrorCaught = false;
      var invalidHeaderCaught = false;

      try {
        final shapefile = Shapefile();
        shapefile.open('${tempDir.path}/missing.shp');
        shapefile.readSHX();
      } on ShapefileIOException {
        ioErrorCaught = true;
      } on InvalidHeaderException {
        invalidHeaderCaught = true;
      }

      expect(ioErrorCaught, isTrue);
      expect(invalidHeaderCaught, isFalse);
    });

    test('can catch all shapefile exceptions with base class', () {
      var exceptionCaught = false;

      try {
        final shapefile = Shapefile();
        shapefile.open('${tempDir.path}/missing.shp');
        shapefile.readSHX();
      } on ShapefileException {
        exceptionCaught = true;
      }

      expect(exceptionCaught, isTrue);
    });
  });

  group('ShapefileErrorType Enum', () {
    test('all error types are defined', () {
      expect(ShapefileErrorType.fileNotFound, isNotNull);
      expect(ShapefileErrorType.invalidFormat, isNotNull);
      expect(ShapefileErrorType.unsupportedType, isNotNull);
      expect(ShapefileErrorType.invalidHeader, isNotNull);
      expect(ShapefileErrorType.invalidBounds, isNotNull);
      expect(ShapefileErrorType.corruptedData, isNotNull);
      expect(ShapefileErrorType.ioError, isNotNull);
    });

    test('error types are unique', () {
      final types = [
        ShapefileErrorType.fileNotFound,
        ShapefileErrorType.invalidFormat,
        ShapefileErrorType.unsupportedType,
        ShapefileErrorType.invalidHeader,
        ShapefileErrorType.invalidBounds,
        ShapefileErrorType.corruptedData,
        ShapefileErrorType.ioError,
      ];

      expect(types.toSet().length, equals(types.length));
    });
  });
}
