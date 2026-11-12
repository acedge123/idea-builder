import 'package:equatable/equatable.dart';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/app_api_exception.dart';
import '../../../onboarding/domain/entities/started_music_session.dart';
import '../../data/session_resume_store.dart';
import '../../domain/entities/session_pairing.dart';
import '../../domain/entities/session_reveal.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/saved_reading_repository.dart';
import '../../domain/repositories/session_experience_repository.dart';
import '../../domain/entities/session_experience.dart';
import '../../domain/entities/session_result.dart';
import '../../domain/repositories/session_result_repository.dart';
import '../../domain/repositories/session_preparation_repository.dart';
import '../../domain/entities/session_milestone.dart';

enum SessionStatus {
  initial,
  loading,
  ready,
  submitting,
  completed,
  revealing,
  waitingForReading,
  revealed,
  failure,
  missingSession,
}

class SessionState extends Equatable {
  const SessionState({
    this.status = SessionStatus.initial,
    this.startedSession,
    this.currentRound,
    this.lastFeedback,
    this.reveal,
    this.sharedReveal,
    this.errorMessage,
    this.requiresReauthentication = false,
    this.exchanges = const [],
    this.read,
    this.selectedSongId,
    this.reacting = false,
    this.reactionMessage,
    this.publication,
    this.sharing = false,
    this.shareVerified = false,
    this.shareMayBePublic = false,
    this.shareError,
    this.milestone,
    this.dismissedMilestones = const [],
    this.finishEarlyRequested = false,
    this.mode = 'discover',
    this.decade,
    this.parentSessionId,
  });

  final SessionStatus status;
  final StartedMusicSession? startedSession;
  final SessionRoundState? currentRound;
  final SessionChoiceFeedback? lastFeedback;
  final SessionReveal? reveal;
  final SharedReveal? sharedReveal;
  final String? errorMessage;
  final bool requiresReauthentication;
  final List<SessionExchange> exchanges;
  final SessionRead? read;
  final String? selectedSongId, reactionMessage;
  final bool reacting;
  final SharePublication? publication;
  final bool sharing, shareVerified, shareMayBePublic;
  final String? shareError;
  final SessionMilestone? milestone;
  final List<int> dismissedMilestones;
  final bool finishEarlyRequested;
  final String mode;
  final int? decade;
  final String? parentSessionId;
  SessionMilestone? get visibleMilestone =>
      status == SessionStatus.ready &&
          !reacting &&
          selectedSongId == null &&
          !dismissedMilestones.contains(milestone?.answered)
      ? milestone
      : null;

  String? get sessionId => startedSession?.sessionId ?? currentRound?.sessionId;

