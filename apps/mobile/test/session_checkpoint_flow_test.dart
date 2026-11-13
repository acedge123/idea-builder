import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:music_dna/src/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/domain/entities/interview_flow.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_flow_repository.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_preparation_repository.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_pushback_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_pairing_card.dart';
import 'session_result_test.dart' show start, reveal;
import 'session_uninterrupted_flow_test.dart' show FlowRepository;

class CheckpointRepository extends FlowRepository
    implements
        SessionFlowRepository,
        SessionPreparationRepository,
        SessionPushbackRepository {
  InterviewFlow flow = InterviewFlow.checkpoints;
  Object? flowError;
  int flowCalls = 0, skips = 0;
  final prepared = <String>[];
  final early = <bool>[];
  final savedReads = <int, SessionRead>{};
  final readRequests = <int>[];
  final pushbackIds = <String>[];

  @override
  Future<InterviewFlow?> fetchFlow({required String sessionId}) async {
    flowCalls++;
    expect(sessionId, start.sessionId);
    if (flowError != null) throw flowError!;
    return flow;
  }

  @override
  Future<SessionExperience> fetchExperience({required String sessionId}) async {
    if (historyGate != null) return historyGate!.future;
    return SessionExperience(
      sessionId: sessionId,
      exchanges: [
        for (var i = 1; i <= answered; i++) ...[
          SessionExchange(
            type: 'choice',
            at: DateTime.utc(2026, 1, 1, 0, 0, i * 2),
            pairingId: 'pair-$i',
          ),
          if (savedReads[i] != null)
            SessionExchange(
              type: 'read',
              at: DateTime.utc(2026, 1, 1, 0, 0, i * 2 + 1),
              answered: i,
              read: savedReads[i],
            ),
        ],
      ],
    );
  }

  @override
  Future<SessionRead> fetchRead({
    required String sessionId,
    required String afterPairingId,
    required int answered,
  }) async {
    readRequests.add(answered);
    final read = await super.fetchRead(
      sessionId: sessionId,
      afterPairingId: afterPairingId,
      answered: answered,
    );
    savedReads[answered] = read;
    return read;
  }

  @override
  Future<void> skipPairing({
    required String sessionId,
    required String pairingId,
    required int msToDecide,
  }) async {
    skips++;
  }

  @override
  Future<void> prepare({
    required String sessionId,
    required String pairingId,
    required String exposureId,
  }) async {
    prepared.add(pairingId);
  }

  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) async {
    early.add(finishEarly);
    revealCalls++;
    return reveal;
  }

  @override
  Future<SavedPushback> submitPushback({
    required String sessionId,
    required String text,
    required String mutationId,
  }) async {
    pushbackIds.add(mutationId);
    return SavedPushback(
      text: text,
      reply: 'Your reply is saved.',
      mutationId: mutationId,
    );
  }

  @override
  SessionCubit cubit() => SessionCubit(
    this,
    startedSession: start,
    experienceRepository: this,
    criticRepository: this,
    resultRepository: this,
    flowRepository: this,
    preparationRepository: this,
    pushbackRepository: this,
  );
}

Future<void> choose(WidgetTester tester, SessionCubit cubit) async {
  await cubit.chooseSong(chosenSongId: 'a', msToDecide: 35);
  await tester.pump();
}

Future<void> finishQuip(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2500));
  await tester.pump();
}

