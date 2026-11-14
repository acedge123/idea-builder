import '../../../core/logging/app_logger.dart';
import '../../auth/data/auth_failure_mapper.dart';
import '../../auth/domain/auth_failure.dart';
import '../../readings/domain/reading_library.dart';
import '../../session/domain/repositories/saved_reading_repository.dart';
import '../domain/guest_reading.dart';
import '../domain/guest_save_repository.dart';
import 'guest_reading_store.dart';

class VerifiedGuestSaveRepository implements GuestSaveRepository {
  VerifiedGuestSaveRepository({
    required this.auth,
    required this.store,
    required this.library,
    required this.reports,
    this.logger = const AppLogger(),
  });
  final GuestSaveAuth auth;
  final GuestReadingStore store;
  final ReadingLibraryRepository library;
  final SavedReadingRepository reports;
  final AppLogger logger;
  static const _wrongOwner = GuestSaveFailure(
    'This guest reading belongs to the original session on this device. Return to that session; signing in to another account does not save it.',
  );

  @override
  Future<GuestReading?> latest() async {
    final user = auth.current;
    if (user == null) return null;
    final entries = await store.load(user.id);
    if (auth.current?.id != user.id) return null;
    for (final reading in entries) {
      if (user.anonymous || reading.emailRequested) return reading;
    }
    // Recover a build15 guest's completed reading through ordinary owner APIs.
    // This never runs for a confirmed account without original local source state.
    if (user.anonymous) {
      final page = await library.list();
      for (final session in page.readings.where((r) => r.completed)) {
        final report = await reports.fetchSavedReading(sessionId: session.id);
        if (auth.current?.id != user.id) return null;
        if (report?.result != null) {
          return remember(
            GuestReading(
              sourceUserId: user.id,
              sessionId: session.id,
              resultVersion: report!.result!.version,
            ),
          );
        }
      }
    }
    return null;
  }

  @override
  Future<GuestReading?> find(String sessionId, int version) async {
    final user = auth.current;
    if (user == null) return null;
    final entries = await store.load(user.id);
    if (auth.current?.id != user.id) return null;
    for (final r in entries) {
      if (r.sessionId == sessionId && r.resultVersion == version) return r;
    }
    return null;
  }

  @override
  Future<GuestReading> remember(GuestReading reading) async {
    if (auth.current?.id != reading.sourceUserId || !auth.current!.anonymous) {
      throw _wrongOwner;
    }
    final existing = await find(reading.sessionId, reading.resultVersion);
    if (existing != null) return existing;
    await store.put(reading);
    logger.event('guest_save.reading_kept', {'version': reading.resultVersion});
    return reading;
  }

  Future<GuestReading> _source(GuestReading reading) async {
    final stored = await find(reading.sessionId, reading.resultVersion);
    if (stored == null || stored.sourceUserId != reading.sourceUserId) {
      throw _wrongOwner;
    }
    return stored;
  }

  Future<GuestIdentity> _user(
    GuestReading reading, {
    bool confirmed = false,
  }) async {
    final user = await auth
        .getUser(); // Server validation, never cached metadata.
    if (user == null ||
        user.id != reading.sourceUserId ||
        auth.current?.id != user.id) {
      throw _wrongOwner;
    }
    if (confirmed && !user.confirmedAs(reading.sourceUserId)) {
      throw const GuestSaveFailure(
        'Confirm your email on this device first, then try again. Your reading is still private.',
      );
    }
    return user;
  }

  Future<void> _readback(GuestReading reading) async {
    final session = await library.detail(reading.sessionId);
    if (session.id != reading.sessionId || !session.completed) {
      throw const GuestSaveFailure(
        'Could not confirm this completed reading. Please try again.',
      );
    }
    final report = await reports.fetchSavedReading(
      sessionId: reading.sessionId,
      resultVersion: reading.resultVersion,
    );
    if (report?.result?.version != reading.resultVersion) {
      throw const GuestSaveFailure(
        'Could not reopen the exact saved reading. Please try again.',
      );
    }
    if (auth.current?.id != reading.sourceUserId) throw _wrongOwner;
  }

  @override
  Future<void> dismiss(GuestReading reading) async {
    final stored = await _source(reading);
    await store.put(stored.copyWith(promptDismissed: true));
  }

  @override
  Future<void> requestEmail(
    GuestReading reading,
    String email,
  ) => _guard(() async {
    final stored = await _source(reading);
    final user = await _user(reading);
    if (!user.anonymous) throw _wrongOwner;
    await _readback(reading);
    // Persist before sending: an unclear network response must retain recovery.
    await store.put(stored.copyWith(emailRequested: true));
    if (auth.current?.id != reading.sourceUserId) throw _wrongOwner;
    await auth.requestEmail(email, expectedOwner: reading.sourceUserId);
    logger.event('guest_save.confirmation_requested');
  });
  @override
  Future<void> checkConfirmation(GuestReading reading) => _guard(() async {
    final stored = await _source(reading);
    if (!stored.emailRequested) throw _wrongOwner;
    await _user(reading, confirmed: true);
    logger.event('guest_save.confirmation_verified');
  });
  @override
  Future<void> finish(
    GuestReading reading,
    String password,
  ) => _guard(() async {
    await checkConfirmation(reading);
    await auth.setPassword(password, expectedOwner: reading.sourceUserId);
    await _user(reading, confirmed: true);
    await _readback(reading);
    // Readback and identity checks are mandatory even after a successful update.
    final stored = await _source(reading);
    await store.put(
      stored.copyWith(emailRequested: false, promptDismissed: true),
    );
    logger.event('guest_save.account_verified', {
      'version': reading.resultVersion,
    });
  });
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      logger.event('guest_save.failed', {
        'errorType': error.runtimeType.toString(),
      });
      if (error is GuestSaveFailure) rethrow;
      final failure = mapAuthFailure(error);
      if (failure.kind == AuthFailureKind.emailInUse) {
        throw const GuestSaveFailure(
          'That email already has an account. Saving this guest reading to an existing account is not available yet. Use a new email or return to your reading.',
        );
      }
      throw GuestSaveFailure(failure.message);
    }
  }
}
