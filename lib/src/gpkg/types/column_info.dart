import 'package:shapekit/src/domain/entities/geometry/envelope.dart';

/// Column definition for explicit schema in [GpkgWriter.addFeatureTable].
class ColumnDef {
  final String name;
  final String sqlType;

  const ColumnDef.text(this.name) : sqlType = 'TEXT';
  const ColumnDef.integer(this.name) : sqlType = 'INTEGER';
  const ColumnDef.real(this.name) : sqlType = 'REAL';
  const ColumnDef.blob(this.name) : sqlType = 'BLOB';
}

/// Metadata about a table column discovered via PRAGMA table_info.
class ColumnInfo {
  final String name;
  final String? type;
  final bool notNull;
  final Object? defaultValue;

  const ColumnInfo({required this.name, this.type, required this.notNull, this.defaultValue});
}

/// Metadata about a feature table.
///
/// Does not include feature count — call [GpkgReader.countFeatures] explicitly
/// when you need it (COUNT(*) can be expensive on large tables).
class FeatureTableMetadata {
  final String tableName;
  final String? identifier;
  final String? description;
  final String geometryColumn;
  final String geometryType;
  final Envelope? bounds;
  final List<ColumnInfo> attributeColumns;

  FeatureTableMetadata({
    required this.tableName,
    required this.identifier,
    required this.description,
    required this.geometryColumn,
    required this.geometryType,
    this.bounds,
    this.attributeColumns = const [],
  });
}

/// CRS information extracted from a GeoPackage's spatial reference system table.
class CrsInfo {
  final int srsId;
  final String? organization;
  final int? epsgCode;
  final String? definition;

  CrsInfo({required this.srsId, this.organization, this.epsgCode, this.definition});
}
