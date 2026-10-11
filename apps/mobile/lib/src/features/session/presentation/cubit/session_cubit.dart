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
import '../../domain/repositories/session_experience_repository.dart';
import '../../domain/entities/session_experience.dart';
import '../../domain/entities/session_result.dart';
import '../../domain/repositories/session_result_repository.dart';

enum SessionStatus {
  initial,
  loading,
  ready,
  submitting,
  completed,
  revealing,
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
    String? selectedSongId,
    bool clearSelection = false,
    bool? reacting,
    String? reactionMessage,
    SharePublication? publication,
    bool clearPublication = false,
    bool? sharing,
    bool? shareVerified,
    bool? shareMayBePublic,
    String? shareError,
    bool clearShareError = false,
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
      read: read ?? this.read,
      selectedSongId: clearSelection
          ? null
          : selectedSongId ?? this.selectedSongId,
      reacting: reacting ?? this.reacting,
      reactionMessage: reactionMessage ?? this.reactionMessage,
      publication: clearPublication ? null : publication ?? this.publication,
      sharing: sharing ?? this.sharing,
      shareVerified: shareVerified ?? this.shareVerified,
      shareMayBePublic: shareMayBePublic ?? this.shareMayBePublic,
      shareError: clearShareError ? null : shareError ?? this.shareError,
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
  }) : _logger = logger ?? const AppLogger(),
       _resumeStore = resumeStore,
       _experienceRepository = experienceRepository,
       _resultRepository = resultRepository,
       super(SessionState(startedSession: startedSession));

  final SessionRepository _repository;
  final AppLogger _logger;
  final SessionResumeStore? _resumeStore;
  final SessionResultRepository? _resultRepository;
  final SessionExperienceRepository? _experienceRepository;
  String? _reactionMutationId;
  SessionReaction? _pendingReaction;
  String? _reactionPairingId;
  bool get hasExperience => _experienceRepository != null;
  SessionReaction? get pendingReaction => _pendingReaction;
  static const int maxPairingRounds = 6;
  static const int maxMsToDecide = 600000;

  Future<void> initialize() async {
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
    final pairing = state.currentRound!.pairing!;
    if (chosenSongId != pairing.songA.id && chosenSongId != pairing.songB.id) {
      return;
    }

    emit(
      state.copyWith(
        status: SessionStatus.submitting,
        clearErrorMessage: true,
        selectedSongId: chosenSongId,
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

  Future<void> revealSession() async {
    if (state.status == SessionStatus.revealing || state.sharing) return;
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
        clearErrorMessage: true,
        requiresReauthentication: false,
      ),
    );

    try {
      final reveal = await _repository.revealSession(sessionId: sessionId);
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
          sharedReveal: sharedReveal,
          clearSharedReveal: sharedReveal == null,
          clearErrorMessage: true,
          requiresReauthentication: false,
        ),
      );
    } catch (error) {
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
          publication: experience?.publication,
          clearPublication: experience?.publication == null,
          shareMayBePublic: experience?.publication?.isPublic == true,
          shareVerified: false,
          clearShareError: true,
          read: experience?.latestRead,
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
          clearErrorMessage: true,
          clearSelection: effect.next != null,
          status: effect.next?.done == true
              ? SessionStatus.completed
              : SessionStatus.ready,
        ),
      );
    } catch (error) {
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
