import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/reading_library.dart';

class ReadingLibraryState {
  const ReadingLibraryState({
    this.rows = const [],
    this.loading = false,
    this.error,
    this.nextCursor,
  });
  final List<ReadingSummary> rows;
  final bool loading;
  final String? error, nextCursor;
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
  }) : super(const ReadingLibraryState());
  final ReadingLibraryRepository _repository;
  final String ownerId;
  final String? Function() currentOwner;
  int _generation = 0;
  Future<void> load({bool more = false}) async {
    if (currentOwner() != ownerId || isClosed || state.loading) return;
    if (more && state.nextCursor == null) return;
    final generation = ++_generation;
    final previous = more ? state.rows : <ReadingSummary>[];
    final cursor = more ? state.nextCursor : null;
    emit(
      ReadingLibraryState(rows: previous, loading: true, nextCursor: cursor),
    );
    try {
      final page = await _repository.list(cursor: cursor);
      if (isClosed || generation != _generation || currentOwner() != ownerId) {
        return;
      }
      final unique = {
        for (final r in [...previous, ...page.readings]) r.id: r,
      };
      emit(
        ReadingLibraryState(
          rows: List.unmodifiable(unique.values),
          nextCursor: page.nextCursor,
        ),
      );
      const AppLogger().event('readings.loaded', {
        'count': unique.length,
        'hasMore': page.nextCursor != null,
      });
    } catch (_) {
      if (isClosed || currentOwner() != ownerId || generation != _generation) {
        return;
      }
      emit(
        ReadingLibraryState(
          rows: previous,
          nextCursor: cursor,
          error: 'We couldn’t load your readings. Please try again.',
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
