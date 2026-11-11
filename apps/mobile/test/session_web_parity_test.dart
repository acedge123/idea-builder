import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/data/session_experience_mapper.dart';
import 'package:music_dna/src/features/session/data/session_result_mapper.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_milestone.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_experience_repository.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_preparation_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/critic_display.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_result_view.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_pairing_card.dart';
import 'session_cubit_test.dart' show FakeSessionRepository;
import 'session_result_test.dart' show start, reveal, wireResult;

SessionMilestone milestone(int n) => SessionMilestone(
  answered: n,
  title: n == 3 ? "The story isn't settled." : 'I have an initial reading.',
  summary: 'Saved server summary; no local interpretation.',
  continueLabel: n == 3 ? 'Three more' : 'Give me two more',
  canFinish: n == 4,
);
const pairing = SessionPairing(
  id: 'pair',
  exposureId: 'served-exposure',
  tests: [],
  songA: SessionPairingSong(id: 'a', title: 'A', artist: 'Artist A'),
  songB: SessionPairingSong(id: 'b', title: 'B', artist: 'Artist B'),
);

class Repository extends FakeSessionRepository
    implements SessionExperienceRepository, SessionPreparationRepository {
  Repository(this.milestoneValue);
  SessionMilestone? milestoneValue;
  final finishRequests = <bool>[];
  int preparations = 0;
  bool failFirstReveal = false, failPrepare = false;
  @override
  Future<SessionRoundState> fetchNextPairing({
    required String sessionId,
  }) async => SessionRoundState(
    sessionId: sessionId,
    round: (milestoneValue?.answered ?? 1) + 1,
    confidence: 0,
    done: false,
    pairing: pairing,
    experienceVersion: true,
    maxAnswered: 6,
  );
  @override
  Future<SessionExperience> fetchExperience({
    required String sessionId,
  }) async => SessionExperience(
    sessionId: sessionId,
    milestone: milestoneValue,
    exchanges: [
      SessionExchange(
        type: 'read',
        at: DateTime.utc(2026),
        read: const SessionRead(thesis: 'Exact saved read.'),
      ),
    ],
  );
  @override
  Future<SessionReactionEffect> react({
    required String sessionId,
    required SessionReaction reaction,
    required String mutationId,
    String? pairingId,
  }) async => throw UnimplementedError();
  @override
  Future<void> prepare({
    required String sessionId,
    required String pairingId,
    required String exposureId,
  }) async {
    preparations++;
    expect(exposureId, 'served-exposure');
    if (failPrepare) throw TimeoutException('Unknown preparation outcome');
  }

  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) async {
    finishRequests.add(finishEarly);
    if (failFirstReveal && finishRequests.length == 1) {
      throw TimeoutException('Unknown write outcome');
    }
    return reveal;
  }
}

SessionCubit makeCubit(Repository repository) => SessionCubit(
  repository,
  startedSession: start,
  experienceRepository: repository,
  preparationRepository: repository,
);

