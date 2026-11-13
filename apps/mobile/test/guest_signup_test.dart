import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:music_dna/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:music_dna/src/features/auth/domain/auth_failure.dart';
import 'package:music_dna/src/features/auth/domain/entities/auth_user.dart'
    as domain;
import 'package:music_dna/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:music_dna/src/features/auth/presentation/pages/auth_stub_page.dart';
import 'package:music_dna/src/features/readings/data/rest_reading_library_repository.dart';
import 'package:music_dna/src/features/readings/domain/reading_library.dart';
import 'package:music_dna/src/features/readings/presentation/reading_library_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/reading_library_page.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';

import 'ab63_auth_startup_test.dart' show session, response;
import 'auth_cubit_test.dart' show FakeAuthRepository;
import 'build8_readings_test.dart' show LibraryFake;

const guestId = 'guest-owner';
const readingId = '00000000-0000-4000-8000-000000000001';
const email = 'new-listener@example.invalid';
const password = 'fixture-password-only';

Map<String, dynamic> user({bool anonymous = true, String id = guestId}) => {
  ...(session(id)['user'] as Map<String, dynamic>),
  'is_anonymous': anonymous,
  if (!anonymous) 'email': email,
};

class SignupHarness {
  SignupHarness({this.confirmationRequired = false, this.failure});
  final bool confirmationRequired;
  bool emailConfirmed = false;
  final Object? failure;
  final authRequests = <String>[];
  final readingRequests = <String>[];
  late final SupabaseClient client;
  late final SessionRemoteDataSource sessions;
  late final AuthRepositoryImpl repository;
  late final AuthCubit auth;

  Future<void> start({bool guest = true, String? persisted}) async {
    client = SupabaseClient(
      'https://auth.invalid',
      'test-public-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        authRequests.add('${request.method} ${request.url.path}');
        if (failure is Exception) throw failure!;
        if (failure is int) {
          return response({
            'error_code': 'email_exists',
            'msg': 'private',
          }, 422);
        }
        if (request.method == 'PUT' && request.url.path == '/auth/v1/user') {
          expect(request.headers['authorization'], contains('Bearer '));
          expect(jsonDecode(request.body), containsPair('email', email));
          expect(jsonDecode(request.body), containsPair('password', password));
          return response(
            user(anonymous: confirmationRequired && !emailConfirmed),
          );
        }
        if (request.url.path == '/auth/v1/signup') {
          return response({
            ...session('new-account'),
            'user': user(id: 'new-account', anonymous: false),
          });
        }
        if (request.url.queryParameters['grant_type'] == 'password') {
          final owner = confirmationRequired && emailConfirmed
              ? guestId
              : 'existing-account';
          return response({
            ...session(owner),
            'user': user(id: owner, anonymous: false),
          });
        }
        fail(
          'Unexpected auth operation: ${request.method} ${request.url.path}',
        );
      }),
    );
    if (persisted != null) {
      await client.auth.setInitialSession(persisted);
    } else if (guest) {
      await client.auth.setInitialSession(
        jsonEncode({...session(guestId), 'user': user()}),
      );
    }
    final api = MusicDnaApiClient(
      baseUrl: 'https://www.musicdna.fm',
      accessTokenProvider: () async => client.auth.currentSession?.accessToken,
      httpClient: MockClient((request) async {
        readingRequests.add('${request.method} ${request.url.path}');
        expect(request.method, 'GET'); // No generation, transfer or rewrite.
        final token = request.headers['authorization']!.split(' ').last;
        final claims =
            jsonDecode(
                  utf8.decode(
                    base64Url.decode(base64Url.normalize(token.split('.')[1])),
                  ),
                )
                as Map<String, dynamic>;
        if (claims['sub'] != guestId) {
          return response({
            'error': {'code': 'NOT_FOUND'},
          }, 404);
        }
        if (request.url.path == '/api/v1/sessions') {
          return response({
            'sessions': [
              {
                'session_id': readingId,
                'started_at': '2026-11-12T23:00:00Z',
                'status': 'completed',
                'mode': 'discover',
              },
            ],
            'next_cursor': null,
          });
        }
        expect(request.url.path, '/api/v1/session/$readingId/report');
        expect(request.url.queryParameters['version'], '1');
        return response(
          jsonDecode(
            File(
              'test/fixtures/report/report-envelope-ok.json',
            ).readAsStringSync(),
          ),
        );
      }),
    );
    sessions = SessionRemoteDataSource(api, experienceV1: true);
    repository = AuthRepositoryImpl(SupabaseAuthRemoteDataSource(client, api));
    auth = AuthCubit(repository)..initialize();
    addTearDown(() async {
      await auth.close();
      await client.dispose();
    });
  }

  Future<void> signup() => auth.signUp(email: email, password: password);
}

