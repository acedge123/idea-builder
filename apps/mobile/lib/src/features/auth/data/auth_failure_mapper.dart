import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/app_api_exception.dart';
import '../domain/auth_failure.dart';

AuthFailure mapAuthFailure(Object error) {
  if (error is AuthFailure) return error;
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is AuthRetryableFetchException) {
    return const AuthFailure(AuthFailureKind.network);
  }
  if (error is AuthException) {
    return AuthFailure(switch (error.code) {
      'user_already_exists' || 'email_exists' => AuthFailureKind.emailInUse,
      'invalid_credentials' => AuthFailureKind.invalidCredentials,
      'email_not_confirmed' => AuthFailureKind.emailUnconfirmed,
      'weak_password' => AuthFailureKind.weakPassword,
      'email_address_invalid' ||
      'email_address_not_authorized' => AuthFailureKind.invalidEmail,
      'over_email_send_rate_limit' ||
      'over_request_rate_limit' ||
      'over_sms_send_rate_limit' => AuthFailureKind.rateLimited,
      'session_expired' ||
      'session_not_found' ||
      'refresh_token_not_found' ||
      'refresh_token_already_used' ||
      'invalid_jwt' => AuthFailureKind.sessionExpired,
      'signup_disabled' ||
      'email_provider_disabled' => AuthFailureKind.signupUnavailable,
      'request_timeout' => AuthFailureKind.network,
      _ =>
        error.statusCode == '429'
            ? AuthFailureKind.rateLimited
            : AuthFailureKind.unknown,
    });
  }
  if (error is AppApiException) {
    return AuthFailure(switch (error.kind) {
      AppApiErrorKind.unauthorized => AuthFailureKind.sessionExpired,
      AppApiErrorKind.network => AuthFailureKind.network,
      _ => AuthFailureKind.unknown,
    });
  }
  return const AuthFailure(AuthFailureKind.unknown);
}
