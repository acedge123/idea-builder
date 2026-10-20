import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math';

import '../domain/continuation_repository.dart';

enum ContinuationStatus { initial, loading, ready, sending, failed }

class ContinuationState {
  const ContinuationState({
    this.status = ContinuationStatus.initial,
    this.messages = const [],
    this.draft = '',
    this.failure,
    this.uncertainDelivery = false,
    this.versions = const [],
  });
  final ContinuationStatus status;
  final List<ConversationMessage> messages;
  final String draft;
  final ContinuationFailure? failure;
  final bool uncertainDelivery;
  final List<ConversationResultVersion> versions;

  bool get busy =>
      status == ContinuationStatus.loading ||
      status == ContinuationStatus.sending;
  bool get canSend =>
      status == ContinuationStatus.ready &&
      !uncertainDelivery &&
      draft.trim().isNotEmpty &&
      draft.trim().length <= 2000;
}

class ContinuationCubit extends Cubit<ContinuationState> {
  ContinuationCubit(this.context, this._repository)
    : super(const ContinuationState());
  final ContinuationContext context;
  final ContinuationRepository _repository;
  String? _mutationId, _submittedMessage;

  void editDraft(String value) {
    if (state.busy || state.uncertainDelivery) return;
    emit(
      ContinuationState(
        status: state.status,
        messages: state.messages,
        draft: value,
        failure: state.failure,
        uncertainDelivery: state.uncertainDelivery,
        versions: state.versions,
      ),
    );
  }

  Future<void> load() async {
    if (state.busy) return;
    _transition(ContinuationStatus.loading);
    try {
      final snapshot = await _repository.load(context);
      _validate(snapshot);
      if (isClosed) return;
      final reconciled =
          _mutationId != null &&
          snapshot.messages.any(
            (m) =>
                m.role == ConversationRole.user &&
                m.mutationId == _mutationId &&
                m.content == _submittedMessage,
          ) &&
          snapshot.messages.any(
            (m) =>
                m.role == ConversationRole.assistant &&
                m.mutationId == '$_mutationId:reply' &&
                m.content.trim().isNotEmpty,
          );
      if (reconciled) {
        _mutationId = null;
        _submittedMessage = null;
      }
      emit(
        ContinuationState(
          status: ContinuationStatus.ready,
          messages: snapshot.messages,
          versions: snapshot.versions,
          draft: reconciled ? '' : state.draft,
          uncertainDelivery: state.uncertainDelivery && !reconciled,
        ),
      );
    } catch (error) {
      _fail(error, writing: false);
    }
  }

  Future<void> send() async {
    if (!state.canSend) return;
    final message = state.draft.trim();
    if (_submittedMessage != message || _mutationId == null) {
      _submittedMessage = message;
      final random = Random.secure();
      _mutationId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    }
    _transition(ContinuationStatus.sending);
    try {
      final snapshot = await _repository.submit(
        context,
        message,
        mutationId: _mutationId!,
      );
      _validate(snapshot);
      if (isClosed) return;
      _mutationId = null;
      _submittedMessage = null;
      emit(
        ContinuationState(
          status: ContinuationStatus.ready,
          messages: snapshot.messages,
          versions: snapshot.versions,
        ),
      );
    } catch (error) {
      _fail(error, writing: true);
    }
  }

  void _validate(ConversationSnapshot snapshot) {
    if (snapshot.sessionId != context.sessionId) {
      throw StateError('Conversation session mismatch');
    }
  }

  void _transition(ContinuationStatus status) => emit(
    ContinuationState(
      status: status,
      messages: state.messages,
      draft: state.draft,
      uncertainDelivery: state.uncertainDelivery,
      versions: state.versions,
    ),
  );

  void _fail(Object error, {required bool writing}) {
    if (isClosed) return;
    final failure = error is ContinuationException
        ? error.failure
        : writing
        ? ContinuationFailure.uncertain
        : ContinuationFailure.rejected;
    emit(
      ContinuationState(
        status: ContinuationStatus.failed,
        messages: state.messages,
        draft: state.draft,
        versions: state.versions,
        failure: failure,
        uncertainDelivery:
            state.uncertainDelivery || failure == ContinuationFailure.uncertain,
      ),
    );
  }
}
