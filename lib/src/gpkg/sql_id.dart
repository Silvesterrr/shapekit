/// Escapes a SQL identifier (table or column name) for safe interpolation
/// inside double-quoted identifiers.
///
/// Caller MUST wrap the result in double quotes:
///
///   db.prepare('SELECT * FROM "${safeSqlId(table)}"');
///
/// Used by [GpkgReader] when querying tables/columns whose names come from
/// user input or from `gpkg_contents`. Escaping (vs. stripping) preserves the
/// original identifier so the query still matches the existing table.
///
/// [GpkgWriter] uses its own stricter sanitization (strip rather than escape)
/// because it normalizes user input before CREATE TABLE.
String safeSqlId(String id) => id.replaceAll('"', '""');
