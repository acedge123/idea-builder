import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sdk;
import 'package:music_dna/src/features/auth/data/auth_failure_mapper.dart';
import 'package:music_dna/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:music_dna/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:music_dna/src/features/auth/domain/auth_failure.dart';
import 'package:music_dna/src/features/auth/domain/entities/auth_user.dart';
import 'package:music_dna/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:music_dna/src/features/auth/presentation/pages/auth_stub_page.dart';
import 'auth_cubit_test.dart' show FakeAuthRepository;

class ErrorSource implements AuthRemoteDataSource {
  ErrorSource(this.error);
  final Object error;
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> observeAuthState() => const Stream.empty();
  @override
  Future<AuthUser> ensureAnonymousSession() async => throw error;
  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => throw error;
  @override
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
  }) async => throw error;
  @override
  Future<void> signOut() async => throw error;
  @override
  Future<void> deleteAccount() async => throw error;
}

class PendingRepository extends FakeAuthRepository {
  final pending = Completer<AuthUser>();
  int calls = 0;
  @override
  Future<AuthUser> signIn({required String email, required String password}) {
    calls++;
    return pending.future;
  }
}

class DeleteFailureRepository extends FakeAuthRepository {
  DeleteFailureRepository()
    : super(
        initialUser: const AuthUser(
          id: 'disposable-user',
          email: 'qa@example.invalid',
        ),
      );
  @override
  Future<void> deleteAccount() async =>
      throw const AuthFailure(AuthFailureKind.network);
}

Future<void> showAuth(
  WidgetTester tester,
  AuthCubit cubit, {
  Future<bool> Function(Uri)? open,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AuthCubit>.value(
        value: cubit,
        child: AuthStubPage(openPasswordRecovery: open ?? (_) async => true),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'maps common SDK codes, not their provider messages or status strings',
    () {
      final expected = {
        'user_already_exists': AuthFailureKind.emailInUse,
        'email_exists': AuthFailureKind.emailInUse,
        'invalid_credentials': AuthFailureKind.invalidCredentials,
        'email_not_confirmed': AuthFailureKind.emailUnconfirmed,
        'weak_password': AuthFailureKind.weakPassword,
        'over_request_rate_limit': AuthFailureKind.rateLimited,
        'email_address_invalid': AuthFailureKind.invalidEmail,
        'session_expired': AuthFailureKind.sessionExpired,
      };
      for (final entry in expected.entries) {
        final failure = mapAuthFailure(
          sdk.AuthApiException(
            'private-provider-diagnostic',
            statusCode: '422',
            code: entry.key,
          ),
        );
        expect(failure.kind, entry.value);
        expect(failure.message, isNot(contains('private-provider')));
        expect(failure.message, isNot(contains('AuthApiException')));
      }
      expect(
        mapAuthFailure(
          const sdk.AuthApiException(
            'User already registered',
            code: 'user_already_exists',
          ),
        ).message,
        'That email already has an account. Sign in instead?',
      );
      expect(
        mapAuthFailure(
          sdk.AuthWeakPasswordException(
            message: 'raw weak password',
            statusCode: '422',
            reasons: ['length'],
          ),
        ).kind,
        AuthFailureKind.weakPassword,
      );
      expect(
        mapAuthFailure(TimeoutException('private endpoint')).kind,
        AuthFailureKind.network,
      );
    },
  );
  test(
    'repository normalizes SDK failures and unknown errors never reach UI',
    () async {
      for (final error in [
        const sdk.AuthApiException(
          'private-provider-secret',
          statusCode: '422',
          code: 'user_already_exists',
        ),
        const sdk.AuthApiException(
          'private-provider-secret',
          code: 'new_unknown_code',
        ),
        StateError('private-provider-secret'),
      ]) {
        final cubit = AuthCubit(AuthRepositoryImpl(ErrorSource(error)))
          ..initialize();
        addTearDown(cubit.close);
        await cubit.signUp(
          email: 'qa@example.invalid',
          password: 'test-password-only',
        );
        expect(
          cubit.state.errorMessage,
          isNot(contains('private-provider-secret')),
        );
        expect(cubit.state.errorMessage, isNot(contains('Exception')));
        expect(
          cubit.state.failureKind,
          error is sdk.AuthApiException && error.code == 'user_already_exists'
              ? AuthFailureKind.emailInUse
              : AuthFailureKind.unknown,
        );
      }
    },
  );
  test(
    'double sign-in is ignored; closed Cubit ignores a late failure',
    () async {
      final repo = PendingRepository();
      final cubit = AuthCubit(repo)..initialize();
      addTearDown(repo.dispose);
      final request = cubit.signIn(
        email: 'qa@example.invalid',
        password: 'test-password-only',
      );
      await cubit.signIn(
        email: 'qa@example.invalid',
        password: 'test-password-only',
      );
      expect(repo.calls, 1);
      await cubit.close();
      repo.pending.completeError(const AuthFailure(AuthFailureKind.network));
      await request;
    },
  );
  testWidgets(
    'duplicate signup switches to Sign in, retaining email and clearing password',
    (tester) async {
      final repo = FakeAuthRepository(
        signUpError: const AuthFailure(AuthFailureKind.emailInUse),
      );
      final cubit = AuthCubit(repo)..initialize();
      addTearDown(repo.dispose);
      addTearDown(cubit.close);
      await showAuth(tester, cubit);
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'qa@example.invalid',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test-password-only',
      );
      await tester.scrollUntilVisible(
        find.text('Create account'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account').hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.text('That email already has an account. Sign in instead?'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      await Scrollable.ensureVisible(
        tester.element(find.text('Sign in instead')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in instead').hitTestable());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'qa@example.invalid',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        isEmpty,
      );
      expect(cubit.state.submissionStatus, AuthSubmissionStatus.idle);
      expect(repo.currentUser, isNull);
      expect(find.text('Sign in to MusicDNA'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    },
  );
  testWidgets(
    'Forgot password opens only canonical recovery URL and sanitizes launch failure',
    (tester) async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repo)..initialize();
      addTearDown(repo.dispose);
      addTearDown(cubit.close);
      Uri? requested;
      await showAuth(
        tester,
        cubit,
        open: (uri) async {
          requested = uri;
          throw PlatformException(
            code: 'private-code',
            message: 'private-device-secret',
          );
        },
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'qa@example.invalid',
      );
      await tester.scrollUntilVisible(
        find.text('Forgot password?'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(requested.toString(), 'https://www.musicdna.fm/auth?mode=forgot');
      expect(requested!.queryParameters, {'mode': 'forgot'});
      expect(find.textContaining('private-device-secret'), findsNothing);
      expect(
        find.textContaining('Couldn’t open password recovery'),
        findsOneWidget,
      );
    },
  );
  testWidgets('failed deletion stays on Account and shows controlled error', (
    tester,
  ) async {
    final repo = DeleteFailureRepository();
    final cubit = AuthCubit(repo)..initialize();
    addTearDown(repo.dispose);
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(path: '/auth', builder: (_, _) => const AuthStubPage()),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: cubit,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(cubit.state.status, AuthStatus.authenticated);
    expect(find.text('Home destination'), findsNothing);
    expect(find.text('Your account'), findsOneWidget);
    expect(
      find.text(const AuthFailure(AuthFailureKind.network).message),
      findsOneWidget,
    );
  });
  testWidgets('error and recovery actions fit small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repo)..initialize();
    addTearDown(repo.dispose);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: BlocProvider<AuthCubit>.value(
            value: cubit,
            child: AuthStubPage(openPasswordRecovery: (_) async => true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Forgot password?'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
