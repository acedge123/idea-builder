import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_dna/src/features/auth/domain/entities/auth_user.dart';
import 'package:music_dna/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'auth_cubit_test.dart' show FakeAuthRepository;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/guest_save/data/guest_reading_store.dart';
import 'package:music_dna/src/features/guest_save/data/verified_guest_save_repository.dart';
import 'package:music_dna/src/features/guest_save/data/supabase_guest_save_auth.dart';
import 'package:music_dna/src/features/guest_save/domain/guest_reading.dart';
import 'package:music_dna/src/features/guest_save/domain/guest_save_repository.dart';
import 'package:music_dna/src/features/guest_save/presentation/guest_save_cubit.dart';
import 'package:music_dna/src/features/guest_save/presentation/guest_save_page.dart';
import 'package:music_dna/src/features/guest_save/presentation/guest_reading_save.dart';
import 'package:music_dna/src/features/guest_save/presentation/guest_account_gate.dart';
import 'package:music_dna/src/features/guest_save/presentation/guest_recovery_card.dart';
import 'package:music_dna/src/features/readings/data/rest_reading_library_repository.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'ab63_auth_startup_test.dart' show response, session;

const owner = 'guest-owner';
const id = '00000000-0000-4000-8000-000000000001';
const reading = GuestReading(
  sourceUserId: owner,
  sessionId: id,
  resultVersion: 1,
);
const confirmed = GuestIdentity(
  owner,
  anonymous: false,
  emailConfirmedAt: '2026-11-13T23:00:00Z',
);

class StaticAuthRepository extends FakeAuthRepository {
  StaticAuthRepository()
    : super(initialUser: const AuthUser(id: owner, isAnonymous: true));
  @override
  Stream<AuthUser?> observeAuthState() => const Stream.empty();
}

class SaveAuth implements GuestSaveAuth {
  @override
  GuestIdentity? current = const GuestIdentity(owner, anonymous: true);
  GuestIdentity? server;
  Object? emailFailure;
  int emailCalls = 0, passwordCalls = 0;
  @override
  Future<GuestIdentity?> getUser() async => server ?? current;
  @override
  Future<void> requestEmail(
    String email, {
    required String expectedOwner,
  }) async {
    expect(expectedOwner, current?.id);
    emailCalls++;
    if (emailFailure != null) throw emailFailure!;
  }

  @override
  Future<void> setPassword(
    String password, {
    required String expectedOwner,
  }) async {
    expect(expectedOwner, current?.id);
    passwordCalls++;
  }
}

