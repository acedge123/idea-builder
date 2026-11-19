import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/app_api_exception.dart';
import '../../onboarding/domain/entities/started_music_session.dart';
import '../../session/data/session_resume_store.dart';
import '../data/refine_operation_store.dart';
import '../domain/reading_library.dart';
import '../domain/refine_repository.dart';

class RefineState {
  const RefineState({
    this.root,
    this.loading = true,
    this.starting = false,
    this.error,
    this.opened,
  });
  final ReadingSummary? root;
  final bool loading, starting;
  final String? error;
  final StartedMusicSession? opened;
}

class RefineCubit extends Cubit<RefineState> {
  RefineCubit(
    this._repository, {
    required this.sessionId,
    required this.ownerId,
    required this.currentOwner,
    required RefineOperationStore operations,
    required SessionResumeStore resumeStore,
  }) : _operations = operations,
       _resume = resumeStore,
       super(const RefineState());
  final RefineRepository _repository;
  final RefineOperationStore _operations;
  final SessionResumeStore _resume;
  final String sessionId, ownerId;
  final String? Function() currentOwner;
  bool get _active => !isClosed && currentOwner() == ownerId;

  Future<void> load() async {
    if (!_active || state.starting) return;
    emit(RefineState(root: state.root));
    try {
      final root = await _repository.rootFor(sessionId);
      if (_active) emit(RefineState(root: root, loading: false));
    } catch (_) {
      if (_active) {
        emit(
          const RefineState(
            loading: false,
            error:
                'Refine is unavailable right now. Your saved reading is unchanged.',
          ),
        );
      }
    }
  }

  Future<void> start() async {
    final root = state.root;
    if (!_active ||
        state.loading ||
        state.starting ||
        state.opened != null ||
        root == null) {
      return;
    }
    emit(RefineState(root: root, loading: false, starting: true));
    try {
      // Persist before POST; a retry after an uncertain response uses this same ID.
      final operation = await _operations.operation(ownerId, root.id);
      if (!_active) return;
      final run = await _repository.start(
        rootId: root.id,
        operationId: operation,
      );
      if (!_active) return;
      final child = run.reading;
      final reference = StartedMusicSession.reference(
        child.id,
        mode: child.mode,
        parentSessionId: child.parentId,
        decade: child.decade,
      );
      await _resume.save(reference);
      if (!_active) return;
      final saved = await _resume.load();
      if (!_active) return;
      if (saved != reference) throw StateError('Resume could not be retained');
      // Settle only AFTER durable owner-scoped resume readback. A crash before
      // this boundary keeps the operation; after it, Home can resume the child.
      await _operations.complete(ownerId, root.id, operation);
      if (_active) {
        emit(RefineState(root: root, loading: false, opened: reference));
      }
    } catch (error) {
      if (!_active) return;
      emit(
        RefineState(
          root: root,
          loading: false,
          error: error is AppApiException && error.isAuthRelated
              ? 'Check your sign-in and OpenAI permission in Account before continuing. Your saved reading is unchanged.'
              : 'We couldn’t confirm the new run. Try again to check the same request. Your original reading is unchanged.',
        ),
      );
    }
  }
}
