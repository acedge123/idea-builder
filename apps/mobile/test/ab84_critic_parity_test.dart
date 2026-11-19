import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_dna/src/features/session/data/session_resume_store.dart';
import 'package:music_dna/src/features/session/domain/entities/critic_stage_policy.dart';
import 'package:music_dna/src/features/session/domain/entities/critic_wait_queue.dart';
import 'package:music_dna/src/features/session/domain/entities/interview_flow.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/domain/repositories/saved_reading_repository.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/features/session/presentation/widgets/interview_preparation_view.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_critic_stage.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_pairing_card.dart';
import 'package:music_dna/src/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/onboarding_reaction.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'onboarding_cubit_test.dart' show FakeOnboardingRepository;
import 'critic_wait_contract_test.dart' show copy, pair;
import 'session_checkpoint_flow_test.dart' show CheckpointRepository;
import 'session_result_test.dart' show start, reveal;

class ParityRepository extends CheckpointRepository {
  Completer<SessionReveal>? revealGate;
  Object? revealError;
  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) async {
    early.add(finishEarly);
    revealCalls++;
    if (revealError != null) throw revealError!;
    return revealGate?.future ?? reveal;
  }

  SessionCubit withCopy({SessionResumeStore? store}) => SessionCubit(
    this,
    startedSession: start,
    experienceRepository: this,
    criticRepository: this,
    resultRepository: this,
    flowRepository: this,
    loadCriticCopy: () async => copy(),
    resumeStore: store,
  );
}

class SlowOpener extends FakeOnboardingRepository {
  SlowOpener()
    : super(
        reactions: const [
          OnboardingReaction(reaction: 'One'),
          OnboardingReaction(reaction: 'Two'),
        ],
      );
  final gate = Completer<StartedMusicSession>();
  @override
  Future<StartedMusicSession> submitOpeningThree({
    required List<String> songs,
  }) {
    expect(songs, ['True', 'Roxanne', 'Little Red Corvette']);
    return gate.future;
  }
}

Future<void> mountSession(WidgetTester tester, SessionCubit cubit) =>
    tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const SessionStubPage(shareBaseUrl: 'https://example.invalid'),
        ),
      ),
    );

