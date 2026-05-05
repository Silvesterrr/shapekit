import 'dart:io';

import 'package:shapekit/shapekit.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('shapekit_stream_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('streams point geometries and DBF attributes like openAll', () async {
    final filePath = '${tempDir.path}/points.shp';
    final records = List.generate(25, (i) => Point(i.toDouble(), (i * 2).toDouble()));
    final fields = [DbaseField.fieldC('NAME', 20), DbaseField.fieldN('VALUE', 10)];
    final attributes = List.generate(25, (i) => ['Point $i', i]);

    Shapefile().writeComplete(
      filePath,
      ShapeType.shapePOINT,
      records,
      minX: 0,
      minY: 0,
      maxX: 24,
      maxY: 48,
      attributeFields: fields,
      attributeRecords: attributes,
    );

    final all = ShapefileExtensions.openAll(filePath, isUtf8: true);
    try {
      final stream = ShapefileStreamReader.open(filePath, isUtf8: true);
      final streamed = await stream.features().toList();

      expect(stream.recordCount, all.records.length);
      expect(stream.fields.map((field) => field.name), all.attributeFields.map((field) => field.name));
      expect(streamed.length, all.records.length);

      for (var i = 0; i < streamed.length; i++) {
        final expectedPoint = all.records[i] as Point;
        final streamedPoint = streamed[i].geometry as Point;
        expect(streamed[i].index, i);
        expect(streamedPoint.x, expectedPoint.x);
        expect(streamedPoint.y, expectedPoint.y);
        expect(streamed[i].attributes['NAME'], all.attributeRecords[i][0]);
        expect(streamed[i].attributes['VALUE'], all.attributeRecords[i][1]);
      }
    } finally {
      all.close();
    }
  });

  test('streams polygon records without materializing records list on reader', () async {
    final filePath = '${tempDir.path}/polygons.shp';
    final records = [
      Polygon(
        bounds: const Envelope(0, 0, 10, 10),
        parts: [0],
        points: [Point(0, 0), Point(10, 0), Point(10, 10), Point(0, 10), Point(0, 0)],
      ),
    ];

    Shapefile().writeComplete(filePath, ShapeType.shapePOLYGON, records, minX: 0, minY: 0, maxX: 10, maxY: 10);

    final stream = ShapefileStreamReader.open(filePath);
    final streamed = await stream.features().toList();

    expect(streamed, hasLength(1));
    expect(streamed.single.geometry, isA<Polygon>());
    expect((streamed.single.geometry as Polygon).numPoints, 5);
  });
}
