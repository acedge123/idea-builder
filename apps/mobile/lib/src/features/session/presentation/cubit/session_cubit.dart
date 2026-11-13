import '../../domain/repositories/session_pushback_repository.dart';
import '../../domain/entities/interview_flow.dart';
import '../../domain/repositories/session_flow_repository.dart';
import '../../domain/entities/critic_stage_policy.dart';
import 'dart:async';
import '../../domain/repositories/session_critic_repository.dart';
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
  critic,
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
    this.criticPending = false,
    this.criticMessage,
    this.criticSettled = false,
    this.criticWaitLine,
    this.skipping = false,
    this.pushbackSaving = false,
    this.pushbackReply,
    this.pushbackError,
    this.prefetchedRound,
    this.nextPairingError,
    this.nextPairingLoading = false,
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
    this.flow = InterviewFlow.perPick,
    this.checkpointAnswered,
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
  final bool criticPending;
  final String? criticMessage;
  final bool criticSettled, nextPairingLoading;
  final bool skipping;
  final bool pushbackSaving;
  final String? pushbackReply, pushbackError;
  final String? criticWaitLine, nextPairingError;
  final SessionRoundState? prefetchedRound;
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
  final InterviewFlow flow;
  final int? checkpointAnswered;
  bool get isCheckpoint =>
      status == SessionStatus.critic &&
      flow == InterviewFlow.checkpoints &&
      checkpointAnswered != null;
  // Server guidance is optional; it must never replace the next song choices.
  SessionMilestone? get visibleMilestone => null;

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
    bool? criticPending,
    String? criticMessage,
    bool clearCriticMessage = false,
    bool? criticSettled,
    bool? skipping,
    bool? pushbackSaving,
    String? pushbackReply,
    bool clearPushbackReply = false,
    String? pushbackError,
    bool clearPushbackError = false,
    String? criticWaitLine,
    bool clearCriticWaitLine = false,
    SessionRoundState? prefetchedRound,
    bool clearPrefetchedRound = false,
    String? nextPairingError,
    bool clearNextPairingError = false,
    bool? nextPairingLoading,
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
    InterviewFlow? flow,
    int? checkpointAnswered,
    bool clearCheckpoint = false,
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
      criticPending: criticPending ?? this.criticPending,
      criticMessage: clearCriticMessage
          ? null
          : criticMessage ?? this.criticMessage,
      criticSettled: criticSettled ?? this.criticSettled,
      skipping: skipping ?? this.skipping,
      pushbackSaving: pushbackSaving ?? this.pushbackSaving,
      pushbackReply: clearPushbackReply
          ? null
          : pushbackReply ?? this.pushbackReply,
      pushbackError: clearPushbackError
          ? null
          : pushbackError ?? this.pushbackError,
      criticWaitLine: clearCriticWaitLine
          ? null
          : criticWaitLine ?? this.criticWaitLine,
      prefetchedRound: clearPrefetchedRound
          ? null
          : prefetchedRound ?? this.prefetchedRound,
      nextPairingError: clearNextPairingError
          ? null
          : nextPairingError ?? this.nextPairingError,
      nextPairingLoading: nextPairingLoading ?? this.nextPairingLoading,
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
      flow: flow ?? this.flow,
      checkpointAnswered: clearCheckpoint
          ? null
          : checkpointAnswered ?? this.checkpointAnswered,
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
    criticPending,
    criticMessage,
    criticSettled,
    criticWaitLine,
    skipping,
    pushbackSaving,
    pushbackReply,
    pushbackError,
    prefetchedRound,
    nextPairingError,
    nextPairingLoading,
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
    flow,
    checkpointAnswered,
  ];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(
    this._repository, {
    StartedMusicSession? startedSession,
    SessionResumeStore? resumeStore,
    AppLogger? logger,
    SessionExperienceRepository? experienceRepository,
    SessionCriticRepository? criticRepository,
    SessionPushbackRepository? pushbackRepository,
    Future<CriticFillers> Function()? loadCriticCopy,
    SessionResultRepository? resultRepository,
    SessionPreparationRepository? preparationRepository,
    SavedReadingRepository? savedReadingRepository,
    SessionFlowRepository? flowRepository,
  }) : _logger = logger ?? const AppLogger(),
       _resumeStore = resumeStore,
       _experienceRepository = experienceRepository,
       _criticRepository = criticRepository,
       _pushbackRepository = pushbackRepository,
       _loadCriticCopy = loadCriticCopy,
       _resultRepository = resultRepository,
       _preparationRepository = preparationRepository,
       _savedReadingRepository = savedReadingRepository,
       _flowRepository = flowRepository,
       super(SessionState(startedSession: startedSession));

  final SessionRepository _repository;
  final SessionFlowRepository? _flowRepository;
  final AppLogger _logger;
  final SessionResumeStore? _resumeStore;
  final SessionResultRepository? _resultRepository;
  final SessionExperienceRepository? _experienceRepository;
  final SessionCriticRepository? _criticRepository;
  final SessionPushbackRepository? _pushbackRepository;
  String? _pushbackText, _pushbackMutationId;
  bool get hasPushback => _pushbackRepository != null;
  int _flowRevision = 0;
  Timer? _criticDeadlineTimer, _criticFillerTimer, _quipHoldTimer;
  bool _holdingQuip = false;
  String? _readPairingId;
  int? _readAnswered;
  final Future<CriticFillers> Function()? _loadCriticCopy;
  CriticFillers? _fillers;
  List<String> _waitingLines = const [];
  int _waitingIndex = 0, _skipCount = 0;
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
    _cancelCriticTimers();
    _flowRevision++;
    final revision = _flowRevision;
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

    try {
      final flow = await _flowRepository?.fetchFlow(sessionId: sessionId);
      if (isClosed || revision != _flowRevision) return;
      if (_flowRepository != null &&
          flow == null &&
          state.startedSession?.flow == InterviewFlow.checkpoints) {
        throw const AppApiException(
          kind: AppApiErrorKind.upstream,
          message: 'The interview could not be restored. Please try again.',
        );
      }
      emit(
        state.copyWith(
          flow: flow ?? state.startedSession?.flow ?? InterviewFlow.perPick,
          clearCheckpoint: true,
        ),
      );
      _logger.event('session.flow_restored', {'flow': state.flow.wireName});
    } catch (error) {
      if (isClosed || revision != _flowRevision) return;
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          errorMessage: _readableError(error),
          requiresReauthentication:
              error is AppApiException && error.isAuthRelated,
        ),
      );
      return;
    }
    if (_fillers == null && _loadCriticCopy != null) {
      _fillers = await _loadCriticCopy();
      if (isClosed || revision != _flowRevision) return;
    }
    _beginWaitingCopy(wait: 0, revision: _flowRevision);
    await _loadNextPairing(
      sessionId: sessionId,
      keepFeedback: state.lastFeedback != null,
      restoreCheckpoint: true,
    );
  }

  Future<void> chooseSong({
    required String chosenSongId,
    required int msToDecide,
  }) async {
    if (state.status != SessionStatus.ready ||
        state.pushbackSaving ||
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

    _cancelCriticTimers();
    final revision = ++_flowRevision;
    _pushbackText = null;
    _pushbackMutationId = null;
    emit(
      state.copyWith(
        status: SessionStatus.submitting,
        skipping: false,
        clearRead: true,
        criticPending: false,
        criticSettled: false,
        clearPrefetchedRound: true,
        clearNextPairingError: true,
        clearCriticWaitLine: true,
        clearCriticMessage: true,
        clearErrorMessage: true,
        selectedSongId: chosenSongId,
        clearLastFeedback: true,
        clearReactionMessage: true,
        clearCheckpoint: true,
        clearPushbackReply: true,
        clearPushbackError: true,
      ),
    );

    _beginWaitingCopy(
      wait: state.currentRound!.round,
      revision: revision,
      pairing: pairing,
    );
    try {
      final feedback = await _repository.submitChoice(
        sessionId: sessionId,
        pairingId: pairingId,
        chosenSongId: chosenSongId,
        msToDecide: _normalizeMsToDecide(msToDecide),
      );
      if (isClosed || revision != _flowRevision) return;
      _logger.event('session.choice_succeeded', <String, Object?>{
        'sessionId': sessionId,
        'pairingId': pairingId,
      });
      if (hasExperience) {
        final answered = state.currentRound!.round;
        _readPairingId = pairingId;
        _readAnswered = answered;
        final finalPick =
            answered >= (state.currentRound!.maxAnswered ?? maxPairingRounds);
        final checkpointFlow = state.flow == InterviewFlow.checkpoints;
        final checkpoint = checkpointFlow && (answered == 2 || answered == 4);
        final quipOnly = checkpointFlow && !checkpoint && !finalPick;
        final pending =
            !finalPick &&
            !quipOnly &&
            feedback.readPending &&
            _criticRepository != null;
        if (_waitingIndex == 0) {
          _waitingLines =
              _fillers?.waitingLines(
                answered,
                hunch: feedback.hunch ?? 'early',
                pairing: pairing,
              ) ??
              const [];
        }
        emit(
          state.copyWith(
            status: SessionStatus.critic,
            lastFeedback: feedback,
            read: feedback.read,
            clearRead: feedback.read == null,
            criticPending: pending,
            criticSettled: !pending,
            nextPairingLoading: true,
            checkpointAnswered: checkpoint ? answered : null,
            clearCheckpoint: !checkpoint,
            criticMessage:
                !pending && !finalPick && !quipOnly && feedback.read == null
                ? (checkpoint
                      ? CriticStagePolicy.checkpointUnavailable
                      : CriticStagePolicy.unavailable)
                : null,
            clearCriticMessage:
                pending || feedback.read != null || finalPick || quipOnly,
          ),
        );
        if (quipOnly) {
          _cancelCriticTimers();
          _holdingQuip = true;
          final lines = _fillers?.waitingLines(
            answered,
            hunch: feedback.hunch ?? 'early',
            pairing: pairing,
          );
          emit(
            state.copyWith(
              clearRead: true,
              criticWaitLine: lines != null && lines.length > 1
                  ? lines[1]
                  : state.criticWaitLine,
            ),
          );
          _quipHoldTimer = Timer(CriticStagePolicy.fillerInterval, () {
            if (isClosed || revision != _flowRevision) return;
            _holdingQuip = false;
            _releaseCriticWhenReady();
          });
        }
        if (pending) {
          _startCriticDeadline(revision);
          unawaited(
            _deliverCriticRead(
              sessionId: sessionId,
              afterPairingId: pairingId,
              answered: answered,
              revision: revision,
            ),
          );
        }
        await _prefetchCriticNext(sessionId: sessionId, revision: revision);
      } else {
        await _loadNextPairing(
          sessionId: sessionId,
          keepFeedback: true,
          feedback: feedback,
        );
      }
    } catch (error) {
      if (isClosed || revision != _flowRevision) return;
      _cancelCriticTimers();
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
        state.pushbackSaving ||
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

    _cancelCriticTimers();
    final revision = ++_flowRevision;
    final skippedPairing = state.currentRound!.pairing!;
    emit(
      state.copyWith(
        status: SessionStatus.submitting,
        skipping: true,
        clearRead: true,
        criticWaitLine: _fillers?.skipLine(_skipCount++, skippedPairing),
        criticPending: false,
        clearCriticMessage: true,
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
      if (isClosed || revision != _flowRevision) return;
      _logger.event('session.skip_succeeded', <String, Object?>{
        'sessionId': sessionId,
        'pairingId': pairingId,
      });
      await _loadNextPairing(sessionId: sessionId, keepFeedback: false);
    } catch (error) {
      if (isClosed || revision != _flowRevision) return;
      _cancelCriticTimers();
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
    if (state.isCheckpoint &&
        state.checkpointAnswered == 4 &&
        !state.criticPending &&
        !state.pushbackSaving) {
      await revealSession(finishEarly: true);
      return;
    }
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
        (state.flow == InterviewFlow.checkpoints &&
            !const [2, 4, 6].contains(state.currentRound?.round)) ||
        repository == null ||
        sessionId == null ||
        pairing?.exposureId == null ||
        state.status != SessionStatus.ready ||
        state.visibleMilestone != null ||
        state.criticPending ||
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
    _cancelCriticTimers();
    _flowRevision++;
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
        criticPending: false,
        clearCriticMessage: true,
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
    SessionChoiceFeedback? feedback,
    String? afterPairingId,
    bool restoreCheckpoint = false,
  }) async {
    final revision = _flowRevision;
    try {
      final nextRound = await _repository.fetchNextPairing(
        sessionId: sessionId,
      );
      if (isClosed || revision != _flowRevision) return;
      final isComplete =
          nextRound.done ||
          (!nextRound.experienceVersion &&
              (nextRound.pairing == null ||
                  nextRound.round > maxPairingRounds));
      final pending =
          !isComplete && afterPairingId != null && _criticRepository != null;
      final answered = nextRound.round - 1;
      if (restoreCheckpoint &&
          !isComplete &&
          state.flow == InterviewFlow.checkpoints &&
          const [2, 4].contains(answered)) {
        // Read history before exposing any cards. A missing/failed read is a
        // recoverable checkpoint, never permission to skip straight past it.
        final experience = await _experienceRepository!.fetchExperience(
          sessionId: sessionId,
        );
        if (isClosed || revision != _flowRevision) return;
        final choices = experience.exchanges
            .where((e) => e.type == 'choice')
            .toList();
        final lastChoice = choices.isEmpty ? null : choices.last;
        if (choices.length != answered || lastChoice?.pairingId == null) {
          throw const AppApiException(
            kind: AppApiErrorKind.upstream,
            message: 'The interview could not be restored. Please try again.',
          );
        }
        SessionRead? savedRead;
        for (final exchange in experience.exchanges.reversed) {
          if (exchange.type == 'choice') break;
          if (exchange.read != null &&
              (exchange.answered == null || exchange.answered == answered)) {
            savedRead = exchange.read;
            break;
          }
        }
        if (savedRead?.thesis.trim().isEmpty == true) savedRead = null;
        _readPairingId = lastChoice!.pairingId;
        _readAnswered = answered;
        _cancelCriticTimers();
        emit(
          state.copyWith(
            status: SessionStatus.critic,
            currentRound: nextRound,
            prefetchedRound: nextRound,
            checkpointAnswered: answered,
            exchanges: experience.exchanges,
            mode: experience.mode,
            decade: experience.decade,
            parentSessionId: experience.parentSessionId,
            read: savedRead,
            clearRead: savedRead == null,
            criticPending: false,
            criticSettled: true,
            criticMessage: savedRead == null
                ? CriticStagePolicy.checkpointUnavailable
                : null,
            clearCriticMessage: savedRead != null,
            clearCriticWaitLine: true,
            clearLastFeedback: true,
            clearSelection: true,
            nextPairingLoading: false,
            clearErrorMessage: true,
          ),
        );
        _logger.event('session.checkpoint_restored', {
          'answered': answered,
          'hasRead': savedRead != null,
        });
        return;
      }
      _logger.event('session.next_pairing_loaded', {
        'round': nextRound.round,
        'done': isComplete,
        'criticPending': pending,
      });
      _cancelCriticTimers();
      // Pairing paint is independent of optional history latency.
      emit(
        state.copyWith(
          status: isComplete ? SessionStatus.completed : SessionStatus.ready,
          currentRound: nextRound,
          lastFeedback: feedback,
          clearLastFeedback: !keepFeedback,
          read: feedback?.read,
          clearRead: afterPairingId != null,
          criticPending: pending,
          skipping: false,
          clearCriticWaitLine: true,
          clearCriticMessage: true,
          clearReveal: true,
          clearSharedReveal: true,
          clearErrorMessage: true,
          requiresReauthentication: false,
          clearSelection:
              nextRound.pairing?.id != state.currentRound?.pairing?.id,
        ),
      );
      if (isComplete && _resultRepository != null) {
        await revealSession();
        if (!isClosed) {
          await _refreshExperience(
            sessionId: sessionId,
            revision: _flowRevision,
            includeRead: false,
          );
        }
        return;
      }
      await _refreshExperience(sessionId: sessionId, revision: revision);
    } catch (error) {
      if (isClosed || revision != _flowRevision) return;
      _logger.error('session.next_pairing_failed', error);
      emit(
        state.copyWith(
          status: SessionStatus.failure,
          lastFeedback: feedback,
          read: feedback?.read,
          criticPending: false,
          errorMessage: _readableError(error),
          requiresReauthentication:
              error is AppApiException && error.isAuthRelated,
        ),
      );
    }
  }

  void _cancelCriticTimers() {
    _criticDeadlineTimer?.cancel();
    _criticFillerTimer?.cancel();
    _quipHoldTimer?.cancel();
    _holdingQuip = false;
  }

  void _beginWaitingCopy({
    required int wait,
    required int revision,
    SessionPairing? pairing,
  }) {
    _waitingIndex = 0;
    _waitingLines = _fillers?.waitingLines(wait, pairing: pairing) ?? const [];
    if (_waitingLines.isEmpty) return;
    emit(state.copyWith(criticWaitLine: _waitingLines.first));
    _criticFillerTimer = Timer.periodic(CriticStagePolicy.fillerInterval, (
      timer,
    ) {
      if (isClosed ||
          revision != _flowRevision ||
          ![
            SessionStatus.loading,
            SessionStatus.submitting,
            SessionStatus.critic,
          ].contains(state.status)) {
        timer.cancel();
        return;
      }
      if (_waitingIndex >= _waitingLines.length - 1) {
        timer.cancel();
        return;
      }
      emit(state.copyWith(criticWaitLine: _waitingLines[++_waitingIndex]));
    });
  }

  void _startCriticDeadline(int revision) {
    _criticDeadlineTimer = Timer(CriticStagePolicy.readDeadline, () {
      if (isClosed ||
          revision != _flowRevision ||
          state.status != SessionStatus.critic ||
          !state.criticPending) {
        return;
      }
      _cancelCriticTimers();
      emit(
        state.copyWith(
          criticSettled: true,
          criticPending: false,
          clearCriticWaitLine: true,
          criticMessage: state.isCheckpoint
              ? CriticStagePolicy.checkpointUnavailable
              : CriticStagePolicy.unavailable,
        ),
      );
      _logger.event('session.critic_wait_elapsed');
      _releaseCriticWhenReady();
    });
  }

  Future<void> _prefetchCriticNext({
    required String sessionId,
    required int revision,
  }) async {
    try {
      final next = await _repository.fetchNextPairing(sessionId: sessionId);
      if (isClosed ||
          revision != _flowRevision ||
          state.status != SessionStatus.critic) {
        return;
      }
      if (next.done || (!next.experienceVersion && next.pairing == null)) {
        _cancelCriticTimers();
        emit(
          state.copyWith(
            status: SessionStatus.completed,
            currentRound: next,
            criticPending: false,
            nextPairingLoading: false,
            clearSelection: true,
          ),
        );
        if (_resultRepository != null) {
          await revealSession();
          if (!isClosed) {
            await _refreshExperience(
              sessionId: sessionId,
              revision: _flowRevision,
              includeRead: false,
            );
          }
        }
        return;
      }
      emit(
        state.copyWith(
          prefetchedRound: next,
          nextPairingLoading: false,
          clearNextPairingError: true,
        ),
      );
      _releaseCriticWhenReady();
      unawaited(
        _refreshExperience(
          sessionId: sessionId,
          revision: _flowRevision,
          includeRead: false,
        ),
      );
    } catch (_) {
      if (isClosed ||
          revision != _flowRevision ||
          state.status != SessionStatus.critic) {
        return;
      }
      emit(
        state.copyWith(
          nextPairingLoading: false,
          nextPairingError:
              'Your choice is saved. The next matchup couldn’t load.',
        ),
      );
      _logger.event('session.next_pairing_unavailable');
    }
  }

  Future<void> retryNextMatchup() async {
    final sessionId = state.sessionId;
    final pairingId = state.currentRound?.pairing?.id;
    if (state.status != SessionStatus.critic ||
        state.nextPairingLoading ||
        sessionId == null ||
        pairingId == null) {
      return;
    }
    emit(state.copyWith(nextPairingLoading: true, clearNextPairingError: true));
    await _prefetchCriticNext(sessionId: sessionId, revision: _flowRevision);
  }

  void _releaseCriticWhenReady() {
    final next = state.prefetchedRound;
    if (state.status != SessionStatus.critic ||
        !state.criticSettled ||
        state.isCheckpoint ||
        _holdingQuip ||
        state.reacting ||
        _pendingReaction != null ||
        next == null) {
      return;
    }
    _cancelCriticTimers();
    _flowRevision++;
    emit(
      state.copyWith(
        status: SessionStatus.ready,
        currentRound: next,
        clearSelection: true,
        clearPrefetchedRound: true,
        criticPending: false,
        criticSettled: false,
        clearCriticWaitLine: true,
        clearCheckpoint: true,
        clearRead: state.flow == InterviewFlow.checkpoints,
        clearLastFeedback: state.flow == InterviewFlow.checkpoints,
        clearCriticMessage: state.flow == InterviewFlow.checkpoints,
      ),
    );
    _logger.event('session.critic_pairing_revealed');
  }

  void continueCheckpoint() {
    if (!state.isCheckpoint ||
        state.criticPending ||
        state.pushbackSaving ||
        state.prefetchedRound == null ||
        state.nextPairingLoading) {
      return;
    }
    final answered = state.checkpointAnswered;
    emit(state.copyWith(clearCheckpoint: true));
    _releaseCriticWhenReady();
    _logger.event('session.checkpoint_continued', {'answered': answered});
  }

  Future<void> retryCheckpointRead() async {
    if (!state.isCheckpoint ||
        state.criticPending ||
        state.pushbackSaving ||
        _criticRepository == null ||
        _readPairingId == null ||
        _readAnswered == null) {
      return;
    }
    // Explicit retry only; never resubmit the committed choice.
    final revision = ++_flowRevision;
    _cancelCriticTimers();
    emit(
      state.copyWith(
        criticPending: true,
        criticSettled: false,
        clearCriticMessage: true,
      ),
    );
    _beginWaitingCopy(wait: _readAnswered!, revision: revision);
    _startCriticDeadline(revision);
    await _deliverCriticRead(
      sessionId: state.sessionId!,
      afterPairingId: _readPairingId!,
      answered: _readAnswered!,
      revision: revision,
    );
    // A next-pair request from the previous revision may have been discarded.
    if (!isClosed &&
        revision == _flowRevision &&
        state.prefetchedRound == null) {
      await _prefetchCriticNext(
        sessionId: state.sessionId!,
        revision: revision,
      );
    }
  }

  Future<void> _refreshExperience({
    required String sessionId,
    required int revision,
    bool includeRead = true,
  }) async {
    // Metadata failure cannot invalidate a committed pick or a finished report.
    try {
      final experience = await _experienceRepository?.fetchExperience(
        sessionId: sessionId,
      );
      if (isClosed || revision != _flowRevision || experience == null) return;
      emit(
        state.copyWith(
          exchanges: experience.exchanges,
          mode: experience.mode,
          decade: experience.decade,
          parentSessionId: experience.parentSessionId,
          publication: experience.publication,
          clearPublication: experience.publication == null,
          shareMayBePublic: experience.publication?.isPublic == true,
          shareVerified: false,
          clearShareError: true,
          read: !includeRead || state.criticPending
              ? null
              : (state.read ?? experience.latestRead),
          milestone: experience.milestone,
          clearMilestone: experience.milestone == null,
        ),
      );
    } catch (_) {
      _logger.event('session.history_refresh_unavailable');
    }
  }

  Future<void> _deliverCriticRead({
    required String sessionId,
    required String afterPairingId,
    required int answered,
    required int revision,
  }) async {
    try {
      final read = await _criticRepository!.fetchRead(
        sessionId: sessionId,
        afterPairingId: afterPairingId,
        answered: answered,
      );
      if (isClosed ||
          revision != _flowRevision ||
          state.status != SessionStatus.critic ||
          !state.criticPending) {
        return;
      }
      _cancelCriticTimers();
      emit(
        state.copyWith(
          read: read,
          criticSettled: true,
          clearCriticWaitLine: true,
          criticPending: false,
          clearCriticMessage: true,
        ),
      );
      _logger.event('session.critic_delivered', {'answered': answered});
      _releaseCriticWhenReady();
    } catch (error) {
      if (isClosed ||
          revision != _flowRevision ||
          state.status != SessionStatus.critic ||
          !state.criticPending) {
        return;
      }
      _cancelCriticTimers();
      // No automatic model retry after an uncertain outcome. Votes remain saved.
      emit(
        state.copyWith(
          criticPending: false,
          criticSettled: true,
          clearCriticWaitLine: true,
          criticMessage: state.isCheckpoint
              ? CriticStagePolicy.checkpointUnavailable
              : CriticStagePolicy.unavailable,
        ),
      );
      _logger.event('session.critic_unavailable', {'answered': answered});
      _releaseCriticWhenReady();
    }
  }

  Future<void> submitPushback(String message) async {
    final text = message.trim();
    final sessionId = state.sessionId;
    if (_pushbackRepository == null ||
        sessionId == null ||
        text.isEmpty ||
        text.length > 500 ||
        !((state.status == SessionStatus.ready &&
                state.flow == InterviewFlow.perPick &&
                state.currentRound?.round == 4) ||
            (state.status == SessionStatus.critic &&
                state.isCheckpoint &&
                !state.criticPending)) ||
        state.pushbackSaving ||
        state.reacting ||
        (!state.isCheckpoint && state.selectedSongId != null) ||
        _pendingReaction != null) {
      return;
    }
    if (_pushbackText != text) {
      _pushbackText = text;
      _pushbackMutationId = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    }
    final revision = _flowRevision;
    emit(state.copyWith(pushbackSaving: true, clearPushbackError: true));
    _logger.event('session.pushback_requested');
    try {
      final saved = await _pushbackRepository.submitPushback(
        sessionId: sessionId,
        text: text,
        mutationId: _pushbackMutationId!,
      );
      if (isClosed || revision != _flowRevision) return;
      emit(state.copyWith(pushbackSaving: false, pushbackReply: saved.reply));
      _logger.event('session.pushback_saved');
      unawaited(_refreshExperience(sessionId: sessionId, revision: revision));
    } catch (_) {
      if (isClosed || revision != _flowRevision) return;
      emit(
        state.copyWith(
          pushbackSaving: false,
          pushbackError:
              "Couldn't save that. Keep going — your picks still count.",
        ),
      );
      _logger.event('session.pushback_unavailable');
    }
  }

  Future<void> react(SessionReaction reaction) async {
    final repository = _experienceRepository;
    final sessionId = state.sessionId;
    if (repository == null ||
        sessionId == null ||
        state.reacting ||
        state.pushbackSaving ||
        state.criticPending ||
        state.status != SessionStatus.ready) {
      return;
    }
    if (_pendingReaction != null && _pendingReaction != reaction) return;
    _pendingReaction = reaction;
    final revision = _flowRevision;
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
      if (isClosed || revision != _flowRevision) return;
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
      if (isClosed || revision != _flowRevision) return;
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

  @override
  Future<void> close() {
    _cancelCriticTimers();
    _flowRevision++;
    return super.close();
  }
}
