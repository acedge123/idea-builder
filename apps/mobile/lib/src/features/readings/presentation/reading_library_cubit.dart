import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/app_api_exception.dart';
import '../domain/reading_library.dart';

class ReadingLibraryState {
  const ReadingLibraryState({
    this.rows = const [],
    this.loading = false,
    this.error,
    this.nextCursor,
    this.signInRequired = false,
  });
  final List<ReadingSummary> rows;
  final bool loading;
  final String? error, nextCursor;
  final bool signInRequired;
  ReadingSummary? get unfinished {
    for (final r in rows) {
      if (!r.completed) return r;
    }
    return null;
  }
}

class ReadingLibraryCubit extends Cubit<ReadingLibraryState> {
  ReadingLibraryCubit(
    this._repository, {
    required this.ownerId,
    required this.currentOwner,
    AppLogger? logger,
  }) : _logger = logger ?? const AppLogger(),
       super(const ReadingLibraryState());
  final ReadingLibraryRepository _repository;
  final String ownerId;
  final String? Function() currentOwner;
  final AppLogger _logger;
  int _generation = 0;
  Future<void> load({bool more = false}) async {
    if (currentOwner() != ownerId || isClosed || state.loading) return;
    if (more && state.nextCursor == null) return;
    final generation = ++_generation;
    final previous = state.rows;
    final cursor = state.nextCursor;
    emit(
      ReadingLibraryState(rows: previous, loading: true, nextCursor: cursor),
    );
    try {
      final page = await _repository.list(cursor: more ? cursor : null);
      if (isClosed || generation != _generation || currentOwner() != ownerId) {
        return;
      }
      final unique = {
        for (final r in [if (more) ...previous, ...page.readings]) r.id: r,
      };
      emit(
        ReadingLibraryState(
          rows: List.unmodifiable(unique.values),
          nextCursor: page.nextCursor,
        ),
      );
      _logger.event('readings.loaded', {
        'count': unique.length,
        'hasMore': page.nextCursor != null,
      });
    } catch (error) {
      if (isClosed || currentOwner() != ownerId || generation != _generation) {
        return;
      }
      final failure = error is AppApiException ? error : null;
      final signInRequired = failure?.kind == AppApiErrorKind.unauthorized;
      _logger.event('readings.load_failed', {
        'kind': failure?.kind.name ?? 'unknown',
        'statusCode': failure?.statusCode,
        'errorType': error.runtimeType.toString(),
      });
      emit(
        ReadingLibraryState(
          rows: previous,
          nextCursor: cursor,
          signInRequired: signInRequired,
          error: signInRequired
              ? 'Please sign out and sign in again to load your readings.'
              : failure?.kind == AppApiErrorKind.network
              ? 'We couldn’t connect. Check your connection and try again.'
              : 'We couldn’t load your readings. Please try again.',
        ),
      );
    }
  }
}

/// Groups loaded child runs under their original without inventing unloaded rows.
List<ReadingSummary> groupReadings(List<ReadingSummary> rows) {
  final roots = rows.where((r) => !r.isExplore).toList();
  final rootIds = roots.map((r) => r.id).toSet();
  return [
    for (final root in roots) ...[
      root,
      ...rows.where((r) => r.isExplore && r.parentId == root.id),
    ],
    ...rows.where((r) => r.isExplore && !rootIds.contains(r.parentId)),
  ];
}
