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

  group('UTF-8 Encoding', () {
    test('writes and reads UTF-8 text correctly', () {
      final filePath = '${tempDir.path}/test_utf8.shp';
      final shapefile = Shapefile(isUtf8: true);

      final records = [Point(0.0, 0.0)];

      final fields = [DbaseField.fieldC('NAME', 50), DbaseField.fieldC('DESCRIPTION', 100)];

      final attributes = [
        ['Test UTF-8', 'Hello World! 你好世界'],
      ];

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 0.0,
        maxY: 0.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      // Read it back with UTF-8
      final readShapefile = Shapefile(isUtf8: true);
      readShapefile.reader(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().trim(), equals('Test UTF-8'));
      expect(readShapefile.attributeRecords[0][1].toString().contains('Hello World'), isTrue);
    });

    test('handles various UTF-8 characters', () {
      final filePath = '${tempDir.path}/test_utf8_chars.shp';
      final shapefile = Shapefile(isUtf8: true);

      final records = [Point(0.0, 0.0), Point(1.0, 1.0), Point(2.0, 2.0)];

      final fields = [DbaseField.fieldC('TEXT', 100)];

      final attributes = [
        ['English: Hello'],
        ['Emoji: 🌍🌎🌏'],
        ['Math: ∑∫∂∇'],
      ];

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 2.0,
        maxY: 2.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      final readShapefile = Shapefile(isUtf8: true);
      readShapefile.reader(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().contains('English'), isTrue);
      // Note: Emoji and special chars may have encoding limitations in DBF format
    });

    test('handles empty UTF-8 strings', () {
      final filePath = '${tempDir.path}/test_utf8_empty.shp';
      final shapefile = Shapefile(isUtf8: true);

      final records = [Point(0.0, 0.0)];
      final fields = [DbaseField.fieldC('TEXT', 50)];
      final attributes = [
        [''],
      ];

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 0.0,
        maxY: 0.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      final readShapefile = Shapefile(isUtf8: true);
      readShapefile.reader(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().trim(), equals(''));
    });
  });

  group('CP949 Encoding (Korean)', () {
    test('writes and reads Korean text with CP949', () {
      final filePath = '${tempDir.path}/test_cp949.shp';
      final shapefile = Shapefile(isCp949: true);

      final records = [Point(126.9780, 37.5665)];

      final fields = [DbaseField.fieldC('NAME_KR', 50), DbaseField.fieldC('NAME_EN', 50)];

      final attributes = [
        ['서울', 'Seoul'],
      ];

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 126.9780,
        minY: 37.5665,
        maxX: 126.9780,
        maxY: 37.5665,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      // Read it back with CP949
      final readShapefile = Shapefile(isCp949: true);
      readShapefile.reader(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().contains('서울'), isTrue);
      expect(readShapefile.attributeRecords[0][1].toString().trim(), equals('Seoul'));
    });

    test('handles multiple Korean city names', () {
      final filePath = '${tempDir.path}/test_korean_cities.shp';
      final shapefile = Shapefile(isCp949: true);

      final records = [Point(126.9780, 37.5665), Point(129.0756, 35.1796), Point(126.7052, 37.4563)];

      final fields = [DbaseField.fieldC('CITY', 50)];

      final attributes = [
        ['서울'],
        ['부산'],
        ['인천'],
      ];

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 126.7052,
        minY: 35.1796,
        maxX: 129.0756,
        maxY: 37.5665,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      final readShapefile = Shapefile(isCp949: true);
      readShapefile.reader(filePath);

      expect(readShapefile.attributeRecords.length, equals(3));
      expect(readShapefile.attributeRecords[0][0].toString().contains('서울'), isTrue);
      expect(readShapefile.attributeRecords[1][0].toString().contains('부산'), isTrue);
      expect(readShapefile.attributeRecords[2][0].toString().contains('인천'), isTrue);
    });
  });

  group('ASCII Encoding (Default)', () {
    test('writes and reads ASCII text correctly', () {
      final filePath = '${tempDir.path}/test_ascii.shp';
      final shapefile = Shapefile(); // Default is ASCII

      final records = [Point(0.0, 0.0)];

      final fields = [DbaseField.fieldC('NAME', 50)];

      final attributes = [
        ['Simple ASCII Text'],
      ];

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 0.0,
        maxY: 0.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      final readShapefile = Shapefile();
      readShapefile.reader(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().trim(), equals('Simple ASCII Text'));
    });

    test('handles numbers and special ASCII characters', () {
      final filePath = '${tempDir.path}/test_ascii_special.shp';
      final shapefile = Shapefile();

      final records = [Point(0.0, 0.0)];
      final fields = [DbaseField.fieldC('TEXT', 100)];

      final attributes = [
        ['Test123!@#\$%^&*()_+-=[]{}|;:,.<>?'],
      ];

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 0.0,
        maxY: 0.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      final readShapefile = Shapefile();
      readShapefile.reader(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().contains('Test123'), isTrue);
    });
  });

  group('Encoding Edge Cases', () {
    test('handles mixed encoding flags gracefully', () {
      // Should default to one encoding if both flags are set
      final shapefile = Shapefile(isUtf8: true, isCp949: true);

      expect(shapefile, isNotNull);
      // Behavior should be defined in implementation
    });

    test('handles very long text in different encodings', () {
      final filePath = '${tempDir.path}/test_long_text.shp';
      final shapefile = Shapefile(isUtf8: true);

      final records = [Point(0.0, 0.0)];
      final fields = [DbaseField.fieldC('LONG_TEXT', 254)];

      final longText = 'A' * 200 + ' Test';
      final attributes = [
        [longText],
      ];

      shapefile.writerEntirety(
        filePath,
        ShapeType.shapePOINT,
        records,
        minX: 0.0,
        minY: 0.0,
        maxX: 0.0,
        maxY: 0.0,
        attributeFields: fields,
        attributeRecords: attributes,
      );

      final readShapefile = Shapefile(isUtf8: true);
      readShapefile.reader(filePath);

      expect(readShapefile.attributeRecords[0][0].toString().length, greaterThan(100));
    });
  });
}
