class GpkgException implements Exception {
  final String message;
  final Object? cause;

  GpkgException(this.message, [this.cause]);

  @override
  String toString() => cause != null ? 'GpkgException: $message\nCaused by: $cause' : 'GpkgException: $message';
}
