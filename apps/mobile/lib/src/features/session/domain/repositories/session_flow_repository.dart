import '../entities/interview_flow.dart';

abstract interface class SessionFlowRepository {
  /// Null means an older server has no flow endpoint, not an unavailable check.
  Future<InterviewFlow?> fetchFlow({required String sessionId});
}
