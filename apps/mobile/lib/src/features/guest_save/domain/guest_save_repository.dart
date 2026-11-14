import 'guest_reading.dart';

abstract interface class GuestSaveRepository {
  Future<GuestReading?> latest();
  Future<GuestReading> remember(GuestReading reading);
  Future<GuestReading?> find(String sessionId, int version);
  Future<void> dismiss(GuestReading reading);
  Future<void> requestEmail(GuestReading reading, String email);
  Future<void> checkConfirmation(GuestReading reading);
  Future<void> finish(GuestReading reading, String password);
}

class GuestIdentity {
  const GuestIdentity(
    this.id, {
    required this.anonymous,
    this.emailConfirmedAt,
  });
  final String id;
  final bool anonymous;
  final String? emailConfirmedAt;
  bool confirmedAs(String owner) =>
      id == owner && !anonymous && emailConfirmedAt != null;
}

abstract interface class GuestSaveAuth {
  GuestIdentity? get current;
  Future<GuestIdentity?> getUser();
  Future<void> requestEmail(String email, {required String expectedOwner});
  Future<void> setPassword(String password, {required String expectedOwner});
}
