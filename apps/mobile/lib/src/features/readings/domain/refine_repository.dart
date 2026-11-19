import 'reading_library.dart';

class RefineRun {
  const RefineRun({required this.reading, required this.replayed});
  final ReadingSummary reading;
  final bool replayed;
}

abstract interface class RefineRepository {
  /// Verifies the current saved reading and its completed immutable original.
  Future<ReadingSummary> rootFor(String sessionId);
  Future<RefineRun> start({
    required String rootId,
    required String operationId,
  });
}
