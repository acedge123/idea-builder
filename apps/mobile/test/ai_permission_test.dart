import 'dart:async';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/domain/repositories/saved_reading_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'session_result_test.dart' show ResultRepository, reveal;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/ai_permission/data/ai_permission_data_source.dart';
import 'package:music_dna/src/features/ai_permission/data/local_ai_permission_repository.dart';
import 'package:music_dna/src/features/ai_permission/domain/ai_permission_repository.dart';
import 'package:music_dna/src/features/ai_permission/domain/ai_permission_service.dart';
import 'package:music_dna/src/features/ai_permission/presentation/ai_permission_cubit.dart';
import 'package:music_dna/src/features/ai_permission/presentation/ai_permission_gate.dart';
import 'package:music_dna/src/features/auth/domain/entities/auth_user.dart';
import 'package:music_dna/src/features/auth/domain/repositories/auth_repository.dart';

void main() {
  late TestAuth auth;
  late LocalAiPermissionRepository repository;
  late AiPermissionService service;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    auth = TestAuth('owner-a');
    repository = LocalAiPermissionRepository(AiPermissionDataSource());
    service = AiPermissionService(repository, auth);
  });
  tearDown(() => auth.dispose());

  test(
    'fresh install is denied; acceptance survives restart and is owner-specific',
    () async {
      expect(await service.load('owner-a'), isFalse);
      await service.allow('owner-a');
      final restarted = LocalAiPermissionRepository(AiPermissionDataSource());
      expect(await restarted.load('owner-a'), isTrue);
      expect(await restarted.load('owner-b'), isFalse);
    },
  );
  test('old disclosure version requires permission again', () async {
    SharedPreferences.setMockInitialValues({
      'musicdna.ai_permission.owner-a': 'old-policy',
    });
    expect(await repository.load('owner-a'), isFalse);
  });
  test(
    'revocation persists without erasing the other owner’s permission',
    () async {
      await service.allow('owner-a');
      auth.change('owner-b');
      await service.allow('owner-b');
      await service.revoke('owner-b');
      final restarted = LocalAiPermissionRepository(AiPermissionDataSource());
      expect(await restarted.load('owner-b'), isFalse);
      expect(await restarted.load('owner-a'), isTrue);
    },
  );
  test(
    'all model-capable routes are blocked before credentials or transport',
    () async {
      var calls = 0;
      var credentialReads = 0;
      final client = MusicDnaApiClient(
        baseUrl: 'https://example.test',
        accessTokenProvider: () async {
          credentialReads++;
          return 'test';
        },
        permissionGuard: service.authorizeRequest,
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      for (final path in [
        '/api/v1/onboarding/react',
        '/api/v1/onboarding/opener',
        '/api/v1/session',
        '/api/v1/session/s/choice',
        '/api/v1/session/s/skip',
        '/api/v1/session/s/prepare',
        '/api/v1/session/s/reveal',
        '/api/v1/session/s/react',
        '/api/v1/session/s/chat',
        '/api/v1/session/s/explore',
        '/api/v1/session/s/future-model-action',
      ]) {
        await expectLater(client.post(path), throwsA(isA<AppApiException>()));
      }
      await expectLater(
        client.get('/api/v1/session/s/next?cursor=x'),
        throwsA(isA<AppApiException>()),
      );
      expect(calls, 0);
      expect(credentialReads, 0);
      await service.allow('owner-a');
      await client.post('/api/v1/onboarding/react');
      expect(calls, 1);
    },
  );
  test(
    'library, saved data, feedback, sharing and deletion do not require AI permission',
    () async {
      var calls = 0;
      final client = MusicDnaApiClient(
        baseUrl: 'https://example.test',
        accessTokenProvider: () async => 'test',
        permissionGuard: service.authorizeRequest,
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      for (final path in [
        '/api/v1/sessions',
        '/api/v1/session/s',
        '/api/v1/session/s/chat?limit=1',
        '/api/v1/session/s/explore',
        '/api/v1/session/s/comparison',
      ]) {
        await client.get(path);
      }
      await client.post('/api/v1/session/s/feedback');
      await client.post('/api/v1/session/s/share');
      await client.delete('/api/v1/account');
      expect(calls, 8);
    },
  );
  for (final changeOwner in [true, false]) {
    test(
      '${changeOwner ? 'account switch' : 'revocation'} during token refresh prevents transport',
      () async {
        await service.allow('owner-a');
        auth.change('owner-b');
        await service.allow('owner-b');
        auth.change('owner-a');
        final token = Completer<String?>();
        final refreshing = Completer<void>();
        var calls = 0;
        final client = MusicDnaApiClient(
          baseUrl: 'https://example.test',
          accessTokenProvider: () {
            refreshing.complete();
            return token.future;
          },
          permissionGuard: service.authorizeRequest,
          httpClient: MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        final request = client.post('/api/v1/session/s/chat');
        final blocked = expectLater(request, throwsA(isA<AppApiException>()));
        await refreshing.future;
        if (changeOwner) {
          auth.change('owner-b');
        } else {
          await service.revoke('owner-a');
        }
        token.complete('previous-token');
        await blocked;
        expect(calls, 0);
      },
    );
  }
  test('storage failure cannot grant permission', () async {
    final repo = LocalAiPermissionRepository(FailingDataSource());
    final cubit = AiPermissionCubit(AiPermissionService(repo, auth));
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.allow();
    expect(cubit.state.status, AiPermissionStatus.failure);
    expect(repo.isAllowed('owner-a'), isFalse);
  });
  test('late acceptance cannot unlock another account', () async {
    final source = DelayedDataSource();
    final repo = LocalAiPermissionRepository(source);
    final cubit = AiPermissionCubit(AiPermissionService(repo, auth));
    addTearDown(cubit.close);
    await cubit.load();
    final acceptance = cubit.allow();
    await source.started.future;
    auth.change('owner-b');
    await Future<void>.delayed(Duration.zero);
    source.finish.complete();
    await acceptance;
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.ownerId, 'owner-b');
    expect(cubit.state.status, AiPermissionStatus.required);
    expect(repo.isAllowed('owner-b'), isFalse);
  });
  test('overlapping allow then revoke remains revoked after restart', () async {
    final source = DelayedDataSource();
    final repo = LocalAiPermissionRepository(source);
    final allow = repo.allow('owner-a');
    await source.started.future;
    final revoke = repo.revoke('owner-a');
    source.finish.complete();
    await allow;
    await revoke;
    expect(repo.isAllowed('owner-a'), isFalse);
    expect(
      await LocalAiPermissionRepository(
        AiPermissionDataSource(),
      ).load('owner-a'),
      isFalse,
    );
  });
  for (final available in [true, false]) {
    test(
      'saved-only initialization never generates, saved exists: $available',
      () async {
        final repo = SavedOnlyRepository(available);
        final cubit = SessionCubit(
          repo,
          experienceRepository: repo,
          savedReadingRepository: repo,
          startedSession: StartedMusicSession.reference('session-1'),
        );
        addTearDown(cubit.close);
        await cubit.initialize(savedOnly: true);
        expect(
          cubit.state.status,
          available ? SessionStatus.revealed : SessionStatus.failure,
        );
        expect(repo.nextCalls, 0);
        expect(repo.revealCalls, 0);
      },
    );
  }
  testWidgets(
    'existing saved reading remains available without AI permission',
    (tester) async {
      var interviewCreated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AiPermissionGate(
            createCubit: () => AiPermissionCubit(
              service,
              canReadWithoutPermission: () async => true,
            ),
            childBuilder: (_) {
              interviewCreated = true;
              return const Text('AI interview');
            },
            readOnlyBuilder: (_) => const Scaffold(body: Text('Saved reading')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved reading'), findsOneWidget);
      expect(interviewCreated, isFalse);
      expect(repository.isAllowed('owner-a'), isFalse);
    },
  );

  testWidgets('interview is not created until explicit Allow', (tester) async {
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AiPermissionGate(
          createCubit: () => AiPermissionCubit(service),
          childBuilder: (_) {
            created++;
            return const Scaffold(body: Text('Interview ready'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(created, 0);
    expect(find.text(AiProcessingPolicy.disclosure), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('allow-openai-processing')),
    );
    await tester.tap(find.byKey(const Key('allow-openai-processing')));
    await tester.pumpAndSettle();
    expect(created, 1);
    expect(find.text('Interview ready'), findsOneWidget);
  });
  testWidgets('Not now returns home without permission or interview creation', (
    tester,
  ) async {
    var created = 0;
    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/test',
          builder: (_, state) => AiPermissionGate(
            createCubit: () => AiPermissionCubit(service),
            childBuilder: (_) {
              created++;
              return const Text('Interview');
            },
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-permission-not-now')));
    await tester.tap(find.byKey(const Key('ai-permission-not-now')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(created, 0);
    expect(repository.isAllowed('owner-a'), isFalse);
  });
  testWidgets(
    'account switch removes the interview until the next user allows',
    (tester) async {
      await service.allow('owner-a');
      await tester.pumpWidget(
        MaterialApp(
          home: AiPermissionGate(
            createCubit: () => AiPermissionCubit(service),
            childBuilder: (_) =>
                const Scaffold(body: Text('Private interview')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private interview'), findsOneWidget);
      auth.change('owner-b');
      await tester.pumpAndSettle();
      expect(find.text('Private interview'), findsNothing);
      expect(find.byKey(const Key('allow-openai-processing')), findsOneWidget);
    },
  );
  testWidgets('settings can revoke permission', (tester) async {
    await service.allow('owner-a');
    await tester.pumpWidget(
      MaterialApp(
        home: AiPermissionGate(createCubit: () => AiPermissionCubit(service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Turn off AI permission'));
    await tester.tap(find.text('Turn off AI permission'));
    await tester.pumpAndSettle();
    expect(repository.isAllowed('owner-a'), isFalse);
    expect(find.byKey(const Key('allow-openai-processing')), findsOneWidget);
  });
  testWidgets('small screen and large text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AiPermissionGate(createCubit: () => AiPermissionCubit(service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('allow-openai-processing')),
    );
    expect(tester.takeException(), isNull);
  });
}

class TestAuth implements AuthRepository {
  TestAuth(String id) : _user = AuthUser(id: id);
  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast(sync: true);
  void change(String? id) {
    _user = id == null ? null : AuthUser(id: id);
    _changes.add(_user);
  }

  @override
  AuthUser? get currentUser => _user;
  @override
  Stream<AuthUser?> observeAuthState() => _changes.stream;
  @override
  Future<AuthUser> ensureAnonymousSession() async {
    change('anonymous');
    return _user!;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => _user!;
  @override
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
  }) async => AuthSignUpResult(user: _user!, hasActiveSession: true);
  @override
  Future<void> signOut() async => change(null);
  @override
  Future<void> deleteAccount() => signOut();
  Future<void> dispose() => _changes.close();
}

class FailingDataSource extends AiPermissionDataSource {
  @override
  Future<void> write(String ownerId, {required bool allowed}) async {
    throw StateError('storage unavailable');
  }
}

class DelayedDataSource extends AiPermissionDataSource {
  final started = Completer<void>();
  final finish = Completer<void>();
  @override
  Future<void> write(String ownerId, {required bool allowed}) async {
    if (allowed) {
      started.complete();
      await finish.future;
    }
    await super.write(ownerId, allowed: allowed);
  }
}

class SavedOnlyRepository extends ResultRepository
    implements SavedReadingRepository {
  SavedOnlyRepository(this.available);
  final bool available;
  int nextCalls = 0;
  @override
  Future<SessionReveal?> fetchSavedReading({required String sessionId}) async =>
      available ? reveal : null;
  @override
  Future<SessionRoundState> fetchNextPairing({
    required String sessionId,
  }) async {
    nextCalls++;
    throw StateError('Saved-only path requested a matchup');
  }
}
