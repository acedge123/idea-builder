import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_dna/src/core/network/app_api_exception.dart';
import 'package:music_dna/src/features/result_feedback/data/unavailable_result_feedback_repository.dart';
import 'package:music_dna/src/features/result_feedback/domain/result_feedback.dart';
import 'package:music_dna/src/features/result_feedback/domain/result_feedback_repository.dart';
import 'package:music_dna/src/features/result_feedback/presentation/result_feedback_cubit.dart';
import 'package:music_dna/src/features/result_feedback/presentation/result_feedback_view.dart';

const target = FeedbackTarget(
  ownerId: 'owner',
  sessionId: 'session',
  resultVersion: 2,
);
const draft = FeedbackDraft(
  accuracy: ReadingAccuracy.partly,
  comment: 'One exception.',
);

class FeedbackRepository implements ResultFeedbackRepository {
  @override
  bool get available => true;
  SavedResultFeedback? stored;
  Object? loadError, saveError;
  int reads = 0;
  final writes = <SavedResultFeedback>[];
  Completer<SavedResultFeedback>? pendingSave;
  Completer<SavedResultFeedback?>? pendingLoad;
  SavedResultFeedback? invalidAck;
  @override
  Future<SavedResultFeedback?> load(FeedbackTarget target) async {
    reads++;
    if (loadError != null) throw loadError!;
    if (pendingLoad != null) return pendingLoad!.future;
    return stored;
  }

  @override
  Future<SavedResultFeedback> save({
    required FeedbackTarget target,
    required FeedbackDraft draft,
    required String mutationId,
  }) async {
    final row = SavedResultFeedback(
      target: target,
      draft: draft,
      mutationId: mutationId,
    );
    writes.add(row);
    if (saveError != null) throw saveError!;
    if (pendingSave != null) return pendingSave!.future;
    return stored = invalidAck ?? row;
  }
}

ResultFeedbackCubit makeCubit(
  FeedbackRepository repository, {
  String? Function()? owner,
}) => ResultFeedbackCubit(
  target: target,
  repository: repository,
  currentOwnerId: owner ?? () => 'owner',
);

