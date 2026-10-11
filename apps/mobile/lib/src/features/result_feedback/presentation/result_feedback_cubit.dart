import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/app_api_exception.dart';
import '../domain/result_feedback.dart';
import '../domain/result_feedback_repository.dart';

class ResultFeedbackState extends Equatable {
  const ResultFeedbackState({
    this.draft = const FeedbackDraft(),
    this.saved,
    this.busy = false,
    this.loaded = false,
    this.uncertain = false,
    this.requiresSignIn = false,
    this.error,
  });
  final FeedbackDraft draft;
  final SavedResultFeedback? saved;
  final bool busy, loaded, uncertain, requiresSignIn;
  final String? error;
  bool get dirty => draft.normalized != (saved?.draft ?? const FeedbackDraft());
  bool get canSave =>
      loaded &&
      !busy &&
      !uncertain &&
      !requiresSignIn &&
      draft.normalized.isValid &&
      dirty;
  @override
  List<Object?> get props => [
    draft,
    saved,
    busy,
    loaded,
    uncertain,
    requiresSignIn,
    error,
  ];
}

class ResultFeedbackCubit extends Cubit<ResultFeedbackState> {
  ResultFeedbackCubit({
    required this.target,
    required ResultFeedbackRepository repository,
    required String? Function() currentOwnerId,
    Stream<String?>? ownerChanges,
    AppLogger logger = const AppLogger(),
  }) : _repository = repository,
       _currentOwnerId = currentOwnerId,
       _logger = logger,
       super(const ResultFeedbackState()) {
    _ownerSubscription = ownerChanges?.listen((owner) {
      if (!isClosed && owner != target.ownerId) _invalidateOwner();
    });
  }
  final FeedbackTarget target;
  final ResultFeedbackRepository _repository;
  final String? Function() _currentOwnerId;
  final AppLogger _logger;
  String? _pendingMutation;
  FeedbackDraft? _pendingDraft;
  StreamSubscription<String?>? _ownerSubscription;
  bool _invalidated = false;

  @override
  Future<void> close() async {
    await _ownerSubscription?.cancel();
    return super.close();
  }

  bool _ownerIsCurrent() {
    if (isClosed || _invalidated) return false;
    if (_currentOwnerId() == target.ownerId && target.ownerId.isNotEmpty) {
      return true;
    }
    _invalidateOwner();
    return false;
  }

  void _invalidateOwner() {
    _invalidated = true;
    _pendingMutation = null;
    _pendingDraft = null;
    emit(
      const ResultFeedbackState(
        requiresSignIn: true,
        error: 'Sign in again to view your feedback.',
      ),
    );
  }

  void edit(FeedbackDraft draft) {
    if (!_ownerIsCurrent() ||
        !state.loaded ||
        state.busy ||
        state.uncertain ||
        state.requiresSignIn) {
      return;
    }
    emit(
      ResultFeedbackState(
        draft: draft,
        saved: state.saved,
        loaded: state.loaded,
      ),
    );
  }

  Future<void> load() async {
    if (!_ownerIsCurrent() || state.busy || !_repository.available) return;
    final before = state;
    emit(
      ResultFeedbackState(
        draft: before.draft,
        saved: before.saved,
        loaded: before.loaded,
        uncertain: before.uncertain,
        busy: true,
      ),
    );
    try {
      final saved = await _repository.load(target);
      if (!_ownerIsCurrent()) return;
      if (saved != null &&
          (saved.target != target ||
              !saved.draft.isValid ||
              saved.mutationId.isEmpty)) {
        throw const FormatException('Invalid feedback identity');
      }
      final reconciled =
          _pendingMutation != null &&
          saved?.mutationId == _pendingMutation &&
          saved?.draft == _pendingDraft;
      if (reconciled) {
        _pendingMutation = null;
        _pendingDraft = null;
      }
      emit(
        ResultFeedbackState(
          draft: reconciled || !before.dirty
              ? saved?.draft ?? const FeedbackDraft()
              : before.draft,
          saved: saved,
          loaded: true,
          uncertain: before.uncertain && !reconciled,
          error: before.uncertain && !reconciled
              ? 'Your save is still unconfirmed. Check again before sending.'
              : null,
        ),
      );
      _logger.event('result_feedback.loaded', {
        'version': target.resultVersion,
      });
    } catch (error) {
      if (!_ownerIsCurrent()) return;
      emit(
        ResultFeedbackState(
          draft: before.draft,
          saved: before.saved,
          loaded: before.loaded,
          uncertain: before.uncertain,
          requiresSignIn: _authError(error),
          error: 'Could not load your feedback. Try again.',
        ),
      );
      _logFailure(error);
    }
  }

  Future<void> save() async {
    if (!_ownerIsCurrent() || !state.canSave || !_repository.available) return;
    final before = state;
    final draft = before.draft.normalized;
    final mutation = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _pendingMutation = mutation;
    _pendingDraft = draft;
    emit(
      ResultFeedbackState(
        draft: before.draft,
        saved: before.saved,
        loaded: true,
        busy: true,
      ),
    );
    try {
      final saved = await _repository.save(
        target: target,
        draft: draft,
        mutationId: mutation,
      );
      if (!_ownerIsCurrent()) return;
      if (saved.target != target ||
          saved.draft != draft ||
          saved.mutationId != mutation) {
        throw const FormatException('Invalid feedback acknowledgment');
      }
      _pendingMutation = null;
      _pendingDraft = null;
      emit(ResultFeedbackState(draft: saved.draft, saved: saved, loaded: true));
      _logger.event('result_feedback.saved', {'version': target.resultVersion});
    } catch (error) {
      if (!_ownerIsCurrent()) return;
      final rejected =
          error is AppApiException &&
          [400, 401, 403, 404, 422].contains(error.statusCode);
      if (rejected) {
        _pendingMutation = null;
        _pendingDraft = null;
      }
      emit(
        ResultFeedbackState(
          draft: before.draft,
          saved: before.saved,
          loaded: true,
          uncertain: !rejected,
          requiresSignIn: _authError(error),
          error: rejected
              ? 'Feedback was not saved. Please try again.'
              : 'Your save is unconfirmed. Check saved feedback before sending again.',
        ),
      );
      _logFailure(error);
    }
  }

  bool _authError(Object error) =>
      error is AppApiException && error.isAuthRelated;
  void _logFailure(Object error) => _logger.event('result_feedback.failed', {
    'version': target.resultVersion,
    'kind': error is AppApiException
        ? error.kind.name
        : 'invalid_or_unconfirmed',
  });
}