  SessionState copyWith({
    SessionStatus? status,
    StartedMusicSession? startedSession,
    bool clearStartedSession = false,
    SessionRoundState? currentRound,
    bool clearCurrentRound = false,
    SessionChoiceFeedback? lastFeedback,
    bool clearLastFeedback = false,
    SessionReveal? reveal,
    bool clearReveal = false,
    SharedReveal? sharedReveal,
    bool clearSharedReveal = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? requiresReauthentication,
    List<SessionExchange>? exchanges,
    SessionRead? read,
    bool clearRead = false,
    String? selectedSongId,
    bool clearSelection = false,
    bool? reacting,
    String? reactionMessage,
    bool clearReactionMessage = false,
    SharePublication? publication,
    bool clearPublication = false,
    bool? sharing,
    bool? shareVerified,
    bool? shareMayBePublic,
    String? shareError,
    bool clearShareError = false,
    SessionMilestone? milestone,
    bool clearMilestone = false,
    List<int>? dismissedMilestones,
    bool? finishEarlyRequested,
    String? mode,
    int? decade,
    String? parentSessionId,
  }) {
    return SessionState(
      status: status ?? this.status,
      startedSession: clearStartedSession
          ? null
          : startedSession ?? this.startedSession,
      currentRound: clearCurrentRound
          ? null
          : currentRound ?? this.currentRound,
      lastFeedback: clearLastFeedback
          ? null
          : lastFeedback ?? this.lastFeedback,
      reveal: clearReveal ? null : reveal ?? this.reveal,
      sharedReveal: clearSharedReveal
          ? null
          : sharedReveal ?? this.sharedReveal,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      requiresReauthentication:
          requiresReauthentication ?? this.requiresReauthentication,
      exchanges: exchanges == null
          ? this.exchanges
          : List.unmodifiable(exchanges),
      read: clearRead ? null : read ?? this.read,
      selectedSongId: clearSelection
          ? null
          : selectedSongId ?? this.selectedSongId,
      reacting: reacting ?? this.reacting,
      reactionMessage: clearReactionMessage
          ? null
          : reactionMessage ?? this.reactionMessage,
      publication: clearPublication ? null : publication ?? this.publication,
      sharing: sharing ?? this.sharing,
      shareVerified: shareVerified ?? this.shareVerified,
      shareMayBePublic: shareMayBePublic ?? this.shareMayBePublic,
      shareError: clearShareError ? null : shareError ?? this.shareError,
      milestone: clearMilestone ? null : milestone ?? this.milestone,
      dismissedMilestones: dismissedMilestones == null
          ? this.dismissedMilestones
          : List.unmodifiable(dismissedMilestones),
      finishEarlyRequested: finishEarlyRequested ?? this.finishEarlyRequested,
      mode: mode ?? this.mode,
      decade: decade ?? this.decade,
      parentSessionId: parentSessionId ?? this.parentSessionId,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    startedSession,
    currentRound,
    lastFeedback,
    reveal,
    sharedReveal,
    errorMessage,
    requiresReauthentication,
    exchanges,
    read,
    selectedSongId,
    reacting,
    reactionMessage,
    publication,
    sharing,
    shareVerified,
    shareMayBePublic,
    shareError,
    milestone,
    dismissedMilestones,
    finishEarlyRequested,
    mode,
    decade,
    parentSessionId,
  ];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(
    this._repository, {
    StartedMusicSession? startedSession,
    SessionResumeStore? resumeStore,
    AppLogger? logger,
    SessionExperienceRepository? experienceRepository,
    SessionResultRepository? resultRepository,
    SessionPreparationRepository? preparationRepository,
    SavedReadingRepository? savedReadingRepository,
  }) : _logger = logger ?? const AppLogger(),
       _resumeStore = resumeStore,
       _experienceRepository = experienceRepository,
       _resultRepository = resultRepository,
       _preparationRepository = preparationRepository,
       _savedReadingRepository = savedReadingRepository,
       super(SessionState(startedSession: startedSession));

  final SessionRepository _repository;
  final AppLogger _logger;
  final SessionResumeStore? _resumeStore;
  final SessionResultRepository? _resultRepository;
  final SessionExperienceRepository? _experienceRepository;
  final SessionPreparationRepository? _preparationRepository;
  final SavedReadingRepository? _savedReadingRepository;
  final _preparedPairings = <String>{};
  String? _reactionMutationId;
  SessionReaction? _pendingReaction;
  String? _reactionPairingId;
  bool get hasExperience => _experienceRepository != null;
  SessionReaction? get pendingReaction => _pendingReaction;
  static const int maxPairingRounds = 6;
  static const int maxMsToDecide = 600000;

  bool _savedOnly = false;
  int? _savedResultVersion;
  Future<void> initialize({bool? savedOnly, int? resultVersion}) async {
    _savedOnly = savedOnly ?? _savedOnly;
    _savedResultVersion = resultVersion ?? _savedResultVersion;
    var sessionId = state.sessionId;
    if ((sessionId == null || sessionId.isEmpty) && _resumeStore != null) {
      final resumedSession = await _resumeStore.load();
      if (resumedSession != null) {
        emit(state.copyWith(startedSession: resumedSession));
        sessionId = resumedSession.sessionId;
      }
    }

    _logger.event('session.initialize', <String, Object?>{
      'hasSessionId': sessionId?.isNotEmpty == true,
    });
    if (sessionId == null || sessionId.isEmpty) {
      emit(
        state.copyWith(
          status: SessionStatus.missingSession,
          clearCurrentRound: true,
          clearReveal: true,
          clearSharedReveal: true,
          clearErrorMessage: true,
          requiresReauthentication: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SessionStatus.loading,
        clearReveal: true,
        clearSharedReveal: true,
        clearErrorMessage: true,
        requiresReauthentication: false,
      ),
    );

    if (_savedOnly ||
        _savedResultVersion != null ||
        _savedReadingRepository != null) {
      try {
        final saved = await _savedReadingRepository?.fetchSavedReading(
          sessionId: sessionId,
          resultVersion: _savedResultVersion,
        );
        if (isClosed) return;
        if (saved == null && (_savedOnly || _savedResultVersion != null)) {
          throw const AppApiException(
            kind: AppApiErrorKind.invalidInput,
            code: 'NO_RESULT',
            message: 'No saved reading is available yet.',
          );
        }
        if (saved != null) {
          // Publication/history metadata is optional; it cannot hide a saved read.
          SessionExperience? experience;
          try {
            experience = await _experienceRepository?.fetchExperience(
              sessionId: sessionId,
            );
          } catch (_) {
            _logger.event('session.saved_metadata_unavailable');
          }
          if (isClosed) return;
          final report = saved.result?.report;
          emit(
            state.copyWith(
              status: SessionStatus.revealed,
              reveal: saved,
              exchanges: experience?.exchanges,
              mode: report?.mode ?? experience?.mode,
              decade: report?.decade ?? experience?.decade,
              parentSessionId:
                  report?.parentSessionId ?? experience?.parentSessionId,
              publication: experience?.publication,
              clearPublication: experience?.publication == null,
              shareVerified: false,
              shareMayBePublic: experience?.publication?.isPublic == true,
              read: experience?.latestRead,
              clearErrorMessage: true,
            ),
          );
          _logger.event('session.saved_report_loaded', {
            'version': saved.result?.version,
          });
          return;
        }
      } catch (error) {
        if (isClosed) return;
        _logger.event('session.saved_only_load_failed');
        emit(
          state.copyWith(
            status: SessionStatus.failure,
            requiresReauthentication:
                error is AppApiException && error.isAuthRelated,
            errorMessage: _readableError(error),
          ),
        );
        return;
      }
    }

    await _loadNextPairing(
      sessionId: sessionId,
      keepFeedback: state.lastFeedback != null,
    );
  }

  Future<void> chooseSong({
    required String chosenSongId,
    required int msToDecide,
  }) async {
    if (state.status != SessionStatus.ready ||
        state.reacting ||
        _pendingReaction != null) {
      return;
    }
    final sessionId = state.sessionId;
    final pairingId = state.currentRound?.pairing?.id;
    _logger.event('session.choice_requested', <String, Object?>{
      'sessionId': sessionId,
      'pairingId': pairingId,
      'chosenSongId': chosenSongId,
      'msToDecide': _normalizeMsToDecide(msToDecide),
    });
    if (sessionId == null || pairingId == null) {
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: 'No active pairing is available yet.',
          requiresReauthentication: false,
        ),
      );
      return;
    }
    if (state.selectedSongId != null && state.selectedSongId != chosenSongId) {
      return;
    }
    final pairing = state.currentRound!.pairing!;
    if (chosenSongId != pairing.songA.id && chosenSongId != pairing.songB.id) {
      return;
    }

    emit(
      state.copyWith(
        status: SessionStatus.submitting,
        clearErrorMessage: true,
        selectedSongId: chosenSongId,
        clearLastFeedback: true,
        clearReactionMessage: true,
      ),
    );

    try {
      final feedback = await _repository.submitChoice(
        sessionId: sessionId,
        pairingId: pairingId,
        chosenSongId: chosenSongId,
        msToDecide: _normalizeMsToDecide(msToDecide),
      );
      _logger.event('session.choice_succeeded', <String, Object?>{
        'sessionId': sessionId,
        'pairingId': pairingId,
      });
      emit(
        state.copyWith(
          lastFeedback: feedback,
          read: feedback.read,
          clearErrorMessage: true,
        ),
      );
      await _loadNextPairing(sessionId: sessionId, keepFeedback: true);
    } catch (error) {
      _logger.error('session.choice_failed', error, <String, Object?>{
        'sessionId': sessionId,
        'pairingId': pairingId,
      });
      final apiError = error is AppApiException ? error : null;
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: _readableError(apiError ?? error),
          requiresReauthentication: apiError?.isAuthRelated == true,
        ),
      );
    }
  }

  Future<void> skipPairing({required int msToDecide}) async {
    if (state.selectedSongId != null) return;
    if (state.status != SessionStatus.ready ||
        state.reacting ||
        _pendingReaction != null) {
      return;
    }
    final sessionId = state.sessionId;
    final pairingId = state.currentRound?.pairing?.id;
    _logger.event('session.skip_requested', <String, Object?>{
      'sessionId': sessionId,
      'pairingId': pairingId,
      'msToDecide': _normalizeMsToDecide(msToDecide),
    });
    if (sessionId == null || pairingId == null) {
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: 'No active pairing is available yet.',
          requiresReauthentication: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SessionStatus.submitting,
        clearLastFeedback: true,
        clearErrorMessage: true,
      ),
    );

    try {
      await _repository.skipPairing(
        sessionId: sessionId,
        pairingId: pairingId,
        msToDecide: _normalizeMsToDecide(msToDecide),
      );
      _logger.event('session.skip_succeeded', <String, Object?>{
        'sessionId': sessionId,
        'pairingId': pairingId,
      });
      await _loadNextPairing(sessionId: sessionId, keepFeedback: false);
    } catch (error) {
      _logger.error('session.skip_failed', error, <String, Object?>{
        'sessionId': sessionId,
        'pairingId': pairingId,
      });
      final apiError = error is AppApiException ? error : null;
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: _readableError(apiError ?? error),
          requiresReauthentication: apiError?.isAuthRelated == true,
        ),
      );
    }
  }

  void clearFeedback() {
    emit(
      state.copyWith(
        clearLastFeedback: true,
        clearErrorMessage: true,
        status: state.currentRound?.pairing != null
            ? SessionStatus.ready
            : state.status,
        requiresReauthentication: false,
      ),
    );
  }

  void continueInterview() {
    final milestone = state.visibleMilestone;
    if (milestone == null || _pendingReaction != null) return;
    _logger.event('session.milestone_continued', {
      'answered': milestone.answered,
    });
    emit(
      state.copyWith(
        dismissedMilestones: [...state.dismissedMilestones, milestone.answered],
      ),
    );
  }

  Future<void> finishEarly() async {
    if (state.visibleMilestone?.canFinish != true || _pendingReaction != null) {
      return;
    }
    await revealSession(finishEarly: true);
  }

  /// Dispatched after the active pairing has actually been rendered.
  Future<void> prepareCurrentPairing() async {
    final repository = _preparationRepository;
    final sessionId = state.sessionId;
    final pairing = state.currentRound?.pairing;
    if (state.mode == 'explore' ||
        repository == null ||
        sessionId == null ||
        pairing?.exposureId == null ||
        state.status != SessionStatus.ready ||
        state.visibleMilestone != null ||
        state.reacting ||
        _pendingReaction != null) {
      return;
    }
    final key = '$sessionId:${pairing!.id}:${pairing.exposureId}';
    if (!_preparedPairings.add(key)) return;
    try {
      await repository.prepare(
        sessionId: sessionId,
        pairingId: pairing.id,
        exposureId: pairing.exposureId!,
      );
      _logger.event('session.preparation_finished', {
        'sessionId': sessionId,
        'pairingId': pairing.id,
      });
    } catch (_) {
      // Optional speed work must never block a pick, retry a model, or replace a read.
      _logger.event('session.preparation_unavailable', {
        'sessionId': sessionId,
        'pairingId': pairing.id,
      });
    }
  }

  Future<void> revealSession({bool finishEarly = false}) async {
    if (state.status == SessionStatus.revealing || state.sharing) return;
    final requestedEarly = finishEarly || state.finishEarlyRequested;
    final sessionId = state.sessionId;
    _logger.event('session.reveal_requested', <String, Object?>{
      'sessionId': sessionId,
    });
    if (sessionId == null || sessionId.isEmpty) {
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: 'No active session is available yet.',
          requiresReauthentication: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SessionStatus.revealing,
        finishEarlyRequested: requestedEarly,
        clearErrorMessage: true,
        requiresReauthentication: false,
      ),
    );

    try {
      final saved = await _savedReadingRepository?.fetchSavedReading(
        sessionId: sessionId,
      );
      if (isClosed) return;
      final reveal =
          saved ??
          await _repository.revealSession(
            sessionId: sessionId,
            finishEarly: requestedEarly,
          );
      if (isClosed) return;
      SharedReveal? sharedReveal;
      if (reveal.result == null &&
          reveal.shareToken != null &&
          reveal.shareToken!.isNotEmpty) {
        try {
          sharedReveal = await _repository.fetchSharedReveal(
            token: reveal.shareToken!,
          );
        } catch (error) {
          _logger.error('session.share_fetch_failed', error, <String, Object?>{
            'sessionId': sessionId,
            'shareToken': reveal.shareToken,
          });
        }
      }
      _logger.event('session.reveal_succeeded', <String, Object?>{
        'sessionId': sessionId,
        'shareToken': reveal.shareToken,
      });

      emit(
        state.copyWith(
          status: SessionStatus.revealed,
          reveal: reveal,
          mode: reveal.result?.report?.mode,
          decade: reveal.result?.report?.decade,
          parentSessionId: reveal.result?.report?.parentSessionId,
          sharedReveal: sharedReveal,
          clearSharedReveal: sharedReveal == null,
          clearErrorMessage: true,
          requiresReauthentication: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      if (error is ReadingPendingException ||
          error is AppApiException && error.kind == AppApiErrorKind.network) {
        // A lost response does not establish failure. Read once before offering retry.
        try {
          final saved = await _savedReadingRepository?.fetchSavedReading(
            sessionId: sessionId,
          );
          if (isClosed) return;
          if (saved != null) {
            emit(
              state.copyWith(
                status: SessionStatus.revealed,
                reveal: saved,
                mode: saved.result?.report?.mode,
                decade: saved.result?.report?.decade,
                parentSessionId: saved.result?.report?.parentSessionId,
                clearErrorMessage: true,
                requiresReauthentication: false,
              ),
            );
            _logger.event('session.saved_reading_recovered', {
              'sessionId': sessionId,
            });
            return;
          }
        } catch (_) {
          // Leave outcome uncertain; never retry a model in the background.
        }
        if (isClosed) return;
        emit(
          state.copyWith(
            status: SessionStatus.waitingForReading,
            clearReveal: true,
            clearErrorMessage: true,
          ),
        );
        return;
      }
      _logger.error('session.reveal_failed', error, <String, Object?>{
        'sessionId': sessionId,
      });
      final apiError = error is AppApiException ? error : null;
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: _readableError(apiError ?? error),
          requiresReauthentication: apiError?.isAuthRelated == true,
        ),
      );
    }
  }

  Future<void> setPublication({required bool publish}) async {
    final repository = _resultRepository;
    final sessionId = state.sessionId;
    if (repository == null ||
        sessionId == null ||
        state.reveal?.result == null ||
        state.status != SessionStatus.revealed ||
        state.sharing) {
      return;
    }
    _logger.event('session.share_requested', {
      'sessionId': sessionId,
      'publish': publish,
    });
    emit(
      state.copyWith(
        sharing: true,
        shareVerified: false,
        shareMayBePublic: publish || state.shareMayBePublic,
        clearPublication: true,
        clearSharedReveal: true,
        clearShareError: true,
      ),
    );
    try {
      final publication = await repository.setPublication(
        sessionId: sessionId,
        publish: publish,
      );
      if (isClosed) return;
      if (publication.isPublic != publish ||
          (publish &&
              publication.resultVersion != null &&
              publication.resultVersion != state.reveal?.result?.version) ||
          (publish && publication.token?.isNotEmpty != true)) {
        throw const AppApiException(
          kind: AppApiErrorKind.upstream,
          message: 'The server returned an unexpected sharing state.',
        );
      }
      emit(state.copyWith(publication: publication, shareMayBePublic: publish));
      if (publish) {
        final shared = await _verifiedShare(publication, sessionId);
        if (isClosed) return;
        emit(state.copyWith(sharedReveal: shared, shareVerified: true));
      }
      _logger.event('session.share_succeeded', {
        'sessionId': sessionId,
        'publish': publish,
      });
      emit(state.copyWith(sharing: false));
    } catch (error) {
      _shareFailed(error);
    }
  }

  Future<void> verifyPublication() async {
    final publication = state.publication;
    final sessionId = state.sessionId;
    if (publication?.isPublic != true ||
        publication?.token?.isNotEmpty != true ||
        sessionId == null ||
        state.sharing) {
      return;
    }
    emit(
      state.copyWith(
        sharing: true,
        shareVerified: false,
        clearShareError: true,
      ),
    );
    try {
      final shared = await _verifiedShare(publication!, sessionId);
      if (isClosed) return;
      emit(
        state.copyWith(
          sharedReveal: shared,
          shareVerified: true,
          sharing: false,
        ),
      );
    } catch (error) {
      _shareFailed(error);
    }
  }

  Future<SharedReveal> _verifiedShare(
    SharePublication publication,
    String sessionId,
  ) async {
    final shared = await _repository.fetchSharedReveal(
      token: publication.token!,
    );
    if (shared.sessionId != sessionId ||
        shared.shareToken != publication.token) {
      throw const AppApiException(
        kind: AppApiErrorKind.upstream,
        message: 'The public reading did not match this session.',
      );
    }
    return shared;
  }

  void _shareFailed(Object error) {
    if (isClosed) return;
    final apiError = error is AppApiException ? error : null;
    _logger.event('session.share_failed', {
      'sessionId': state.sessionId,
      'kind': apiError?.kind.name ?? 'unknown',
    });
    emit(
      state.copyWith(
        sharing: false,
        shareVerified: false,
        shareError: _readableError(error),
        requiresReauthentication: apiError?.isAuthRelated == true,
      ),
    );
  }

  Future<void> _loadNextPairing({
    required String sessionId,
    required bool keepFeedback,
  }) async {
    try {
      final nextRound = await _repository.fetchNextPairing(
        sessionId: sessionId,
      );
      _logger.event('session.next_pairing_loaded', <String, Object?>{
        'sessionId': sessionId,
        'round': nextRound.round,
        'done': nextRound.done,
        'hasPairing': nextRound.pairing != null,
      });
      final isComplete =
          nextRound.done ||
          (!nextRound.experienceVersion &&
              (nextRound.pairing == null ||
                  nextRound.round > maxPairingRounds));
      final experience = _experienceRepository == null
          ? null
          : await _experienceRepository.fetchExperience(sessionId: sessionId);
      emit(
        state.copyWith(
          status: isComplete ? SessionStatus.completed : SessionStatus.ready,
          currentRound: nextRound,
          clearLastFeedback: !keepFeedback,
          clearReveal: true,
          clearSharedReveal: true,
          clearErrorMessage: true,
          requiresReauthentication: false,
          exchanges: experience?.exchanges,
          mode: experience?.mode,
          decade: experience?.decade,
          parentSessionId: experience?.parentSessionId,
          publication: experience?.publication,
          clearPublication: experience?.publication == null,
          shareMayBePublic: experience?.publication?.isPublic == true,
          shareVerified: false,
          clearShareError: true,
          read: experience?.latestRead,
          milestone: experience?.milestone,
          clearMilestone: experience?.milestone == null,
          clearRead: experience != null && experience.latestRead == null,
          clearSelection:
              nextRound.pairing?.id != state.currentRound?.pairing?.id,
        ),
      );
      if (isComplete && _resultRepository != null) await revealSession();
    } catch (error) {
      _logger.error('session.next_pairing_failed', error, <String, Object?>{
        'sessionId': sessionId,
      });
      final apiError = error is AppApiException ? error : null;
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: _readableError(apiError ?? error),
          requiresReauthentication: apiError?.isAuthRelated == true,
        ),
      );
    }
  }

  Future<void> react(SessionReaction reaction) async {
    final repository = _experienceRepository;
    final sessionId = state.sessionId;
    if (repository == null ||
        sessionId == null ||
        state.reacting ||
        state.status != SessionStatus.ready) {
      return;
    }
    if (_pendingReaction != null && _pendingReaction != reaction) return;
    _pendingReaction = reaction;
    _reactionPairingId ??= state.currentRound?.pairing?.id;
    _reactionMutationId ??= List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _logger.event('session.reaction_requested', {
      'sessionId': sessionId,
      'kind': reaction.wireName,
    });
    emit(state.copyWith(reacting: true, clearErrorMessage: true));
    try {
      final effect = await repository.react(
        sessionId: sessionId,
        reaction: reaction,
        mutationId: _reactionMutationId!,
        pairingId: _reactionPairingId,
      );
      final experience = await repository.fetchExperience(sessionId: sessionId);
      _pendingReaction = null;
      _reactionMutationId = null;
      _reactionPairingId = null;
      emit(
        state.copyWith(
          reacting: false,
          reactionMessage: effect.message,
          currentRound: effect.next,
          exchanges: experience.exchanges,
          read: experience.latestRead,
          clearRead: experience.latestRead == null,
          clearErrorMessage: true,
          clearSelection: effect.next != null,
          status: effect.next?.done == true
              ? SessionStatus.completed
              : SessionStatus.ready,
        ),
      );
      _logger.event('session.reaction_succeeded', {
        'sessionId': sessionId,
        'effect': effect.effect,
      });
      if (effect.next?.done == true && _resultRepository != null) {
        await revealSession();
      }
    } catch (error) {
      _logger.event('session.reaction_failed', {'sessionId': sessionId});
      final apiError = error is AppApiException ? error : null;
      emit(
        state.copyWith(
          reacting: false,
          errorMessage: _readableError(error),
          requiresReauthentication: apiError?.isAuthRelated == true,
        ),
      );
    }
  }

  String _readableError(Object error) {
    if (error is AppApiException) {
      switch (error.code) {
        case 'NO_RESULT':
          return 'No saved reading is available yet.';
        case 'VERSION_NOT_FOUND':
          return 'This saved reading version is not available.';
        case 'NOT_FOUND':
          return 'This reading could not be found in your account.';
        case 'UNAVAILABLE':
          return 'Your saved reading could not be loaded. Please try again.';
      }
      switch (error.kind) {
        case AppApiErrorKind.unauthorized:
        case AppApiErrorKind.forbidden:
          return 'Your session expired. Sign in again to keep going.';
        case AppApiErrorKind.network:
          return 'You appear to be offline. Reconnect and retry this step.';
        case AppApiErrorKind.invalidInput:
          return error.message;
        case AppApiErrorKind.upstream:
        case AppApiErrorKind.internal:
        case AppApiErrorKind.unknown:
          return error.message.isEmpty
              ? 'We could not continue your session right now.'
              : error.message;
      }
    }

    final message = error.toString().trim();
    return message.isEmpty ? 'Something went wrong.' : message;
  }

  int _normalizeMsToDecide(int msToDecide) {
    return msToDecide.clamp(0, maxMsToDecide).toInt();
  }
}
