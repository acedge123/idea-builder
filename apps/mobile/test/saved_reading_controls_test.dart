import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music_dna/src/core/theme/app_theme.dart';
import 'package:music_dna/src/features/auth/domain/entities/auth_user.dart';
import 'package:music_dna/src/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/explore_cubit.dart';
import 'package:music_dna/src/features/readings/presentation/explore_view.dart';
import 'package:music_dna/src/features/result_feedback/domain/result_feedback.dart';
import 'package:music_dna/src/features/result_feedback/presentation/result_feedback_cubit.dart';
import 'package:music_dna/src/features/result_feedback/presentation/result_feedback_view.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';

import 'auth_cubit_test.dart' show FakeAuthRepository;
import 'build8_views_test.dart' show ViewRepository;
import 'result_feedback_test.dart' show FeedbackRepository;
import 'session_result_test.dart' show ResultRepository, cubitFor, result;

void main() {
  testWidgets(
    'saved reading renders feedback and decades together for a listener',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final authRepository = FakeAuthRepository(
        initialUser: const AuthUser(id: 'owner', email: 'reviewer@example.com'),
      );
      final auth = AuthCubit(authRepository)..initialize();
      final session = cubitFor(ResultRepository());
      addTearDown(authRepository.dispose);
      addTearDown(auth.close);
      addTearDown(session.close);
      await session.initialize();
      expect(session.state.status, SessionStatus.revealed);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: auth),
            BlocProvider<SessionCubit>.value(value: session),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: SessionStubPage(
              shareBaseUrl: 'https://www.musicdna.fm',
              ownerId: 'owner',
              createFeedbackCubit:
                  ({required sessionId, required resultVersion}) =>
                      ResultFeedbackCubit(
                        target: FeedbackTarget(
                          ownerId: 'owner',
                          sessionId: sessionId,
                          resultVersion: resultVersion,
                        ),
                        repository: FeedbackRepository(),
                        currentOwnerId: () => 'owner',
                      ),
              createExploreCubit: ({required sessionId, required isExplore}) =>
                  ExploreCubit(
                    ViewRepository(),
                    sessionId: sessionId,
                    isExplore: isExplore,
                    ownerId: 'owner',
                    currentOwner: () => 'owner',
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(result.headline), findsOneWidget);
      expect(find.byType(ResultFeedbackView), findsOneWidget);
      expect(find.byType(ExploreView), findsOneWidget);
      await tester.ensureVisible(find.text('How did this read land?'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Your decade runs'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
