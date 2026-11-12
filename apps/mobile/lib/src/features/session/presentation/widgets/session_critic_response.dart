import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/session_experience.dart';
import '../cubit/session_cubit.dart';
import 'session_experience_view.dart';

/// The previous pick's saved words lead into the new pairing, as on web.
/// This widget is never rendered with the old, already-selected matchup.
class SessionCriticResponse extends StatelessWidget {
  const SessionCriticResponse({
    super.key,
    required this.state,
    required this.onReaction,
  });
  final SessionState state;
  final ValueChanged<SessionReaction> onReaction;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedback = state.lastFeedback;
    if (state.read == null && state.criticMessage == null && feedback == null) {
      return SessionExperienceView(
        exchanges: state.exchanges,
        read: state.read,
        showHistory: false,
        showReactionControls: false,
        busy: state.reacting,
        reactionMessage: state.reactionMessage,
        onReaction: onReaction,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE CRITIC · AFTER CHOICE ${(state.currentRound?.round ?? 2) - 1}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 16),
          if (state.reactionMessage != null)
            Text(state.reactionMessage!, style: theme.textTheme.headlineSmall)
          else ...[
            if (feedback != null)
              for (final text in [
                feedback.verdict,
                feedback.why,
              ].where((x) => x.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    text,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      height: 1.3,
                    ),
                  ),
                ),
            if (state.read != null)
              SessionReadView(read: state.read!, compact: true),
            if (state.criticMessage != null)
              Text(
                state.criticMessage!,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.mutedForeground,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
