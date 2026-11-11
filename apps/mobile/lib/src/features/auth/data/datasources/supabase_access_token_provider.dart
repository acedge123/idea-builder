import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/app_api_exception.dart';
import '../../../../core/logging/app_logger.dart';

/// Supabase v2 restores local sessions before refreshing expired access tokens.
/// Wait at the API boundary so protected reads/writes never use that stale token.
class SupabaseAccessTokenProvider {
  SupabaseAccessTokenProvider(
    this._auth, {
    this.refreshTimeout = const Duration(seconds: 20),
  });

  final GoTrueClient _auth;
  final Duration refreshTimeout;

  Future<String?> call() async {
    final initial = _auth.currentSession;
    if (initial == null) return null;
    if (!initial.isExpired) return initial.accessToken;

    const logger = AppLogger();
    logger.event('auth.api_refresh_started');
    try {
      // The SDK shares an in-flight refresh with startup recovery/other callers.
      await _auth.refreshSession().timeout(refreshTimeout);
    } on TimeoutException {
      logger.event('auth.api_refresh_failed', {'kind': 'timeout'});
      throw const AppApiException(
        kind: AppApiErrorKind.network,
        message: 'Sign-in refresh timed out. Please try again.',
      );
    } on AuthRetryableFetchException {
      logger.event('auth.api_refresh_failed', {'kind': 'network'});
      throw const AppApiException(
        kind: AppApiErrorKind.network,
        message: 'Could not refresh sign-in. Check your connection and retry.',
      );
    } on AuthException {
      logger.event('auth.api_refresh_failed', {'kind': 'unauthorized'});
      throw _signInRequired;
    }

    final refreshed = _auth.currentSession;
    // Do not send an old screen's operation under a newly switched account, or
    // adopt a refresh response that the SDK discarded after sign-out.
    if (refreshed == null ||
        refreshed.user.id != initial.user.id ||
        refreshed.isExpired) {
      logger.event('auth.api_refresh_discarded');
      throw _signInRequired;
    }
    logger.event('auth.api_refresh_ready');
    return refreshed.accessToken;
  }

  static const _signInRequired = AppApiException(
    kind: AppApiErrorKind.unauthorized,
    statusCode: 401,
    message: 'Please sign in again.',
  );
}
