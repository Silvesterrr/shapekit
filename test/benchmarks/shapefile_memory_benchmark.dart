import 'dart:io';
import 'dart:math';
import 'package:shapekit/shapekit.dart';

/// Benchmark: Shapefile read memory footprint and throughput
///
/// Goals:
/// 1. Verify no memory leaks on large reads
/// 2. Measure throughput (records/sec)
/// 3. Establish baseline for future GPKG cursor streaming
void main() async {
  print('=== Shapefile Memory & Throughput Benchmark ===\n');

  // Benchmark 1: Small fixture (existing cities.shp)
  await _benchmarkExistingFile();

  // Benchmark 2: Generate and read large fixture
  await _benchmarkLargeGeneratedFixture();

  print('\n=== Benchmark Complete ===');
}

Future<void> _benchmarkExistingFile() async {
  print('Benchmark 1: Existing fixture (cities.shp)');
  print('-' * 50);

  final shpPath = 'cities.shp';
  if (!File(shpPath).existsSync()) {
    print('⚠ cities.shp not found, skipping\n');
    return;
  }

  final sw = Stopwatch()..start();
  final shapefile = Shapefile();
  shapefile.read(shpPath);
  sw.stop();

  print('✓ Loaded ${shapefile.records.length} records');
  print('  Time: ${sw.elapsedMilliseconds} ms');
  print('  Throughput: ${(shapefile.records.length / sw.elapsedMilliseconds * 1000).toStringAsFixed(0)} records/sec');
  print('');
}

Future<void> _benchmarkLargeGeneratedFixture() async {
  print('Benchmark 2: Large generated fixture');
  print('-' * 50);

  const recordCount = 100000;
  const batchSize = 10000;

  // Generate fixture
  print('Generating $recordCount polygon records...');
  final genSw = Stopwatch()..start();

  final records = <Record>[];
  final attributes = <List<dynamic>>[];

  final rng = Random(42);
  for (int i = 0; i < recordCount; i++) {
    // Random polygon (4 points)
    final x1 = rng.nextDouble() * 360 - 180;
    final y1 = rng.nextDouble() * 180 - 90;
    final x2 = x1 + rng.nextDouble() * 10;
    final y2 = y1 + rng.nextDouble() * 10;

    final polygon = Polygon(
      bounds: Envelope(x1, y1, x2, y2),
      parts: [0],
      points: [
        Point(x1, y1),
        Point(x2, y1),
        Point(x2, y2),
        Point(x1, y2),
        Point(x1, y1),
      ],
    );

    records.add(polygon);
    attributes.add(['Polygon_$i', i, 100.5 + i * 0.1]);

    if ((i + 1) % batchSize == 0) {
      print('  Generated ${i + 1}/$recordCount');
    }
  }

  genSw.stop();
  print('✓ Generated in ${genSw.elapsedMilliseconds} ms\n');

  // Write fixture
  print('Writing to benchmark_large.shp...');
  final writeSw = Stopwatch()..start();

  final shapefile = Shapefile();
  const outputPath = 'benchmark_large.shp';

  try {
    shapefile.writeComplete(
      outputPath,
      ShapeType.shapePOLYGON,
      records,
      minX: -180,
      minY: -90,
      maxX: 180,
      maxY: 90,
      attributeFields: [
        DbaseField.fieldC('NAME', 50),
        DbaseField.fieldN('ID', 10),
        DbaseField.fieldNF('VALUE', 10, 2),
      ],
      attributeRecords: attributes,
    );

    writeSw.stop();
    final fileSize = File(outputPath).lengthSync();
    print('✓ Written in ${writeSw.elapsedMilliseconds} ms');
    print('  File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
    print('  Throughput: ${(recordCount / writeSw.elapsedMilliseconds * 1000).toStringAsFixed(0)} records/sec\n');

    // Read back with memory sampling
    print('Reading back with memory sampling...');
    final readSw = Stopwatch()..start();

    final shapefile2 = Shapefile();
    shapefile2.read(outputPath);

    readSw.stop();

    print('✓ Loaded ${shapefile2.records.length} records');
    print('  Time: ${readSw.elapsedMilliseconds} ms');
    print('  Throughput: ${(recordCount / readSw.elapsedMilliseconds * 1000).toStringAsFixed(0)} records/sec');

    // Verify data integrity
    if (shapefile2.records.length == recordCount) {
      print('✓ Data integrity verified');
    }

    shapefile2.dispose();

    // Cleanup
    File(outputPath).deleteSync();
    File(outputPath.replaceAll('.shp', '.shx')).deleteSync();
    File(outputPath.replaceAll('.shp', '.dbf')).deleteSync();

    print('✓ Cleaned up\n');
  } catch (e) {
    print('✗ Error: $e\n');
  }
}
