import '../domain/guest_reading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/guest_save_repository.dart';

class SupabaseGuestSaveAuth implements GuestSaveAuth {
  SupabaseGuestSaveAuth(this._client);
  final SupabaseClient _client;
  // Must be allowlisted in Supabase Auth before device confirmation acceptance.
  static const confirmationRedirect = 'fm.musicdna.app://auth/save-reading';
  GuestIdentity? _map(User? user) => user == null
      ? null
      : GuestIdentity(
          user.id,
          anonymous: user.isAnonymous,
          emailConfirmedAt: user.emailConfirmedAt,
        );
  @override
  GuestIdentity? get current => _map(_client.auth.currentUser);
  @override
  Future<GuestIdentity?> getUser() async =>
      _map((await _client.auth.getUser()).user);
  @override
  Future<void> requestEmail(
    String email, {
    required String expectedOwner,
  }) async {
    _requireOwner(expectedOwner);
    await _client.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: confirmationRedirect,
    );
  }

  void _requireOwner(String owner) {
    if (current?.id != owner) {
      throw const GuestSaveFailure(
        'The original guest session changed. Return to your reading on the original device.',
      );
    }
  }

  @override
  Future<void> setPassword(
    String password, {
    required String expectedOwner,
  }) async {
    _requireOwner(expectedOwner);
    await _client.auth.updateUser(UserAttributes(password: password));
  }
}
