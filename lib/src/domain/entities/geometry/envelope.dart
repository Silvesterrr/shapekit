/// Axis-aligned bounding box shared across all format implementations.
///
/// Used for shapefile header bounds and feature table metadata.
class Envelope {
  final double minX, minY, maxX, maxY;

  const Envelope(this.minX, this.minY, this.maxX, this.maxY);
  const Envelope.zero() : this(0.0, 0.0, 0.0, 0.0);

  bool intersects(Envelope o) => maxX >= o.minX && minX <= o.maxX && maxY >= o.minY && minY <= o.maxY;

  @override
  String toString() => 'Envelope($minX, $minY, $maxX, $maxY)';

  @override
  bool operator ==(Object other) =>
      other is Envelope && minX == other.minX && minY == other.minY && maxX == other.maxX && maxY == other.maxY;

  @override
  int get hashCode => Object.hash(minX, minY, maxX, maxY);
}

/// Bounding box with optional M (measure) values.
///
/// M values are optional per ESRI spec.
class EnvelopeM extends Envelope {
  const EnvelopeM(super.minX, super.minY, super.maxX, super.maxY, [this.minM, this.maxM]);

  final double? minM;
  final double? maxM;

  bool get hasM => minM != null && maxM != null;

  @override
  String toString() {
    final mPart = hasM ? ', minM($minM), maxM($maxM)' : '';
    return 'Envelope($minX, $minY, $maxX, $maxY)$mPart';
  }
}

/// Bounding box with Z coordinates and optional M values.
///
/// Z values are always present. M values are optional per ESRI spec.
class EnvelopeZ extends Envelope {
  const EnvelopeZ(super.minX, super.minY, super.maxX, super.maxY, this.minZ, this.maxZ, [this.minM, this.maxM]);

  final double minZ;
  final double maxZ;
  final double? minM;
  final double? maxM;

  bool get hasM => minM != null && maxM != null;

  @override
  String toString() {
    final mPart = hasM ? ', minM($minM), maxM($maxM)' : '';
    return 'Envelope($minX, $minY, $maxX, $maxY, minZ($minZ), maxZ($maxZ))$mPart';
  }
}