void main() {
  test(
    'selection matches 117 cases evaluated by the actual pinned web functions',
    () {
      final oracle =
          jsonDecode(
                File('test/fixtures/critic-wait-web.json').readAsStringSync(),
              )
              as Map;
      expect(oracle['revision'], 'be86204ac616a46d148c53ca798ebbf16315c65d');
      for (final row in oracle['cases'] as List) {
        final flow = row['flow'] == 'checkpoints'
            ? InterviewFlow.checkpoints
            : InterviewFlow.perPick;
        final wait = row['answered'] as int;
        final budget = CriticStagePolicy.quipBudget(flow, wait);
        expect(budget, row['budget']);
        final decade = row['decade'] as String?;
        final year = decade == null ? null : int.parse(decade.substring(0, 4));
        expect(
          copy().waitingLines(
            wait,
            hunch: row['hunch'] as String?,
            pairing: year == null ? null : pair(year, year + 9),
            budget: budget,
            used: Set<String>.from(row['used'] as List),
          ),
          row['expected'],
          reason: '$row',
        );
      }
    },
  );

  test(
    'late hunch leaves the displayed opener and an already-started joke intact',
    () {
      final queue = CriticWaitQueue(copy: copy(), wait: 2, budget: 3, used: {});
      final first = queue.line;
      queue.updateHunch('against');
      expect(queue.line, first);
      expect(queue.advance(), 'Somebody raised you right.');
      queue.updateHunch('with');
      expect(queue.advance(), 'Or you rebelled perfectly.');
      expect(queue.canAdvance, isFalse);
      final partial = CriticWaitQueue(
        copy: copy(),
        wait: 2,
        budget: 3,
        used: {copy().neutral[2], copy().person[2][0]},
      );
      expect(
        partial.line,
        isNull,
        reason: 'A used setup never leaves its orphaned punchline',
      );
    },
  );

  test('displayed history is owner and interview scoped', () async {
    SharedPreferences.setMockInitialValues({});
    String? owner = 'owner-a';
    final store = SessionResumeStore(currentOwner: () => owner);
    await store.saveCriticLines('interview-a', {'Actually shown'});
    expect(await store.loadCriticLines('interview-a'), {'Actually shown'});
    expect(await store.loadCriticLines('interview-b'), isEmpty);
    owner = 'owner-b';
    expect(await store.loadCriticLines('interview-a'), isEmpty);
    owner = null;
    await store.saveCriticLines('interview-a', {'No owner'});
    expect(await store.loadCriticLines('interview-a'), isEmpty);
  });

  testWidgets('third-song preparation uses shared copy and adds no dwell', (
    tester,
  ) async {
    final repo = SlowOpener();
    final cubit = OnboardingCubit(repo, loadCriticCopy: () async => copy());
    addTearDown(cubit.close);
    await tester.pump();
    await cubit.submitSong(song: 'True');
    await cubit.submitSong(song: 'Roxanne');
    final last = cubit.submitSong(song: 'Little Red Corvette');
    expect(cubit.state.stage, OnboardingStage.submitting);
    expect(cubit.state.preparationLine, 'Noted.');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InterviewPreparationView(line: cubit.state.preparationLine),
        ),
      ),
    );
    expect(find.text(CriticStagePolicy.preparingTitle), findsOneWidget);
    expect(find.text('Noted.'), findsOneWidget);
    repo.gate.complete(start);
    await last;
    expect(cubit.state.stage, OnboardingStage.success);
  });

  test(
    'optional preparation copy cannot block onboarding or undo success',
    () async {
      final repo = SlowOpener();
      final pendingCopy = Completer<CriticFillers>();
      final cubit = OnboardingCubit(
        repo,
        loadCriticCopy: () => pendingCopy.future,
      );
      addTearDown(cubit.close);
      await cubit.submitSong(song: 'True');
      await cubit.submitSong(song: 'Roxanne');
      final last = cubit.submitSong(song: 'Little Red Corvette');
      repo.gate.complete(start);
      await last;
      expect(cubit.state.stage, OnboardingStage.success);
      pendingCopy.completeError(Exception('No copy available'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.stage, OnboardingStage.success);
    },
  );

  testWidgets('preparation does not rotate or delay a ready first pairing', (
    tester,
  ) async {
    final repo = ParityRepository()..nextGate = Completer<SessionRoundState>();
    final cubit = repo.withCopy();
    addTearDown(cubit.close);
    final init = cubit.initialize();
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const SessionStubPage(shareBaseUrl: 'https://example.invalid'),
        ),
      ),
    );
    expect(find.byType(InterviewPreparationView), findsOneWidget);
    expect(find.text(CriticStagePolicy.preparingTitle), findsOneWidget);
    expect(find.text('Noted.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Noted.'), findsOneWidget);
    repo.nextGate!.complete(repo.round());
    await init;
    await tester.pump();
    expect(find.byType(InterviewPreparationView), findsNothing);
    expect(find.byType(SessionSongChoiceCard), findsNWidgets(2));
  });

  testWidgets(
    'odd-pick quip stays neutral and dwells from tap, not hunch/save',
    (tester) async {
      final repo = ParityRepository();
      final cubit = repo.withCopy();
      addTearDown(cubit.close);
      await cubit.initialize();
      repo.saveGate = Completer<void>();
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      expect(cubit.state.criticWaitLine, 'Writing that down.');
      await tester.pump(const Duration(seconds: 2));
      repo.saveGate!.complete();
      await choice;
      expect(cubit.state.criticWaitLine, 'Writing that down.');
      expect(cubit.state.status, SessionStatus.critic);
      await tester.pump(const Duration(milliseconds: 499));
      expect(cubit.state.status, SessionStatus.critic);
      await tester.pump(const Duration(milliseconds: 1));
      expect(cubit.state.status, SessionStatus.ready);
      expect(repo.readRequests, isEmpty);
    },
  );

  testWidgets('a slow save adds no second 2.5-second hold', (tester) async {
    final repo = ParityRepository();
    final cubit = repo.withCopy();
    addTearDown(cubit.close);
    await cubit.initialize();
    repo.saveGate = Completer<void>();
    final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
    await tester.pump(const Duration(seconds: 6));
    repo.saveGate!.complete();
    await choice;
    expect(cubit.state.status, SessionStatus.ready);
    expect(repo.choiceCalls, 1);
  });

  testWidgets(
    'a ready checkpoint interrupts quips immediately and preserves Next control',
    (tester) async {
      final repo = ParityRepository()..answered = 1;
      final cubit = repo.withCopy();
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      await tester.pump(const Duration(milliseconds: 100));
      repo.reads[2]!.complete(
        const SessionRead(thesis: 'Actual Critic, not a quip'),
      );
      await tester.pump();
      expect(cubit.state.isCheckpoint, isTrue);
      expect(cubit.state.criticWaitLine, isNull);
      expect(cubit.state.read?.thesis, 'Actual Critic, not a quip');
      expect(cubit.state.currentRound?.pairing?.id, 'pair-2');
      cubit.continueCheckpoint();
      expect(cubit.state.currentRound?.pairing?.id, 'pair-3');
      expect(cubit.state.read, isNull);
    },
  );

  testWidgets(
    'final wait keeps its tap context and clock across save/next/reveal, then stops',
    (tester) async {
      final repo = ParityRepository()..answered = 5;
      repo.revealGate = Completer<SessionReveal>();
      SharedPreferences.setMockInitialValues({});
      final store = SessionResumeStore(currentOwner: () => 'owner-a');
      await store.saveCriticLines(start.sessionId, {'Noted.'});
      final cubit = repo.withCopy(store: store);
      addTearDown(cubit.close);
      await cubit.initialize();
      await mountSession(tester, cubit);
      repo.saveGate = Completer<void>();
      repo.nextGate = Completer<SessionRoundState>();
      final shown = <String>[];
      final sub = cubit.stream.listen((s) {
        if (s.criticWaitLine != null &&
            (shown.isEmpty || shown.last != s.criticWaitLine)) {
          shown.add(s.criticWaitLine!);
        }
      });
      addTearDown(sub.cancel);
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      final opener = cubit.state.criticWaitLine;
      await tester.pump(const Duration(seconds: 2));
      repo.saveGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(cubit.state.criticWaitLine, isNot(opener));
      final second = cubit.state.criticWaitLine;
      repo.nextGate!.complete(repo.round());
      await tester.pump();
      expect(cubit.state.status, SessionStatus.revealing);
      expect(cubit.state.criticWaitLine, second);
      expect(cubit.state.criticPickedTitle, 'First song 6');
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 2500));
      }
      expect(shown.length, greaterThan(4));
      expect(shown.toSet().length, shown.length);
      expect(
        shown,
        isNot(contains('Noted.')),
        reason: 'Already displayed at preparation',
      );
      repo.revealGate!.complete(reveal);
      await choice;
      final count = shown.length;
      await tester.pump(const Duration(seconds: 10));
      expect(shown.length, count);
      expect(cubit.state.status, SessionStatus.revealed);
      expect(repo.revealCalls, 1);
    },
  );

  testWidgets('a stale reveal cannot paint or cancel a newer final wait', (
    tester,
  ) async {
    final repo = ParityRepository()..answered = 5;
    final oldGate = Completer<SessionReveal>();
    repo.revealGate = oldGate;
    final cubit = repo.withCopy();
    addTearDown(cubit.close);
    await cubit.initialize();
    final oldChoice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
    await tester.pump();
    expect(cubit.state.status, SessionStatus.revealing);
    final newGate = Completer<SessionReveal>();
    repo.revealGate = newGate;
    final resumed = cubit.initialize();
    await tester.pump();
    final line = cubit.state.criticWaitLine;
    oldGate.complete(reveal);
    await oldChoice;
    expect(cubit.state.status, SessionStatus.revealing);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(cubit.state.criticWaitLine, isNot(line));
    newGate.complete(reveal);
    await resumed;
    expect(cubit.state.status, SessionStatus.revealed);
  });

  testWidgets(
    'final pending failure stops quips; explicit retry uses only unseen copy',
    (tester) async {
      final repo = ParityRepository()..answered = 5;
      repo.revealGate = Completer<SessionReveal>();
      final cubit = repo.withCopy();
      addTearDown(cubit.close);
      await cubit.initialize();
      await mountSession(tester, cubit);
      final first = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      await tester.pump();
      repo.revealGate!.completeError(const ReadingPendingException());
      await first;
      expect(cubit.state.status, SessionStatus.waitingForReading);
      final oldLine = cubit.state.criticWaitLine;
      await tester.pump(const Duration(seconds: 10));
      expect(cubit.state.criticWaitLine, oldLine);
      repo.revealError = null;
      repo.revealGate = Completer<SessionReveal>();
      final retry = cubit.revealSession();
      expect(cubit.state.status, SessionStatus.revealing);
      expect(cubit.state.criticWaitLine, isNot(oldLine));
      repo.revealGate!.complete(reveal);
      await retry;
      expect(repo.choiceCalls, 1);
      expect(cubit.state.status, SessionStatus.revealed);
    },
  );

  testWidgets('resume persists only displayed lines, not the unused queue', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionResumeStore(currentOwner: () => 'owner-a');
    final repo = ParityRepository()..answered = 1;
    await store.saveCriticLines(start.sessionId, {'Noted.'});
    final cubit = repo.withCopy(store: store);
    await cubit.initialize();
    await mountSession(tester, cubit);
    await cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
    // Exit before setup/punchline has ever been displayed.
    await tester.pump();
    await cubit.close();
    final used = await store.loadCriticLines(start.sessionId);
    expect(used, {'Noted.', 'Filing that away…'});
    final resumed = repo.withCopy(store: store);
    addTearDown(resumed.close);
    await resumed.initialize();
    expect(resumed.state.isCheckpoint, isTrue);
    final retry = resumed.retryCheckpointRead();
    expect(resumed.state.criticWaitLine, 'Somebody raised you right.');
    await tester.pump(const Duration(milliseconds: 2500));
    expect(resumed.state.criticWaitLine, 'Or you rebelled perfectly.');
    repo.reads[2]!.complete(const SessionRead(thesis: 'Restored checkpoint'));
    await retry;
  });

  testWidgets(
    'final activity survives pool exhaustion, reduced motion and large text',
    (tester) async {
      final c = copy();
      final exhausted = c.waitingLines(
        6,
        budget: null,
        used: {...c.neutral, ...c.person.expand((x) => x)},
      );
      expect(exhausted, isEmpty);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SessionCriticStage(
                  state: const SessionState(status: SessionStatus.revealing),
                  onRetryNext: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(CriticStagePolicy.writingTitle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
