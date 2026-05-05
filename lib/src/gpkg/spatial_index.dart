import 'dart:typed_data';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:shapekit/src/gpkg/codec/wkb_decoder.dart';

class SpatialIndex {
  /// Build the R-tree spatial index for [tableName] in the GeoPackage at [path].
  ///
  /// Opens its own read/write connection — caller must ensure no other write
  /// connection to [path] is open (close any [GpkgReader] first to avoid
  /// SQLITE_BUSY).
  ///
  /// If the R-tree virtual table already exists AND is populated (row count > 0),
  /// this is a no-op — pass [force] to rebuild anyway.
  ///
  /// **Durability:** for bulk speed, the build sets `journal_mode=OFF` and
  /// `synchronous=OFF` for the duration of the call. A power-loss or crash
  /// mid-build leaves the destination GPKG corrupt — callers are expected to
  /// be operating on a temporary import target and recover by deleting and
  /// re-importing.
  static Future<void> build(
    String path,
    String tableName, {
    String geomColumn = 'geom',
    bool force = false,
    void Function(int rowsDone, int rowsTotal)? onProgress,
  }) async {
    final db = sqlite3.sqlite3.open(path);
    try {
      await _buildDb(db, tableName, geomColumn: geomColumn, force: force, onProgress: onProgress);
    } finally {
      db.dispose(); // wykona się PO zakończeniu Future dzięki await
    }
  }

  /// Returns true if the R-tree index for [tableName] exists.
  ///
  /// WARNING: synchronous file I/O — do not call on the Flutter main isolate.
  static bool exists(String path, String tableName, {String geomColumn = 'geom'}) {
    final db = sqlite3.sqlite3.open(path);
    try {
      return _existsDb(db, tableName, geomColumn: geomColumn);
    } finally {
      db.dispose();
    }
  }

  /// Returns true if the R-tree exists and can serve at least one row without
  /// a SQLite corruption error. Reads exactly one entry (LIMIT 1) — O(1).
  ///
  /// WARNING: synchronous file I/O — do not call on the Flutter main isolate.
  static bool isHealthy(String path, String tableName, {String geomColumn = 'geom'}) {
    final db = sqlite3.sqlite3.open(path);
    try {
      return _isHealthyDb(db, tableName, geomColumn: geomColumn);
    } finally {
      db.dispose();
    }
  }

  static Future<void> _buildDb(
    sqlite3.Database db,
    String tableName, {
    String geomColumn = 'geom',
    int rowsPerStatement = 200,
    int progressIntervalRows = 50000,
    bool force = false,
    void Function(int rowsDone, int rowsTotal)? onProgress,
  }) async {
    final rtreeName = 'rtree_${tableName}_$geomColumn';

    if (force) {
      db.execute('DROP TABLE IF EXISTS $rtreeName');
      db.execute('CREATE VIRTUAL TABLE $rtreeName USING rtree(id, minx, maxx, miny, maxy)');
    } else {
      db.execute('CREATE VIRTUAL TABLE IF NOT EXISTS $rtreeName USING rtree(id, minx, maxx, miny, maxy)');
      if (_rowCount(db, rtreeName) > 0) {
        return; // Already populated by source GPKG — trust it.
      }
    }

    final total = db.select('SELECT COUNT(*) as c FROM $tableName').first['c'] as int;

    final savedJournal = _pragmaValue(db, 'journal_mode');
    final savedSync = _pragmaValue(db, 'synchronous');
    final savedLocking = _pragmaValue(db, 'locking_mode');

    db.execute('PRAGMA journal_mode = OFF');
    db.execute('PRAGMA synchronous = OFF');
    db.execute('PRAGMA temp_store = MEMORY');
    db.execute('PRAGMA cache_size = -65536');
    db.execute('PRAGMA locking_mode = EXCLUSIVE');

    final selectStmt = db.prepare('SELECT rowid as id, $geomColumn FROM $tableName;');
    final fullChunkStmt = db.prepare(_buildMultiInsert(rtreeName, rowsPerStatement));

    var inTransaction = false;
    try {
      db.execute('BEGIN TRANSACTION');
      inTransaction = true;

      // Cursor is closed implicitly when selectStmt is disposed in finally.
      final cursor = selectStmt.selectCursor([]);
      final chunk = <Object?>[];
      var chunkRows = 0;
      var rowsDone = 0;
      var rowsSinceProgress = 0;

      while (cursor.moveNext()) {
        final row = cursor.current;
        final id = row['id'] as int;
        final blob = row[geomColumn] as Uint8List?;

        if (blob == null) continue;

        final env = WkbDecoder.extractEnvelope(blob) ?? _bboxFromCoords(WkbDecoder.decode(blob));
        if (env == null) continue;

        chunk.addAll([id, env.minX, env.maxX, env.minY, env.maxY]);
        chunkRows++;

        if (chunkRows >= rowsPerStatement) {
          fullChunkStmt.execute(chunk);
          rowsDone += chunkRows;
          rowsSinceProgress += chunkRows;
          chunk.clear();
          chunkRows = 0;
          if (rowsSinceProgress >= progressIntervalRows) {
            onProgress?.call(rowsDone, total);
            rowsSinceProgress = 0;
          }
        }
      }

      if (chunkRows > 0) {
        final lastStmt = db.prepare(_buildMultiInsert(rtreeName, chunkRows));
        try {
          lastStmt.execute(chunk);
        } finally {
          lastStmt.dispose();
        }
        rowsDone += chunkRows;
      }

      db.execute('COMMIT');
      inTransaction = false;
      onProgress?.call(rowsDone, total);
    } finally {
      if (inTransaction) {
        try {
          db.execute('ROLLBACK');
        } catch (_) {
          // Best effort — connection may already be in error state.
        }
      }
      fullChunkStmt.dispose();
      selectStmt.dispose();

      _restorePragma(db, 'locking_mode', savedLocking);
      _restorePragma(db, 'synchronous', savedSync);
      _restorePragma(db, 'journal_mode', savedJournal);
    }
  }

