import 'dart:typed_data';
import 'package:sqlite3/sqlite3.dart';
import 'package:shapekit/src/gpkg/codec/wkb_decoder.dart';

void main() {
  final db = sqlite3.open(
    r'C:\Users\Nth\Inspection\logs+maps\maps 2.0.3\czech-republic.gpkg',
    mode: OpenMode.readOnly,
  );

  // Sample from buildings (5M polygon features)
  final table = 'gis_osm_buildings_a_free';
  final stmt = db.prepare('SELECT rowid, geom FROM "$table" LIMIT 10');

  print('Sample rows from $table:');
  for (final row in stmt.select([])) {
    final blob = row['geom'] as Uint8List?;
    if (blob == null) {
      print('  rowid=${row['rowid']}: null blob');
      continue;
    }

    // Show first 12 bytes of header
    final header = blob.take(12).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final flags = blob.length >= 4 ? blob[3] : 0;
    final envelopeIndicator = (flags >> 1) & 0x07;
    final headerSize = _headerSize(blob);

    // WKB geomType
    int? geomType;
    if (blob.length > headerSize + 5) {
      final bd = ByteData.sublistView(blob);
      final byteOrder = bd.getUint8(headerSize);
      final endian = byteOrder == 0x01 ? Endian.little : Endian.big;
      geomType = bd.getUint32(headerSize + 1, endian);
    }

    final env = WkbDecoder.extractEnvelope(blob);
    final coords = WkbDecoder.decode(blob);

    print('  rowid=${row['rowid']}: len=${blob.length}, '
        'flags=0x${flags.toRadixString(16)}, envIndicator=$envelopeIndicator, '
        'headerSize=$headerSize, wkbType=$geomType, '
        'hasEnv=${env != null}, coordsLen=${coords?.length}');
    print('    header: $header');
  }
  stmt.dispose();
  db.dispose();
}

int _headerSize(Uint8List bytes) {
  final flags = bytes[3];
  final envelopeIndicator = (flags >> 1) & 0x07;
  int size = 8;
  switch (envelopeIndicator) {
    case 1: size += 32; break;
    case 2: size += 48; break;
    case 3: size += 48; break;
    case 4: size += 64; break;
  }
  return size;
}
