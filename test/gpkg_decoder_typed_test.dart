import 'package:test/test.dart';
import 'package:shapekit/shapekit.dart';
import 'dart:typed_data';

void main() {
  group('WkbDecoder typed methods', () {
    test('decodePoint returns Point geometry', () {
      final wkb = WkbEncoder.encodePoint(10.0, 20.0);
      final point = WkbDecoder.decodePoint(wkb);

      expect(point, isNotNull);
      expect(point!.x, 10.0);
      expect(point.y, 20.0);
    });

    test('decodePoint returns null for non-point WKB', () {
      final wkb = WkbEncoder.encodeLineString([(0.0, 0.0), (1.0, 1.0)]);
      final point = WkbDecoder.decodePoint(wkb);
      expect(point, isNull);
    });

    test('decodePolyline returns Polyline geometry', () {
      final points = [(0.0, 0.0), (10.0, 10.0), (20.0, 0.0)];
      final wkb = WkbEncoder.encodeLineString(points);
      final polyline = WkbDecoder.decodePolyline(wkb);

      expect(polyline, isNotNull);
      expect(polyline!.numPoints, 3);
      expect(polyline.points[0].x, 0.0);
      expect(polyline.points[0].y, 0.0);
      expect(polyline.points[1].x, 10.0);
      expect(polyline.points[1].y, 10.0);
      expect(polyline.points[2].x, 20.0);
      expect(polyline.points[2].y, 0.0);
    });

    test('decodePolyline returns null for non-linestring WKB', () {
      final wkb = WkbEncoder.encodePoint(5.0, 5.0);
      final polyline = WkbDecoder.decodePolyline(wkb);
      expect(polyline, isNull);
    });

    test('decodePolygon returns Polygon geometry', () {
      final ring = [
        (0.0, 0.0),
        (10.0, 0.0),
        (10.0, 10.0),
        (0.0, 10.0),
        (0.0, 0.0),
      ];
      final wkb = WkbEncoder.encodePolygon(ring);
      final polygon = WkbDecoder.decodePolygon(wkb);

      expect(polygon, isNotNull);
      expect(polygon, isA<Polygon>());
      // 5 points (ring closed)
      expect(polygon!.numPoints, 5);
    });

    test('decodePolygon returns null for non-polygon WKB', () {
      final wkb = WkbEncoder.encodePoint(5.0, 5.0);
      final polygon = WkbDecoder.decodePolygon(wkb);
      expect(polygon, isNull);
    });

    test('decodeAsRecord dispatches Point correctly', () {
      final wkb = WkbEncoder.encodePoint(5.0, 5.0);
      final record = WkbDecoder.decodeAsRecord(wkb);

      expect(record, isA<Point>());
      final p = record as Point;
      expect(p.x, 5.0);
      expect(p.y, 5.0);
    });

    test('decodeAsRecord dispatches LineString correctly', () {
      final wkb = WkbEncoder.encodeLineString([(0.0, 0.0), (1.0, 1.0)]);
      final record = WkbDecoder.decodeAsRecord(wkb);

      expect(record, isA<Polyline>());
    });

    test('decodeAsRecord dispatches Polygon correctly', () {
      final wkb = WkbEncoder.encodePolygon([
        (0.0, 0.0),
        (10.0, 0.0),
        (10.0, 10.0),
        (0.0, 0.0),
      ]);
      final record = WkbDecoder.decodeAsRecord(wkb);

      expect(record, isA<Polygon>());
    });

    test('decodeAsRecord returns null for invalid blob', () {
      final record = WkbDecoder.decodeAsRecord(Uint8List(4));
      expect(record, isNull);
    });
  });

  group('WkbEncoder.encode(Record)', () {
    test('encodes Point', () {
      final point = Point(10.0, 20.0);
      final blob = WkbEncoder.encode(point);

      // Verify roundtrip
      final decoded = WkbDecoder.decodePoint(blob);
      expect(decoded, isNotNull);
      expect(decoded!.x, 10.0);
      expect(decoded.y, 20.0);
    });

    test('encodes Polyline', () {
      final polyline = Polyline(
        bounds: Envelope(0, 0, 10, 10),
        parts: [0],
        points: [Point(0, 0), Point(10, 10)],
      );
      final blob = WkbEncoder.encode(polyline);

      final decoded = WkbDecoder.decodePolyline(blob);
      expect(decoded, isNotNull);
      expect(decoded!.numPoints, 2);
    });

    test('encodes Polygon', () {
      final polygon = Polygon(
        bounds: Envelope(0, 0, 10, 10),
        parts: [0],
        points: [
          Point(0, 0),
          Point(10, 0),
          Point(10, 10),
          Point(0, 10),
          Point(0, 0),
        ],
      );
      final blob = WkbEncoder.encode(polygon);

      final decoded = WkbDecoder.decodePolygon(blob);
      expect(decoded, isNotNull);
      expect(decoded!.numPoints, 5);
    });

    test('encode handles MultiPoint', () {
      final multi = MultiPoint(
        points: [Point(0, 0), Point(10, 10)],
        bounds: Envelope(0, 0, 10, 10),
      );
      final blob = WkbEncoder.encode(multi);

      // MultiPoint encodes successfully
      expect(blob, isNotNull);
      expect(blob.length, greaterThan(8));
    });
  });

  group('GeometryType', () {
    test('fromWkbType categorizes correctly', () {
      expect(GeometryTypeExtension.fromWkbType(1), GeometryType.point);
      expect(GeometryTypeExtension.fromWkbType(4), GeometryType.point);
      expect(GeometryTypeExtension.fromWkbType(2), GeometryType.line);
      expect(GeometryTypeExtension.fromWkbType(5), GeometryType.line);
      expect(GeometryTypeExtension.fromWkbType(3), GeometryType.polygon);
      expect(GeometryTypeExtension.fromWkbType(6), GeometryType.polygon);
      expect(GeometryTypeExtension.fromWkbType(99), GeometryType.unknown);
    });

    test('fromString categorizes correctly', () {
      expect(GeometryTypeExtension.fromString('POINT'), GeometryType.point);
      expect(
          GeometryTypeExtension.fromString('LINESTRING'), GeometryType.line);
      expect(
          GeometryTypeExtension.fromString('MULTIPOLYGON'), GeometryType.polygon);
      expect(GeometryTypeExtension.fromString('GEOMETRY'), GeometryType.unknown);
    });
  });

  group('GeoFeature', () {
    test('type getter returns correct category', () {
      final pointFeature = GeoFeature(
        fid: 1,
        geometry: Point(0, 0),
      );
      expect(pointFeature.type, GeometryType.point);
      expect(pointFeature.isPoint, true);
      expect(pointFeature.isLine, false);
    });

    test('isLine excludes Polygon', () {
      final polygonFeature = GeoFeature(
        fid: 1,
        geometry: Polygon(
          bounds: Envelope(0, 0, 1, 1),
          parts: [0],
          points: [Point(0, 0), Point(1, 0), Point(1, 1), Point(0, 0)],
        ),
      );
      expect(polygonFeature.isLine, false);
      expect(polygonFeature.isPolygon, true);
    });
  });

  group('ShapeType convenience getters', () {
    test('isPoint alias works', () {
      expect(ShapeType.shapePOINT.isPoint, true);
      expect(ShapeType.shapePOLYLINE.isPoint, false);
    });

    test('isLine alias works', () {
      expect(ShapeType.shapePOLYLINE.isLine, true);
      expect(ShapeType.shapePOLYLINEM.isLine, true);
      expect(ShapeType.shapePOLYLINEZ.isLine, true);
      expect(ShapeType.shapePOINT.isLine, false);
    });

    test('isPolygon alias works', () {
      expect(ShapeType.shapePOLYGON.isPolygon, true);
      expect(ShapeType.shapePOLYGONM.isPolygon, true);
      expect(ShapeType.shapePOLYGONZ.isPolygon, true);
      expect(ShapeType.shapePOINT.isPolygon, false);
    });
  });
}
