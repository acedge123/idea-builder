import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/readings/domain/reading_library.dart';
import '../../features/readings/presentation/explore_cubit.dart';
import '../../features/readings/data/rest_reading_library_repository.dart';
import '../../features/readings/presentation/reading_library_cubit.dart';

import '../../app/router/auth_router_notifier.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/entities/auth_user.dart' as music_auth;
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/continuation/domain/continuation_repository.dart';
import '../../features/continuation/data/rest_continuation_repository.dart';
import '../../features/continuation/presentation/continuation_cubit.dart';
import '../../features/onboarding/domain/entities/started_music_session.dart';
import '../../features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import '../../features/onboarding/data/repositories/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/session/data/datasources/session_remote_data_source.dart';
import '../../features/session/data/repositories/session_repository_impl.dart';
import '../../features/session/data/session_resume_store.dart';
import '../../features/session/domain/repositories/session_repository.dart';
import '../../features/session/domain/repositories/session_experience_repository.dart';
import '../../features/session/domain/repositories/session_result_repository.dart';
import '../../features/session/domain/repositories/session_preparation_repository.dart';
import '../../features/session/domain/repositories/saved_reading_repository.dart';
import '../../features/session/presentation/cubit/session_cubit.dart';
import '../../features/result_feedback/data/unavailable_result_feedback_repository.dart';
import '../../features/result_feedback/data/rest_result_feedback_repository.dart';
import '../../features/result_feedback/domain/result_feedback.dart';
import '../../features/result_feedback/domain/result_feedback_repository.dart';
import '../../features/result_feedback/presentation/result_feedback_cubit.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../network/music_dna_api_client.dart';

class AppDependencies {
  AppDependencies({
    required this.config,
    required this.supabase,
    ContinuationRepository? continuationRepository,
  }) {
    apiClient = MusicDnaApiClient(
      baseUrl: config.apiBaseUrl,
      accessTokenProvider: () async =>
          supabase.auth.currentSession?.accessToken,
    );
    authRemoteDataSource = SupabaseAuthRemoteDataSource(supabase, apiClient);
    authRepository = AuthRepositoryImpl(authRemoteDataSource);
    _ownerChanges = authRepository.observeAuthState().listen((user) {
      if (_continuationOwner != null && user?.id != _continuationOwner) {
        for (final cubit in _continuations.values) {
          cubit.close();
        }
        _continuations.clear();
        _continuationOwner = null;
      }
    });
    this.continuationRepository =
        continuationRepository ??
        (config.experienceV1
            ? RestContinuationRepository(apiClient)
            : const UnavailableContinuationRepository());
  }

  final AppConfig config;
  final SupabaseClient supabase;
  late final ContinuationRepository continuationRepository;
  final Map<ContinuationContext, ContinuationCubit> _continuations = {};
  String? _continuationOwner;
  late final StreamSubscription<music_auth.AuthUser?> _ownerChanges;
  void dispose() {
    _ownerChanges.cancel();
    for (final cubit in _continuations.values) {
      cubit.close();
    }
    _continuations.clear();
    authRouterNotifier.dispose();
  }

  ContinuationCubit continuationFor(ContinuationContext context) {
    final owner = authRepository.currentUser?.id;
    if (owner == null || context.ownerId != owner) {
      throw StateError('Reading owner authentication required');
    }
    if (_continuationOwner != owner) {
      for (final cubit in _continuations.values) {
        cubit.close();
      }
      _continuations.clear();
      _continuationOwner = owner;
    }
    for (final entry in _continuations.entries) {
      if (entry.key.sessionId == context.sessionId &&
          entry.key.resultVersion == context.resultVersion &&
          identical(entry.key.original, context.original)) {
        return entry.value;
      }
    }
    final cubit = ContinuationCubit(context, continuationRepository)..load();
    _continuations[context] = cubit;
    return cubit;
  }

  late final AppLogger logger = const AppLogger();
  late final AuthRemoteDataSource authRemoteDataSource;
  late final AuthRepository authRepository;
  late final AuthRouterNotifier authRouterNotifier = AuthRouterNotifier(
    authRepository,
  );
  late final MusicDnaApiClient apiClient;
  late final OnboardingRemoteDataSource onboardingRemoteDataSource =
      OnboardingRemoteDataSource(apiClient);
  late final OnboardingRepository onboardingRepository =
      OnboardingRepositoryImpl(onboardingRemoteDataSource);
  late final SessionRemoteDataSource sessionRemoteDataSource =
      SessionRemoteDataSource(apiClient, experienceV1: config.experienceV1);
  late final SessionRepository sessionRepository = SessionRepositoryImpl(
    sessionRemoteDataSource,
  );
  late final SessionResumeStore sessionResumeStore = SessionResumeStore(
    currentOwner: () => authRepository.currentUser?.id,
  );
  late final ReadingLibraryRepository readingLibraryRepository =
      RestReadingLibraryRepository(sessionRemoteDataSource);
  ReadingLibraryCubit createReadingLibraryCubit() => ReadingLibraryCubit(
    readingLibraryRepository,
    ownerId: authRepository.currentUser!.id,
    currentOwner: () => authRepository.currentUser?.id,
  );
  late final ResultFeedbackRepository resultFeedbackRepository =
      config.experienceV1
      ? RestResultFeedbackRepository(apiClient)
      : const UnavailableResultFeedbackRepository();

  bool get hasResultFeedback =>
      config.experienceV1 && resultFeedbackRepository.available;

  ResultFeedbackCubit createResultFeedbackCubit({
    required String sessionId,
    required int resultVersion,
  }) => ResultFeedbackCubit(
    target: FeedbackTarget(
      ownerId: authRepository.currentUser?.id ?? '',
      sessionId: sessionId,
      resultVersion: resultVersion,
    ),
    repository: resultFeedbackRepository,
    currentOwnerId: () => authRepository.currentUser?.id,
    ownerChanges: authRepository.observeAuthState().map((user) => user?.id),
    logger: logger,
  );

  ExploreCubit createExploreCubit({
    required String sessionId,
    required bool isExplore,
  }) => ExploreCubit(
    readingLibraryRepository,
    sessionId: sessionId,
    isExplore: isExplore,
    ownerId: authRepository.currentUser!.id,
    currentOwner: () => authRepository.currentUser?.id,
  );

  AuthCubit createAuthCubit() {
    return AuthCubit(authRepository, logger: logger)..initialize();
  }

  OnboardingCubit createOnboardingCubit() {
    return OnboardingCubit(
      onboardingRepository,
      resumeStore: sessionResumeStore,
      logger: logger,
    );
  }

  SessionCubit createSessionCubit({StartedMusicSession? startedSession}) {
    return SessionCubit(
      sessionRepository,
      experienceRepository: config.experienceV1
          ? sessionRepository as SessionExperienceRepository
          : null,
      resultRepository: config.experienceV1
          ? sessionRepository as SessionResultRepository
          : null,
      preparationRepository: config.experienceV1
          ? sessionRepository as SessionPreparationRepository
          : null,
      savedReadingRepository: config.experienceV1
          ? sessionRepository as SavedReadingRepository
          : null,
      startedSession: startedSession,
      resumeStore: sessionResumeStore,
      logger: logger,
    );
  }
}
