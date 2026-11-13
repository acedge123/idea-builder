import 'package:flutter/material.dart';

import '../cubit/session_cubit.dart';
import 'session_experience_view.dart';
import 'session_pushback_link.dart';
import '../../domain/entities/critic_stage_policy.dart';

/// A checkpoint owns the screen. Upcoming song cards stay held by the cubit.
class SessionCheckpointView extends StatelessWidget {
  const SessionCheckpointView({
    super.key,
    required this.state,
    required this.onContinue,
    required this.onFinish,
    required this.onRetryRead,
    required this.onRetryNext,
    this.onPushback,
  });

  final SessionState state;
  final VoidCallback onContinue, onFinish, onRetryRead, onRetryNext;
  final ValueChanged<String>? onPushback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = state.criticPending || state.pushbackSaving;
    final four = state.checkpointAnswered == 4;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'After ${state.checkpointAnswered} choices',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 24),
          if (state.read != null)
            SessionReadView(read: state.read!, compact: true)
          else ...[
            Semantics(
              liveRegion: true,
              child: Text(
                state.criticMessage ?? CriticStagePolicy.checkpointUnavailable,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: busy ? null : onRetryRead,
              child: const Text('Try again'),
            ),
          ],
          if (onPushback != null)
            SessionPushbackLink(
              key: ValueKey(state.checkpointAnswered),
              state: state,
              onSubmit: onPushback!,
            ),
          const SizedBox(height: 24),
          if (four) ...[
            FilledButton(
              onPressed: busy ? null : onFinish,
              child: const Text('Get my reading now'),
            ),
            const SizedBox(height: 12),
          ],
          if (state.prefetchedRound?.pairing != null && !four)
            FilledButton(
              onPressed: busy ? null : onContinue,
              child: const Text('Next pairing'),
            )
          else if (state.prefetchedRound?.pairing != null)
            OutlinedButton(
              onPressed: busy ? null : onContinue,
              child: const Text('Keep going (final pair)'),
            )
          else if (state.nextPairingLoading)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading the next pairing',
            ),
          if (state.nextPairingError != null) ...[
            Text(state.nextPairingError!, style: theme.textTheme.bodyMedium),
            TextButton(
              onPressed: busy || state.nextPairingLoading ? null : onRetryNext,
              child: const Text('Retry loading matchup'),
            ),
          ],
        ],
      ),
    );
  }
}
