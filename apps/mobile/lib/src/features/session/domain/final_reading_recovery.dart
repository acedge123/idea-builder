import 'entities/session_reveal.dart';
import 'repositories/saved_reading_repository.dart';

class FinalReadingSuperseded implements Exception {
  const FinalReadingSuperseded();
}

/// Matches web recoverFinalReading. An explicit rejected draft has finished;
/// unknown provider/network outcomes may still commit and are never auto-retried.
Future<SessionReveal> recoverFinalReading({
  required Future<SessionReveal?> Function() readSaved,
  required Future<SessionReveal> Function() generate,
  required bool Function() isCurrent,
}) async {
  void checkCurrent() {
    if (!isCurrent()) throw const FinalReadingSuperseded();
  }

  Future<SessionReveal?> read() async {
    checkCurrent();
    final saved = await readSaved();
    checkCurrent();
    return saved;
  }

  final saved = await read();
  if (saved != null) return saved;
  for (var attempt = 0; attempt < 2; attempt++) {
    checkCurrent();
    try {
      final result = await generate();
      checkCurrent();
      return result;
    } catch (error, stack) {
      checkCurrent();
      final recovered = await read();
      if (recovered != null) return recovered;
      if (attempt == 0 &&
          error is ReadingPendingException &&
          error.narrationStatus == 'invalid_generation') {
        continue;
      }
      Error.throwWithStackTrace(error, stack);
    }
  }
  throw const ReadingPendingException();
}

String? finalReadingError(String? status) => switch (status) {
  'invalid_generation' =>
    'That draft didn’t pass the Critic’s evidence check. Your choices are saved — retry for a new draft.',
  'narrator_failure' =>
    'The Critic couldn’t finish this draft. Your choices are saved — retry your reading.',
  null => null,
  _ => 'The reading wasn’t saved. Your choices are safe — retry your reading.',
};
