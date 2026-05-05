import 'dart:typed_data';

/// A batch of raw features returned by [GpkgReader.queryFeaturesInBounds].
///
/// Contains feature IDs, WKB geometry blobs, and optionally attribute values
/// when called with [loadAttributes] = true.
class RawFeatureBatch {
  final List<int> fids;
  final List<Uint8List> geoms;
  final int generation;
  final List<Map<String, dynamic>>? attributes;

  RawFeatureBatch({required this.fids, required this.geoms, required this.generation, this.attributes});

  bool get hasAttributes => attributes != null;
}
