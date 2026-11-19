import '../../../core/network/app_api_exception.dart';
import '../../session/data/datasources/session_remote_data_source.dart';
import '../../session/domain/entities/session_mode.dart';
import '../domain/reading_library.dart';
import '../domain/refine_repository.dart';

class RestRefineRepository implements RefineRepository {
  RestRefineRepository(this._remote, this._library);
  final SessionRemoteDataSource _remote;
  final ReadingLibraryRepository _library;
  Never _invalid() => throw const AppApiException(
    kind: AppApiErrorKind.upstream,
    message:
        'The refinement could not be verified. Your original reading is unchanged.',
  );

  @override
  Future<ReadingSummary> rootFor(String sessionId) async {
    final source = await _library.detail(sessionId);
    if (source.id != sessionId ||
        !source.completed ||
        !source.sessionMode.supported) {
      _invalid();
    }
    if (source.sessionMode == SessionMode.discover) return source;
    final parent = source.parentId;
    if (parent == null || parent.isEmpty || parent == sessionId) _invalid();
    final root = await _library.detail(parent);
    if (root.id != parent ||
        !root.completed ||
        root.sessionMode != SessionMode.discover) {
      _invalid();
    }
    return root;
  }

  @override
  Future<RefineRun> start({
    required String rootId,
    required String operationId,
  }) async {
    final data = await _remote.startRefine(
      rootId: rootId,
      operationId: operationId,
    );
    final id = data['session_id'];
    if (data['mode'] != 'refine' ||
        data['replayed'] is! bool ||
        id is! String ||
        id.isEmpty ||
        id == rootId) {
      _invalid();
    }
    // Normal owner-scoped GET must confirm identity/root before local navigation.
    final child = await _library.detail(id);
    if (child.id != id ||
        child.sessionMode != SessionMode.refine ||
        child.parentId != rootId) {
      _invalid();
    }
    return RefineRun(reading: child, replayed: data['replayed'] as bool);
  }
}