  static bool _existsDb(sqlite3.Database db, String tableName, {String geomColumn = 'geom'}) {
    final rtreeName = 'rtree_${tableName}_$geomColumn';
    final stmt = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name = ?;");
    try {
      return stmt.select([rtreeName]).isNotEmpty;
    } catch (_) {
      return false;
    } finally {
      stmt.dispose();
    }
  }

  static bool _isHealthyDb(sqlite3.Database db, String tableName, {String geomColumn = 'geom'}) {
    final rtreeName = 'rtree_${tableName}_$geomColumn';
    try {
      db.select('SELECT id FROM $rtreeName LIMIT 1');
      return true;
    } on sqlite3.SqliteException catch (e) {
      // SQLITE_CORRUPT (11) and SQLITE_CORRUPT_VTAB (267) = R-Tree undersize blobs.
      // Transient errors (BUSY=5, LOCKED=6) propagate so callers see them.
      if (e.resultCode == 11 || e.extendedResultCode == 267) return false;
      rethrow;
    }
  }

  static String _buildMultiInsert(String rtreeName, int rows) {
    final values = StringBuffer('(?, ?, ?, ?, ?)');
    for (var i = 1; i < rows; i++) {
      values.write(', (?, ?, ?, ?, ?)');
    }
    return 'INSERT INTO $rtreeName (id, minx, maxx, miny, maxy) VALUES $values;';
  }

  static String? _pragmaValue(sqlite3.Database db, String name) {
    try {
      final result = db.select('PRAGMA $name');
      if (result.isEmpty) return null;
      final v = result.first.values.first;
      return v?.toString();
    } catch (_) {
      return null;
    }
  }

  static void _restorePragma(sqlite3.Database db, String name, String? value) {
    if (value == null) return;
    try {
      db.execute('PRAGMA $name = $value');
    } catch (_) {
      // Best effort — some pragmas reject the round-trip value.
    }
  }

  static int _rowCount(sqlite3.Database db, String rtreeName) {
    try {
      final result = db.select('SELECT COUNT(*) as cnt FROM $rtreeName');
      return result.first['cnt'] as int;
    } catch (_) {
      return 0;
    }
  }

  static ({double minX, double minY, double maxX, double maxY})? _bboxFromCoords(Float32List? coords) {
    if (coords == null || coords.length < 2) return null;
    var minX = coords[0], maxX = coords[0];
    var minY = coords[1], maxY = coords[1];
    for (int i = 2; i < coords.length; i += 2) {
      if (coords[i] < minX) minX = coords[i];
      if (coords[i] > maxX) maxX = coords[i];
      if (coords[i + 1] < minY) minY = coords[i + 1];
      if (coords[i + 1] > maxY) maxY = coords[i + 1];
    }
    return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }
}
