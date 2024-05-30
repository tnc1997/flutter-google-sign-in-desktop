class DateHeaderParseException implements Exception {
  final String message;

  const DateHeaderParseException(this.message);

  @override
  String toString() {
    return 'DateHeaderParseException: $message';
  }
}
