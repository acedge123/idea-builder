import '../domain/ai_permission_repository.dart';
import 'ai_permission_data_source.dart';

class LocalAiPermissionRepository implements AiPermissionRepository {
  LocalAiPermissionRepository(this._dataSource);
  final AiPermissionDataSource _dataSource;
  final Map<String, bool> _allowed = {};
  final Map<String, int> _revisions = {};
  final Map<String, Future<void>> _writes = {};

  @override
  bool isAllowed(String ownerId) => _allowed[ownerId] == true;

  @override
  Future<bool> load(String ownerId) async {
    final revision = _revisions[ownerId] ?? 0;
    final allowed = await _dataSource.read(ownerId);
    if (revision == (_revisions[ownerId] ?? 0)) _allowed[ownerId] = allowed;
    return isAllowed(ownerId);
  }

  @override
  Future<void> allow(String ownerId) async {
    final revision = _nextRevision(ownerId);
    await _write(ownerId, allowed: true);
    if (_revisions[ownerId] == revision) _allowed[ownerId] = true;
  }

  @override
  Future<void> revoke(String ownerId) async {
    _nextRevision(ownerId);
    // Stop new AI requests immediately, even if local storage fails.
    _allowed[ownerId] = false;
    await _write(ownerId, allowed: false);
  }

  Future<void> _write(String ownerId, {required bool allowed}) {
    final previous = _writes[ownerId] ?? Future<void>.value();
    final next = previous.then(
      (_) => _dataSource.write(ownerId, allowed: allowed),
    );
    // Keep writes ordered even when another permission screen replaces this
    // one. A failed write must not poison later retries.
    _writes[ownerId] = next.catchError((Object _) {});
    return next;
  }

  int _nextRevision(String ownerId) =>
      _revisions[ownerId] = (_revisions[ownerId] ?? 0) + 1;
}
