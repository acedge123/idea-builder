import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_dna/src/features/continuation/domain/continuation_repository.dart';
import 'package:music_dna/src/features/continuation/presentation/continuation_cubit.dart';
import 'package:music_dna/src/features/continuation/presentation/continuation_page.dart';
import 'package:music_dna/src/features/session/domain/entities/session_reveal.dart';

const original = SessionReveal(
  interpretation: 'Your original saved reading.',
  vector: {'energy': 0.35},
  allowedClaims: [],
  counterarguments: [],
);

ContinuationContext savedContext() => ContinuationContext(
  sessionId: 'saved-session',
  ownerId: 'owner',
  original: original,
  evidence: [],
  resultVersion: 2,
);

class FakeConversationRepository implements ContinuationRepository {
  ConversationSnapshot snapshot = ConversationSnapshot(
    sessionId: 'saved-session',
    messages: [],
  );
  Object? loadError, submitError;
  Completer<ConversationSnapshot>? pending;
  final List<String> sent = [];
  @override
  Future<ConversationSnapshot> load(ContinuationContext context) async {
    if (loadError != null) throw loadError!;
    return snapshot;
  }

  @override
  Future<ConversationSnapshot> submit(
    ContinuationContext context,
    String message,
  ) async {
    sent.add(message);
    if (submitError != null) throw submitError!;
    if (pending != null) return pending!.future;
    return snapshot;
  }
}

void main() {
  test(
    'default transport is unavailable and retains the original and draft',
    () async {
      final cubit = ContinuationCubit(
        savedContext(),
        const UnavailableContinuationRepository(),
      );
      addTearDown(cubit.close);
      cubit.editDraft('Not quite');
      await cubit.load();
      expect(cubit.state.failure, ContinuationFailure.unavailable);
      expect(cubit.state.draft, 'Not quite');
      expect(cubit.context.original, same(original));
      expect(cubit.context.resultVersion, 2);
      await cubit.send();
      expect(cubit.state.canSend, false);
    },
  );

  test(
    'preserves authoritative order and repeated messages without rewriting evidence',
    () async {
      final messages = [
        ConversationMessage(
          role: ConversationRole.user,
          content: 'No',
          createdAt: DateTime(2026),
        ),
        ConversationMessage(
          role: ConversationRole.assistant,
          content: 'Tell me more',
          createdAt: DateTime(2026),
        ),
        ConversationMessage(
          role: ConversationRole.user,
          content: 'No',
          createdAt: DateTime(2026),
        ),
      ];
      final repository = FakeConversationRepository()
        ..snapshot = ConversationSnapshot(
          sessionId: 'saved-session',
          messages: messages,
        );
      final cubit = ContinuationCubit(savedContext(), repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.messages, orderedEquals(messages));
      expect(() => cubit.state.messages.clear(), throwsUnsupportedError);
      expect(original.vector['energy'], 0.35);
    },
  );

  test(
    'accepts a short turn, trims it and serializes duplicate taps',
    () async {
      final repository = FakeConversationRepository()..pending = Completer();
      final cubit = ContinuationCubit(savedContext(), repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.editDraft('  No  ');
      final sending = cubit.send();
      await cubit.send();
      cubit.editDraft('Cannot replace an in-flight draft');
      expect(repository.sent, ['No']);
      expect(cubit.state.draft, '  No  ');
      repository.pending!.complete(repository.snapshot);
      await sending;
      expect(cubit.state.draft, isEmpty);
      expect(cubit.context.original, same(original));
    },
  );

  test('does not send empty or oversized turns', () async {
    final repository = FakeConversationRepository();
    final cubit = ContinuationCubit(savedContext(), repository);
    addTearDown(cubit.close);
    await cubit.load();
    for (final draft in ['  ', List.filled(2001, 'x').join()]) {
      cubit.editDraft(draft);
      await cubit.send();
    }
    expect(repository.sent, isEmpty);
  });

  test(
    'definite rejection retains draft for deliberate retry after reload',
    () async {
      final repository = FakeConversationRepository()
        ..submitError = const ContinuationException(
          ContinuationFailure.rejected,
        );
      final cubit = ContinuationCubit(savedContext(), repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.editDraft('Keep this draft');
      await cubit.send();
      expect(cubit.state.draft, 'Keep this draft');
      expect(cubit.state.messages, isEmpty);
      repository.submitError = null;
      await cubit.load();
      await cubit.send();
      expect(repository.sent, ['Keep this draft', 'Keep this draft']);
      expect(cubit.state.draft, isEmpty);
    },
  );

  test('auth expiry does not clear the draft', () async {
    final repository = FakeConversationRepository()
      ..submitError = const ContinuationException(
        ContinuationFailure.authentication,
      );
    final cubit = ContinuationCubit(savedContext(), repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.editDraft('My response');
    await cubit.send();
    expect(cubit.state.failure, ContinuationFailure.authentication);
    expect(cubit.state.draft, 'My response');
    repository.submitError = null;
    await cubit.load();
    expect(cubit.state.draft, 'My response');
  });

  test(
    'unknown write failures block blind retry even after history reload',
    () async {
      final repository = FakeConversationRepository()
        ..submitError = TimeoutException('lost acknowledgment');
      final cubit = ContinuationCubit(savedContext(), repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.editDraft('Did it arrive?');
      await cubit.send();
      expect(cubit.state.uncertainDelivery, true);
      repository.submitError = null;
      await cubit.load();
      await cubit.send();
      expect(repository.sent, ['Did it arrive?']);
      expect(cubit.state.draft, 'Did it arrive?');
    },
  );

  test(
    'rejects cross-session history and quarantines cross-session write responses',
    () async {
      final repository = FakeConversationRepository()
        ..snapshot = ConversationSnapshot(
          sessionId: 'other-session',
          messages: [],
        );
      final cubit = ContinuationCubit(savedContext(), repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, ContinuationStatus.failed);
      repository.snapshot = ConversationSnapshot(
        sessionId: 'saved-session',
        messages: [],
      );
      await cubit.load();
      cubit.editDraft('A response');
      repository.snapshot = ConversationSnapshot(
        sessionId: 'other-session',
        messages: [],
      );
      await cubit.send();
      expect(cubit.state.uncertainDelivery, true);
      expect(cubit.state.draft, 'A response');
      expect(cubit.state.messages, isEmpty);
    },
  );

  testWidgets(
    'small phone, large text and keyboard do not overflow; back keeps result',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = ContinuationCubit(
        savedContext(),
        FakeConversationRepository(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: const Scaffold(body: Text('Saved result version 2')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              BlocProvider.value(value: cubit, child: const ContinuationPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'No');
      expect(cubit.state.draft, 'No');
      expect(find.byTooltip('Send response'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Saved result version 2'), findsOneWidget);
      expect(cubit.context.original, same(original));
      expect(cubit.state.draft, 'No');
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              BlocProvider.value(value: cubit, child: const ContinuationPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
