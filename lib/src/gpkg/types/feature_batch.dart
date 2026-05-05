import 'package:shapekit/src/gpkg/types/geo_feature.dart';

/// A batch of decoded features from a spatial query
///
/// Batching allows streaming large datasets without OOM.
class FeatureBatch {
  final List<GeoFeature> features;
  final int generation;
  final String tableName;

  const FeatureBatch({required this.features, required this.generation, required this.tableName});

  int get length => features.length;
  bool get isEmpty => features.isEmpty;
  bool get isNotEmpty => features.isNotEmpty;
}
