abstract interface class SessionPreparationRepository {
  Future<void> prepare({
    required String sessionId,
    required String pairingId,
    required String exposureId,
  });
}
