import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/core/network/music_dna_api_client.dart';
import 'package:music_dna/src/features/auth/domain/entities/auth_user.dart';
import 'package:music_dna/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:music_dna/src/features/continuation/domain/continuation_repository.dart';
import 'package:music_dna/src/features/continuation/presentation/continuation_cubit.dart';
import 'package:music_dna/src/features/continuation/presentation/continuation_page.dart';
import 'package:music_dna/src/features/onboarding/domain/entities/onboarding_reaction.dart';
import 'package:music_dna/src/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:music_dna/src/features/onboarding/presentation/pages/onboarding_stub_page.dart';
import 'package:music_dna/src/features/session/data/datasources/session_remote_data_source.dart';
import 'package:music_dna/src/features/session/domain/entities/session_experience.dart';
import 'package:music_dna/src/features/session/domain/entities/session_pairing.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_experience_view.dart';
import 'package:music_dna/src/features/session/presentation/widgets/session_pairing_card.dart';

import 'auth_cubit_test.dart' show FakeAuthRepository;
import 'continuation_test.dart' show FakeConversationRepository, savedContext;
import 'onboarding_cubit_test.dart' show FakeOnboardingRepository;
import 'session_cubit_test.dart' show FakeSessionRepository;
import 'session_reference_alignment_test.dart' show pairing;

