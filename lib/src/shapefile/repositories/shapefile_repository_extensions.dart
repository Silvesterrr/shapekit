import 'package:shapekit/src/shapefile/repositories/shapefile_repository.dart';

extension ShapefileExtensions on Shapefile {
  /// Opens and reads all components of a shapefile in one call
  ///
  /// Combines [open], [readSHX], [readSHP], [readDBF], and [readPRJ].
  static Shapefile openAll(String path, {bool isUtf8 = true}) {
    final reader = Shapefile(isUtf8: isUtf8);
    reader.open(path);
    reader.readSHX();
    reader.readSHP();
    reader.readDBF();
    reader.readPRJ();
    return reader;
  }
}
