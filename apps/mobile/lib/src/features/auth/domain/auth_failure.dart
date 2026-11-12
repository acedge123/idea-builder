enum AuthFailureKind {
  emailInUse,
  invalidCredentials,
  emailUnconfirmed,
  weakPassword,
  invalidEmail,
  rateLimited,
  network,
  sessionExpired,
  signupUnavailable,
  unknown,
}

/// Only controlled product copy crosses the auth boundary into presentation.
class AuthFailure implements Exception {
  const AuthFailure(this.kind);
  final AuthFailureKind kind;
  String get message => switch (kind) {
    AuthFailureKind.emailInUse =>
      'That email already has an account. Sign in instead?',
    AuthFailureKind.invalidCredentials =>
      'The email or password is incorrect. Please try again.',
    AuthFailureKind.emailUnconfirmed =>
      'Confirm your email before signing in. Check your inbox and spam folder.',
    AuthFailureKind.weakPassword =>
      'Choose a stronger password. Try a longer mix of letters, numbers and symbols.',
    AuthFailureKind.invalidEmail => 'Enter a valid email address.',
    AuthFailureKind.rateLimited =>
      'Too many attempts. Wait a few minutes and try again.',
    AuthFailureKind.network =>
      'We couldn’t connect. Check your internet connection and try again.',
    AuthFailureKind.sessionExpired =>
      'Your session has expired. Sign in again to continue.',
    AuthFailureKind.signupUnavailable =>
      'New accounts aren’t available right now. Please try again later.',
    AuthFailureKind.unknown => 'Something went wrong. Please try again.',
  };
  @override
  String toString() => 'AuthFailure(${kind.name})';
}