void main() {
  test(
    'account change immediately clears visible feedback and drafts',
    () async {
      final owners = StreamController<String?>();
      final repository = FeedbackRepository()
        ..stored = const SavedResultFeedback(
          target: target,
          draft: draft,
          mutationId: 'prior',
        );
      final cubit = ResultFeedbackCubit(
        target: target,
        repository: repository,
        currentOwnerId: () => 'owner',
        ownerChanges: owners.stream,
      );
      await cubit.load();
      cubit.edit(draft.copyWith(comment: 'Private draft'));
      owners.add('other');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.saved, isNull);
      expect(cubit.state.draft, const FeedbackDraft());
      expect(cubit.state.requiresSignIn, true);
      await cubit.save();
      expect(repository.writes, isEmpty);
      await cubit.close();
      await owners.close();
    },
  );
  test('production repository is unavailable and makes no transport calls', () {
    expect(const UnavailableResultFeedbackRepository().available, false);
  });
  test('normalize and validate the three labels and optional field limits', () {
    for (final label in ReadingAccuracy.values) {
      expect(FeedbackDraft(accuracy: label).isValid, true);
    }
    expect(const FeedbackDraft().isValid, false);
    expect(
      draft.copyWith(comment: '  trimmed  ').normalized.comment,
      'trimmed',
    );
    expect(draft.copyWith(comment: 'a' * 2001).isValid, false);
    expect(draft.copyWith(usefulSentence: 'a' * 1001).isValid, false);
    expect(draft.copyWith(inaccurateSentence: 'a' * 1001).isValid, false);
  });
  test(
    'load restores saved content for the exact version without a write',
    () async {
      final repository = FeedbackRepository()
        ..stored = const SavedResultFeedback(
          target: target,
          draft: draft,
          mutationId: 'prior',
        );
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.draft, draft);
      expect(cubit.state.dirty, false);
      expect(cubit.state.canSave, false);
      expect(repository.writes, isEmpty);
    },
  );
  test(
    'initial load failure blocks writes until successful restoration',
    () async {
      final repository = FeedbackRepository()
        ..loadError = TimeoutException('offline');
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.edit(draft);
      await cubit.save();
      expect(cubit.state.loaded, false);
      expect(repository.writes, isEmpty);
      repository.loadError = null;
      await cubit.load();
      cubit.edit(draft);
      expect(cubit.state.canSave, true);
    },
  );
  test('dirty draft survives reload and load failure', () async {
    final repository = FeedbackRepository();
    final cubit = makeCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.edit(draft);
    await cubit.load();
    expect(cubit.state.draft, draft);
    repository.loadError = TimeoutException('offline');
    await cubit.load();
    expect(cubit.state.draft, draft);
  });
  test(
    'save binds owner session version and repeated taps do not duplicate',
    () async {
      final repository = FeedbackRepository()..pendingSave = Completer();
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.edit(draft);
      final saving = cubit.save();
      await cubit.save();
      cubit.edit(draft.copyWith(comment: 'Cannot change in flight'));
      expect(repository.writes.length, 1);
      expect(repository.writes.single.target, target);
      expect(repository.writes.single.mutationId.length, 32);
      repository.pendingSave!.complete(repository.writes.single);
      await saving;
      expect(cubit.state.draft, draft);
      expect(cubit.state.saved, repository.writes.single);
      await cubit.save();
      expect(repository.writes.length, 1);
    },
  );
  test(
    'definitive rejection preserves draft and allows manual retry',
    () async {
      final repository = FeedbackRepository()
        ..saveError = const AppApiException(
          kind: AppApiErrorKind.invalidInput,
          message: 'Invalid',
          statusCode: 400,
        );
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.edit(draft);
      await cubit.save();
      expect(cubit.state.draft, draft);
      expect(cubit.state.uncertain, false);
      repository.saveError = null;
      await cubit.save();
      expect(cubit.state.saved, isNotNull);
    },
  );
  test(
    'lost acknowledgment blocks resubmit until exact mutation is read',
    () async {
      final repository = FeedbackRepository()
        ..saveError = TimeoutException('lost');
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.edit(draft);
      await cubit.save();
      expect(cubit.state.uncertain, true);
      cubit.edit(draft.copyWith(comment: 'No duplicate'));
      await cubit.save();
      await cubit.load();
      expect(cubit.state.uncertain, true);
      expect(cubit.state.draft, draft);
      expect(repository.writes.length, 1);
      repository.stored = repository.writes.single;
      await cubit.load();
      expect(cubit.state.uncertain, false);
      expect(cubit.state.dirty, false);
      expect(repository.writes.length, 1);
    },
  );
  test('another mutation cannot reconcile the uncertain save', () async {
    final repository = FeedbackRepository()
      ..saveError = TimeoutException('lost');
    final cubit = makeCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.edit(draft);
    await cubit.save();
    repository.stored = const SavedResultFeedback(
      target: target,
      draft: draft,
      mutationId: 'other',
    );
    await cubit.load();
    expect(cubit.state.uncertain, true);
  });
  test(
    'wrong version or owner cannot restore or acknowledge feedback',
    () async {
      for (final wrong in [
        const FeedbackTarget(
          ownerId: 'other',
          sessionId: 'session',
          resultVersion: 2,
        ),
        const FeedbackTarget(
          ownerId: 'owner',
          sessionId: 'other',
          resultVersion: 2,
        ),
        const FeedbackTarget(
          ownerId: 'owner',
          sessionId: 'session',
          resultVersion: 1,
        ),
      ]) {
        final repository = FeedbackRepository()
          ..stored = SavedResultFeedback(
            target: wrong,
            draft: draft,
            mutationId: 'wrong',
          );
        final cubit = makeCubit(repository);
        await cubit.load();
        expect(cubit.state.saved, isNull);
        expect(cubit.state.loaded, false);
        repository.stored = null;
        await cubit.load();
        cubit.edit(draft);
        repository.invalidAck = SavedResultFeedback(
          target: wrong,
          draft: draft,
          mutationId: 'wrong',
        );
        await cubit.save();
        expect(cubit.state.saved, isNull);
        expect(cubit.state.uncertain, true);
        await cubit.close();
      }
    },
  );
  test('expired authentication retains draft but requires sign in', () async {
    final repository = FeedbackRepository()
      ..saveError = const AppApiException(
        kind: AppApiErrorKind.unauthorized,
        statusCode: 401,
        message: 'Expired',
      );
    final cubit = makeCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.edit(draft);
    await cubit.save();
    expect(cubit.state.requiresSignIn, true);
    expect(cubit.state.canSave, false);
    expect(cubit.state.draft, draft);
  });
  test('owner switch while loading discards late private data', () async {
    String? owner = 'owner';
    final repository = FeedbackRepository()..pendingLoad = Completer();
    final cubit = makeCubit(repository, owner: () => owner);
    addTearDown(cubit.close);
    final loading = cubit.load();
    owner = 'other';
    repository.pendingLoad!.complete(
      const SavedResultFeedback(
        target: target,
        draft: draft,
        mutationId: 'prior',
      ),
    );
    await loading;
    expect(cubit.state.draft, const FeedbackDraft());
    expect(cubit.state.saved, isNull);
    expect(cubit.state.requiresSignIn, true);
  });
  test('logout during save clears draft and ignores acknowledgment', () async {
    String? owner = 'owner';
    final repository = FeedbackRepository()..pendingSave = Completer();
    final cubit = makeCubit(repository, owner: () => owner);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.edit(draft);
    final saving = cubit.save();
    owner = null;
    repository.pendingSave!.complete(repository.writes.single);
    await saving;
    expect(cubit.state.draft, const FeedbackDraft());
    expect(cubit.state.saved, isNull);
  });
  test('closing during request ignores completion', () async {
    final repository = FeedbackRepository()..pendingLoad = Completer();
    final cubit = makeCubit(repository);
    final loading = cubit.load();
    await cubit.close();
    repository.pendingLoad!.complete(null);
    await loading;
    expect(cubit.isClosed, true);
  });
  testWidgets(
    'controls fit a small phone at large text and save optional details',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FeedbackRepository();
      final cubit = makeCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BlocProvider.value(
                  value: cubit,
                  child: ResultFeedbackView(onSignIn: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<ReadingAccuracy>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partly accurate').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add details'));
      await tester.pumpAndSettle();
      final comment = find.widgetWithText(TextField, 'Comment (optional)');
      await tester.ensureVisible(comment);
      await tester.enterText(comment, 'One exception.');
      await tester.pump();
      await tester.ensureVisible(find.text('Save feedback'));
      await tester.tap(find.text('Save feedback'));
      await tester.pumpAndSettle();
      expect(repository.writes.single.draft, draft);
      expect(find.text('Feedback saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
