import '../entities/session_result.dart';

abstract interface class SessionResultRepository {
  Future<SharePublication> setPublication({
    required String sessionId,
    required bool publish,
  });
}
