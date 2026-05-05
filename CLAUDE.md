# ShapeKit — instrukcje dla Claude Code

## Co to jest

Dart library do odczytu i zapisu wektorowych formatów geospatial (Shapefile, GeoPackage).
Aktualnie trwa **refaktoryzacja opisana w `REDESIGN_PLAN_v2.md`** — przeczytaj ten plik
przed rozpoczęciem jakiejkolwiek pracy.

---

## Aktualny stan plików (przed refaktoryzacją)

```
lib/shapekit.dart                              ← barrel file (public API)
lib/src/
  domain/
    entities/
      geometry/record.dart, point.dart, polyline.dart, polygon.dart
      shapefile_bounds.dart                    ← klasy Bounds / BoundsM / BoundsZ (ZOSTANĄ zastąpione)
      dbase_field.dart
    exceptions/
      shapefile_exception.dart                 ← FileNotFoundException tu dziedziczy po ShapefileException (BUG — do naprawy)
  data/
    models/shapefile_header.dart, shapefile_offset.dart
    repositories/dbase_repository.dart, shapefile_repository.dart,
                 shapefile_repository_extensions.dart, projection_repository.dart
    serializers/geometry_serializer.dart, geometry_deserializer.dart
  gpkg/
    gpkg_connection.dart                       ← 653 linie, 7 klas — do rozbicia
    gpkg_writer.dart
    wkb_decoder.dart, wkb_encoder.dart
    spatial_index.dart
    geo_feature.dart, feature_batch.dart, geometry_type.dart
    crs_transformer.dart                       ← DO USUNIĘCIA
    envelope_extensions.dart                   ← DO USUNIĘCIA
    gpkg_import.dart                           ← DO USUNIĘCIA
    gpkg_import_progress.dart                  ← DO USUNIĘCIA
```

---

## Hierarchia Bounds (istniejąca, do zunifikowania)

Plik `shapefile_bounds.dart` zawiera **trzy klasy** (nie jedną):

```dart
class Bounds          // 2D: minX, minY, maxX, maxY
class BoundsM extends Bounds   // + opcjonalne M (measure) values
class BoundsZ extends Bounds   // + Z (elevation) + opcjonalne M values
```

**Plan unifikacji (Step 1):** `Bounds` → `Envelope`, `BoundsM extends Envelope`,
`BoundsZ extends Envelope`. Nowy plik: `domain/entities/geometry/envelope.dart`.
`shapefile_bounds.dart` zostaje usunięty. `BoundsM` i `BoundsZ` przenoszą się do
`envelope.dart` z tą samą logiką.

---

## Zasady — czego NIE robić

### Zakres biblioteki (hard limits)
Poniższe rzeczy są **poza zakresem biblioteki**. Jeśli jakiś kod to robi lub
próbujesz to dodać — zatrzymaj się.

- **CRS reprojection** (`proj4dart`, transformacje współrzędnych między układami)
- **Import pipelines** (kopiowanie, reprojekcja, indeksowanie całych plików)
- **Auto-schema migration** (`ALTER TABLE`, dodawanie kolumn w locie)
- **PRAGMA manipulation** (zmiana journal_mode, synchronous itp. przez core API)
- **Envelope upgrade orchestration** (SQL UPDATE geometrii — może być w appce)
- **LOD table resolution** (wybór tabeli na podstawie zoom level)
- **Envelope optimization** (nadpisywanie headerów GPKG przez core API)

### Zasady kodu
- Brak `ALTER TABLE` w żadnym miejscu biblioteki
- Brak `upgradeGeometryEnvelopes()` w `GpkgReader` — orchestracja to appka
- `WkbDecoder.upgradeEnvelope()` **zostaje jako publiczne** — to czysty WKB codec
- Brak `buildSpatialIndex` jako parametru `close()` — caller buduje indeks osobno
- Brak parametru `lod` w query metodach — caller sam resolwuje nazwę tabeli
- Brak `ensureSpatialIndex()` w `GpkgReader` — caller używa `SpatialIndex.build()`
- `GpkgTableWriter.writeRow()` **nie filtruje** zarezerwowanych kolumn (`fid`, geomColumn)
  — caller jest odpowiedzialny za nie przekazywanie ich w `properties`. Próba wstawienia
  zduplikowanej kolumny lub PRIMARY KEY spowoduje SQLite error (celowe, fail fast).

---

## Zasady kodu (techniczne)

### SpatialIndex — krytyczne
`SpatialIndex.build()` **musi być `async` z `await`**:

```dart
// POPRAWNIE:
static Future<void> build(String path, ...) async {
  final db = sqlite3.sqlite3.open(path);
  try {
    await _buildDb(db, ...);  // await jest konieczne
  } finally {
    db.dispose();             // wykona się po zakończeniu Future
  }
}

// BŁĄD (finally wykona się przed zakończeniem Future):
static Future<void> build(String path, ...) {  // brak async
  final db = sqlite3.sqlite3.open(path);
  try {
    return _buildDb(db, ...); // brak await
  } finally {
    db.dispose();             // wykona się natychmiast!
  }
}
```

`SpatialIndex.exists()` i `SpatialIndex.isHealthy()` są synchroniczne — zawsze
dokumentuj je jako: "WARNING: synchronous file I/O — do not call on the Flutter
main isolate."

### SQL injection — sanityzacja identyfikatorów
Wszystkie identyfikatory SQL (nazwy tabel, kolumn) muszą przejść przez `_safeId()`
**przed** interpolacją do stringa SQL:

```dart
// POPRAWNIE:
final safeTable = _safeId(tableName);
db.execute('CREATE TABLE IF NOT EXISTS "$safeTable" ...');

// BŁĄD:
db.execute('CREATE TABLE IF NOT EXISTS $tableName ...');
```

### SQLite locking
Nie otwieraj drugiego połączenia write do pliku GPKG gdy pierwsze jest otwarte.
Przed wywołaniem `SpatialIndex.build()` (które otwiera własne połączenie R/W),
zamknij istniejący `GpkgReader`:

```dart
// POPRAWNIE:
final conn = GpkgReader.open(dest);
final tables = conn.listFeatureTables();
conn.close(); // zamknij PRZED build
for (final table in tables) {
  await SpatialIndex.build(dest, table);
}

// BŁĄD:
final conn = GpkgReader.open(dest);
for (final table in conn.listFeatureTables()) {
  await SpatialIndex.build(dest, table); // conn nadal otwarty → SQLITE_BUSY
}
conn.close();
```

---

## Nazewnictwo po refaktoryzacji

| Stara nazwa | Nowa nazwa |
|---|---|
| `GpkgConnection` | `GpkgReader` |
| `gpkg_connection.dart` | `gpkg_reader.dart` |
| `Bounds` | `Envelope` |
| `shapefile_bounds.dart` | `domain/entities/geometry/envelope.dart` |

**Step 0 to osobny git commit** — tylko rename, zero zmian logicznych.

---

## Hierarchia wyjątków (docelowa)

```
Exception
  ├─ ShapefileException          (base dla błędów shapefile)
  │    ├─ InvalidFormatException
  │    ├─ UnsupportedTypeException
  │    ├─ InvalidHeaderException
  │    ├─ InvalidBoundsException
  │    ├─ CorruptedDataException
  │    └─ ShapefileIOException
  │
  ├─ FileNotFoundException        (shared — NIE dziedziczy po ShapefileException)
  │
  └─ GpkgException(message, [cause])   (base dla błędów GeoPackage)
```

`FileNotFoundException` **nie dziedziczy po `ShapefileException`** — to aktualny bug
w `shapefile_exception.dart` który naprawiamy w Step 3.

---

## featureCount — usunięty celowo

`FeatureTableMetadata` **nie ma pola `featureCount`**. Było zawsze `-1` (zepsuty),
a naprawienie przez `COUNT(*)` spowalniało pobieranie metadanych przy dużych plikach.

Gdy potrzebujesz liczby rekordów: `conn.countFeatures('table_name')`. Caller płaci
koszt `COUNT(*)` świadomie.

---

## Kolejność implementacji

Szczegóły każdego kroku są w `REDESIGN_PLAN_v2.md`. Implementuj po kolei:

```
Step 0  → rename commit (GpkgConnection→GpkgReader, gpkg_connection→gpkg_reader)
Step 1  → Envelope w domain (Bounds→Envelope, BoundsM/BoundsZ extend Envelope)
Step 2  → nowe pliki typów gpkg (exceptions.dart, column_info.dart, raw_feature_batch.dart)
Step 3  → FileNotFoundException fix (standalone, nie extends ShapefileException)
Step 4  → refactor gpkg_reader.dart (slim down, detectCrs(table), usun lod/upgrade/pragma)
Step 5  → refactor gpkg_writer.dart (Envelope bounds param, fix SQL injection, no auto-migration)
Step 6  → wkb_decoder.dart (zostaw upgradeEnvelope jako public, usun tylko orchestrację)
Step 7  → spatial_index.dart (async fix, path-based public + db-based private)
Step 8  → usuń pliki out-of-scope
Step 9  → barrel file (shapekit.dart)
Step 10 → pubspec.yaml (usuń proj4dart)
```

Uruchom testy po każdym kroku. Testy pisze się przed Step 3 (nie przed Step 0).
