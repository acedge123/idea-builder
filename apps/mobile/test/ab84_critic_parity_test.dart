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
import 'critic_wait_contract_test.dart' show copy, pair, bundle;
import 'session_checkpoint_flow_test.dart' show CheckpointRepository;
import 'session_result_test.dart' show start, reveal;

class ParityRepository extends CheckpointRepository {
  Completer<SessionReveal>? revealGate;
  Object? revealError;
  CriticFillers? customCopy;
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
    loadCriticCopy: () async => customCopy ?? copy(),
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
    'selection matches the current web oracle including displayed-history fallback',
    () {
      final oracle =
          jsonDecode(
                File('test/fixtures/critic-wait-web.json').readAsStringSync(),
              )
              as Map;
      expect(oracle['revision'], '3fa9a4273fd4b954312af2ad677e0d2df8252b9a');
      for (final row in oracle['cases'] as List) {
        final flow = row['flow'] == 'checkpoints'
            ? InterviewFlow.checkpoints
            : InterviewFlow.perPick;
        final wait = row['answered'] as int;
        final budget = CriticStagePolicy.quipBudget(
          flow,
          wait,
          finalReading: row['final_reading'] == true,
        );
        expect(budget, row['budget']);
        final decade = row['decade'] as String?;
        final year = decade == null ? null : int.parse(decade.substring(0, 4));
        expect(
          copy().waitingLines(
            wait,
            hunch: row['hunch'] as String?,
            finalReading: row['final_reading'] == true,
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
    'reaction-first waits stay empty until a saved hunch; started jokes stay intact',
    () {
      for (final pick in [2, 3]) {
        final queue = CriticWaitQueue(
          copy: copy(),
          wait: pick,
          budget: pick == 2 ? 3 : 1,
          used: {},
        );
        expect(queue.line, isNull);
        queue.updateHunch('against');
        expect(queue.line, copy().reaction['against']![pick]);
      }
      final queue = CriticWaitQueue(
        copy: copy(),
        wait: 2,
        hunch: 'against',
        budget: 3,
        used: {},
      );
      queue.advance();
      expect(queue.line, 'Somebody raised you right.');
      queue.acknowledgePaint(queue.line!);
      queue.updateHunch('with');
      expect(queue.advance(), 'Or you rebelled perfectly.');
      expect(queue.canAdvance, isFalse);
      final partial = CriticWaitQueue(
        copy: copy(),
        wait: 2,
        hunch: 'early',
        budget: 3,
        used: {copy().reaction['early']![2], copy().person[2][0]},
      );
      expect(partial.line, isNot(copy().reaction['early']![2]));
      expect(partial.advance(), copy().person[0].first);
      expect(partial.advance(), copy().person[0].last);
      expect(partial.canAdvance, isFalse);
    },
  );

  testWidgets('line dwell starts on paint and late timers never catch up', (
    tester,
  ) async {
    final repo = ParityRepository()..answered = 3;
    final cubit = repo.withCopy();
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
    final first = cubit.state.criticWaitLine;
    await tester.pump(const Duration(seconds: 5));
    expect(
      cubit.state.criticWaitLine,
      first,
      reason: 'Selection is not a paint',
    );
    cubit.acknowledgeCriticLine(first!);
    await tester.pump(const Duration(milliseconds: 2499));
    expect(cubit.state.criticWaitLine, first);
    // Duplicate rebuild acknowledgements cannot restart this beat.
    cubit.acknowledgeCriticLine(first);
    await tester.pump(const Duration(milliseconds: 1));
    expect(cubit.state.criticWaitLine, copy().reaction['early']![4]);
    cubit.acknowledgeCriticLine(cubit.state.criticWaitLine!);
    await tester.pump(const Duration(seconds: 10));
    expect(cubit.state.criticWaitLine, "Dig it. We'll let you cook.");
    repo.reads[4]!.complete(
      const SessionRead(thesis: 'Ready before that line paints'),
    );
    await tester.pump();
    expect(cubit.state.criticPending, isFalse);
  });

  testWidgets(
    'picks 2 and 3 show activity until a durable hunch, with no neutral flash',
    (tester) async {
      for (final pick in [2, 3]) {
        final repo = ParityRepository()..answered = pick - 1;
        final cubit = repo.withCopy();
        await cubit.initialize();
        if (cubit.state.isCheckpoint) cubit.continueCheckpoint();
        await mountSession(tester, cubit);
        repo.saveGate = Completer<void>();
        final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
        await tester.pump();
        expect(cubit.state.criticWaitLine, isNull);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        expect(cubit.state.criticWaitLine, isNull);
        repo.saveGate!.complete();
        await choice;
        await tester.pump();
        expect(cubit.state.criticWaitLine, copy().reaction['early']![pick]);
        if (pick == 3) {
          await tester.pump(const Duration(milliseconds: 2499));
          expect(cubit.state.status, SessionStatus.critic);
          await tester.pump(const Duration(milliseconds: 1));
          expect(cubit.state.status, SessionStatus.ready);
        }
        await cubit.close();
      }
    },
  );

  testWidgets(
    'ready Critic finishes only an already-painted setup and full punchline beat',
    (tester) async {
      final repo = ParityRepository()..answered = 1;
      final cubit = repo.withCopy();
      addTearDown(cubit.close);
      await cubit.initialize();
      await mountSession(tester, cubit);
      await cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, 'Somebody raised you right.');
      repo.reads[2]!.complete(
        const SessionRead(thesis: 'Ready evidence-bound read'),
      );
      await tester.pump();
      expect(cubit.state.criticPending, isTrue);
      expect(cubit.state.read, isNull);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, 'Or you rebelled perfectly.');
      await tester.pump(const Duration(milliseconds: 2499));
      expect(cubit.state.criticPending, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(cubit.state.criticPending, isFalse);
      expect(cubit.state.read?.thesis, 'Ready evidence-bound read');
      expect(cubit.state.isCheckpoint, isTrue);
    },
  );

  testWidgets(
    'ready final report finishes a compatible two-line person group without Overtime',
    (tester) async {
      final data = jsonDecode(bundle) as Map<String, dynamic>;
      (data['person'] as List)[6] = [
        'I\'m starting to like you.',
        "Don't make it weird.",
      ];
      final repo = ParityRepository()..answered = 5;
      repo.customCopy = CriticFillers.fromJson(data);
      repo.revealGate = Completer<SessionReveal>();
      final cubit = repo.withCopy();
      addTearDown(cubit.close);
      await cubit.initialize();
      await mountSession(tester, cubit);
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, "I'm starting to like you.");
      repo.revealGate!.complete(reveal);
      await tester.pump();
      expect(cubit.state.status, SessionStatus.revealing);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, "Don't make it weird.");
      await tester.pump(const Duration(milliseconds: 2499));
      expect(cubit.state.status, SessionStatus.revealing);
      await tester.pump(const Duration(milliseconds: 1));
      await choice;
      expect(cubit.state.status, SessionStatus.revealed);
    },
  );

