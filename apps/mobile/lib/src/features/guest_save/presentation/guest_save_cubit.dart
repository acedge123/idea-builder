import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/guest_reading.dart';
import '../domain/guest_save_repository.dart';

enum GuestSaveStep {
  loading,
  email,
  confirmation,
  password,
  saved,
  unavailable,
}

class GuestSaveState extends Equatable {
  const GuestSaveState(
    this.step, {
    this.reading,
    this.busy = false,
    this.error,
  });
  final GuestSaveStep step;
  final GuestReading? reading;
  final bool busy;
  final String? error;
  @override
  List<Object?> get props => [step, reading, busy, error];
}

class GuestSaveCubit extends Cubit<GuestSaveState> {
  GuestSaveCubit(this.repository)
    : super(const GuestSaveState(GuestSaveStep.loading));
  final GuestSaveRepository repository;
  Future<void> load(String sessionId, int version) async {
    try {
      final reading = await repository.find(sessionId, version);
      if (isClosed) return;
      emit(
        GuestSaveState(
          reading == null
              ? GuestSaveStep.unavailable
              : reading.emailRequested
              ? GuestSaveStep.confirmation
              : GuestSaveStep.email,
          reading: reading,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(const GuestSaveState(GuestSaveStep.unavailable));
    }
  }

  void changeEmail() {
    if (!state.busy && state.step == GuestSaveStep.confirmation) {
      emit(GuestSaveState(GuestSaveStep.email, reading: state.reading));
    }
  }

  Future<void> requestEmail(String email) => _run(
    GuestSaveStep.email,
    () => repository.requestEmail(state.reading!, email.trim()),
    GuestSaveStep.confirmation,
  );
  Future<void> checkConfirmation() => _run(
    GuestSaveStep.confirmation,
    () => repository.checkConfirmation(state.reading!),
    GuestSaveStep.password,
  );
  Future<void> finish(String password) => _run(
    GuestSaveStep.password,
    () => repository.finish(state.reading!, password),
    GuestSaveStep.saved,
  );
  Future<void> _run(
    GuestSaveStep expected,
    Future<void> Function() action,
    GuestSaveStep next,
  ) async {
    if (state.busy || state.step != expected || state.reading == null) return;
    final reading = state.reading!;
    emit(GuestSaveState(expected, reading: reading, busy: true));
    try {
      await action();
      if (!isClosed) emit(GuestSaveState(next, reading: reading));
    } catch (error) {
      if (!isClosed) {
        emit(
          GuestSaveState(
            expected,
            reading: reading,
            error: error is GuestSaveFailure
                ? error.message
                : 'Could not save. Please try again.',
          ),
        );
      }
    }
  }
}
