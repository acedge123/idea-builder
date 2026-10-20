import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'session_cubit_test.dart' show FakeSessionRepository;
import 'session_result_test.dart' show ResultRepository;
import 'package:flutter_test/flutter_test.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_experience_view.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_pairing_card.dart';

const pairing = SessionPairing(
  id: 'pairing',
  tests: [],
  songA: SessionPairingSong(
    id: 'a',
    title: 'A very long song title that wraps across the phone',
    artist: 'Artist A',
    primaryLane: 'hidden-lane-a',
    year: 1995,
  ),
  songB: SessionPairingSong(
    id: 'b',
    title: 'Another song',
    artist: 'Artist B',
    primaryLane: 'hidden-lane-b',
    year: 2001,
  ),
);

Widget host(Widget child, {double scale = 1, bool reduceMotion = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
    );

void main() {
  test(
    'exchange grouping retains reads, skips and reactions in server order',
    () {
      final at = DateTime.utc(2026, 10, 20);
      final exchanges = [
        SessionExchange(type: 'choice', at: at, pairingId: 'one'),
        SessionExchange(
          type: 'read',
          at: at,
          read: const SessionRead(thesis: 'First'),
        ),
        SessionExchange(type: 'reaction', at: at, reaction: 'not_quite'),
        SessionExchange(type: 'skip', at: at, pairingId: 'skip'),
        SessionExchange(type: 'choice', at: at, pairingId: 'two'),
        SessionExchange(
          type: 'read',
          at: at,
          read: const SessionRead(thesis: 'Second'),
        ),
      ];
      final groups = groupSessionExchanges(exchanges);
      expect(groups.length, 3);
      expect(groups.first.exchanges, exchanges.take(3));
      expect(groups.first.hasReaction, isTrue);
      expect(groups.last.exchanges.last.read?.thesis, 'Second');
    },
  );

  testWidgets('advancing scrolls to latest exchange below a long opening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = _PresentationCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: const SessionStubPage(shareBaseUrl: 'https://example.invalid'),
        ),
      ),
    );
    cubit.show(
      SessionState(
        status: SessionStatus.ready,
        startedSession: StartedMusicSession(
          sessionId: 's',
          sessionLane: '',
          sessionLaneConfidence: 0,
          analysisLane: '',
          analysisConfidence: 0,
          hypothesis: List.filled(30, 'Long opening.').join(' '),
          reaction: '',
          reasoning: const [],
          secondaryLanes: const [],
          songs: const ['One', 'Two', 'Three'],
        ),
        currentRound: const SessionRoundState(
          sessionId: 's',
          round: 2,
          confidence: 0,
          done: false,
          pairing: pairing,
          experienceVersion: true,
          prompt: 'The actual next question',
        ),
        exchanges: [
          SessionExchange(
            type: 'choice',
            at: DateTime.utc(2026),
            feedback: 'Latest saved feedback',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final y = tester.getTopLeft(find.text('Latest saved feedback')).dy;
    expect(y, greaterThanOrEqualTo(0));
    expect(y, lessThan(300));
    expect(find.text('The actual next question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('acknowledged feedback remains visible when next pairing fails', (
    tester,
  ) async {
    final cubit = _PresentationCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: const SessionStubPage(shareBaseUrl: 'https://example.invalid'),
        ),
      ),
    );
    cubit.show(
      const SessionState(
        status: SessionStatus.failure,
        selectedSongId: 'a',
        currentRound: SessionRoundState(
          sessionId: 's',
          round: 1,
          confidence: 0,
          done: false,
          pairing: pairing,
        ),
        lastFeedback: SessionChoiceFeedback(
          verdict: 'Committed verdict',
          why: 'Saved explanation',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Committed verdict'), findsOneWidget);
    expect(find.text('Saved explanation'), findsOneWidget);
    expect(find.text('✓ Your choice'), findsOneWidget);
  });

  test('reaction completion automatically loads the saved result', () async {
    final repository = _CompletingReactionRepository();
    final cubit = SessionCubit(
      repository,
      experienceRepository: repository,
      resultRepository: repository,
      startedSession: const StartedMusicSession(
        sessionId: 'session-1',
        sessionLane: '',
        sessionLaneConfidence: 0,
        analysisLane: '',
        analysisConfidence: 0,
        hypothesis: '',
        reaction: '',
        reasoning: [],
        secondaryLanes: [],
        songs: [],
      ),
    );
    addTearDown(cubit.close);
    await cubit.initialize();
    await cubit.react(SessionReaction.harder);
    expect(cubit.state.status, SessionStatus.revealed);
    expect(repository.revealCalls, 1);
  });

  testWidgets(
    'latest feedback and read stay visible once; older choices expand',
    (tester) async {
      final at = DateTime.utc(2026, 10, 20);
      const latest = SessionRead(thesis: 'Exact saved theory', tier: 'theory');
      await tester.pumpWidget(
        host(
          SessionExperienceView(
            exchanges: [
              SessionExchange(
                type: 'choice',
                at: at,
                feedback: 'Earlier verdict',
              ),
              SessionExchange(
                type: 'read',
                at: at,
                read: const SessionRead(thesis: 'Earlier theory'),
              ),
              SessionExchange(
                type: 'choice',
                at: at,
                feedback: 'Latest verdict',
              ),
              SessionExchange(type: 'read', at: at, read: latest),
            ],
            read: latest,
            busy: false,
            onReaction: (_) {},
          ),
        ),
      );
      expect(find.text('Exact saved theory'), findsOneWidget);
      expect(find.text('Latest verdict'), findsOneWidget);
      expect(find.text('Earlier verdict'), findsNothing);
      await tester.tap(find.text('Earlier choices (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Earlier verdict'), findsOneWidget);
      expect(find.text('Earlier theory'), findsOneWidget);
    },
  );

  testWidgets(
    'recorded reaction restores its label and removes submit controls',
    (tester) async {
      final at = DateTime.utc(2026, 10, 20);
      await tester.pumpWidget(
        host(
          SessionExperienceView(
            exchanges: [
              SessionExchange(
                type: 'read',
                at: at,
                read: const SessionRead(thesis: 'Stored'),
              ),
              SessionExchange(type: 'reaction', at: at, reaction: 'not_quite'),
            ],
            read: const SessionRead(thesis: 'Stored'),
            busy: false,
            onReaction: (_) {},
          ),
        ),
      );
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    },
  );

  testWidgets('revision exposes provenance and the stored follow-up', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SessionReadView(
          read: SessionRead(
            thesis: 'Exact changed interpretation',
            direction: 'revising',
            previousClaim: 'Earlier claim',
            changedBy: 'A over B',
            question: 'Old question must not drive the next pairing',
            supporting: 3,
            tested: 4,
          ),
        ),
      ),
    );
    expect(find.text('REVISING THE READ'), findsOneWidget);
    expect(find.text('Earlier: Earlier claim'), findsOneWidget);
    expect(find.text('Changed by A over B.'), findsOneWidget);
    expect(find.textContaining('Old question'), findsOneWidget);
  });

  testWidgets(
    'selected card is semantic, retained and alternative disabled at 320px/200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final taps = <String>[];
      await tester.pumpWidget(
        host(
          SessionPairingCard(
            pairing: pairing,
            isBusy: false,
            selectedSongId: 'a',
            onChoose: taps.add,
            onSkip: () {},
          ),
          scale: 2,
          reduceMotion: true,
        ),
      );
      expect(find.textContaining('hidden-lane'), findsNothing);
      expect(find.text('✓ Your choice'), findsOneWidget);
      final card = tester.getSemantics(
        find.byType(SessionSongChoiceCard).first,
      );
      expect(card.flagsCollection.isSelected, Tristate.isTrue);
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
            .duration,
        Duration.zero,
      );
      await tester.ensureVisible(find.text('Another song'));
      await tester.tap(find.text('Another song'));
      expect(taps, isEmpty);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}

class _PresentationCubit extends SessionCubit {
  _PresentationCubit() : super(FakeSessionRepository());
  @override
  bool get hasExperience => true;
  void show(SessionState state) => emit(state);
}

class _CompletingReactionRepository extends ResultRepository {
  @override
  Future<SessionRoundState> fetchNextPairing({
    required String sessionId,
  }) async => SessionRoundState(
    sessionId: sessionId,
    round: 4,
    confidence: 0,
    done: false,
    pairing: pairing,
    experienceVersion: true,
  );
  @override
  Future<SessionReactionEffect> react({
    required String sessionId,
    required SessionReaction reaction,
    required String mutationId,
    String? pairingId,
  }) async => SessionReactionEffect(
    effect: 'completed',
    message: 'Saved completion',
    next: SessionRoundState(
      sessionId: sessionId,
      round: 4,
      confidence: 0,
      done: true,
      experienceVersion: true,
    ),
  );
}
