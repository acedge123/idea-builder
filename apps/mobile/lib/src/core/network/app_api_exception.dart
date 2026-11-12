enum AppApiErrorKind {
  unauthorized,
  forbidden,
  invalidInput,
  upstream,
  network,
  internal,
  unknown,
}

class AppApiException implements Exception {
  const AppApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
  });

  final AppApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;

  bool get isAuthRelated =>
      kind == AppApiErrorKind.unauthorized || kind == AppApiErrorKind.forbidden;

  @override
  String toString() =>
      'AppApiException(kind: $kind, statusCode: $statusCode, message: $message)';
}
