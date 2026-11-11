import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/ai_permission_service.dart';

enum AiPermissionStatus {
  checking,
  required,
  saving,
  allowed,
  readOnly,
  failure,
}

class AiPermissionState {
  const AiPermissionState(this.status, {this.ownerId, this.message});
  final AiPermissionStatus status;
  final String? ownerId;
  final String? message;
}

class AiPermissionCubit extends Cubit<AiPermissionState> {
  AiPermissionCubit(
    this._service, {
    AppLogger logger = const AppLogger(),
    Future<bool> Function()? canReadWithoutPermission,
  }) : _logger = logger,
       _canReadWithoutPermission = canReadWithoutPermission,
       super(const AiPermissionState(AiPermissionStatus.checking)) {
    _ownerSubscription = _service.ownerChanges.listen((owner) {
      if (owner != state.ownerId) unawaited(load());
    }, onError: (Object _) => _fail());
  }

  final AiPermissionService _service;
  final AppLogger _logger;
  final Future<bool> Function()? _canReadWithoutPermission;
  late final StreamSubscription<String?> _ownerSubscription;
  int _generation = 0;

  Future<void> load() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(
      AiPermissionState(
        AiPermissionStatus.checking,
        ownerId: _service.currentOwner,
      ),
    );
    try {
      final owner = await _service.ensureOwner();
      final allowed = await _service.load(owner);
      if (!_isCurrent(generation, owner)) return;
      final readOnly =
          !allowed &&
          _canReadWithoutPermission != null &&
          await _canReadWithoutPermission();
      if (!_isCurrent(generation, owner)) return;
      emit(
        AiPermissionState(
          allowed
              ? AiPermissionStatus.allowed
              : readOnly
              ? AiPermissionStatus.readOnly
              : AiPermissionStatus.required,
          ownerId: owner,
        ),
      );
    } catch (_) {
      if (!isClosed && generation == _generation) _fail();
    }
  }

  Future<void> allow() => _save(allowed: true);
  Future<void> revoke() => _save(allowed: false);

  Future<void> _save({required bool allowed}) async {
    final owner = state.ownerId;
    if (owner == null || state.status == AiPermissionStatus.saving) return;
    final generation = ++_generation;
    emit(AiPermissionState(AiPermissionStatus.saving, ownerId: owner));
    try {
      if (allowed) {
        await _service.allow(owner);
      } else {
        await _service.revoke(owner);
      }
      if (!_isCurrent(generation, owner)) return;
      _logger.event('ai_processing_permission_changed', {'allowed': allowed});
      emit(
        AiPermissionState(
          allowed ? AiPermissionStatus.allowed : AiPermissionStatus.required,
          ownerId: owner,
        ),
      );
    } catch (_) {
      if (!isClosed && generation == _generation) _fail();
    }
  }

  bool _isCurrent(int generation, String owner) =>
      !isClosed && generation == _generation && _service.currentOwner == owner;

  void _fail() {
    if (isClosed) return;
    _logger.event('ai_processing_permission_unavailable');
    emit(
      AiPermissionState(
        AiPermissionStatus.failure,
        ownerId: _service.currentOwner,
        message:
            'We couldn’t load or save your AI permission. Please try again.',
      ),
    );
  }

  @override
  Future<void> close() async {
    _generation++;
    await _ownerSubscription.cancel();
    return super.close();
  }
}