Future<void> landRead(
  WidgetTester tester,
  CheckpointRepository repo,
  int answered,
) async {
  repo.reads[answered]!.complete(
    SessionRead(thesis: 'Saved Critic after $answered'),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'six-choice path holds checkpoints and writes only after 2/4, then one final report',
    (tester) async {
      final repo = CheckpointRepository();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      for (var answered = 1; answered <= 6; answered++) {
        await choose(tester, cubit);
        if (const [1, 3, 5].contains(answered)) {
          expect(cubit.state.status, SessionStatus.critic);
          expect(cubit.state.prefetchedRound?.round, answered + 1);
          expect(cubit.state.read, isNull);
          await cubit.chooseSong(chosenSongId: 'a', msToDecide: 0);
          expect(repo.choiceCalls, answered);
          await tester.pump(const Duration(milliseconds: 2499));
          expect(cubit.state.status, SessionStatus.critic);
          await tester.pump(const Duration(milliseconds: 1));
          expect(cubit.state.status, SessionStatus.ready);
        } else if (answered == 2 || answered == 4) {
          await landRead(tester, repo, answered);
          expect(cubit.state.isCheckpoint, isTrue);
          expect(cubit.state.checkpointAnswered, answered);
          expect(cubit.state.status, SessionStatus.critic);
          await tester.pump(const Duration(seconds: 30));
          expect(cubit.state.status, SessionStatus.critic);
          await cubit.chooseSong(chosenSongId: 'a', msToDecide: 0);
          expect(repo.choiceCalls, answered);
          cubit.continueCheckpoint();
          expect(cubit.state.status, SessionStatus.ready);
          expect(cubit.state.currentRound?.round, answered + 1);
          expect(cubit.state.read, isNull);
        }
      }
      expect(repo.readRequests, [2, 4]);
      expect(repo.early, [false]);
      expect(cubit.state.status, SessionStatus.revealed);
    },
  );

  testWidgets(
    'a read arriving before the next pairing remains on its checkpoint until explicit Continue',
    (tester) async {
      final repo = CheckpointRepository()..answered = 1;
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      repo.nextGate = Completer<SessionRoundState>();
      final saving = cubit.chooseSong(chosenSongId: 'a', msToDecide: 20);
      await tester.pump();
      await landRead(tester, repo, 2);
      expect(cubit.state.isCheckpoint, isTrue);
      expect(cubit.state.read?.thesis, 'Saved Critic after 2');
      cubit.continueCheckpoint();
      expect(cubit.state.status, SessionStatus.critic);
      repo.nextGate!.complete(repo.round());
      await saving;
      expect(cubit.state.status, SessionStatus.critic);
      cubit.continueCheckpoint();
      expect(cubit.state.currentRound?.round, 3);
      expect(cubit.state.status, SessionStatus.ready);
    },
  );

  testWidgets(
    'history failure during checkpoint restore never exposes upcoming cards',
    (tester) async {
      final repo = CheckpointRepository()..answered = 4;
      repo.historyGate = Completer<SessionExperience>();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      final states = <SessionState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);
      final loading = cubit.initialize();
      await tester.pump();
      repo.historyGate!.completeError(Exception('history unavailable'));
      await loading;
      expect(cubit.state.status, SessionStatus.failure);
      expect(states.any((s) => s.status == SessionStatus.ready), isFalse);
      expect(repo.readRequests, isEmpty);
    },
  );

  testWidgets(
    'four-choice finish is explicit, never offers a fifth choice or another intermediate read',
    (tester) async {
      final repo = CheckpointRepository()..answered = 3;
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      await choose(tester, cubit);
      await landRead(tester, repo, 4);
      await cubit.finishEarly();
      expect(repo.early, [true]);
      expect(repo.choiceCalls, 1);
      expect(repo.readRequests, [4]);
      expect(cubit.state.status, SessionStatus.revealed);
      cubit.continueCheckpoint();
      expect(cubit.state.status, SessionStatus.revealed);
    },
  );

  testWidgets('skips do not advance checkpoints or request narration', (
    tester,
  ) async {
    final repo = CheckpointRepository()..answered = 1;
    final cubit = repo.cubit();
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.skipPairing(msToDecide: 10);
    await cubit.skipPairing(msToDecide: 10);
    expect(repo.answered, 1);
    expect(repo.skips, 2);
    expect(repo.readRequests, isEmpty);
    expect(cubit.state.currentRound?.round, 2);
    await choose(tester, cubit);
    await landRead(tester, repo, 2);
    expect(cubit.state.checkpointAnswered, 2);
  });

  testWidgets(
    'resume restores saved checkpoint before any upcoming cards and never generates a read',
    (tester) async {
      final repo = CheckpointRepository()..answered = 2;
      repo.savedReads[2] = const SessionRead(
        thesis: 'Original saved checkpoint',
      );
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      final states = <SessionState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);
      await cubit.initialize();
      expect(repo.flowCalls, 1);
      expect(cubit.state.status, SessionStatus.critic);
      expect(cubit.state.read?.thesis, 'Original saved checkpoint');
      expect(states.any((s) => s.status == SessionStatus.ready), isFalse);
      expect(repo.readRequests, isEmpty);
      await cubit.initialize();
      expect(repo.flowCalls, 2);
      expect(cubit.state.isCheckpoint, isTrue);
      cubit.continueCheckpoint();
      expect(cubit.state.currentRound?.round, 3);
    },
  );

  testWidgets(
    'resume with no saved read offers retry/continue, not automatic narration',
    (tester) async {
      final repo = CheckpointRepository()..answered = 4;
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.isCheckpoint, isTrue);
      expect(cubit.state.read, isNull);
      expect(cubit.state.criticMessage, contains('picks are saved'));
      expect(repo.readRequests, isEmpty);
      final retry = cubit.retryCheckpointRead();
      await tester.pump();
      await landRead(tester, repo, 4);
      await retry;
      expect(repo.choiceCalls, 0);
      expect(cubit.state.read?.thesis, 'Saved Critic after 4');
      expect(cubit.state.isCheckpoint, isTrue);
    },
  );

  testWidgets(
    'checkpoint timeout keeps choice saved; Continue discards late narration',
    (tester) async {
      final repo = CheckpointRepository()..answered = 1;
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      await choose(tester, cubit);
      await tester.pump(const Duration(seconds: 20));
      expect(cubit.state.isCheckpoint, isTrue);
      expect(cubit.state.criticSettled, isTrue);
      expect(cubit.state.criticMessage, contains('still chewing'));
      expect(repo.readRequests, [2]);
      cubit.continueCheckpoint();
      expect(cubit.state.currentRound?.round, 3);
      await landRead(tester, repo, 2);
      expect(cubit.state.read, isNull);
      expect(repo.choiceCalls, 1);
      expect(repo.readRequests, [2]);
    },
  );

  testWidgets(
    'failed flow lookup blocks restore rather than switching to per-pick',
    (tester) async {
      final repo = CheckpointRepository()
        ..flowError = const AppApiException(
          kind: AppApiErrorKind.upstream,
          statusCode: 503,
          code: 'UNAVAILABLE',
          message: 'Unavailable',
        );
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.status, SessionStatus.failure);
      expect(cubit.state.currentRound, isNull);
      expect(repo.choiceCalls, 0);
      repo.flowError = null;
      await cubit.initialize();
      expect(cubit.state.flow, InterviewFlow.checkpoints);
      expect(cubit.state.status, SessionStatus.ready);
    },
  );

  testWidgets(
    'optional pushback works at each checkpoint with distinct operation keys',
    (tester) async {
      final repo = CheckpointRepository()..answered = 1;
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      await choose(tester, cubit);
      await landRead(tester, repo, 2);
      await cubit.submitPushback('My own view');
      cubit.continueCheckpoint();
      await choose(tester, cubit);
      await finishQuip(tester);
      await choose(tester, cubit);
      await landRead(tester, repo, 4);
      expect(cubit.state.pushbackReply, isNull);
      await cubit.submitPushback('My own view');
      expect(repo.pushbackIds.length, 2);
      expect(repo.pushbackIds[0], isNot(repo.pushbackIds[1]));
      expect(repo.answered, 4);
    },
  );

  testWidgets(
    'checkpoint screens show exact actions without any next song cards, including at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = CheckpointRepository()..answered = 2;
      repo.savedReads[2] = const SessionRead(
        thesis: 'Read both choices before choosing again.',
      );
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: BlocProvider<SessionCubit>.value(
            value: cubit,
            child: const SessionStubPage(
              shareBaseUrl: 'https://example.invalid',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SessionSongChoiceCard), findsNothing);
      expect(find.text('Next pairing'), findsOneWidget);
      expect(find.text('Get my reading now'), findsNothing);
      expect(find.text("That's not me — push back"), findsOneWidget);
      await tester.ensureVisible(find.text('Next pairing'));
      await tester.tap(find.text('Next pairing'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionSongChoiceCard), findsNWidgets(2));
      expect(
        find.text('Read both choices before choosing again.'),
        findsNothing,
      );
      await choose(tester, cubit);
      await finishQuip(tester);
      await choose(tester, cubit);
      await landRead(tester, repo, 4);
      await tester.pumpAndSettle();
      expect(find.text('Get my reading now'), findsOneWidget);
      expect(find.text('Keep going (final pair)'), findsOneWidget);
      expect(find.byType(SessionSongChoiceCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'session-specific flow lookup sends bearer, never reads the global flow, and propagates denials/outages',
    () async {
      var status = 200;
      String? code;
      final client = MockClient((req) async {
        expect(req.url.path, '/api/v1/interview-flow');
        expect(req.url.queryParameters, {'session': 'owned-session'});
        expect(req.headers['authorization'], 'Bearer owner');
        expect(req.headers['x-musicdna-experience'], '1');
        return http.Response(
          jsonEncode(
            status == 200
                ? {'contract': 1, 'flow': 'checkpoints', 'saved': true}
                : {
                    'error': {'code': code, 'message': 'Unavailable'},
                  },
          ),
          status,
        );
      });
      addTearDown(client.close);
      final repo = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://example.invalid',
            accessTokenProvider: () async => 'owner',
            httpClient: client,
          ),
          experienceV1: true,
        ),
      );
      expect(
        await repo.fetchFlow(sessionId: 'owned-session'),
        InterviewFlow.checkpoints,
      );
      for (final entry in [
        (401, 'UNAUTHORIZED'),
        (404, 'NOT_FOUND'),
        (503, 'UNAVAILABLE'),
      ]) {
        status = entry.$1;
        code = entry.$2;
        await expectLater(
          repo.fetchFlow(sessionId: 'owned-session'),
          throwsA(isA<AppApiException>()),
        );
      }
    },
  );

  test(
    'an unscoped flow response cannot replace the saved interview flow',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'contract': 1, 'flow': 'checkpoints', 'saved': false}),
          200,
        ),
      );
      addTearDown(client.close);
      final repo = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://example.invalid',
            accessTokenProvider: () async => 'owner',
            httpClient: client,
          ),
          experienceV1: true,
        ),
      );
      await expectLater(
        repo.fetchFlow(sessionId: 's'),
        throwsA(isA<AppApiException>()),
      );
    },
  );

  test(
    'only an absent legacy route can omit flow; unknown flow contracts fail visibly',
    () async {
      var status = 404;
      final client = MockClient(
        (_) async => http.Response(
          status == 404
              ? '<html>not found</html>'
              : jsonEncode({'contract': 1, 'flow': 'future_flow'}),
          status,
        ),
      );
      addTearDown(client.close);
      final repo = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://example.invalid',
            accessTokenProvider: () async => 'owner',
            httpClient: client,
          ),
          experienceV1: true,
        ),
      );
      expect(await repo.fetchFlow(sessionId: 's'), isNull);
      status = 200;
      await expectLater(
        repo.fetchFlow(sessionId: 's'),
        throwsA(isA<AppApiException>()),
      );
    },
  );

  test(
    'mobile start advertises capability and retains the returned flow in resume storage',
    () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/opener')) {
          return http.Response(
            jsonEncode({'lane': 'rock', 'confidence': 0}),
            200,
          );
        }
        expect(req.url.path, '/api/v1/session');
        expect(req.headers['x-musicdna-interview-flow'], 'checkpoints-v1');
        return http.Response(
          jsonEncode({
            'session_id': 's',
            'lane': 'rock',
            'lane_confidence': 0,
            'flow': 'checkpoints',
          }),
          200,
        );
      });
      addTearDown(client.close);
      final repo = OnboardingRepositoryImpl(
        OnboardingRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://example.invalid',
            accessTokenProvider: () async => 'owner',
            httpClient: client,
          ),
        ),
      );
      final session = await repo.submitOpeningThree(
        songs: ['One', 'Two', 'Three'],
      );
      expect(session.flow, InterviewFlow.checkpoints);
      expect(
        StartedMusicSession.fromJson(session.toJson())?.flow,
        InterviewFlow.checkpoints,
      );
    },
  );
}