class UpgradeRepository extends FakeAuthRepository {
  UpgradeRepository(this.pending)
    : super(initialUser: const domain.AuthUser(id: guestId, isAnonymous: true));
  final bool pending;
  domain.AuthUser? upgraded;
  @override
  domain.AuthUser? get currentUser => upgraded ?? super.currentUser;
  @override
  Future<domain.AuthSignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    upgraded = domain.AuthUser(
      id: guestId,
      email: pending ? null : email,
      isAnonymous: pending,
    );
    return domain.AuthSignUpResult(user: upgraded!, hasActiveSession: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'signup upgrades the guest UUID; library and exact report survive restore',
    () async {
      final h = SignupHarness();
      await h.start();
      await h.signup();
      expect(h.authRequests, ['PUT /auth/v1/user']);
      expect(h.auth.state.user!.id, guestId);
      expect(h.auth.state.user!.isAnonymous, false);
      expect(h.auth.state.submissionStatus, AuthSubmissionStatus.success);
      final library = RestReadingLibraryRepository(h.sessions);
      expect((await library.list()).readings.single.id, readingId);
      final report = await SessionRepositoryImpl(
        h.sessions,
      ).fetchSavedReading(sessionId: readingId, resultVersion: 1);
      expect(report!.result!.version, 1);
      expect(report.result!.headline, "Polish doesn't mean polite. ...");

      final restored = SignupHarness();
      await restored.start(
        persisted: jsonEncode(h.client.auth.currentSession!.toJson()),
      );
      expect(restored.repository.currentUser!.id, guestId);
      expect(restored.repository.currentUser!.isAnonymous, false);
      expect(
        (await RestReadingLibraryRepository(
          restored.sessions,
        ).list()).readings.single.id,
        readingId,
      );
      final reopened = await SessionRepositoryImpl(
        restored.sessions,
      ).fetchSavedReading(sessionId: readingId, resultVersion: 1);
      expect(reopened, report);
      expect(restored.authRequests, isEmpty);
      expect(h.readingRequests.every((r) => r.startsWith('GET ')), true);
    },
  );

  for (final failure in [422, http.ClientException('private diagnostic')]) {
    test(
      'failed upgrade keeps the guest session and saved reading: $failure',
      () async {
        final h = SignupHarness(failure: failure);
        await h.start();
        await h.signup();
        expect(h.authRequests, ['PUT /auth/v1/user']);
        expect(h.auth.state.user!.id, guestId);
        expect(h.auth.state.user!.isAnonymous, true);
        expect(h.auth.state.submissionStatus, AuthSubmissionStatus.failure);
        expect(
          h.auth.state.failureKind,
          failure == 422 ? AuthFailureKind.emailInUse : AuthFailureKind.network,
        );
        expect(
          (await RestReadingLibraryRepository(
            h.sessions,
          ).list()).readings.single.id,
          readingId,
        );
      },
    );
  }

  test(
    'confirmation-pending upgrade retains an authenticated guest across restore',
    () async {
      final h = SignupHarness(confirmationRequired: true);
      await h.start();
      await h.signup();
      expect(h.auth.state.status, AuthStatus.authenticated);
      expect(
        h.auth.state.submissionStatus,
        AuthSubmissionStatus.emailConfirmationRequired,
      );
      expect(h.auth.state.user!.id, guestId);
      expect(h.auth.state.infoMessage, contains('stay signed in'));
      final restored = SignupHarness();
      await restored.start(
        persisted: jsonEncode(h.client.auth.currentSession!.toJson()),
      );
      expect(restored.repository.currentUser!.id, guestId);
      expect(
        (await RestReadingLibraryRepository(
          restored.sessions,
        ).list()).readings.single.id,
        readingId,
      );
    },
  );

