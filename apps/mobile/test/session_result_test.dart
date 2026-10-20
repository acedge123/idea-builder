import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_dna/src/features/continuation/domain/continuation_repository.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/data/session_result_mapper.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/domain/entities/session_result.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_experience_repository.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_result_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_result_view.dart';

import 'session_cubit_test.dart' show FakeSessionRepository;

Map<String, dynamic> wireResult() => {
  'contract': 1,
  'result_version': 1,
  'outcome': 'supported',
  'headline': 'You favored transformation, with one exception.',
  'supporting_choices': [
    {
      'tradeoff': 'transformation over familiarity',
      'examples': ['A over B'],
      'supporting': 3,
      'tested': 4,
    },
  ],
  'tension': {'claim': 'One choice challenged this.', 'notes': 'C over D'},
  'share_token': null,
  'full': {
    'archetypeName': 'Architect',
    'interpretation': 'The stored full reading.',
    'vector': {'movement': 0.35},
    'allowed_claims': [],
    'counterarguments': [],
  },
};

final result = mapSessionResult(wireResult());
final reveal = SessionReveal(
  interpretation: 'The stored full reading.',
  vector: const {},
  allowedClaims: const [],
  counterarguments: const [],
  result: result,
);
const start = StartedMusicSession(
  sessionId: 'session-1',
  sessionLane: 'alternative',
  sessionLaneConfidence: 0,
  analysisLane: 'alternative',
  analysisConfidence: 0,
  hypothesis: '',
  reaction: '',
  reasoning: [],
  secondaryLanes: [],
  songs: [],
);

class ResultRepository extends FakeSessionRepository
    implements SessionResultRepository, SessionExperienceRepository {
  ResultRepository()
    : super(
        reveal: reveal,
        nextPairings: [
          const SessionRoundState(
            sessionId: 'session-1',
            round: 7,
            confidence: 0,
            done: true,
            experienceVersion: true,
          ),
        ],
      );
  final List<bool> publications = [];
  int revealCalls = 0, lookups = 0;
  Object? publicationError, lookupError;
  Completer<SharePublication>? pending;
  SharePublication? restoredPublication;
  String publicSessionId = 'session-1';
  int? publishedResultVersion;
  @override
  Future<SessionReveal> revealSession({required String sessionId}) async {
    revealCalls++;
    return reveal;
  }

  @override
  Future<SharePublication> setPublication({
    required String sessionId,
    required bool publish,
  }) async {
    publications.add(publish);
    if (publicationError != null) throw publicationError!;
    if (pending != null) return pending!.future;
    return SharePublication(
      isPublic: publish,
      token: publish ? 'opaque-token' : null,
      resultVersion: publishedResultVersion,
    );
  }

  @override
  Future<SharedReveal> fetchSharedReveal({required String token}) async {
    lookups++;
    if (lookupError != null) throw lookupError!;
    return SharedReveal(
      sessionId: publicSessionId,
      shareToken: token,
      completedAt: DateTime(2026),
      interpretation: 'Public projection',
      definingChoices: const [],
    );
  }

  @override
  Future<SessionExperience> fetchExperience({
    required String sessionId,
  }) async => SessionExperience(
    sessionId: sessionId,
    exchanges: [],
    publication: restoredPublication,
  );
  @override
  Future<SessionReactionEffect> react({
    required String sessionId,
    required SessionReaction reaction,
    required String mutationId,
    String? pairingId,
  }) async =>
      const SessionReactionEffect(effect: 'pacing_only', message: 'Not a vote');
}

SessionCubit cubitFor(ResultRepository repository) => SessionCubit(
  repository,
  startedSession: start,
  experienceRepository: repository,
  resultRepository: repository,
);

