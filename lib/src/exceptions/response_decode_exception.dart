class ResponseDecodeException implements Exception {
  final String message;

  const ResponseDecodeException(this.message);

  @override
  String toString() {
    return 'ResponseDecodeException: $message';
  }
}
