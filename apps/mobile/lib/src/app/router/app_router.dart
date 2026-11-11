import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../features/auth/presentation/pages/auth_stub_page.dart';
import '../../features/continuation/domain/continuation_repository.dart';
import '../../features/continuation/presentation/continuation_page.dart';
import '../../features/foundation/presentation/pages/foundation_home_page.dart';
import '../../features/onboarding/domain/entities/started_music_session.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/onboarding/presentation/pages/onboarding_stub_page.dart';
import '../../features/session/presentation/cubit/session_cubit.dart';
import '../../features/session/presentation/pages/session_stub_page.dart';
import '../../features/readings/presentation/reading_library_page.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

GoRouter buildAppRouter(AppDependencies dependencies) {
  return GoRouter(
    refreshListenable: dependencies.authRouterNotifier,
    redirect: (context, state) {
      final hasSession = dependencies.authRouterNotifier.isAuthenticated;
      final isProtectedRoute =
          state.matchedLocation == '/readings' ||
          state.matchedLocation == '/session' ||
          state.matchedLocation.startsWith('/session/');

      if (!hasSession && isProtectedRoute) {
        return '/auth';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => FoundationHomePage(
          config: dependencies.config,
          createLibraryCubit: dependencies.createReadingLibraryCubit,
        ),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthStubPage()),
      GoRoute(
        path: '/readings',
        builder: (context, state) => BlocBuilder<AuthCubit, AuthState>(
          builder: (context, auth) {
            if (auth.user == null || auth.user!.isAnonymous) {
              return const AuthStubPage();
            }
            return BlocProvider(
              key: ValueKey(auth.user!.id),
              create: (_) => dependencies.createReadingLibraryCubit()..load(),
              child: const ReadingLibraryPage(),
            );
          },
        ),
      ),

      GoRoute(
        path: '/onboarding',
        builder: (context, state) => BlocProvider<OnboardingCubit>(
          create: (_) => dependencies.createOnboardingCubit(),
          child: const OnboardingStubPage(),
        ),
      ),
      GoRoute(
        path: '/session/:sessionId/continuation',
        builder: (context, state) => AnimatedBuilder(
          animation: dependencies.authRouterNotifier,
          builder: (context, _) {
            final saved = state.extra;
            if (!dependencies.config.experienceV1 ||
                saved is! ContinuationContext ||
                saved.ownerId != dependencies.authRepository.currentUser?.id ||
                saved.sessionId != state.pathParameters['sessionId']) {
              return Scaffold(
                appBar: AppBar(title: const Text('Conversation unavailable')),
                body: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Open your saved reading to continue.'),
                  ),
                ),
              );
            }
            return BlocProvider.value(
              value: dependencies.continuationFor(saved),
              child: const ContinuationPage(),
            );
          },
        ),
      ),
      GoRoute(
        path: '/session/:sessionId',
        builder: (context, state) => BlocProvider<SessionCubit>(
          key: ValueKey((
            dependencies.authRepository.currentUser?.id,
            state.pathParameters['sessionId'],
          )),
          create: (_) => dependencies.createSessionCubit(
            startedSession: StartedMusicSession.reference(
              state.pathParameters['sessionId']!,
            ),
          )..initialize(),
          child: SessionStubPage(
            ownerId: dependencies.authRepository.currentUser?.id,
            createFeedbackCubit: dependencies.hasResultFeedback
                ? dependencies.createResultFeedbackCubit
                : null,
            createExploreCubit: dependencies.config.experienceV1
                ? dependencies.createExploreCubit
                : null,
            shareBaseUrl: dependencies.config.shareBaseUrl,
            startedSession: StartedMusicSession.reference(
              state.pathParameters['sessionId']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) => BlocProvider<SessionCubit>(
          create: (_) => dependencies.createSessionCubit(
            startedSession: state.extra is StartedMusicSession
                ? state.extra as StartedMusicSession
                : null,
          )..initialize(),
          child: SessionStubPage(
            ownerId: dependencies.authRepository.currentUser?.id,
            createFeedbackCubit: dependencies.hasResultFeedback
                ? dependencies.createResultFeedbackCubit
                : null,
            createExploreCubit: dependencies.config.experienceV1
                ? dependencies.createExploreCubit
                : null,
            shareBaseUrl: dependencies.config.shareBaseUrl,
            startedSession: state.extra is StartedMusicSession
                ? state.extra as StartedMusicSession
                : null,
          ),
        ),
      ),
    ],
  );
}
