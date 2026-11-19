import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_dna/src/features/session/domain/repositories/saved_reading_repository.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';
import 'package:music_dna/src/features/session/presentation/cubit/session_cubit.dart';
import 'ab84_critic_parity_test.dart' show ParityRepository, mountSession;
import 'critic_wait_contract_test.dart' show copy;
import 'session_result_test.dart' show start, reveal;

class RetryingFinal extends ParityRepository implements SavedReadingRepository {
  final rejected = Completer<SessionReveal>(),
      accepted = Completer<SessionReveal>();
  @override
  Future<SessionReveal?> fetchSavedReading({
    required String sessionId,
    int? resultVersion,
  }) async => null;
  @override
  Future<SessionReveal> revealSession({
    required String sessionId,
    bool finishEarly = false,
  }) {
    revealCalls++;
    return revealCalls == 1 ? rejected.future : accepted.future;
  }

  SessionCubit controller() => SessionCubit(
    this,
    startedSession: start,
    experienceRepository: this,
    criticRepository: this,
    resultRepository: this,
    flowRepository: this,
    savedReadingRepository: this,
    loadCriticCopy: () async => copy(),
  );
}

void main() {
  testWidgets(
    'slow final vote holds Neutral, never starts Overtime without saved hunch',
    (tester) async {
      final repo = ParityRepository()..answered = 5;
      repo.revealGate = Completer<SessionReveal>();
      final c = repo.withCopy();
      addTearDown(c.close);
      await c.initialize();
      await mountSession(tester, c);
      repo.saveGate = Completer<void>();
      final run = c.chooseSong(chosenSongId: 'a', msToDecide: 1);
      final neutral = c.state.criticWaitLine;
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 2500));
        expect(c.state.criticWaitLine, neutral);
        expect(copy().overtime, isNot(contains(c.state.criticWaitLine)));
      }
      repo.saveGate!.complete();
      await tester.pump();
      expect(
        c.state.criticWaitLine,
        copy().reaction['early']![6 % copy().reaction['early']!.length],
      );
      // The hunch arrives asynchronously; time starts after the first painted frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
      expect(c.state.criticWaitLine, copy().person[0].first);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(c.state.criticWaitLine, copy().person[0].last);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(c.state.criticWaitLine, copy().overtime.first);
      repo.revealGate!.complete(reveal);
      await run;
      expect(c.state.status, SessionStatus.revealed);
    },
  );
  testWidgets(
    'automatic rejected-draft retry keeps the same displayed wait and beat deadline',
    (tester) async {
      final repo = RetryingFinal()..answered = 5;
      final c = repo.controller();
      addTearDown(c.close);
      await c.initialize();
      await mountSession(tester, c);
      final run = c.chooseSong(chosenSongId: 'a', msToDecide: 1);
      await tester.pump();
      final neutral = c.state.criticWaitLine;
      await tester.pump(const Duration(seconds: 2));
      repo.rejected.completeError(
        const ReadingPendingException(narrationStatus: 'invalid_generation'),
      );
      await tester.pump();
      expect(repo.revealCalls, 2);
      expect(c.state.criticWaitLine, neutral);
      await tester.pump(const Duration(milliseconds: 499));
      expect(c.state.criticWaitLine, neutral);
      await tester.pump(const Duration(milliseconds: 1));
      expect(c.state.criticWaitLine, isNot(neutral));
      repo.accepted.complete(reveal);
      await run;
      expect(repo.choiceCalls, 1);
      expect(c.state.status, SessionStatus.revealed);
    },
  );
}
