class AuthorizationRequestException implements Exception {
  final String? error;

  const AuthorizationRequestException({
    this.error,
  });

  @override
  String toString() {
    var report = 'AuthorizationResponseException';

    final error = this.error;
    if (error != null) {
      report += ': $error';
    }

    return report;
  }
}