void main() {
  test('milestone is server-supplied and legacy history still works', () {
    expect(
      mapSessionExperience({
        'contract': 1,
        'session_id': 's',
        'exchanges': [],
      }, 's').milestone,
      isNull,
    );
    expect(
      mapSessionMilestone({
        'answered': 4,
        'title': 'Saved title',
        'summary': 'Saved summary',
        'continue_label': 'Continue',
        'can_finish': true,
      }).canFinish,
      true,
    );
    expect(
      () => mapSessionMilestone({
        'answered': 3,
        'title': 'x',
        'summary': 'x',
        'continue_label': 'Continue',
        'can_finish': true,
      }),
      throwsException,
    );
  });
  test(
    'halftime cannot finish and continuing does not submit a vote',
    () async {
      final repository = Repository(milestone(3));
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.visibleMilestone?.answered, 3);
      await cubit.finishEarly();
      expect(repository.finishRequests, isEmpty);
      cubit.continueInterview();
      expect(cubit.state.visibleMilestone, isNull);
      expect(cubit.state.currentRound?.pairing, pairing);
      expect(cubit.state.read?.thesis, 'Exact saved read.');
      expect(repository.lastChoiceSongId, isNull);
    },
  );
  test(
    'initial reading timeout retries the same early-finish intent',
    () async {
      final repository = Repository(milestone(4))..failFirstReveal = true;
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.finishEarly();
      expect(cubit.state.status, SessionStatus.failure);
      expect(cubit.state.finishEarlyRequested, true);
      await cubit.revealSession();
      expect(repository.finishRequests, [true, true]);
      expect(cubit.state.status, SessionStatus.revealed);
      expect(cubit.state.reveal, reveal);
      expect(repository.lastChoiceSongId, isNull);
    },
  );
  test(
    'preparation waits for a visible pairing and never retries after uncertainty',
    () async {
      final repository = Repository(milestone(3))..failPrepare = true;
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.prepareCurrentPairing();
      expect(repository.preparations, 0);
      cubit.continueInterview();
      await cubit.prepareCurrentPairing();
      await cubit.prepareCurrentPairing();
      expect(repository.preparations, 1);
      expect(cubit.state.status, SessionStatus.ready);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.read?.thesis, 'Exact saved read.');
    },
  );
  test(
    'modern reveal maps exactly and older saved results remain supported',
    () {
      final wire = wireResult()
        ..['reveal'] = {
          'answered': 4,
          'twist': 'Exact twist.',
          'challenge': 'Exact challenge?',
        };
      expect(mapSessionResult(wire).reveal?.twist, 'Exact twist.');
      expect(mapSessionResult(wire).reveal?.challenge, 'Exact challenge?');
      expect(mapSessionResult(wireResult()).reveal, isNull);
      wire['reveal'] = {'answered': 'four', 'challenge': 'x'};
      expect(() => mapSessionResult(wire), throwsException);
    },
  );
  test(
    'compact web formatting retains qualifications and does not add a claim',
    () {
      expect(
        compactCriticRead(
          'A over B. One choice for scale (1 supporting, 0 against), not a pattern.',
        ),
        'One choice for scale, not a pattern.',
      );
      expect(
        compactCriticRead('An exception remains. Not a verdict.'),
        'An exception remains. Not a verdict.',
      );
    },
  );
  test(
    'REST early reveal and preparation use the shared contract and normal bearer',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode(
            r.url.path.endsWith('/prepare')
                ? {'contract': 1, 'prepared': 2}
                : wireResult(),
          ),
          200,
        );
      });
      addTearDown(client.close);
      final repository = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://example.invalid',
            accessTokenProvider: () async => 'test-bearer',
            httpClient: client,
          ),
          experienceV1: true,
        ),
      );
      await repository.revealSession(sessionId: 's', finishEarly: true);
      await repository.prepare(sessionId: 's', pairingId: 'p', exposureId: 'e');
      expect(jsonDecode(requests.first.body), {'finish_early': true});
      expect(jsonDecode(requests.last.body), {
        'pairing_id': 'p',
        'exposure_id': 'e',
      });
      expect(
        requests.every(
          (r) =>
              r.headers['authorization'] == 'Bearer test-bearer' &&
              r.headers['X-MusicDNA-Experience'] == '1',
        ),
        true,
      );
    },
  );
  testWidgets(
    'Critic request can complete after the old 20-second mobile timeout',
    (tester) async {
      final pending = Completer<http.Response>();
      final client = MockClient((_) => pending.future);
      addTearDown(client.close);
      final remote = SessionRemoteDataSource(
        MusicDnaApiClient(
          baseUrl: 'https://example.invalid',
          accessTokenProvider: () async => 'test',
          httpClient: client,
        ),
      );
      final request = remote.revealSession(sessionId: 's');
      await tester.pump();
      await tester.pump(const Duration(seconds: 21));
      pending.complete(http.Response('{}', 200));
      await tester.pump();
      expect(await request, isEmpty);
    },
  );
  testWidgets('small-phone milestone hides choices until explicit continue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = Repository(milestone(4));
    final cubit = makeCubit(repository);
    addTearDown(cubit.close);
    await cubit.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: BlocProvider<SessionCubit>.value(
            value: cubit,
            child: const SessionStubPage(
              shareBaseUrl: 'https://example.invalid',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SessionSongChoiceCard), findsNothing);
    expect(repository.preparations, 0);
    await tester.ensureVisible(find.text('Give me two more'));
    await tester.tap(find.text('Give me two more'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionSongChoiceCard), findsNWidgets(2));
    expect(repository.preparations, 1);
    expect(repository.finishRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'full reveal renders server twist and challenge without repeating support cards',
    (tester) async {
      final mapped = mapSessionResult(
        wireResult()
          ..['reveal'] = {
            'answered': 4,
            'twist': 'Saved twist.',
            'challenge': 'Saved challenge?',
          },
      );
      final saved = SessionReveal(
        interpretation: 'Saved prose.',
        vector: const {},
        allowedClaims: [],
        counterarguments: [],
        result: mapped,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionResultView(
                state: SessionState(
                  status: SessionStatus.revealed,
                  reveal: saved,
                ),
                shareUrl: null,
                onPublish: () {},
                onRevoke: () {},
                onVerify: () {},
                onCopy: () {},
                onSignIn: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Saved twist.'), findsOneWidget);
      expect(find.text('Saved challenge?'), findsOneWidget);
      expect(find.text('The choices behind it'), findsNothing);
      expect(find.text('The receipts'), findsOneWidget);
    },
  );
}