void main() {
  testWidgets(
    'versioned result opens continuation with exact original and returns unchanged',
    (tester) async {
      final repository = ResultRepository();
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      ContinuationContext? received;
      late GoRouter router;
      router = GoRouter(
        initialLocation: '/session',
        routes: [
          GoRoute(
            path: '/session',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const SessionStubPage(
                shareBaseUrl: 'https://www.musicdna.fm',
                ownerId: 'owner',
              ),
            ),
          ),
          GoRoute(
            path: '/session/:id/continuation',
            builder: (_, state) {
              received = state.extra as ContinuationContext;
              return Scaffold(
                body: TextButton(
                  onPressed: router.pop,
                  child: const Text('Return to reading'),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Push back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push back'));
      await tester.pumpAndSettle();
      expect(received!.original, same(reveal));
      expect(received!.resultVersion, result.version);
      expect(received!.ownerId, 'owner');
      await tester.tap(find.text('Return to reading'));
      await tester.pumpAndSettle();
      expect(find.text(result.headline), findsOneWidget);
      expect(cubit.state.reveal, same(reveal));
      expect(repository.revealCalls, 1);
    },
  );
  test(
    'reported published version mismatch prevents verification and preserves revoke',
    () async {
      final repository = ResultRepository()..publishedResultVersion = 2;
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.setPublication(publish: true);
      expect(cubit.state.shareVerified, false);
      expect(cubit.state.shareMayBePublic, true);
      expect(repository.lookups, 0);
      expect(cubit.state.shareError, isNotNull);
    },
  );
  test(
    'v1 reveal opts in, maps result and full separately and ignores token as consent',
    () async {
      final requests = <http.Request>[];
      final repository = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://www.musicdna.fm',
            accessTokenProvider: () async => 'test-token',
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode({...wireResult(), 'share_token': 'not-consent'}),
                200,
              );
            }),
          ),
          experienceV1: true,
        ),
      );
      final mapped = await repository.revealSession(sessionId: 'session-1');
      expect(requests.single.headers['X-MusicDNA-Experience'], '1');
      expect(requests.single.url.path, '/api/v1/session/session-1/reveal');
      expect(mapped.result!.version, 1);
      expect(mapped.result!.headline, result.headline);
      expect(mapped.interpretation, 'The stored full reading.');
      expect(mapped.vector['movement'], 0.35);
      expect(mapped.shareToken, isNull);
    },
  );

  test(
    'legacy reveal keeps its shape and sends no experience header',
    () async {
      final repository = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://www.musicdna.fm',
            accessTokenProvider: () async => null,
            httpClient: MockClient((request) async {
              expect(
                request.headers.containsKey('X-MusicDNA-Experience'),
                false,
              );
              return http.Response(
                jsonEncode({
                  'interpretation': 'Legacy reading',
                  'share_token': 'legacy',
                  'vector': {},
                  'allowed_claims': [],
                  'counterarguments': [],
                }),
                200,
              );
            }),
          ),
        ),
      );
      final mapped = await repository.revealSession(sessionId: 'session-1');
      expect(mapped.result, isNull);
      expect(mapped.interpretation, 'Legacy reading');
      expect(mapped.shareToken, 'legacy');
    },
  );

  test(
    'schema drift fails recoverably instead of displaying an empty v1 result',
    () {
      for (final patch in [
        {'contract': 2},
        {'result_version': null},
        {'outcome': 'unknown'},
        {'headline': ''},
        {'supporting_choices': 'invalid'},
      ]) {
        expect(
          () => mapSessionResult({...wireResult(), ...patch}),
          throwsA(isA<AppApiException>()),
        );
      }
      final sparse = mapSessionResult({
        ...wireResult(),
        'outcome': 'insufficient_evidence',
        'headline': 'Not enough independent evidence yet.',
        'supporting_choices': [],
        'tension': null,
      });
      expect(sparse.supportingChoices, isEmpty);
    },
  );

  test(
    'publication uses the explicit endpoint, body and contract header',
    () async {
      final repository = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://www.musicdna.fm',
            accessTokenProvider: () async => null,
            httpClient: MockClient((request) async {
              expect(request.url.path, '/api/v1/session/session-1/share');
              expect(request.headers['X-MusicDNA-Experience'], '1');
              final publishing = jsonDecode(request.body)['publish'] as bool;
              return http.Response(
                jsonEncode({
                  'contract': 1,
                  'is_public': publishing,
                  'share_token': publishing ? 'opaque' : null,
                }),
                200,
              );
            }),
          ),
          experienceV1: true,
        ),
      );
      expect(
        (await repository.setPublication(
          sessionId: 'session-1',
          publish: true,
        )).token,
        'opaque',
      );
      expect(
        (await repository.setPublication(
          sessionId: 'session-1',
          publish: false,
        )).token,
        isNull,
      );
      expect(
        () => mapSharePublication({
          'contract': 1,
          'is_public': true,
          'share_token': null,
        }, true),
        throwsA(isA<AppApiException>()),
      );
    },
  );

  test(
    'authoritative completion automatically reveals without auto-publishing',
    () async {
      final repository = ResultRepository();
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.status, SessionStatus.revealed);
      expect(cubit.state.reveal, same(reveal));
      expect(repository.revealCalls, 1);
      expect(repository.publications, isEmpty);
      expect(repository.lookups, 0);
      expect(cubit.state.shareVerified, false);
    },
  );

  test(
    'explicit publish verifies public identity, revoke hides the link, original stays unchanged',
    () async {
      final repository = ResultRepository();
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.setPublication(publish: true);
      expect(cubit.state.shareVerified, true);
      expect(cubit.state.publication!.token, 'opaque-token');
      await cubit.setPublication(publish: false);
      expect(repository.publications, [true, false]);
      expect(cubit.state.publication!.isPublic, false);
      expect(cubit.state.shareVerified, false);
      expect(cubit.state.shareMayBePublic, false);
      expect(cubit.state.sharedReveal, isNull);
      expect(cubit.state.reveal, same(reveal));
    },
  );

  test(
    'uncertain revoke retains cancel capability but not an old copyable link',
    () async {
      final repository = ResultRepository();
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.setPublication(publish: true);
      repository.publicationError = TimeoutException('acknowledgment lost');
      await cubit.setPublication(publish: false);
      expect(cubit.state.publication, isNull);
      expect(cubit.state.shareVerified, false);
      expect(cubit.state.shareMayBePublic, true);
      expect(cubit.state.shareError, isNotNull);
      expect(cubit.state.status, SessionStatus.revealed);
      repository.publicationError = null;
      await cubit.setPublication(publish: false);
      expect(cubit.state.shareMayBePublic, false);
    },
  );

  test('public lookup failure retries GET, not another publication', () async {
    final repository = ResultRepository()
      ..lookupError = const AppApiException(
        kind: AppApiErrorKind.unknown,
        message: 'Not found',
        statusCode: 404,
      );
    final cubit = cubitFor(repository);
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.setPublication(publish: true);
    expect(cubit.state.shareVerified, false);
    expect(cubit.state.shareMayBePublic, true);
    repository.lookupError = null;
    await cubit.verifyPublication();
    expect(cubit.state.shareVerified, true);
    expect(repository.publications, [true]);
    expect(repository.lookups, 2);
  });

  test('cross-session public response is never accepted', () async {
    final repository = ResultRepository()..publicSessionId = 'someone-else';
    final cubit = cubitFor(repository);
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.setPublication(publish: true);
    expect(cubit.state.shareVerified, false);
    expect(cubit.state.sharedReveal, isNull);
    expect(cubit.state.reveal, same(reveal));
  });

  test('parallel taps serialize while publication is in flight', () async {
    final repository = ResultRepository()..pending = Completer();
    final cubit = cubitFor(repository);
    addTearDown(cubit.close);
    await cubit.initialize();
    final sending = cubit.setPublication(publish: true);
    await cubit.setPublication(publish: true);
    await cubit.setPublication(publish: false);
    expect(repository.publications, [true]);
    repository.pending!.complete(
      const SharePublication(isPublic: true, token: 'opaque-token'),
    );
    await sending;
    expect(cubit.state.shareVerified, true);
  });

  test(
    'resume exposes revoke for an existing publication without auto-publish',
    () async {
      final repository = ResultRepository()
        ..restoredPublication = const SharePublication(
          isPublic: true,
          token: 'opaque-token',
        );
      final cubit = cubitFor(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.shareMayBePublic, true);
      expect(cubit.state.shareVerified, false);
      expect(repository.publications, isEmpty);
      await cubit.verifyPublication();
      expect(cubit.state.shareVerified, true);
    },
  );

  testWidgets(
    'v1 result fits a small phone at large text, starts private and exposes full reading',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var publishes = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SessionResultView(
                  state: SessionState(reveal: reveal),
                  shareUrl: null,
                  onPublish: () => publishes++,
                  onRevoke: () {},
                  onVerify: () {},
                  onCopy: () {},
                  onSignIn: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(result.headline), findsOneWidget);
      expect(find.byTooltip('Copy share link'), findsNothing);
      await tester.ensureVisible(find.text('Publish this read'));
      await tester.tap(find.text('Publish this read'));
      expect(publishes, 1);
      await tester.ensureVisible(find.text('Full reading'));
      await tester.tap(find.text('Full reading'));
      await tester.pumpAndSettle();
      expect(find.text('The stored full reading.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
