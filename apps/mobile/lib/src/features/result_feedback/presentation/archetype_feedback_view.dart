import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/result_feedback.dart';
import 'result_feedback_cubit.dart';

/// Uses the same owner/version-bound, readback-confirmed save flow as accuracy,
/// with a distinct target and no implicit learning enrollment.
class ArchetypeFeedbackView extends StatelessWidget {
  const ArchetypeFeedbackView({
    super.key,
    required this.name,
    required this.onSignIn,
  });
  final String name;
  final VoidCallback onSignIn;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ResultFeedbackCubit, ResultFeedbackState>(
    builder: (context, state) {
      final cubit = context.read<ResultFeedbackCubit>();
      final editable =
          state.loaded &&
          !state.busy &&
          !state.uncertain &&
          !state.requiresSignIn;
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('Does $name fit you?'),
        children: [
          const Text(
            'Optional. This rates the archetype, separately from the reading.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in [
                (ReadingAccuracy.accurate, 'Yes'),
                (ReadingAccuracy.partly, 'Somewhat'),
                (ReadingAccuracy.missed, 'No'),
              ])
                ChoiceChip(
                  label: Text(choice.$2),
                  selected: state.draft.accuracy == choice.$1,
                  onSelected: editable
                      ? (_) => cubit.edit(
                          state.draft.copyWith(accuracy: choice.$1),
                        )
                      : null,
                ),
            ],
          ),
          if (state.busy) const LinearProgressIndicator(),
          if (state.saved != null && !state.dirty && !state.uncertain)
            const Text('Archetype feedback saved'),
          if (state.error != null) Text(state.error!),
          if (state.loaded && !state.uncertain)
            TextButton(
              onPressed: state.canSave ? cubit.save : null,
              child: const Text('Save archetype feedback'),
            ),
          if (state.uncertain || !state.loaded || state.error != null)
            TextButton(
              onPressed: state.busy || state.requiresSignIn ? null : cubit.load,
              child: Text(
                state.uncertain
                    ? 'Check saved archetype feedback'
                    : 'Reload archetype feedback',
              ),
            ),
          if (state.requiresSignIn)
            TextButton(onPressed: onSignIn, child: const Text('Sign in again')),
        ],
      );
    },
  );
}