  testWidgets('four-choice early finish never consumes Overtime', (
    tester,
  ) async {
    final repo = ParityRepository()..answered = 3;
    final cubit = repo.withCopy();
    addTearDown(cubit.close);
    await cubit.initialize();
    await mountSession(tester, cubit);
    await cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
    repo.reads[4]!.complete(const SessionRead(thesis: 'Four choices'));
    await tester.pump();
    repo.revealGate = Completer<SessionReveal>();
    final early = cubit.finishEarly();
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      expect(copy().overtime, isNot(contains(cubit.state.criticWaitLine)));
      await tester.pump(const Duration(milliseconds: 2500));
    }
    expect(cubit.state.status, SessionStatus.revealing);
    repo.revealGate!.complete(reveal);
    await early;
    expect(repo.early, [true]);
  });

  testWidgets('failed Critic interrupts a started joke immediately', (
    tester,
  ) async {
    final repo = ParityRepository()..answered = 1;
    final cubit = repo.withCopy();
    addTearDown(cubit.close);
    await cubit.initialize();
    await mountSession(tester, cubit);
    await cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    expect(cubit.state.criticWaitLine, 'Somebody raised you right.');
    repo.reads[2]!.completeError(Exception('unavailable'));
    await tester.pump();
    expect(cubit.state.criticPending, isFalse);
    expect(cubit.state.criticWaitLine, isNull);
    expect(cubit.state.criticMessage, CriticStagePolicy.checkpointUnavailable);
    await tester.pump(const Duration(seconds: 10));
    expect(cubit.state.criticWaitLine, isNull);
  });

  testWidgets(
    'next-offer failure stops a joke and retry does not repeat the vote or model',
    (tester) async {
      final repo = ParityRepository()..answered = 1;
      final cubit = repo.withCopy();
      addTearDown(cubit.close);
      await cubit.initialize();
      await mountSession(tester, cubit);
      repo.nextGate = Completer<SessionRoundState>();
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, 'Somebody raised you right.');
      repo.nextGate!.completeError(Exception('unavailable'));
      await choice;
      expect(cubit.state.criticWaitLine, isNull);
      expect(cubit.state.nextPairingError, isNotNull);
      repo.reads[2]!.complete(const SessionRead(thesis: 'Saved read'));
      await tester.pump();
      repo.nextGate = null;
      await cubit.retryNextMatchup();
      expect(repo.choiceCalls, 1);
      expect(repo.readRequests, [2]);
      expect(cubit.state.read?.thesis, 'Saved read');
      cubit.continueCheckpoint();
      expect(cubit.state.status, SessionStatus.ready);
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
      await mountSession(tester, cubit);
      repo.saveGate = Completer<void>();
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      expect(cubit.state.criticWaitLine, 'Writing that down.');
      await tester.pump();
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
    await mountSession(tester, cubit);
    repo.saveGate = Completer<void>();
    final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
    await tester.pump();
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
    'final six keeps tap clock; Overtime starts only during final writing and ends once',
    (tester) async {
      final repo = ParityRepository()..answered = 5;
      repo.revealGate = Completer<SessionReveal>();
      final cubit = repo.withCopy();
      addTearDown(cubit.close);
      await cubit.initialize();
      await mountSession(tester, cubit);
      repo.saveGate = Completer<void>();
      repo.nextGate = Completer<SessionRoundState>();
      final choice = cubit.chooseSong(chosenSongId: 'a', msToDecide: 1);
      final opener = cubit.state.criticWaitLine;
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      repo.saveGate!.complete();
      await tester.pump();
      expect(cubit.state.criticWaitLine, opener);
      await tester.pump(const Duration(milliseconds: 500));
      expect(cubit.state.criticWaitLine, 'Okay. Thinking.');
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, copy().person[0].first);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, copy().person[0].last);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(cubit.state.criticWaitLine, copy().person[0].last);
      expect(cubit.state.status, SessionStatus.critic);
      repo.nextGate!.complete(repo.round());
      await tester.pump();
      expect(cubit.state.status, SessionStatus.revealing);
      expect(cubit.state.criticPickedTitle, 'First song 6');
      await tester.pump();
      for (final line in copy().overtime) {
        expect(cubit.state.criticWaitLine, line);
        await tester.pump(const Duration(milliseconds: 2500));
      }
      await tester.pump(const Duration(seconds: 10));
      expect(cubit.state.criticWaitLine, copy().overtime.last);
      repo.revealGate!.complete(reveal);
      await choice;
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
    await mountSession(tester, cubit);
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
    expect(used, {'Noted.', 'Turning that one over…'});
    final resumed = repo.withCopy(store: store);
    addTearDown(resumed.close);
    await resumed.initialize();
    await mountSession(tester, resumed);
    expect(resumed.state.isCheckpoint, isTrue);
    final retry = resumed.retryCheckpointRead();
    expect(resumed.state.criticWaitLine, 'Running that back in my head.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    expect(resumed.state.criticWaitLine, 'Somebody raised you right.');
    await tester.pump(const Duration(milliseconds: 2500));
    expect(resumed.state.criticWaitLine, 'Or you rebelled perfectly.');
    repo.reads[2]!.complete(const SessionRead(thesis: 'Restored checkpoint'));
    await tester.pump(const Duration(milliseconds: 2500));
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
