import 'dart:io';
import 'package:test/test.dart';
import 'package:shapekit/src/gpkg/gpkg_connection.dart';
import 'package:shapekit/src/gpkg/gpkg_reader.dart';
import 'package:shapekit/src/gpkg/exceptions.dart';
import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart' show FileNotFoundException;
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('GpkgConnection', () {
    late String testDbPath;

    setUp(() {
      testDbPath = 'test_gpkg_conn_${DateTime.now().millisecondsSinceEpoch}.gpkg';
    });

    tearDown(() {
      if (File(testDbPath).existsSync()) {
        File(testDbPath).deleteSync();
      }
    });

    test('throws FileNotFoundException for non-existent file', () {
      expect(() => GpkgConnection.open('no_such_file.gpkg'), throwsA(isA<FileNotFoundException>()));
    });

    test('open read-only and select from gpkg_contents', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath);
      final rows = conn.select("SELECT table_name FROM gpkg_contents WHERE data_type = ?", ['features']);

      expect(rows, isNotEmpty);
      expect(rows.first['table_name'], isA<String>());

      conn.close();
    });

    test('open read-write, execute CREATE + INSERT + select persists', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath, readOnly: false);

      conn.execute('''
        CREATE TABLE test_data (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          value REAL
        )
      ''');

      conn.execute('INSERT INTO test_data (name, value) VALUES (?, ?)', ['hello', 3.14]);

      final rows = conn.select('SELECT * FROM test_data');
      expect(rows.length, equals(1));
      expect(rows.first['name'], equals('hello'));
      expect(rows.first['value'], equals(3.14));

      conn.close();

      // Re-open to verify persistence
      final conn2 = GpkgConnection.open(testDbPath);
      final rows2 = conn2.select('SELECT * FROM test_data');
      expect(rows2.length, equals(1));
      conn2.close();
    });

    test('hasTable returns true for existing table', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath);
      expect(conn.hasTable('gpkg_contents'), isTrue);
      expect(conn.hasTable('test_points'), isTrue);

      conn.close();
    });

    test('hasTable returns false for non-existing table', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath);
      expect(conn.hasTable('no_such_table'), isFalse);

      conn.close();
    });

    test('execute on read-only throws StateError', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath);
      expect(() => conn.execute('CREATE TABLE foo (id INTEGER)'), throwsA(isA<StateError>()));

      conn.close();
    });

    test('transaction commits on success', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath, readOnly: false);
      conn.execute('CREATE TABLE tx_test (id INTEGER PRIMARY KEY, val TEXT)');

      final result = conn.transaction(() {
        conn.execute('INSERT INTO tx_test (val) VALUES (?)', ['a']);
        conn.execute('INSERT INTO tx_test (val) VALUES (?)', ['b']);
        return 42;
      });

      expect(result, equals(42));

      final rows = conn.select('SELECT val FROM tx_test ORDER BY val');
      expect(rows.length, equals(2));
      expect(rows[0]['val'], equals('a'));
      expect(rows[1]['val'], equals('b'));

      conn.close();
    });

    test('transaction rolls back on exception', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath, readOnly: false);
      conn.execute('CREATE TABLE tx_test (id INTEGER PRIMARY KEY, val TEXT)');

      expect(
        () => conn.transaction<void>(() {
          conn.execute('INSERT INTO tx_test (val) VALUES (?)', ['a']);
          throw Exception('boom');
        }),
        throwsA(predicate((Object e) => e.toString().contains('boom'))),
      );

      // Row should not be persisted because the transaction rolled back.
      final rows = conn.select('SELECT * FROM tx_test');
      expect(rows, isEmpty);

      conn.close();
    });

    test('transaction on read-only throws StateError', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath);
      expect(() => conn.transaction(() => null), throwsA(isA<StateError>()));

      conn.close();
    });

    test('throws GpkgException when used after close', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath);
      conn.close();

      expect(() => conn.select('SELECT 1'), throwsA(isA<GpkgException>()));
      expect(() => conn.hasTable('foo'), throwsA(isA<GpkgException>()));
    });

    test('select with no params default', () {
      _createMinimalGeoPackage(testDbPath);

      final conn = GpkgConnection.open(testDbPath);
      // No second argument uses the default empty list.
      final rows = conn.select('SELECT 1 AS v');
      expect(rows.first['v'], equals(1));

      conn.close();
    });
  });

  group('GpkgReader.hasTable', () {
    late String testDbPath;

    setUp(() {
      testDbPath = 'test_gpkg_reader_hastable_${DateTime.now().millisecondsSinceEpoch}.gpkg';
    });

    tearDown(() {
      if (File(testDbPath).existsSync()) {
        File(testDbPath).deleteSync();
      }
    });

    test('hasTable returns true for existing table', () {
      _createMinimalGeoPackage(testDbPath);

      final reader = GpkgReader.open(testDbPath);
      expect(reader.hasTable('gpkg_contents'), isTrue);
      expect(reader.hasTable('test_points'), isTrue);
      reader.close();
    });

    test('hasTable returns false for non-existing table', () {
      _createMinimalGeoPackage(testDbPath);

      final reader = GpkgReader.open(testDbPath);
      expect(reader.hasTable('nonexistent'), isFalse);
      reader.close();
    });
  });
}

void _createMinimalGeoPackage(String path) {
  final db = sqlite3.open(path);
  try {
    db.execute('''
      CREATE TABLE gpkg_spatial_ref_sys (
        srs_id INTEGER PRIMARY KEY,
        organization TEXT,
        organization_coordsys_id INTEGER,
        definition TEXT
      );
    ''');
    db.execute('''
      INSERT INTO gpkg_spatial_ref_sys VALUES (4326, 'EPSG', 4326, 'WGS84');
    ''');
    db.execute('''
      CREATE TABLE gpkg_contents (
        table_name TEXT PRIMARY KEY,
        data_type TEXT,
        identifier TEXT,
        description TEXT,
        last_change TEXT,
        min_x REAL, min_y REAL, max_x REAL, max_y REAL,
        srs_id INTEGER
      );
    ''');
    db.execute('''
      CREATE TABLE gpkg_geometry_columns (
        table_name TEXT,
        column_name TEXT,
        geometry_type_name TEXT,
        srs_id INTEGER,
        z INTEGER, m INTEGER,
        PRIMARY KEY (table_name, column_name)
      );
    ''');
    db.execute('''
      CREATE TABLE test_points (rowid INTEGER PRIMARY KEY, geom BLOB NOT NULL);
    ''');
    db.execute('''
      INSERT INTO gpkg_contents VALUES (
        'test_points', 'features', 'test_points', 'Test',
        datetime('now'), -180, -90, 180, 90, 4326
      );
    ''');
    db.execute('''
      INSERT INTO gpkg_geometry_columns VALUES (
        'test_points', 'geom', 'POINT', 4326, 0, 0
      );
    ''');
  } finally {
    db.dispose();
  }
}
