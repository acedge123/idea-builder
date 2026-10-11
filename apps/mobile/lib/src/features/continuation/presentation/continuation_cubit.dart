import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/continuation_repository.dart';

enum ContinuationStatus { initial, loading, ready, sending, failed }

class ContinuationState {
  const ContinuationState({
    this.status = ContinuationStatus.initial,
    this.messages = const [],
    this.draft = '',
    this.failure,
    this.uncertainDelivery = false,
  });
  final ContinuationStatus status;
  final List<ConversationMessage> messages;
  final String draft;
  final ContinuationFailure? failure;
  final bool uncertainDelivery;

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

  void editDraft(String value) {
    if (state.status == ContinuationStatus.sending) return;
    emit(
      ContinuationState(
        status: state.status,
        messages: state.messages,
        draft: value,
        failure: state.failure,
        uncertainDelivery: state.uncertainDelivery,
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
      emit(
        ContinuationState(
          status: ContinuationStatus.ready,
          messages: snapshot.messages,
          draft: state.draft,
          uncertainDelivery: state.uncertainDelivery,
        ),
      );
    } catch (error) {
      _fail(error, writing: false);
    }
  }

  Future<void> send() async {
    if (!state.canSend) return;
    final message = state.draft.trim();
    _transition(ContinuationStatus.sending);
    try {
      final snapshot = await _repository.submit(context, message);
      _validate(snapshot);
      if (isClosed) return;
      emit(
        ContinuationState(
          status: ContinuationStatus.ready,
          messages: snapshot.messages,
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
        failure: failure,
        uncertainDelivery:
            state.uncertainDelivery || failure == ContinuationFailure.uncertain,
      ),
    );
  }
}