void main() {
  void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('compact read omits audit counts; history preserves frozen wording', (
    tester,
  ) async {
    const saved =
        'Mr. Brightside over B. The evidence is contested (2 supporting, 1 against); no supported claim yet.';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SessionReadView(
            read: SessionRead(
              thesis: saved,
              auditText: 'Separate frozen evidence.',
            ),
            compact: true,
          ),
        ),
      ),
    );
    expect(
      find.text(
        'Mr. Brightside over B. The evidence is contested; no supported claim yet.',
      ),
      findsOneWidget,
    );
    expect(find.text(saved), findsNothing);
    expect(find.text('Separate frozen evidence.'), findsNothing);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SessionReadView(read: SessionRead(thesis: saved)),
        ),
      ),
    );
    expect(find.text(saved), findsOneWidget);
  });

  testWidgets(
    'read history retains separate audit text without process labels',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionReadView(
              read: SessionRead(
                thesis: 'The authored read.',
                auditText: 'Separate frozen evidence.',
                voiceVersion: 'critic-expression-v2',
                narrationStatus: 'ok',
              ),
            ),
          ),
        ),
      );
      expect(find.text('The authored read.'), findsOneWidget);
      expect(find.text('Separate frozen evidence.'), findsOneWidget);
      expect(find.text('critic-expression-v2'), findsNothing);
      expect(find.text('ok'), findsNothing);
    },
  );

  testWidgets(
    'song choices precede optional reactions; opening disclosure does not submit',
    (tester) async {
      phone(tester);
      final cubit = _PageCubit();
      addTearDown(cubit.close);
      cubit.show(
        SessionState(
          status: SessionStatus.ready,
          currentRound: const SessionRoundState(
            sessionId: 's',
            round: 3,
            confidence: 0,
            done: false,
            pairing: pairing,
            experienceVersion: true,
            maxAnswered: 6,
            prompt: 'The actual server question',
          ),
          read: const SessionRead(
            thesis: 'A tentative lean; not enough evidence yet.',
          ),
          exchanges: [
            SessionExchange(
              type: 'choice',
              at: DateTime.utc(2026),
              feedback: 'Earlier verbose feedback',
            ),
          ],
        ),
      );
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
      expect(find.text('Earlier verbose feedback'), findsNothing);
      expect(find.text('Not quite'), findsNothing);
      final optional = find.text('React to the Critic');
      expect(
        tester.getTopLeft(find.byType(SessionSongChoiceCard).last).dy,
        lessThan(tester.getTopLeft(optional).dy),
      );
      expect(find.text('CHOICE 03 / 6'), findsOneWidget);
      expect(find.text('The actual server question'), findsNothing);
      expect(find.text('Which one would you keep?'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 2 / 6);
      await tester.ensureVisible(optional);
      await tester.tap(optional);
      await tester.pumpAndSettle();
      expect(cubit.reactions, isEmpty);
      await tester.ensureVisible(find.text('Not quite'));
      await tester.tap(find.text('Not quite'));
      expect(cubit.reactions, [SessionReaction.notQuite]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending reaction stays expanded with only the original retry enabled',
    (tester) async {
      phone(tester, size: const Size(320, 700));
      final reactions = <SessionReaction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionReactionControls(
                exchanges: const [],
                read: const SessionRead(thesis: 'Stored'),
                busy: false,
                pendingReaction: SessionReaction.notQuite,
                onReaction: reactions.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, "That's me"))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Prove it'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Retry Not quite'));
      expect(reactions, [SessionReaction.notQuite]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('release gate stays a failure with one understandable error', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'EXPERIENCE_DISABLED',
            'message': 'V1 parity acceptance is pending.',
          },
        }),
        503,
      ),
    );
    addTearDown(client.close);
    final source = SessionRemoteDataSource(
      MusicDnaApiClient(
        baseUrl: 'https://example.invalid',
        accessTokenProvider: () async => null,
        httpClient: client,
      ),
    );
    String? copy;
    try {
      await source.fetchNextPairing(sessionId: 's');
      fail('Gate must not be bypassed');
    } on AppApiException catch (error) {
      expect(error.statusCode, 503);
      copy = error.message;
    }
    final cubit = _PageCubit();
    addTearDown(cubit.close);
    cubit.show(SessionState(status: SessionStatus.failure, errorMessage: copy));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SessionCubit>.value(
          value: cubit,
          child: const SessionStubPage(shareBaseUrl: 'https://example.invalid'),
        ),
      ),
    );
    expect(find.text(copy), findsOneWidget);
    expect(find.textContaining('parity acceptance'), findsNothing);
    expect(find.text('Retry session'), findsOneWidget);
    expect(find.byType(SessionSongChoiceCard), findsNothing);
  });

  testWidgets(
    'opening stage keeps current input and latest reply; earlier songs remain available',
    (tester) async {
      phone(tester);
      final repository = FakeAuthRepository(
        initialUser: const AuthUser(id: 'fixture', isAnonymous: true),
      );
      final auth = AuthCubit(repository)..initialize();
      final onboarding = OnboardingCubit(
        FakeOnboardingRepository(
          reactions: const [
            OnboardingReaction(reaction: 'First saved reply'),
            OnboardingReaction(reaction: 'Latest saved reply'),
          ],
        ),
      );
      addTearDown(repository.dispose);
      addTearDown(auth.close);
      addTearDown(onboarding.close);
      await onboarding.submitSong(song: 'Mr. Brightside');
      await onboarding.submitSong(song: 'Second Song');
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: onboarding),
            ],
            child: const OnboardingStubPage(),
          ),
        ),
      );
      expect(find.text('YOUR SONGS · 3 / 3'), findsOneWidget);
      expect(find.text('Second Song'), findsOneWidget);
      expect(find.text('Latest saved reply'), findsOneWidget);
      expect(find.text('First saved reply'), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.tap(find.text('Earlier songs (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Mr. Brightside'), findsOneWidget);
      expect(find.text('First saved reply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved fallback remains verbatim; clarification fills a draft without sending',
    (tester) async {
      phone(tester);
      const fallback = "I couldn't ground that reply in the saved evidence.";
      final repository = FakeConversationRepository()
        ..snapshot = ConversationSnapshot(
          sessionId: 'saved-session',
          messages: [
            ConversationMessage(
              role: ConversationRole.assistant,
              content: fallback,
              createdAt: DateTime.utc(2026),
            ),
          ],
        );
      final cubit = ContinuationCubit(savedContext(), repository);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const ContinuationPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your original saved reading.'), findsNothing);
      expect(find.text(fallback), findsOneWidget);
      await tester.ensureVisible(find.text('The voice'));
      await tester.tap(find.text('The voice'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft, 'It is the voice that matters to me because ');
      expect(repository.sent, isEmpty);
      expect(cubit.state.messages.single.content, fallback);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'The context'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Original reading'));
      await tester.tap(find.text('Original reading'));
      await tester.pumpAndSettle();
      expect(find.text('Your original saved reading.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PageCubit extends SessionCubit {
  _PageCubit() : super(FakeSessionRepository());
  final reactions = <SessionReaction>[];
  @override
  bool get hasExperience => true;
  void show(SessionState value) => emit(value);
  @override
  Future<void> react(SessionReaction reaction) async => reactions.add(reaction);
}
