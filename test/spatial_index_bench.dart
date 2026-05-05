// Benchmark harness for SpatialIndex.build.
//
// Run with a real GPKG:
//   BENCH_GPKG=/path/to/file.gpkg dart test test/spatial_index_bench.dart
//
// Outputs a summary line per table and a final total:
//   TABLE <name>: build=Xs, rows=N, rate=N rows/s, headers=N/N
//   TOTAL: build=Xs, rows=N, rate=N rows/s
//
// Skips automatically (exit 0) when BENCH_GPKG is not set, so CI is unaffected.

import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:shapekit/src/gpkg/spatial_index.dart';
import 'package:shapekit/src/gpkg/codec/wkb_decoder.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final benchPath = Platform.environment['BENCH_GPKG'];

  if (benchPath == null) {
    test('skip: BENCH_GPKG not set', () {}, skip: 'Set BENCH_GPKG to run');
    return;
  }

  test('SpatialIndex.build throughput — all tables', () async {
    final file = File(benchPath);
    if (!file.existsSync()) {
      fail('BENCH_GPKG file not found: $benchPath');
    }

    var db = sqlite3.open(benchPath);
    final tables = db
        .select("SELECT table_name FROM gpkg_contents WHERE data_type = 'features'")
        .map((r) => r['table_name'] as String)
        .toList();

    if (tables.isEmpty) {
      db.dispose();
      fail('No feature tables in $benchPath');
    }

    // ignore: avoid_print
    print('\nBenchmarking all ${tables.length} tables in $benchPath');

    var totalRows = 0;
    var totalMs = 0;

    for (final table in tables) {
      final geomCol = _geomCol(db, table);
      final rowCount =
          db.select('SELECT COUNT(*) as c FROM "$table"').first['c'] as int;

      final (headerHits, noHeader) = _sampleEnvelopeStats(db, table, geomCol);
      final sampleTotal = headerHits + noHeader;
      final headerPct = sampleTotal > 0 ? (headerHits * 100 ~/ sampleTotal) : 0;

      // Drop existing R-Tree so build runs from scratch.
      final rtreeName = 'rtree_${table}_$geomCol';
      try {
        db.execute('DROP TABLE IF EXISTS "$rtreeName"');
      } catch (_) {}

      // Close before path-based build (SpatialIndex.build opens its own connection).
      db.dispose();

      final sw = Stopwatch()..start();
      await SpatialIndex.build(benchPath, table, geomColumn: geomCol);
      sw.stop();

      // Re-open for next iteration.
      db = sqlite3.open(benchPath);

      final ms = sw.elapsedMilliseconds;
      final rate = ms > 0 ? (rowCount * 1000 ~/ ms) : 0;

      // ignore: avoid_print
      print('  TABLE $table: build=${(ms / 1000).toStringAsFixed(2)}s '
          'rows=$rowCount rate=$rate rows/s headers=$headerPct%');

      totalRows += rowCount;
      totalMs += ms;
    }

    final totalRate = totalMs > 0 ? (totalRows * 1000 ~/ totalMs) : 0;
    // ignore: avoid_print
    print('TOTAL: build=${(totalMs / 1000).toStringAsFixed(1)}s '
        'rows=$totalRows rate=$totalRate rows/s');

    db.dispose();
  }, timeout: const Timeout(Duration(hours: 2)));
}

(int headerHits, int noHeader) _sampleEnvelopeStats(
    Database db, String table, String geomCol) {
  var hits = 0;
  var misses = 0;
  const sampleSize = 1000;

  try {
    final stmt = db.prepare(
        'SELECT "$geomCol" FROM "$table" ORDER BY rowid LIMIT $sampleSize');
    for (final row in stmt.select([])) {
      final blob = row[geomCol];
      if (blob is Uint8List) {
        if (WkbDecoder.extractEnvelope(blob) != null) {
          hits++;
        } else {
          misses++;
        }
      } else if (blob is List) {
        final u = Uint8List.fromList(blob.cast<int>());
        if (WkbDecoder.extractEnvelope(u) != null) {
          hits++;
        } else {
          misses++;
        }
      }
    }
    stmt.dispose();
  } catch (_) {}

  return (hits, misses);
}

String _geomCol(Database db, String table) {
  try {
    final stmt = db.prepare(
        'SELECT column_name FROM gpkg_geometry_columns WHERE table_name = ?');
    final row = stmt.select([table]).firstOrNull;
    stmt.dispose();
    return row?['column_name'] as String? ?? 'geom';
  } catch (_) {
    return 'geom';
  }
}
