/// Main test file for ShapeKit library
///
/// This file imports all test suites to provide comprehensive coverage.
/// Run with: dart test
library;

import 'package:test/test.dart';

// Geometry tests
import 'geometry/point_test.dart' as point_tests;
import 'geometry/polyline_test.dart' as polyline_tests;
import 'geometry/polygon_test.dart' as polygon_tests;

// I/O tests
import 'io/shapefile_read_test.dart' as read_tests;
import 'io/shapefile_write_test.dart' as write_tests;
import 'io/dbase_test.dart' as dbase_tests;

// Encoding tests
import 'encoding/text_encoding_test.dart' as encoding_tests;

// Exception tests
import 'exceptions/error_handling_test.dart' as exception_tests;

// Integration tests
import 'integration/end_to_end_test.dart' as integration_tests;

void main() {
  group('ShapeKit Library Tests', () {
    group('Geometry Tests', () {
      group('Point Tests', point_tests.main);
      group('Polyline Tests', polyline_tests.main);
      group('Polygon Tests', polygon_tests.main);
    });

    group('I/O Tests', () {
      group('Shapefile Read Tests', read_tests.main);
      group('Shapefile Write Tests', write_tests.main);
      group('DBase Tests', dbase_tests.main);
    });

    group('Encoding Tests', () {
      group('Text Encoding Tests', encoding_tests.main);
    });

    group('Exception Tests', () {
      group('Error Handling Tests', exception_tests.main);
    });

    group('Integration Tests', () {
      group('End-to-End Tests', integration_tests.main);
    });
  });
}
