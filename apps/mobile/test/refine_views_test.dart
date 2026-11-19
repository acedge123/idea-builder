import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_dna/src/core/theme/app_theme.dart';
import 'package:music_dna/src/features/auth/domain/entities/auth_user.dart';
import 'package:music_dna/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/started_music_session.dart';
import 'package:music_dna/src/features/readings/data/refine_operation_store.dart';
import 'package:music_dna/src/features/readings/presentation/refine_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/refine_view.dart';
import 'package:music_dna/src/features/session/data/session_resume_store.dart';
import 'package:music_dna/src/features/session/domain/entities/reading_report.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_mode.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/features/session/presentation/widgets/reading_report_sections.dart';
import 'auth_cubit_test.dart' show FakeAuthRepository;
import 'session_result_test.dart' show start, ResultRepository, cubitFor;
import 'session_checkpoint_flow_test.dart'
    show CheckpointRepository, choose, landRead;
import 'refine_library_test.dart' show Refiner;

class RefineCheckpointRepository extends CheckpointRepository {
  @override
  Future<SessionExperience> fetchExperience({required String sessionId}) async {
    final x = await super.fetchExperience(sessionId: sessionId);
    return SessionExperience(
      sessionId: x.sessionId,
      exchanges: x.exchanges,
      mode: 'refine',
      parentSessionId: 'original-root',
    );
  }

  SessionCubit child() => SessionCubit(
    this,
    startedSession: StartedMusicSession.reference(
      start.sessionId,
      mode: 'refine',
      parentSessionId: 'original-root',
    ),
    experienceRepository: this,
    criticRepository: this,
    resultRepository: this,
    flowRepository: this,
    preparationRepository: this,
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'Refine navigates straight to the verified child and retains route identity',
    (tester) async {
      StartedMusicSession? opened;
      final c = RefineCubit(
        Refiner(),
        sessionId: 'root',
        ownerId: 'owner',
        currentOwner: () => 'owner',
        operations: RefineOperationStore(),
        resumeStore: SessionResumeStore(currentOwner: () => 'owner'),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider.value(
              value: c,
              child: const Scaffold(body: RefineView()),
            ),
          ),
          GoRoute(
            path: '/session/:id',
            builder: (_, state) {
              opened = state.extra as StartedMusicSession;
              return const Scaffold(body: Text('Existing interview'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(c.close);
      await c.load();
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.dark()),
      );
      await tester.tap(find.text('Refine My DNA — six more'));
      await tester.pumpAndSettle();
      expect(find.text('Existing interview'), findsOneWidget);
      expect(opened?.sessionId, 'child');
      expect(opened?.parentSessionId, 'root');
      expect(opened?.sessionMode, SessionMode.refine);
      expect(opened?.songs, isEmpty);
    },
  );
  for (final guest in [false, true]) {
    testWidgets(
      'saved report offers Refine only to a registered listener (guest=$guest)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final authRepo = FakeAuthRepository(
          initialUser: AuthUser(
            id: 'owner',
            email: 'qa@example.com',
            isAnonymous: guest,
          ),
        );
        final auth = AuthCubit(authRepo)..initialize(),
            session = cubitFor(ResultRepository());
        addTearDown(authRepo.dispose);
        addTearDown(auth.close);
        addTearDown(session.close);
        await session.initialize();
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: session),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(),
              home: SessionStubPage(
                shareBaseUrl: 'https://www.musicdna.fm',
                ownerId: 'owner',
                createRefineCubit: ({required sessionId}) => RefineCubit(
                  Refiner(),
                  sessionId: sessionId,
                  ownerId: 'owner',
                  currentOwner: () => 'owner',
                  operations: RefineOperationStore(),
                  resumeStore: SessionResumeStore(currentOwner: () => 'owner'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(RefineView), guest ? findsNothing : findsOneWidget);
        if (!guest) {
          await tester.ensureVisible(find.text('Refine My DNA — six more'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  testWidgets(
    'cumulative server count is labelled separately from the run progress',
    (tester) async {
      final panel = DnaPanel(
        answered: 10,
        dimensions: [],
        undecided: [],
        receipts: [],
        matchups: [],
      );
      final report = ReadingReport(
        panelAvailable: true,
        panel: panel,
        mode: 'refine',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadingDimensions(report: report),
            ),
          ),
        ),
      );
      expect(
        find.textContaining(
          '10 choices across your original reading and this refinement',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Interview progress counts only the new choices'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'refinement skips count only its own answers and four-choice finish stays explicit',
    (tester) async {
      final repo = RefineCheckpointRepository()..answered = 3;
      final c = repo.child();
      addTearDown(c.close);
      await c.initialize();
      expect(c.state.sessionMode, SessionMode.refine);
      expect(c.state.currentRound?.round, 4);
      await c.skipPairing(msToDecide: 10);
      expect(repo.answered, 3);
      expect(c.state.currentRound?.round, 4);
      await choose(tester, c);
      await landRead(tester, repo, 4);
      await c.finishEarly();
      expect(repo.early, [true]);
      expect(repo.choiceCalls, 1);
      expect(c.state.sessionMode, SessionMode.refine);
      expect(c.state.parentSessionId, 'original-root');
      expect(c.state.status, SessionStatus.revealed);
    },
  );
  testWidgets(
    'refinement six-answer flow uses its own 2/4 checkpoints and one final reading',
    (tester) async {
      final repo = RefineCheckpointRepository(), c = repo.child();
      addTearDown(c.close);
      await c.initialize();
      for (var n = 1; n <= 6; n++) {
        await choose(tester, c);
        if ([1, 3, 5].contains(n)) {
          await tester.pump(const Duration(milliseconds: 2500));
          await tester.pump();
          expect(c.state.currentRound?.round, n + 1);
        } else if (n == 2 || n == 4) {
          await landRead(tester, repo, n);
          expect(c.state.checkpointAnswered, n);
          c.continueCheckpoint();
        }
      }
      expect(repo.readRequests, [2, 4]);
      expect(repo.early, [false]);
      expect(c.state.status, SessionStatus.revealed);
      expect(c.state.sessionMode, SessionMode.refine);
    },
  );
}
