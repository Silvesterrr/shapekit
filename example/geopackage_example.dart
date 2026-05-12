import 'dart:io';

import 'package:shapekit/shapekit.dart';

Future<void> main() async {
  const path = 'cities.gpkg';

  await createGeoPackageExample(path);
  await readGeoPackageExample(path);
}

Future<void> createGeoPackageExample(String path) async {
  print('=== Writing GeoPackage Example ===\n');

  final file = File(path);
  if (file.existsSync()) {
    file.deleteSync();
  }

  GpkgWriter.initialize(path);
  GpkgWriter.addFeatureTable(
    path,
    'cities',
    geomType: 'POINT',
    bounds: const Envelope(126.7052, 35.1796, 129.0756, 37.5665),
    columns: const [
      ColumnDef.text('name'),
      ColumnDef.integer('population'),
      ColumnDef.real('area_km2'),
    ],
  );

  final writer = GpkgWriter.openTableWriter(path, 'cities');

  writer.writeFeature(Point(126.9780, 37.5665), {
    'name': 'Seoul',
    'population': 9776000,
    'area_km2': 605.21,
  });
  writer.writeFeature(Point(129.0756, 35.1796), {
    'name': 'Busan',
    'population': 3413000,
    'area_km2': 770.07,
  });
  writer.writeFeature(Point(126.7052, 37.4563), {
    'name': 'Incheon',
    'population': 2954000,
    'area_km2': 1062.60,
  });

  await writer.close();

  print('Created $path with 3 point features');
  print('Added a feature table with typed attribute columns\n');
}

Future<void> readGeoPackageExample(String path) async {
  print('=== Reading GeoPackage Example ===\n');

  final gpkg = GpkgReader.open(path);

  try {
    final tables = gpkg.listFeatureTables();
    print('Feature tables: $tables');

    if (tables.isEmpty) {
      print('No feature tables found.');
      return;
    }

    final table = tables.first;
    final metadata = gpkg.getTableMetadata(table);

    print('Using table: $table');
    print('Geometry column: ${metadata?.geometryColumn}');
    print('Geometry type: ${metadata?.geometryType}');
    print('Bounds: ${metadata?.bounds}\n');

    await for (final batch in gpkg.queryFeatures(
      table: table,
      bounds: const Envelope(120, 30, 130, 40),
      loadAttributes: true,
      batchSize: 2,
    )) {
      print('Batch size: ${batch.length}');

      for (final feature in batch.features) {
        final point = feature.geometry as Point;
        print(
          '  fid=${feature.fid} '
          'point=(${point.x}, ${point.y}) '
          'attrs=${feature.attributes}',
        );
      }
    }

    print('');
  } on GpkgException catch (e) {
    print('GeoPackage error: $e');
  } finally {
    gpkg.close();
  }
}
