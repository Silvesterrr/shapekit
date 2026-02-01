## 0.2.1

### Breaking Changes
- **Optional M values**: M (measure) values are now optional per ESRI shapefile spec
  - `BoundsM`: `minM` and `maxM` are now nullable (`double?`)
  - `BoundsZ`: `minM` and `maxM` are now nullable (`double?`)
  - `PolylineM`, `PolygonM`, `MultiPointM`: `arrayM` is now nullable (`List<double>?`)
  - `PolylineZ`, `PolygonZ`, `MultiPointZ`: `arrayM` is now nullable (`List<double>?`)
  - Added `hasM` getter to check if M values are present
  - Note: `PointM` and `PointZ` still require M values (not optional for single points)
- **BoundsZ constructor order changed**: Z values now come before optional M values
  - Old: `BoundsZ(minX, minY, maxX, maxY, minM, maxM, minZ, maxZ)`
  - New: `BoundsZ(minX, minY, maxX, maxY, minZ, maxZ, [minM, maxM])`

### Fixes
- Relaxed `meta` dependency constraint (`^1.15.0`) for Flutter SDK compatibility
- Updated README examples to use new API (`read()`, `writeComplete()`)
- Clarified MultiPatch is not yet implemented

## 0.2.0

### Breaking Changes
- **Error handling refactored**: Methods no longer return `bool` for success/failure
  - `reader()` → `read()` (now returns `void`, throws on error)
  - `writer()` → `write()` (now returns `void`, throws on error)
  - `writerEntirety()` → `writeComplete()` (now returns `void`, throws on error)
  - `analysis()` → `analyze()` (now returns `void`, throws on error)
- All I/O methods now throw `ShapefileException` subclasses instead of returning `false`
- Changed `PointZ` constructor parameter order for consistency
- Removed `minM`/`maxM` parameters from methods - now using proper `BoundsM` classes
- Changed type dependencies to immutable

### Improvements
- Switched bounds to use multiple classes (`Bounds`, `BoundsM`, `BoundsZ`) for type safety
- Implemented MultiPoint, MultiPointM, and MultiPointZ in `analyze()` method
- Reordered `analyze()` method cases for cleaner code organization
- Improved test coverage for all geometry types (PointM, PolylineM/Z, PolygonM/Z)
- Cleaned up duplicate tests and improved test organization
- Added 120-character line width formatting rule in `analysis_options.yaml`
- Minor README fixes
- Various bug fixes

### Migration Guide
```dart
// Before (0.1.0)
if (shapefile.reader('path.shp')) {
  // success
} else {
  // error
}

// After (0.2.0)
try {
  shapefile.read('path.shp');
  // success
} on ShapefileException catch (e) {
  // error handling
}
```

## 0.1.0

- Initial release of ShapeKit
- Complete support for reading and writing ESRI Shapefiles (.shp, .shx, .dbf, .prj)
- Support for all 13 standard shapefile geometry types
- Full dBASE III+ (.dbf) file support for feature attributes
- UTF-8 encoding support
- Type-safe geometry classes with immutable data structures
- Clean architecture with well-organized codebase
