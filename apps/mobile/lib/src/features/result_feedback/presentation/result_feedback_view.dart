import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/result_feedback.dart';
import 'result_feedback_cubit.dart';

class ResultFeedbackView extends StatefulWidget {
  const ResultFeedbackView({super.key, required this.onSignIn});
  final VoidCallback onSignIn;
  @override
  State<ResultFeedbackView> createState() => _ResultFeedbackViewState();
}

class _ResultFeedbackViewState extends State<ResultFeedbackView> {
  final _useful = TextEditingController();
  final _inaccurate = TextEditingController();
  final _comment = TextEditingController();

  void _sync(ResultFeedbackState state) {
    for (final entry in [
      (_useful, state.draft.usefulSentence),
      (_inaccurate, state.draft.inaccurateSentence),
      (_comment, state.draft.comment),
    ]) {
      if (entry.$1.text != entry.$2) entry.$1.text = entry.$2;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(context.read<ResultFeedbackCubit>().state);
  }

  @override
  void dispose() {
    _useful.dispose();
    _inaccurate.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ResultFeedbackCubit, ResultFeedbackState>(
        listener: (_, state) => _sync(state),
        builder: (context, state) {
          final cubit = context.read<ResultFeedbackCubit>();
          final editable =
              state.loaded &&
              !state.busy &&
              !state.uncertain &&
              !state.requiresSignIn;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'How did this read land?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReadingAccuracy>(
                key: ValueKey(state.draft.accuracy),
                initialValue: state.draft.accuracy,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Accuracy'),
                items: const [
                  DropdownMenuItem(
                    value: ReadingAccuracy.accurate,
                    child: Text('Accurate'),
                  ),
                  DropdownMenuItem(
                    value: ReadingAccuracy.partly,
                    child: Text('Partly accurate'),
                  ),
                  DropdownMenuItem(
                    value: ReadingAccuracy.missed,
                    child: Text('Missed'),
                  ),
                ],
                onChanged: editable
                    ? (accuracy) =>
                          cubit.edit(state.draft.copyWith(accuracy: accuracy))
                    : null,
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Add details'),
                children: [
                  TextField(
                    controller: _useful,
                    enabled: editable,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: FeedbackDraft.sentenceLimit,
                    decoration: const InputDecoration(
                      labelText: 'Most useful sentence (optional)',
                    ),
                    onChanged: (value) => cubit.edit(
                      cubit.state.draft.copyWith(usefulSentence: value),
                    ),
                  ),
                  TextField(
                    controller: _inaccurate,
                    enabled: editable,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: FeedbackDraft.sentenceLimit,
                    decoration: const InputDecoration(
                      labelText: 'Inaccurate sentence (optional)',
                    ),
                    onChanged: (value) => cubit.edit(
                      cubit.state.draft.copyWith(inaccurateSentence: value),
                    ),
                  ),
                  TextField(
                    controller: _comment,
                    enabled: editable,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: FeedbackDraft.commentLimit,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                    ),
                    onChanged: (value) =>
                        cubit.edit(cubit.state.draft.copyWith(comment: value)),
                  ),
                ],
              ),
              if (state.busy) const LinearProgressIndicator(),
              if (state.saved != null && !state.dirty && !state.uncertain)
                const Text('Feedback saved', semanticsLabel: 'Feedback saved'),
              if (state.error != null)
                Text(state.error!, semanticsLabel: state.error!),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (!state.uncertain && state.loaded)
                    FilledButton.icon(
                      onPressed: state.canSave ? cubit.save : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Save feedback'),
                    ),
                  if (state.uncertain || !state.loaded || state.error != null)
                    TextButton.icon(
                      onPressed: state.busy || state.requiresSignIn
                          ? null
                          : cubit.load,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        state.uncertain
                            ? 'Check saved feedback'
                            : 'Reload feedback',
                      ),
                    ),
                  if (state.requiresSignIn)
                    TextButton(
                      onPressed: widget.onSignIn,
                      child: const Text('Sign in again'),
                    ),
                ],
              ),
            ],
          );
        },
      );
}
