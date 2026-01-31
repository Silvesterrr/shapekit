/// Represents a field definition in a dBASE file
///
/// Each field has a name, type, length, and optional decimal count.
/// Use the factory constructors to create fields of specific types.
///
/// ## Supported Field Types
///
/// - **C** (Character): Text strings up to 254 characters
/// - **D** (Date): Date values in YYYYMMDD format
/// - **L** (Logical): Boolean values (T/F)
/// - **N** (Numeric): Integer or floating point numbers
/// - **F** (Float): Floating point numbers (same as N with decimals)
class DbaseField {
  /// Creates a new DbaseField with default values
  DbaseField();

  String _name = '';

  String get name => _name;

  set name(String s) => _name = s.length > 11 ? s.substring(0, 11) : s;
  String type = '';
  int fieldLength = 0;
  int fieldCount = 0;
  int id = 0;
  int flag = 0;

  /// Creates a Character (text) field
  ///
  /// Parameters:
  /// - [nameC]: Field name (max 11 characters)
  /// - [length]: Maximum text length (default: 10, max: 254)
  ///
  /// Example:
  /// ```dart
  /// final nameField = DbaseField.fieldC('NAME', 50);
  /// ```
  factory DbaseField.fieldC(String nameC, [int length = 10]) => DbaseField()
    ..name = nameC
    ..type = 'C'
    ..fieldLength = length;

  /// Creates a Date field
  ///
  /// Stores dates in YYYYMMDD format (8 bytes).
  ///
  /// Parameters:
  /// - [nameD]: Field name (max 11 characters)
  ///
  /// Example:
  /// ```dart
  /// final dateField = DbaseField.fieldD('CREATED');
  /// ```
  factory DbaseField.fieldD(String nameD) => DbaseField()
    ..name = nameD
    ..type = 'D'
    ..fieldLength = 8;

  /// Creates a Logical (boolean) field
  ///
  /// Stores boolean values as 'T' (true) or 'F' (false).
  ///
  /// Parameters:
  /// - [nameL]: Field name (max 11 characters)
  ///
  /// Example:
  /// ```dart
  /// final activeField = DbaseField.fieldL('ACTIVE');
  /// ```
  factory DbaseField.fieldL(String nameL) => DbaseField()
    ..name = nameL
    ..type = 'L'
    ..fieldLength = 1;

  /// Creates a Numeric field for integers
  ///
  /// Parameters:
  /// - [nameN]: Field name (max 11 characters)
  /// - [length]: Total number of digits (default: 10)
  ///
  /// Example:
  /// ```dart
  /// final countField = DbaseField.fieldN('COUNT', 5);
  /// ```
  factory DbaseField.fieldN(String nameN, [int length = 10]) => DbaseField()
    ..name = nameN
    ..type = 'N'
    ..fieldLength = length;

  /// Creates a Numeric field for floating point numbers
  ///
  /// Parameters:
  /// - [nameN]: Field name (max 11 characters)
  /// - [length]: Total number of digits including decimal point (default: 20)
  /// - [count]: Number of decimal places (default: 8)
  ///
  /// Example:
  /// ```dart
  /// final areaField = DbaseField.fieldNF('AREA', 15, 6);
  /// ```
  factory DbaseField.fieldNF(String nameN, [int length = 20, int count = 8]) => DbaseField()
    ..name = nameN
    ..type = 'N'
    ..fieldLength = length
    ..fieldCount = count;

  @override
  String toString() => '{$name, $type, $fieldLength, $fieldCount, $id, $flag}';
}
