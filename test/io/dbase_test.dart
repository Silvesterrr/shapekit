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

  group('DBase File Operations', () {
    test('creates and reads a DBF file with character fields', () {
      final filePath = '${tempDir.path}/test.dbf';
      final dbf = DbaseFile();

      final fields = [DbaseField.fieldC('NAME', 50), DbaseField.fieldC('CITY', 30)];

      final records = [
        ['Alice', 'Seoul'],
        ['Bob', 'Busan'],
        ['Charlie', 'Incheon'],
      ];

      dbf.writerEntirety(filePath, fields, records);

      // Read it back
      final readDbf = DbaseFile();
      final success = readDbf.reader(filePath);

      expect(success, isTrue);
      expect(readDbf.fields.length, equals(2));
      expect(readDbf.records.length, equals(3));

      expect(readDbf.fields[0].name, equals('NAME'));
      expect(readDbf.fields[0].type, equals('C'));
      expect(readDbf.fields[0].length, equals(50));

      expect(readDbf.records[0][0].toString().trim(), equals('Alice'));
      expect(readDbf.records[1][0].toString().trim(), equals('Bob'));
      expect(readDbf.records[2][0].toString().trim(), equals('Charlie'));
    });

    test('creates and reads a DBF file with numeric fields', () {
      final filePath = '${tempDir.path}/test_numeric.dbf';
      final dbf = DbaseFile();

      final fields = [DbaseField.fieldN('COUNT', 10), DbaseField.fieldNF('PRICE', 10, 2)];

      final records = [
        [100, 19.99],
        [200, 29.99],
        [150, 24.50],
      ];

      dbf.writerEntirety(filePath, fields, records);

      // Read it back
      final readDbf = DbaseFile();
      readDbf.reader(filePath);

      expect(readDbf.fields[0].type, equals('N'));
      expect(readDbf.fields[1].type, equals('N'));
      expect(readDbf.fields[1].decimalCount, equals(2));

      expect(readDbf.records[0][0], equals(100));
      expect(readDbf.records[0][1], closeTo(19.99, 0.01));
    });

    test('creates and reads a DBF file with logical fields', () {
      final filePath = '${tempDir.path}/test_logical.dbf';
      final dbf = DbaseFile();

      final fields = [DbaseField.fieldC('NAME', 20), DbaseField.fieldL('ACTIVE')];

      final records = [
        ['Item A', true],
        ['Item B', false],
        ['Item C', true],
      ];

      dbf.writerEntirety(filePath, fields, records);

      // Read it back
      final readDbf = DbaseFile();
      readDbf.reader(filePath);

      expect(readDbf.fields[1].type, equals('L'));
      expect(readDbf.records[0][1], isTrue);
      expect(readDbf.records[1][1], isFalse);
    });

    test('creates and reads a DBF file with date fields', () {
      final filePath = '${tempDir.path}/test_date.dbf';
      final dbf = DbaseFile();

      final fields = [DbaseField.fieldC('EVENT', 30), DbaseField.fieldD('DATE')];

      final records = [
        ['Event 1', DateTime(2026, 1, 31)],
        ['Event 2', DateTime(2026, 2, 1)],
      ];

      dbf.writerEntirety(filePath, fields, records);

      // Read it back
      final readDbf = DbaseFile();
      readDbf.reader(filePath);

      expect(readDbf.fields.length, equals(2));
      expect(readDbf.fields[1].name, equals('DATE'));
      expect(readDbf.fields[1].type, equals('D'));

      // Verify first record
      expect(readDbf.records[0][1], isA<DateTime>());
      expect(readDbf.records[0][1], equals(DateTime(2026, 1, 31)));
    });

    test('handles empty records', () {
      final filePath = '${tempDir.path}/test_empty.dbf';
      final dbf = DbaseFile();

      final fields = [DbaseField.fieldC('NAME', 50)];

      dbf.writerEntirety(filePath, fields, []);

      final readDbf = DbaseFile();
      readDbf.reader(filePath);

      expect(readDbf.fields.length, equals(1));
      expect(readDbf.records.length, equals(0));
    });

    test('handles many records', () {
      final filePath = '${tempDir.path}/test_many.dbf';
      final dbf = DbaseFile();

      final fields = [DbaseField.fieldN('ID', 10), DbaseField.fieldC('VALUE', 20)];

      final records = List.generate(1000, (i) => [i, 'Value $i']);

      dbf.writerEntirety(filePath, fields, records);

      final readDbf = DbaseFile();
      readDbf.reader(filePath);

      expect(readDbf.records.length, equals(1000));
      expect(readDbf.records[500][0], equals(500));
    });

    test('handles long text values', () {
      final filePath = '${tempDir.path}/test_long.dbf';
      final dbf = DbaseFile();

      final fields = [
        DbaseField.fieldC('DESCRIPTION', 254), // Max length
      ];

      final longText = 'A' * 254;
      final records = [
        [longText],
      ];

      dbf.writerEntirety(filePath, fields, records);

      final readDbf = DbaseFile();
      readDbf.reader(filePath);

      expect(readDbf.records[0][0].toString().trim().length, equals(254));
    });

    test('handles mixed field types', () {
      final filePath = '${tempDir.path}/test_mixed.dbf';
      final dbf = DbaseFile();

      final fields = [
        DbaseField.fieldC('NAME', 50),
        DbaseField.fieldN('AGE', 3),
        DbaseField.fieldNF('SALARY', 10, 2),
        DbaseField.fieldL('EMPLOYED'),
        DbaseField.fieldD('HIRE_DATE'),
      ];

      final records = [
        ['Alice', 30, 50000.50, true, DateTime(2020, 1, 15)],
        ['Bob', 25, 45000.00, false, DateTime(2021, 3, 20)],
      ];

      dbf.writerEntirety(filePath, fields, records);

      final readDbf = DbaseFile();
      readDbf.reader(filePath);

      expect(readDbf.fields.length, equals(5));
      expect(readDbf.records.length, equals(2));
      expect(readDbf.records[0][0].toString().trim(), equals('Alice'));
      expect(readDbf.records[0][1], equals(30));
      expect(readDbf.records[0][2], closeTo(50000.50, 0.01));
      expect(readDbf.records[0][3], isTrue);
      expect(readDbf.records[0][4], equals(DateTime(2020, 1, 15)));
    });
  });

  group('DBase Field Types', () {
    test('DbaseField.fieldC creates character field', () {
      final field = DbaseField.fieldC('NAME', 50);

      expect(field.name, equals('NAME'));
      expect(field.type, equals('C'));
      expect(field.length, equals(50));
      expect(field.decimalCount, equals(0));
    });

    test('DbaseField.fieldN creates numeric field', () {
      final field = DbaseField.fieldN('COUNT', 10);

      expect(field.name, equals('COUNT'));
      expect(field.type, equals('N'));
      expect(field.length, equals(10));
      expect(field.decimalCount, equals(0));
    });

    test('DbaseField.fieldNF creates float field', () {
      final field = DbaseField.fieldNF('PRICE', 10, 2);

      expect(field.name, equals('PRICE'));
      expect(field.type, equals('N'));
      expect(field.length, equals(10));
      expect(field.decimalCount, equals(2));
    });

    test('DbaseField.fieldL creates logical field', () {
      final field = DbaseField.fieldL('ACTIVE');

      expect(field.name, equals('ACTIVE'));
      expect(field.type, equals('L'));
      expect(field.length, equals(1));
    });

    test('DbaseField.fieldD creates date field', () {
      final field = DbaseField.fieldD('DATE');

      expect(field.name, equals('DATE'));
      expect(field.type, equals('D'));
      expect(field.length, equals(8));
    });
  });
}
