import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:music_dna/src/features/session/domain/entities/critic_stage_policy.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_critic_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/core/widgets/music_thinking_view.dart';
import 'package:music_dna/src/features/ai_permission/domain/ai_permission_service.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/data/repositories/session_repository_impl.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/domain/entities/session_result.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_critic_repository.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_experience_repository.dart';
import 'package:music_dna/src/features/session/domain/repositories/session_result_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_pairing_card.dart';
import 'session_cubit_test.dart' show FakeSessionRepository;
import 'session_result_test.dart' show start, reveal;

class FlowRepository extends FakeSessionRepository
    implements
        SessionExperienceRepository,
        SessionCriticRepository,
        SessionResultRepository {
  int answered = 0, choiceCalls = 0, revealCalls = 0;
  final reads = <int, Completer<SessionRead>>{};
  Completer<void>? saveGate;
  Completer<SessionExperience>? historyGate;
  Completer<SessionRoundState>? nextGate;
  bool inline = false;
  SessionCubit cubit() => SessionCubit(
    this,
    startedSession: start,
    experienceRepository: this,
    criticRepository: this,
    resultRepository: this,
    loadCriticCopy: () async => CriticFillers.fromJson(
      jsonDecode(File('assets/copy/critic-fillers.json').readAsStringSync())
          as Map<String, dynamic>,
    ),
  );
  SessionRoundState round() => SessionRoundState(
    sessionId: start.sessionId,
    round: answered + 1,
    confidence: 0,
    done: answered == 6,
    experienceVersion: true,
    maxAnswered: 6,
    pairing: answered == 6
        ? null
        : SessionPairing(
            id: 'pair-${answered + 1}',
            tests: const [],
            songA: SessionPairingSong(
              id: 'a',
              title: 'First song ${answered + 1}',
              artist: 'First artist',
            ),
            songB: SessionPairingSong(
              id: 'b',
              title: 'Second song ${answered + 1}',
              artist: 'Second artist',
            ),
          ),
  );
  @override
  Future<SessionRoundState> fetchNextPairing({
    required String sessionId,
  }) async => nextGate?.future ?? round();
  @override
  Future<SessionChoiceFeedback> submitChoice({
    required String sessionId,
    required String pairingId,
    required String chosenSongId,
    required int msToDecide,
  }) async {
    choiceCalls++;
    await saveGate?.future;
    answered++;
    return SessionChoiceFeedback(
      verdict: 'Saved choice',
      why: 'Exact saved acknowledgement',
      readPending: !inline,
      read: inline ? const SessionRead(thesis: 'New inline Critic') : null,
    );
  }

  @override
  Future<SessionExperience> fetchExperience({
    required String sessionId,
  }) async =>
      historyGate?.future ??
      SessionExperience(sessionId: sessionId, exchanges: const []);
  @override
  Future<SessionRead> fetchRead({
    required String sessionId,
    required String afterPairingId,
    required int answered,
  }) {
    if (afterPairingId != 'pair-$answered') {
      throw StateError('Fake read cursor mismatch');
    }
    return reads.putIfAbsent(answered, () => Completer<SessionRead>()).future;
  }

  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) async {
    revealCalls++;
    expect(finishEarly, isFalse);
    return reveal;
  }

  @override
  Future<SharePublication> setPublication({
    required String sessionId,
    required bool publish,
  }) async => const SharePublication(isPublic: false);
  @override
  Future<SessionReactionEffect> react({
    required String sessionId,
    required SessionReaction reaction,
    required String mutationId,
    String? pairingId,
  }) async => throw UnimplementedError();
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'old inline response never flashes new prose over the selected old pairing',
    () async {
      final repo = FlowRepository()..inline = true;
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      final states = <SessionState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);
      repo.nextGate = Completer<SessionRoundState>();
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 70);
      await flush();
      expect(cubit.state.status, SessionStatus.critic);
      expect(cubit.state.currentRound?.pairing?.id, 'pair-1');
      repo.nextGate!.complete(repo.round());
      await choice;
      await flush();
      expect(cubit.state.currentRound?.pairing?.id, 'pair-2');
      expect(cubit.state.read?.thesis, 'New inline Critic');
      expect(
        states
            .where((s) => s.read?.thesis == 'New inline Critic')
            .every(
              (s) =>
                  s.status == SessionStatus.critic ||
                  s.currentRound?.pairing?.id == 'pair-2',
            ),
        isTrue,
      );
    },
  );
  test(
    'next pairing stays hidden and untappable until the exact Critic read arrives',
    () async {
      final repo = FlowRepository();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.chooseSong(chosenSongId: 'a', msToDecide: 40);
      expect(cubit.state.status, SessionStatus.critic);
      expect(cubit.state.currentRound?.pairing?.id, 'pair-1');
      expect(cubit.state.prefetchedRound?.pairing?.id, 'pair-2');
      await cubit.chooseSong(chosenSongId: 'b', msToDecide: 60);
      expect(repo.choiceCalls, 1);
      repo.reads[1]!.complete(
        const SessionRead(thesis: 'Latest exact response'),
      );
      await flush();
      expect(cubit.state.status, SessionStatus.ready);
      expect(cubit.state.currentRound?.pairing?.id, 'pair-2');
      expect(cubit.state.read?.thesis, 'Latest exact response');
      expect(cubit.state.criticPending, isFalse);
    },
  );
  test(
    'history and narration failures cannot invalidate a saved choice or force a retry',
    () async {
      final repo = FlowRepository();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      repo.historyGate = Completer<SessionExperience>();
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 10);
      await flush();
      expect(cubit.state.status, SessionStatus.critic);
      expect(cubit.state.prefetchedRound?.pairing?.id, 'pair-2');
      repo.reads[1]!.completeError(TimeoutException('unknown model outcome'));
      repo.historyGate!.completeError(Exception('history unavailable'));
      await choice;
      await flush();
      expect(cubit.state.status, SessionStatus.ready);
      expect(cubit.state.criticMessage, CriticStagePolicy.unavailable);
      expect(repo.choiceCalls, 1);
      repo.historyGate = null;
      await cubit.chooseSong(chosenSongId: 'b', msToDecide: 30);
      expect(repo.choiceCalls, 2);
    },
  );
  test(
    'six choices flow directly into one final report with no checkpoints or last-pick narration',
    () async {
      final repo = FlowRepository();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      for (var i = 0; i < 6; i++) {
        expect(cubit.state.visibleMilestone, isNull);
        await cubit.chooseSong(chosenSongId: 'a', msToDecide: 10);
        if (i < 5) {
          repo.reads[i + 1]!.complete(const SessionRead(thesis: 'Exact read'));
          await flush();
          expect(cubit.state.status, SessionStatus.ready);
        }
      }
      expect(repo.choiceCalls, 6);
      expect(repo.revealCalls, 1);
      expect(repo.reads.keys, [1, 2, 3, 4, 5]);
      expect(cubit.state.status, SessionStatus.revealed);

      await flush();
      expect(cubit.state.reveal, reveal);
      expect(cubit.state.status, SessionStatus.revealed);
    },
  );
  test(
    'double tap while saving is ignored and completion after close never emits',
    () async {
      final repo = FlowRepository();
      final cubit = repo.cubit();
      await cubit.initialize();
      repo.saveGate = Completer<void>();
      final first = cubit.chooseSong(chosenSongId: 'a', msToDecide: 10);
      await cubit.chooseSong(chosenSongId: 'b', msToDecide: 10);
      expect(repo.choiceCalls, 1);
      await cubit.close();
      repo.saveGate!.complete();
      await first;
    },
  );
  test(
    'REST separates a durable acknowledgement from narration and checks its response binding',
    () async {
      final calls = <http.Request>[];
      var wrongPosition = false;
      final client = MockClient((r) async {
        calls.add(r);
        return http.Response(
          jsonEncode(
            r.url.path.endsWith('/choice')
                ? {
                    'contract': 1,
                    'feedback': {'verdict': 'Saved', 'why': 'Exact'},
                    'read': null,
                    'read_pending': true,
                  }
                : {
                    'contract': 1,
                    'after_pairing_id': wrongPosition ? 'other' : 'p',
                    'answered': 2,
                    'read': {'thesis': 'Exact shared writer text'},
                  },
          ),
          200,
        );
      });
      addTearDown(client.close);
      final repo = SessionRepositoryImpl(
        SessionRemoteDataSource(
          MusicDnaApiClient(
            baseUrl: 'https://example.invalid',
            accessTokenProvider: () async => 'owner-token',
            httpClient: client,
          ),
          experienceV1: true,
        ),
      );
      expect(
        (await repo.submitChoice(
          sessionId: 's',
          pairingId: 'p',
          chosenSongId: 'a',
          msToDecide: 10,
        )).readPending,
        isTrue,
      );
      expect(jsonDecode(calls.first.body)['defer_read'], isTrue);
      expect(
        (await repo.fetchRead(
          sessionId: 's',
          afterPairingId: 'p',
          answered: 2,
        )).thesis,
        'Exact shared writer text',
      );
      expect(jsonDecode(calls.last.body), {
        'after_pairing_id': 'p',
        'answered': 2,
      });
      expect(calls.last.headers['authorization'], 'Bearer owner-token');
      expect(
        AiPermissionService.requiresPermission(
          'POST',
          '/api/v1/session/s/read',
        ),
        isTrue,
      );
      wrongPosition = true;
      await expectLater(
        repo.fetchRead(sessionId: 's', afterPairingId: 'p', answered: 2),
        throwsException,
      );
    },
  );
  testWidgets(
    'Critic-only stage hides old and new cards; read and next pairing appear together',
    (tester) async {
      final repo = FlowRepository();
      final cubit = repo.cubit();
      addTearDown(cubit.close);
      await cubit.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SessionCubit>.value(
            value: cubit,
            child: const SessionStubPage(
              shareBaseUrl: 'https://example.invalid',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.saveGate = Completer<void>();
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 10);
      await tester.pump();
      await tester.pump();
      expect(find.byType(SessionSongChoiceCard), findsNothing);
      expect(find.text('YOU PICKED · First song 1'), findsOneWidget);
      expect(find.byType(SessionCriticStage), findsOneWidget);
      repo.saveGate!.complete();
      await choice;
      await tester.pump();
      expect(find.byType(SessionSongChoiceCard), findsNothing);
      expect(find.text('Writing that down.'), findsOneWidget);
      expect(find.text('Next matchup'), findsNothing);
      repo.reads[1]!.complete(const SessionRead(thesis: 'Late exact prose'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SessionSongChoiceCard), findsNWidgets(2));
      expect(find.text('First song 1'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Late exact prose')).dy,
        lessThan(tester.getTopLeft(find.text('First song 2')).dy),
      );
      expect(find.text('Late exact prose'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'thinking design supports reduced motion and large text without implying progress',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MusicThinkingView(
                  title: 'Writing your reading',
                  body: 'Your choices are saved.',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Writing your reading'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
