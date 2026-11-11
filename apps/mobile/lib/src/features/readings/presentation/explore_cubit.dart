import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/app_api_exception.dart';
import '../domain/reading_library.dart';

class ExploreState {
  const ExploreState({
    this.options,
    this.comparison,
    this.loading = true,
    this.starting = false,
    this.error,
    this.comparisonError,
    this.openedId,
  });
  final ExploreOptions? options;
  final DecadeComparison? comparison;
  final bool loading, starting;
  final String? error, comparisonError, openedId;
}

/// Persists one operation ID across lost responses/restarts; values are not credentials.
class ExploreOperationStore {
  Future<String> operation(String owner, String root, int decade) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'musicdna.explore.start.$owner.$root.$decade';
    final previous = prefs.getString(key);
    if (previous != null) return previous;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString(key, id);
    return id;
  }

  Future<void> complete(String owner, String root, int decade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('musicdna.explore.start.$owner.$root.$decade');
  }
}

class ExploreCubit extends Cubit<ExploreState> {
  ExploreCubit(
    this._repository, {
    required this.sessionId,
    required this.isExplore,
    required this.ownerId,
    required this.currentOwner,
    ExploreOperationStore? operations,
  }) : _operations = operations ?? ExploreOperationStore(),
       super(const ExploreState());
  final ReadingLibraryRepository _repository;
  final ExploreOperationStore _operations;
  final String sessionId, ownerId;
  final bool isExplore;
  final String? Function() currentOwner;
  bool get _active => !isClosed && ownerId == currentOwner();
  Future<void> load() async {
    if (!_active) return;
    try {
      final options = await _repository.options(sessionId);
      if (!_active) return;
      emit(ExploreState(options: options, loading: false));
    } catch (_) {
      if (_active) {
        emit(
          ExploreState(
            options: state.options,
            comparison: state.comparison,
            loading: false,
            error: 'Decades are unavailable right now. Your reading is saved.',
          ),
        );
      }
    }
    if (!isExplore || !_active) return;
    try {
      final comparison = await _repository.comparison(sessionId);
      if (!_active) return;
      emit(
        ExploreState(
          options: state.options,
          comparison: comparison,
          loading: false,
          error: state.error,
        ),
      );
    } catch (_) {
      if (_active) {
        emit(
          ExploreState(
            options: state.options,
            loading: false,
            error: state.error,
            comparisonError:
                'The comparison is unavailable. Your original reading is unchanged.',
          ),
        );
      }
    }
  }

  Future<void> start(int decade) async {
    final options = state.options;
    if (!_active ||
        state.starting ||
        options == null ||
        !options.decades.any((d) => d.decade == decade && d.ready)) {
      return;
    }
    emit(
      ExploreState(
        options: options,
        comparison: state.comparison,
        loading: false,
        starting: true,
      ),
    );
    try {
      final operation = await _operations.operation(
        ownerId,
        options.rootId,
        decade,
      );
      if (!_active) return;
      final id = await _repository.startExplore(
        sessionId: options.rootId,
        decade: decade,
        mutationId: operation,
      );
      if (!_active) return;
      await _operations.complete(ownerId, options.rootId, decade);
      if (_active) {
        emit(
          ExploreState(
            options: options,
            comparison: state.comparison,
            loading: false,
            openedId: id,
          ),
        );
      }
    } catch (error) {
      if (!_active) return;
      // Keep operation ID on uncertain writes, including network/server errors.
      if (error is AppApiException &&
          [400, 401, 403, 404].contains(error.statusCode)) {
        await _operations.complete(ownerId, options.rootId, decade);
      }
      if (_active) {
        emit(
          ExploreState(
            options: options,
            comparison: state.comparison,
            loading: false,
            error:
                'We couldn’t confirm the new run. Check My readings before trying again.',
          ),
        );
      }
    }
  }
}