class Harness {
  final auth = SaveAuth();
  final store = GuestReadingStore();
  final requests = <String>[];
  bool completed = true, unavailable = false, wrongVersion = false;
  late final remote = SessionRemoteDataSource(
    MusicDnaApiClient(
      baseUrl: 'https://www.musicdna.fm',
      accessTokenProvider: () async => 'owner-bearer',
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        expect(
          request.method,
          'GET',
        ); // No reveal, publication, transfer or generation.
        expect(request.headers['X-MusicDNA-Experience'], '1');
        expect(request.headers['authorization'], 'Bearer owner-bearer');
        if (unavailable) {
          return response({
            'error': {'code': 'UNAVAILABLE'},
          }, 503);
        }
        final row = {
          'session_id': id,
          'started_at': '2026-11-13T23:00:00Z',
          'status': completed ? 'completed' : 'in_progress',
          'mode': 'discover',
        };
        if (request.url.path == '/api/v1/sessions') {
          return response({
            'sessions': [row],
            'next_cursor': null,
          });
        }
        if (request.url.path == '/api/v1/session/$id') return response(row);
        expect(request.url.path, '/api/v1/session/$id/report');
        expect(request.url.queryParameters['version'], isIn([null, '1']));
        final fixture =
            jsonDecode(
                  File(
                    'test/fixtures/report/report-envelope-ok.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        if (wrongVersion) (fixture['frozen'] as Map)['result_version'] = 2;
        return response(fixture);
      }),
    ),
    experienceV1: true,
  );
  late final repository = VerifiedGuestSaveRepository(
    auth: auth,
    store: store,
    library: RestReadingLibraryRepository(remote),
    reports: SessionRepositoryImpl(remote),
  );
  Future<void> pending() async {
    await repository.remember(reading);
    await repository.requestEmail(reading, 'new@example.invalid');
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['MUSICDNA_GUEST_SAVE_SCREENSHOTS'];
  if (directory == null) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    final font = Platform.environment['MUSICDNA_TEST_FONT'];
    if (font != null) {
      final bytes = File(font).readAsBytesSync();
      await (FontLoader(
        'qa-font',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  test(
    'email request alone stays pending; no password or saved claim',
    () async {
      final h = Harness();
      await h.repository.remember(reading);
      final c = GuestSaveCubit(h.repository);
      await c.load(id, 1);
      await c.requestEmail('new@example.invalid');
      expect(c.state.step, GuestSaveStep.confirmation);
      expect((await h.repository.find(id, 1))!.emailRequested, true);
      await c.checkConfirmation();
      expect(c.state.step, GuestSaveStep.confirmation);
      expect(c.state.error, contains('Confirm your email'));
      expect(h.auth.passwordCalls, 0);
      await c.close();
    },
  );
  test(
    'same confirmed UID, password and exact owner/version readback are required',
    () async {
      final h = Harness();
      await h.pending();
      h.auth.server = confirmed;
      final c = GuestSaveCubit(h.repository);
      await c.load(id, 1);
      await c.checkConfirmation();
      expect(c.state.step, GuestSaveStep.password);
      expect(h.auth.passwordCalls, 0);
      await c.finish('private-fixture-password');
      expect(c.state.step, GuestSaveStep.saved);
      expect(h.auth.passwordCalls, 1);
      expect((await h.repository.find(id, 1))!.emailRequested, false);
      expect(h.requests.where((r) => r.endsWith('/report')), hasLength(2));
      await c.close();
    },
  );
  for (final user in [
    const GuestIdentity(
      'another-owner',
      anonymous: false,
      emailConfirmedAt: 'now',
    ),
    const GuestIdentity(owner, anonymous: false),
    const GuestIdentity(owner, anonymous: true, emailConfirmedAt: 'now'),
  ]) {
    test(
      'denies unverified identity: ${user.id}/${user.anonymous}/${user.emailConfirmedAt}',
      () async {
        final h = Harness();
        await h.pending();
        h.auth.server = user;
        await expectLater(
          h.repository.finish(reading, 'private'),
          throwsA(isA<GuestSaveFailure>()),
        );
        expect(h.auth.passwordCalls, 0);
        expect((await h.store.load(owner)).single.emailRequested, true);
      },
    );
  }
  test(
    'missing source on a confirmed callback fails closed, without mutation',
    () async {
      final h = Harness();
      h.auth.current = confirmed;
      expect(await h.repository.latest(), null);
      await expectLater(
        h.repository.finish(reading, 'private'),
        throwsA(isA<GuestSaveFailure>()),
      );
      expect(h.auth.passwordCalls, 0);
      expect(h.requests, isEmpty);
    },
  );
  test(
    'duplicate email keeps guest reading; no existing-account transfer offered',
    () async {
      final h = Harness();
      await h.repository.remember(reading);
      h.auth.emailFailure = const AuthException(
        'raw provider diagnostic',
        code: 'email_exists',
      );
      final c = GuestSaveCubit(h.repository);
      await c.load(id, 1);
      await c.requestEmail('existing@example.invalid');
      expect(c.state.step, GuestSaveStep.email);
      expect(c.state.error, contains('existing account is not available'));
      expect(c.state.error, isNot(contains('raw provider')));
      expect(h.auth.current!.id, owner);
      expect(await h.repository.latest(), isNotNull);
      await c.close();
    },
  );
  for (final failure in ['unavailable', 'incomplete', 'version']) {
    test(
      '$failure readback never says saved; retry preserves source',
      () async {
        final h = Harness();
        await h.pending();
        h.auth.server = confirmed;
        final c = GuestSaveCubit(h.repository);
        await c.load(id, 1);
        await c.checkConfirmation();
        h.unavailable = failure == 'unavailable';
        h.completed = failure != 'incomplete';
        h.wrongVersion = failure == 'version';
        await c.finish('private');
        expect(c.state.step, GuestSaveStep.password);
        expect(c.state.error, isNotNull);
        expect((await h.repository.find(id, 1))!.emailRequested, true);
        h.unavailable = false;
        h.completed = true;
        h.wrongVersion = false;
        await c.finish('private');
        expect(c.state.step, GuestSaveStep.saved);
        await c.close();
      },
    );
  }
  test(
    'owner changes hide all local readings and prevent subsequent writes',
    () async {
      final h = Harness();
      await h.pending();
      h.auth.current = const GuestIdentity('other', anonymous: false);
      expect(await h.repository.latest(), null);
      expect(await h.repository.find(id, 1), null);
      await expectLater(
        h.repository.finish(reading, 'private'),
        throwsA(isA<GuestSaveFailure>()),
      );
      expect(h.auth.passwordCalls, 0);
    },
  );
  test(
    'restart retains pending source, dismissal and prior readings without secrets',
    () async {
      final h = Harness();
      await h.pending();
      await h.repository.dismiss(reading);
      await h.repository.remember(
        const GuestReading(
          sourceUserId: owner,
          sessionId: 'another-reading',
          resultVersion: 2,
        ),
      );
      final stored = await GuestReadingStore().load(owner);
      expect(stored, hasLength(2));
      final old = stored.singleWhere((r) => r.sessionId == id);
      expect(old.promptDismissed, true);
      expect(old.emailRequested, true);
      final c = GuestSaveCubit(h.repository);
      await c.load(id, 1);
      expect(c.state.step, GuestSaveStep.confirmation);
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('musicdna.guest_readings.v1.$owner')!;
      expect(json, isNot(contains('example.invalid')));
      expect(json, isNot(contains('private')));
      expect(json, isNot(contains('bearer')));
      await c.close();
    },
  );
  test(
    'build15 guest recovery uses owner-only read APIs, never a generation call',
    () async {
      final h = Harness();
      final result = await h.repository.latest();
      expect(result!.readingPath, '/session/$id?version=1');
      expect((await h.repository.find(id, 1))!.sourceUserId, owner);
      expect(h.requests, [
        'GET /api/v1/sessions',
        'GET /api/v1/session/$id/report',
      ]);
    },
  );
  test(
    'native Supabase adapter sends email and password in separate verified steps',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final redirects = <String?>[];
      var verified = false;
      Map<String, dynamic> sdkUser() => {
        ...session(owner)['user'] as Map<String, dynamic>,
        'is_anonymous': !verified,
        if (verified) 'email_confirmed_at': '2026-11-13T23:00:00Z',
      };
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'public-fixture',
        httpClient: MockClient((r) async {
          if (r.method == 'GET') return response(sdkUser());
          expect(r.method, 'PUT');
          expect(r.url.path, '/auth/v1/user');
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          redirects.add(r.url.queryParameters['redirect_to']);
          return response(sdkUser());
        }),
      );
      await client.auth.setInitialSession(
        jsonEncode({...session(owner), 'user': sdkUser()}),
      );
      final auth = SupabaseGuestSaveAuth(client);
      await auth.requestEmail('new@example.invalid', expectedOwner: owner);
      expect(bodies.single['email'], 'new@example.invalid');
      expect(bodies.single.containsKey('password'), false);
      expect(redirects.single, SupabaseGuestSaveAuth.confirmationRedirect);
      verified = true;
      expect((await auth.getUser())!.confirmedAs(owner), true);
      await auth.setPassword('not-persisted', expectedOwner: owner);
      expect(bodies.last['password'], 'not-persisted');
      expect(bodies.last.containsKey('email'), false);
      await expectLater(
        auth.setPassword('private', expectedOwner: 'other'),
        throwsA(isA<GuestSaveFailure>()),
      );
      expect(bodies, hasLength(2));
      await client.dispose();
    },
  );
  testWidgets(
    'completion sheet dismisses, permanent save action reopens exact reading',
    (tester) async {
      final h = Harness();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: GuestReadingSave(
                repository: h.repository,
                reading: reading,
              ),
            ),
          ),
          GoRoute(
            path: '/save-reading',
            builder: (_, state) {
              expect(state.uri.queryParameters, {
                'session': id,
                'version': '1',
              });
              return const Scaffold(body: Text('Save form'));
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Keep this reading.'), findsOneWidget);
      await tester.tap(find.text('Not now — back to my reading'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this reading.'), findsNothing);
      expect((await h.repository.find(id, 1))!.promptDismissed, true);
      await tester.tap(find.text('Keep this reading'));
      await tester.pumpAndSettle();
      expect(find.text('Save form'), findsOneWidget);
      router.dispose();
    },
  );
  testWidgets(
    'pending Account screen has no sign-in transfer shortcut and no password before confirmation',
    (tester) async {
      final h = Harness();
      await h.pending();
      await tester.pumpWidget(
        MaterialApp(home: GuestAccountGate(repository: h.repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text("I've confirmed my email"), findsOneWidget);
      expect(find.text('Set your password'), findsNothing);
      expect(find.text('Sign in'), findsNothing);
      await tester.tap(find.text("I've confirmed my email"));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Confirm your email on this device first'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Home recovery returns to immutable version after navigation/restart',
    (tester) async {
      final h = Harness();
      await h.repository.remember(reading);
      await h.repository.dismiss(reading);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(body: GuestRecoveryCard(repository: h.repository)),
          ),
          GoRoute(
            path: '/session/:id',
            builder: (_, state) {
              expect(state.pathParameters['id'], id);
              expect(state.uri.queryParameters['version'], '1');
              return const Scaffold(body: Text('Exact reading'));
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue your reading'));
      await tester.pumpAndSettle();
      expect(find.text('Exact reading'), findsOneWidget);
      router.dispose();
    },
  );
  testWidgets(
    'leaving a completed guest report prompts and retains its immutable ID',
    (tester) async {
      final h = Harness();
      final authRepo = StaticAuthRepository();
      addTearDown(authRepo.dispose);
      final auth = AuthCubit(authRepo)..initialize();

      final sessions = SessionRepositoryImpl(h.remote);
      final cubit = SessionCubit(
        sessions,
        savedReadingRepository: sessions,
        startedSession: StartedMusicSession.reference(id),
      );
      await cubit.initialize(savedOnly: true, resultVersion: 1);
      expect(cubit.state.status, SessionStatus.revealed);
      final router = GoRouter(
        initialLocation: '/report',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home reached')),
          ),
          GoRoute(
            path: '/report',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider<AuthCubit>(create: (_) => auth),
                BlocProvider<SessionCubit>.value(value: cubit),
              ],
              child: SessionStubPage(
                shareBaseUrl: 'https://www.musicdna.fm',
                ownerId: owner,
                guestSaveRepository: h.repository,
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now — back to my reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Leave for now'), findsOneWidget);
      expect(find.text('Home reached'), findsNothing);
      await tester.tap(find.text('Leave for now'));
      await tester.pumpAndSettle();
      expect(find.text('Home reached'), findsOneWidget);
      expect((await h.repository.latest())!.readingPath, reading.readingPath);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await cubit.close();
    },
  );
  testWidgets(
    'ordinary sign-in is explicitly separate and cancel retains the guest',
    (tester) async {
      final h = Harness();
      await h.repository.remember(reading);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => GuestSavePage(
              repository: h.repository,
              sessionId: id,
              version: 1,
            ),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, state) {
              expect(state.uri.queryParameters['mode'], 'sign-in-only');
              return const Scaffold(body: Text('Ordinary sign-in'));
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Already have an account?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Already have an account?'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Sign in without saving this reading'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in without saving this reading'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in without saving?'), findsOneWidget);
      await tester.tap(find.text('Keep my guest session'));
      await tester.pumpAndSettle();
      expect(find.text('Ordinary sign-in'), findsNothing);
      expect(h.auth.current!.id, owner);
      await tester.tap(find.text('Sign in without saving this reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in without saving'));
      await tester.pumpAndSettle();
      expect(find.text('Ordinary sign-in'), findsOneWidget);
      expect(h.auth.emailCalls, 0);
      expect(h.auth.passwordCalls, 0);
      router.dispose();
    },
  );
  testWidgets(
    'save form fits a small phone with large text and keeps password masked',
    (tester) async {
      final h = Harness();
      await h.pending();
      h.auth.server = confirmed;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'qa-font'),
          ),
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: GuestSavePage(
              repository: h.repository,
              sessionId: id,
              version: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text("I've confirmed my email"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("I've confirmed my email"));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        true,
      );
      expect(tester.takeException(), null);
      await capture(tester, 'password-small-large-text');
    },
  );
}