  test('signup without a guest still creates an ordinary account', () async {
    final h = SignupHarness();
    await h.start(guest: false);
    await h.signup();
    expect(h.authRequests, ['POST /auth/v1/signup']);
    expect(h.auth.state.user!.id, 'new-account');
  });

  test(
    'confirmed email signs back into the same guest owner and saved version',
    () async {
      final h = SignupHarness(confirmationRequired: true);
      await h.start();
      await h.signup();
      h.emailConfirmed =
          true; // Model the provider accepting email confirmation.
      await h.auth.signIn(email: email, password: password);
      expect(h.auth.state.user!.id, guestId);
      expect(h.auth.state.user!.isAnonymous, false);
      expect(
        (await RestReadingLibraryRepository(
          h.sessions,
        ).list()).readings.single.id,
        readingId,
      );
      final report = await SessionRepositoryImpl(
        h.sessions,
      ).fetchSavedReading(sessionId: readingId, resultVersion: 1);
      expect(report!.result!.version, 1);
      expect(h.authRequests, ['PUT /auth/v1/user', 'POST /auth/v1/token']);
    },
  );

  test(
    'existing-account sign-in never upgrades or claims the guest reading',
    () async {
      final h = SignupHarness();
      await h.start();
      await h.auth.signIn(email: email, password: password);
      expect(h.authRequests, ['POST /auth/v1/token']);
      expect(h.auth.state.user!.id, 'existing-account');
      await expectLater(
        SessionRepositoryImpl(
          h.sessions,
        ).fetchSavedReading(sessionId: readingId, resultVersion: 1),
        throwsA(
          isA<AppApiException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      expect(h.readingRequests, ['GET /api/v1/session/$readingId/report']);
    },
  );

  testWidgets('signup without a guest still opens the new interview', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final auth = AuthCubit(repository)..initialize();
    addTearDown(repository.dispose);
    addTearDown(auth.close);
    final router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(path: '/auth', builder: (_, _) => const AuthStubPage()),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Scaffold(body: Text('New interview')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('New interview'), findsOneWidget);
  });

  for (final pending in [false, true]) {
    testWidgets(
      'guest signup routes to saved readings only after confirmation: pending=$pending',
      (tester) async {
        final repository = UpgradeRepository(pending);
        final auth = AuthCubit(repository)..initialize();
        addTearDown(repository.dispose);
        addTearDown(auth.close);
        final router = GoRouter(
          initialLocation: '/auth',
          routes: [
            GoRoute(path: '/auth', builder: (_, _) => const AuthStubPage()),
            GoRoute(
              path: '/readings',
              builder: (_, _) => BlocProvider(
                create: (_) => ReadingLibraryCubit(
                  LibraryFake(
                    page: Future.value(
                      ReadingPage([
                        ReadingSummary(
                          id: readingId,
                          startedAt: DateTime.utc(2026, 11, 12),
                          completed: true,
                        ),
                      ]),
                    ),
                  ),
                  ownerId: guestId,
                  currentOwner: () => repository.currentUser?.id,
                )..load(),
                child: const ReadingLibraryPage(),
              ),
            ),
            GoRoute(
              path: '/onboarding',
              builder: (_, _) => const Text('Unexpected new interview'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          BlocProvider.value(
            value: auth,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign up'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), email);
        await tester.enterText(find.byType(TextFormField).at(1), password);
        await tester.ensureVisible(find.text('Create account'));
        await tester.tap(find.text('Create account').hitTestable());
        await tester.pumpAndSettle();
        expect(find.text('Unexpected new interview'), findsNothing);
        if (pending) {
          expect(router.routeInformationProvider.value.uri.path, '/auth');
          expect(auth.state.user!.isAnonymous, true);
          expect(find.textContaining('stay signed in'), findsWidgets);
        } else {
          expect(router.routeInformationProvider.value.uri.path, '/readings');
          expect(find.text('My readings'), findsWidgets);
          expect(find.textContaining('Open reading'), findsOneWidget);
        }
      },
    );
  }
}
