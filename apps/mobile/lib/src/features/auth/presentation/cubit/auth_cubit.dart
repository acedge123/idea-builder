import '../../domain/auth_failure.dart';
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

enum AuthSubmissionStatus {
  idle,
  submitting,
  success,
  emailConfirmationRequired,
  failure,
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.submissionStatus = AuthSubmissionStatus.idle,
    this.errorMessage,
    this.failureKind,
    this.infoMessage,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.authenticated(AuthUser user)
    : this(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final AuthUser? user;
  final AuthSubmissionStatus submissionStatus;
  final String? errorMessage;
  final AuthFailureKind? failureKind;
  final String? infoMessage;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool clearUser = false,
    AuthSubmissionStatus? submissionStatus,
    String? errorMessage,
    AuthFailureKind? failureKind,
    bool clearErrorMessage = false,
    String? infoMessage,
    bool clearInfoMessage = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      failureKind: clearErrorMessage ? null : failureKind ?? this.failureKind,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      infoMessage: clearInfoMessage ? null : infoMessage ?? this.infoMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    user,
    submissionStatus,
    errorMessage,
    failureKind,
    infoMessage,
  ];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authRepository, {AppLogger? logger})
    : _logger = logger ?? const AppLogger(),
      super(const AuthState.loading());

  final AuthRepository _authRepository;
  final AppLogger _logger;
  StreamSubscription<AuthUser?>? _subscription;

  void initialize() {
    final currentUser = _authRepository.currentUser;
    _logger.event('auth.initialize', <String, Object?>{
      'hasCurrentUser': currentUser != null,
    });
    emit(
      currentUser == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(currentUser),
    );

    _subscription ??= _authRepository.observeAuthState().listen((
      AuthUser? user,
    ) {
      if (user?.isAnonymous == true &&
          user?.id == state.user?.id &&
          state.submissionStatus ==
              AuthSubmissionStatus.emailConfirmationRequired) {
        // A delayed SDK userUpdated/token event must not erase the pending
        // confirmation instructions or turn the guest into a completed signup.
        return;
      }
      _logger.event('auth.state_changed', <String, Object?>{
        'authenticated': user != null,
      });
      emit(
        user == null
            ? state.copyWith(
                status: AuthStatus.unauthenticated,
                clearUser: true,
                submissionStatus: AuthSubmissionStatus.idle,
                clearInfoMessage: true,
              )
            : state.copyWith(
                status: AuthStatus.authenticated,
                user: user,
                submissionStatus: AuthSubmissionStatus.success,
                clearErrorMessage: true,
                clearInfoMessage: true,
              ),
      );
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.submissionStatus == AuthSubmissionStatus.submitting) return;
    _logger.event('auth.sign_in_requested');
    emit(
      state.copyWith(
        submissionStatus: AuthSubmissionStatus.submitting,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
    try {
      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );
      if (isClosed) return;
      _logger.event('auth.sign_in_succeeded', <String, Object?>{
        'userId': user.id,
      });
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          submissionStatus: AuthSubmissionStatus.success,
          clearErrorMessage: true,
          clearInfoMessage: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _logFailure('auth.sign_in_failed', error);
      emit(
        state.copyWith(
          submissionStatus: AuthSubmissionStatus.failure,
          errorMessage: _readableError(error),
          failureKind: error is AuthFailure
              ? error.kind
              : AuthFailureKind.unknown,
        ),
      );
    }
  }

  Future<void> ensureAnonymousSession() async {
    _logger.event('auth.ensure_anonymous_requested');
    emit(
      state.copyWith(
        submissionStatus: AuthSubmissionStatus.submitting,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
    try {
      final user = await _authRepository.ensureAnonymousSession();
      _logger.event('auth.ensure_anonymous_succeeded', <String, Object?>{
        'userId': user.id,
      });
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          submissionStatus: AuthSubmissionStatus.success,
          clearErrorMessage: true,
          clearInfoMessage: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _logFailure('auth.ensure_anonymous_failed', error);
      emit(
        state.copyWith(
          submissionStatus: AuthSubmissionStatus.failure,
          errorMessage: _readableError(error),
          failureKind: error is AuthFailure
              ? error.kind
              : AuthFailureKind.unknown,
        ),
      );
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    if (state.submissionStatus == AuthSubmissionStatus.submitting) return;
    _logger.event('auth.sign_up_requested');
    emit(
      state.copyWith(
        submissionStatus: AuthSubmissionStatus.submitting,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
    try {
      final result = await _authRepository.signUp(
        email: email,
        password: password,
      );
      if (isClosed) return;
      _logger.event('auth.sign_up_succeeded', <String, Object?>{
        'userId': result.user.id,
        'hasActiveSession': result.hasActiveSession,
      });
      if (!result.hasActiveSession || result.user.isAnonymous) {
        emit(
          state.copyWith(
            status: result.hasActiveSession
                ? AuthStatus.authenticated
                : AuthStatus.unauthenticated,
            user: result.hasActiveSession ? result.user : null,
            clearUser: !result.hasActiveSession,
            submissionStatus: AuthSubmissionStatus.emailConfirmationRequired,
            infoMessage: result.hasActiveSession
                ? 'Check your email to confirm your account, then sign in '
                      'here. Your guest reading is still saved on this device; '
                      'stay signed in until you confirm.'
                : 'Check your email to confirm your account, then sign in.',
            clearErrorMessage: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          submissionStatus: AuthSubmissionStatus.success,
          clearErrorMessage: true,
          clearInfoMessage: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _logFailure('auth.sign_up_failed', error);
      emit(
        state.copyWith(
          submissionStatus: AuthSubmissionStatus.failure,
          errorMessage: _readableError(error),
          failureKind: error is AuthFailure
              ? error.kind
              : AuthFailureKind.unknown,
        ),
      );
    }
  }

  Future<void> signOut() async {
    if (state.submissionStatus == AuthSubmissionStatus.submitting) return;
    _logger.event('auth.sign_out_requested');
    emit(
      state.copyWith(
        submissionStatus: AuthSubmissionStatus.submitting,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
    try {
      await _authRepository.signOut();
      if (!isClosed) emit(const AuthState.unauthenticated());
    } catch (error) {
      if (isClosed) return;
      _logFailure('auth.sign_out_failed', error);
      emit(
        state.copyWith(
          submissionStatus: AuthSubmissionStatus.failure,
          errorMessage: _readableError(error),
          failureKind: error is AuthFailure
              ? error.kind
              : AuthFailureKind.unknown,
        ),
      );
    }
  }

  Future<void> deleteAccount() async {
    _logger.event('auth.delete_account_requested');
    emit(
      state.copyWith(
        submissionStatus: AuthSubmissionStatus.submitting,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
    try {
      await _authRepository.deleteAccount();
      _logger.event('auth.delete_account_succeeded');
      emit(
        const AuthState.unauthenticated().copyWith(
          submissionStatus: AuthSubmissionStatus.success,
          infoMessage: 'Your account has been deleted.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      _logFailure('auth.delete_account_failed', error);
      emit(
        state.copyWith(
          submissionStatus: AuthSubmissionStatus.failure,
          errorMessage: _readableError(error),
          failureKind: error is AuthFailure
              ? error.kind
              : AuthFailureKind.unknown,
        ),
      );
    }
  }

  void clearFeedback() {
    emit(
      state.copyWith(
        submissionStatus: AuthSubmissionStatus.idle,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
  }

  String _readableError(Object error) => error is AuthFailure
      ? error.message
      : const AuthFailure(AuthFailureKind.unknown).message;

  void _logFailure(String event, Object error) {
    _logger.event(event, {
      'kind': error is AuthFailure ? error.kind.name : 'unknown',
      'errorType': error.runtimeType.toString(),
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
