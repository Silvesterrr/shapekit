import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:shapekit/src/domain/exceptions/shapefile_exception.dart' show FileNotFoundException;
import 'package:shapekit/src/gpkg/exceptions.dart';

/// Low-level connection to a GeoPackage (SQLite) file for raw SQL operations.
///
/// Unlike [GpkgReader] which provides typed domain-level queries, this class
/// exposes generic [select], [execute], and [transaction] primitives, useful
/// for reading/writing metadata tables (e.g. `layer_styles`) that are not part
/// of the GeoPackage core spec.
///
/// No types from `package:sqlite3` leak through the public API. Rows are
/// returned as plain `Map<String, Object?>` with SQLite primitives
/// (int, double, String, Uint8List, null).
class GpkgConnection {
  late final sqlite3.Database _db;
  final String path;
  final bool readOnly;
  bool _isClosed = false;

  GpkgConnection._(this.path, this.readOnly);

  /// Opens a GeoPackage file.
  ///
  /// When [readOnly] is true (default), opens via SQLite's `immutable=1` URI
  /// flag, identical to [GpkgReader.open].
  ///
  /// Throws [FileNotFoundException] if file doesn't exist.
  static GpkgConnection open(String path, {bool readOnly = true}) {
    if (!File(path).existsSync()) {
      throw FileNotFoundException(path);
    }

    final conn = GpkgConnection._(path, readOnly);
    if (readOnly) {
      final uri = 'file:${Uri.encodeFull(path.replaceAll(r'\', '/'))}?immutable=1';
      conn._db = sqlite3.sqlite3.open(uri, uri: true);
    } else {
      conn._db = sqlite3.sqlite3.open(path);
    }
    return conn;
  }

  /// Runs a raw SELECT and returns rows as plain maps.
  ///
  /// Parameters use `?` placeholders, bound from [params].
  /// Returned values are SQLite primitives (int, double, String, Uint8List, null).
  List<Map<String, Object?>> select(String sql, [List<Object?> params = const []]) {
    _checkClosed();
    final stmt = _db.prepare(sql);
    try {
      return stmt.select(params).map((row) => Map<String, Object?>.from(row)).toList();
    } finally {
      stmt.dispose();
    }
  }

  /// Runs a raw INSERT / UPDATE / DELETE / CREATE / etc.
  ///
  /// Throws [StateError] if this connection was opened read-only.
  void execute(String sql, [List<Object?> params = const []]) {
    _checkClosed();
    if (readOnly) {
      throw StateError('Cannot execute write statement on a read-only connection');
    }
    final stmt = _db.prepare(sql);
    try {
      stmt.execute(params);
    } finally {
      stmt.dispose();
    }
  }

  /// Returns true if a table named [name] exists in `sqlite_master`.
  bool hasTable(String name) {
    _checkClosed();
    final stmt = _db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name = ? LIMIT 1;");
    try {
      return stmt.select([name]).isNotEmpty;
    } finally {
      stmt.dispose();
    }
  }

  /// Runs [body] inside a transaction.
  ///
  /// Commits on success, rolls back on exception (re-thrown).
  T transaction<T>(T Function() body) {
    _checkClosed();
    if (readOnly) {
      throw StateError('Cannot start transaction on a read-only connection');
    }
    _db.execute('BEGIN');
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Closes the connection.
  void close() {
    if (!_isClosed) {
      _db.dispose();
      _isClosed = true;
    }
  }

  void _checkClosed() {
    if (_isClosed) {
      throw GpkgException('Connection is closed');
    }
  }
}
