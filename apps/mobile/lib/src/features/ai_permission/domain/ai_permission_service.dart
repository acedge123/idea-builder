import '../../../core/network/app_api_exception.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import 'ai_permission_repository.dart';

class AiPermissionService {
  AiPermissionService(this._repository, this._auth);
  final AiPermissionRepository _repository;
  final AuthRepository _auth;

  String? get currentOwner => _auth.currentUser?.id;
  Stream<String?> get ownerChanges =>
      _auth.observeAuthState().map((user) => user?.id).distinct();

  Future<String> ensureOwner() async =>
      currentOwner ?? (await _auth.ensureAnonymousSession()).id;

  Future<bool> load(String ownerId) => _repository.load(ownerId);

  Future<void> allow(String ownerId) async {
    _checkOwner(ownerId);
    await _repository.allow(ownerId);
    _checkOwner(ownerId);
  }

  Future<void> revoke(String ownerId) async {
    _checkOwner(ownerId);
    await _repository.revoke(ownerId);
    _checkOwner(ownerId);
  }

  /// Called before obtaining credentials; validates again immediately before
  /// dispatch so token refresh, account switches and revocation fail closed.
  Future<void Function()> authorizeRequest(String method, String path) async {
    if (!requiresPermission(method, path)) return () {};
    final owner = currentOwner;
    if (owner == null) _permissionRequired();
    final allowed = await _repository.load(owner);
    if (!allowed) _permissionRequired();
    void validate() {
      _checkOwner(owner);
      if (!_repository.isAllowed(owner)) _permissionRequired();
    }

    validate();
    return validate;
  }

  static bool requiresPermission(String method, String path) {
    final uri = Uri.parse(path);
    final route = uri.path;
    if (method == 'GET') {
      return RegExp(r'^/api/v1/session/[^/]+/next$').hasMatch(route);
    }
    if (method != 'POST') return false;
    if (route.startsWith('/api/v1/onboarding/')) return true;
    if (route == '/api/v1/session') return true;
    // New session write operations require permission by default. Saved
    // feedback and publication do not invoke AI and remain accessible.
    if (!route.startsWith('/api/v1/session/')) return false;
    return !RegExp(r'/(feedback|share)$').hasMatch(route);
  }

  void _checkOwner(String owner) {
    if (currentOwner != owner) _permissionRequired();
  }

  Never _permissionRequired() => throw const AppApiException(
    kind: AppApiErrorKind.forbidden,
    message: 'Allow OpenAI processing in Account → AI permission to continue.',
  );
}
