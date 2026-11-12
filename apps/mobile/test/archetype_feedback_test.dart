import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:music_dna/src/features/result_feedback/domain/result_feedback.dart';
import 'package:music_dna/src/features/result_feedback/presentation/result_feedback_cubit.dart';
import 'package:music_dna/src/features/result_feedback/presentation/archetype_feedback_view.dart';

import 'rest_result_feedback_test.dart' show repo, row, history, target;
import 'result_feedback_test.dart' show FeedbackRepository;

const fitTarget = FeedbackTarget(
  ownerId: 'owner',
  sessionId: 'session',
  resultVersion: 1,
  feedbackTarget: 'archetype:The Romantic',
);
Map<String, dynamic> fitRow() => {
  ...row(),
  'target': fitTarget.feedbackTarget,
  'mutation_id': 'fit-mutation',
};
http.Response ack() => http.Response(
  jsonEncode({
    'contract': 1,
    'id': 'saved',
    'updated': false,
    'replayed': true,
  }),
  200,
);

void main() {
  test(
    'archetype and accuracy loads cannot consume each other or a different version',
    () async {
      final repository = repo(
        (_) async => history([
          {...row(), 'id': 'accuracy', 'accuracy': 'accurate'},
          fitRow(),
          {
            ...fitRow(),
            'id': 'version2',
            'result_version': 2,
            'accuracy': 'not_accurate',
          },
          {
            ...fitRow(),
            'id': 'other-archetype',
            'target': 'archetype:The Witness',
          },
        ]),
      );
      expect(
        (await repository.load(target))!.draft.accuracy,
        ReadingAccuracy.accurate,
      );
      expect(
        (await repository.load(fitTarget))!.draft.accuracy,
        ReadingAccuracy.partly,
      );
      expect((await repository.load(fitTarget))!.target, fitTarget);
      expect(target, isNot(fitTarget));
    },
  );
  test(
    'save binds exact frozen name/version and waits for matching mutation readback',
    () async {
      final readback = Completer<http.Response>();
      final methods = <String>[];
      final repository = repo((request) async {
        methods.add(request.method);
        if (request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['target'], 'archetype:The Romantic');
          expect(body['result_version'], 1);
          expect(body['mutation_id'], 'fit-mutation');
          expect(body['accuracy'], 'mixed');
          return ack();
        }
        return readback.future;
      });
      var completed = false;
      final saving = repository
          .save(
            target: fitTarget,
            draft: const FeedbackDraft(
              accuracy: ReadingAccuracy.partly,
              comment: 'One exception',
            ),
            mutationId: 'fit-mutation',
          )
          .then((value) {
            completed = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(methods, ['POST', 'GET']);
      expect(completed, false);
      readback.complete(history([fitRow()]));
      final saved = await saving;
      expect(saved.target, fitTarget);
      expect(saved.mutationId, 'fit-mutation');
    },
  );
  for (final replacement in [null, 'wrong-mutation']) {
    test(
      'missing or mismatched mutation $replacement cannot claim saved',
      () async {
        final repository = repo(
          (request) async => request.method == 'POST'
              ? ack()
              : history([
                  {...fitRow(), 'mutation_id': replacement},
                ]),
        );
        await expectLater(
          repository.save(
            target: fitTarget,
            draft: const FeedbackDraft(
              accuracy: ReadingAccuracy.partly,
              comment: 'One exception',
            ),
            mutationId: 'fit-mutation',
          ),
          throwsFormatException,
        );
      },
    );
  }
  test(
    'cross-target acknowledgment is rejected even when row ID matches',
    () async {
      final repository = repo(
        (request) async => request.method == 'POST'
            ? ack()
            : history([
                {...fitRow(), 'target': null},
              ]),
      );
      await expectLater(
        repository.save(
          target: fitTarget,
          draft: const FeedbackDraft(
            accuracy: ReadingAccuracy.partly,
            comment: 'One exception',
          ),
          mutationId: 'fit-mutation',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'late save cannot restore archetype feedback after owner changes',
    () async {
      var owner = 'owner';
      final owners = StreamController<String?>();
      final repository = FeedbackRepository()
        ..pendingSave = Completer<SavedResultFeedback>();
      final cubit = ResultFeedbackCubit(
        target: fitTarget,
        repository: repository,
        currentOwnerId: () => owner,
        ownerChanges: owners.stream,
      );
      await cubit.load();
      cubit.edit(const FeedbackDraft(accuracy: ReadingAccuracy.accurate));
      final saving = cubit.save();
      owner = 'other';
      owners.add(owner);
      await Future<void>.delayed(Duration.zero);
      repository.pendingSave!.complete(repository.writes.single);
      await saving;
      expect(cubit.state.saved, isNull);
      expect(cubit.state.draft.accuracy, isNull);
      expect(cubit.state.requiresSignIn, true);
      await cubit.close();
      await owners.close();
    },
  );
  test('new version never inherits an old fit acknowledgment', () async {
    final repository = FeedbackRepository()
      ..pendingSave = Completer<SavedResultFeedback>();
    final old = ResultFeedbackCubit(
      target: fitTarget,
      repository: repository,
      currentOwnerId: () => 'owner',
    );
    await old.load();
    old.edit(const FeedbackDraft(accuracy: ReadingAccuracy.accurate));
    final saving = old.save();
    await old.close();
    final next = ResultFeedbackCubit(
      target: const FeedbackTarget(
        ownerId: 'owner',
        sessionId: 'session',
        resultVersion: 2,
        feedbackTarget: 'archetype:The Romantic',
      ),
      repository: FeedbackRepository(),
      currentOwnerId: () => 'owner',
    );
    await next.load();
    repository.pendingSave!.complete(repository.writes.single);
    await saving;
    expect(next.state.saved, isNull);
    expect(next.state.draft.accuracy, isNull);
    await next.close();
  });
  testWidgets(
    'fit is compact and optional, with honest saving on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = ResultFeedbackCubit(
        target: fitTarget,
        repository: FeedbackRepository(),
        currentOwnerId: () => 'owner',
      );
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: BlocProvider.value(
                  value: cubit,
                  child: ArchetypeFeedbackView(
                    name: 'The Romantic',
                    onSignIn: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Yes'), findsNothing);
      await tester.tap(find.text('Does The Romantic fit you?'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Somewhat'));
      await tester.tap(find.text('Somewhat'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save archetype feedback'));
      await tester.tap(find.text('Save archetype feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Archetype feedback saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
