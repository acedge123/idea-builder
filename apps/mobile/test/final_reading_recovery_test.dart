import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/features/session/domain/repositories/saved_reading_repository.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'package:music_dna/src/features/session/presentation/pages/session_stub_page.dart';
import 'session_result_test.dart' show ResultRepository, start, reveal;

class RecoveryRepository extends ResultRepository
    implements SavedReadingRepository {
  RecoveryRepository({this.saved = const [], this.generated = const []});
  final List<Object?> saved, generated;
  final calls = <String>[];
  final early = <bool>[];
  int reads = 0, writes = 0;
  Future<T> value<T>(Object? raw) async {
    final resolved = raw is Future ? await raw : raw;
    if (resolved is Exception || resolved is Error) throw resolved!;
    return resolved as T;
  }

  @override
  Future<SessionReveal?> fetchSavedReading({
    required String sessionId,
    int? resultVersion,
  }) {
    expect(sessionId, 'session-1');
    calls.add('read');
    final index = reads++;
    return value<SessionReveal?>(index < saved.length ? saved[index] : null);
  }

  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) {
    expect(sessionId, 'session-1');
    calls.add('generate');
    early.add(finishEarly);
    final index = writes++;
    if (index >= generated.length) throw StateError('Unexpected generation');
    return value<SessionReveal>(generated[index]);
  }

  SessionCubit cubit() =>
      SessionCubit(this, startedSession: start, savedReadingRepository: this);
}

const rejected = ReadingPendingException(narrationStatus: 'invalid_generation');
const timeout = AppApiException(
  kind: AppApiErrorKind.network,
  message: 'timeout',
);

void main() {
  test('saved first: no new generation', () async {
    final repo = RecoveryRepository(saved: [reveal]);
    final c = repo.cubit();
    addTearDown(c.close);
    await c.revealSession();
    expect(repo.calls, ['read']);
    expect(c.state.reveal, same(reveal));
  });
  test(
    'explicit rejection gets one retry, preserving four-answer intent',
    () async {
      final repo = RecoveryRepository(generated: [rejected, reveal]);
      final c = repo.cubit();
      addTearDown(c.close);
      await c.revealSession(finishEarly: true);
      expect(repo.calls, ['read', 'generate', 'read', 'generate']);
      expect(repo.early, [true, true]);
      expect(c.state.status, SessionStatus.revealed);
    },
  );
  test(
    'concurrent saved report wins over retry after rejected draft',
    () async {
      final repo = RecoveryRepository(
        saved: [null, reveal],
        generated: [rejected],
      );
      final c = repo.cubit();
      addTearDown(c.close);
      await c.revealSession();
      expect(repo.calls, ['read', 'generate', 'read']);
      expect(c.state.reveal, same(reveal));
    },
  );
  testWidgets(
    'two rejections stop and offer an honest retry without final actions',
    (tester) async {
      final repo = RecoveryRepository(generated: [rejected, rejected]);
      final c = repo.cubit();
      addTearDown(c.close);
      await c.revealSession();
      expect(repo.calls, ['read', 'generate', 'read', 'generate', 'read']);
      expect(c.state.status, SessionStatus.waitingForReading);
      expect(c.state.reveal, isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: c,
            child: const SessionStubPage(
              shareBaseUrl: 'https://www.musicdna.fm',
            ),
          ),
        ),
      );
      expect(find.text('Your reading needs another draft'), findsOneWidget);
      expect(find.text('Retry my reading'), findsOneWidget);
      expect(find.textContaining('evidence check'), findsOneWidget);
      expect(find.text('Publish link'), findsNothing);
    },
  );
  for (final error in [
    timeout,
    const ReadingPendingException(),
    const AppApiException(
      kind: AppApiErrorKind.upstream,
      message: 'provider failure',
    ),
    Exception('unknown transport failure'),
  ]) {
    test(
      'every generation error checks saved report first: ${error.runtimeType}',
      () async {
        final repo = RecoveryRepository(
          saved: [null, reveal],
          generated: [error],
        );
        final c = repo.cubit();
        addTearDown(c.close);
        await c.revealSession();
        expect(repo.calls, ['read', 'generate', 'read']);
        expect(c.state.reveal, same(reveal));
      },
    );
  }
  test(
    'unknown in-flight outcome never automatically repeats generation',
    () async {
      final repo = RecoveryRepository(generated: [timeout]);
      final c = repo.cubit();
      addTearDown(c.close);
      await c.revealSession();
      expect(repo.calls, ['read', 'generate', 'read']);
      expect(c.state.status, SessionStatus.waitingForReading);
      expect(c.state.errorMessage, isNull);
      expect(c.state.reveal, isNull);
    },
  );
  test(
    'narrator failure and unknown unsaved statuses do not automatically retry',
    () async {
      for (final status in ['narrator_failure', 'pending']) {
        final repo = RecoveryRepository(
          generated: [ReadingPendingException(narrationStatus: status)],
        );
        final c = repo.cubit();
        await c.revealSession();
        expect(repo.writes, 1);
        expect(repo.reads, 2);
        expect(c.state.reveal, isNull);
        expect(c.state.errorMessage, isNotNull);
        await c.close();
      }
    },
  );
  test('unavailable initial readback prevents all generation', () async {
    final repo = RecoveryRepository(saved: [timeout]);
    final c = repo.cubit();
    addTearDown(c.close);
    await c.revealSession();
    expect(repo.calls, ['read']);
    expect(c.state.reveal, isNull);
    expect(c.state.status, SessionStatus.failure);
    expect(c.state.errorMessage, contains('couldn’t check'));
  });
  test(
    'unavailable readback after rejection prevents the automatic second write',
    () async {
      final repo = RecoveryRepository(
        saved: [null, timeout],
        generated: [rejected],
      );
      final c = repo.cubit();
      addTearDown(c.close);
      await c.revealSession();
      expect(repo.calls, ['read', 'generate', 'read']);
      expect(c.state.reveal, isNull);
    },
  );
  test(
    'navigation during preflight prevents generation and stale paint',
    () async {
      final pending = Completer<SessionReveal?>();
      final repo = RecoveryRepository(saved: [pending.future]);
      final c = repo.cubit();
      final run = c.revealSession();
      await Future<void>.delayed(Duration.zero);
      await c.close();
      pending.complete(null);
      await run;
      expect(repo.calls, ['read']);
    },
  );
  test(
    'navigation during generation prevents readback and retry under another owner',
    () async {
      final pending = Completer<SessionReveal>();
      final repo = RecoveryRepository(generated: [pending.future]);
      final c = repo.cubit();
      final run = c.revealSession();
      await Future<void>.delayed(Duration.zero);
      await c.close();
      pending.completeError(rejected);
      await run;
      expect(repo.calls, ['read', 'generate']);
    },
  );
}
