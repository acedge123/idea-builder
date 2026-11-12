import 'package:flutter/material.dart';
import '../../../../core/widgets/music_thinking_view.dart';
import '../../domain/entities/session_experience.dart';
import '../cubit/session_cubit.dart';
import 'session_experience_view.dart';

/// Lives below the songs. Its reserved space prevents a short reply from
/// clamping the scroll position and moving the cards beneath a listener's tap.
class SessionCriticResponse extends StatelessWidget {
  const SessionCriticResponse({
    super.key,
    required this.state,
    required this.onReaction,
  });
  final SessionState state;
  final ValueChanged<SessionReaction> onReaction;
  static const _minimumHeight = 180.0;
  @override
  Widget build(BuildContext context) {
    if (!state.criticPending &&
        state.criticMessage == null &&
        state.read == null &&
        state.exchanges.isEmpty) {
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minimumHeight),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: state.criticPending
            ? const MusicThinkingView(
                title: 'The Critic is thinking',
                body:
                    'You can choose the next song while the response finishes.',
                compact: true,
              )
            : state.criticMessage != null
            ? Text(state.criticMessage!)
            : SessionExperienceView(
                showHistory: false,
                showReactionControls: false,
                exchanges: state.exchanges,
                read: state.read,
                busy: state.reacting,
                reactionMessage: state.reactionMessage,
                onReaction: onReaction,
              ),
      ),
    );
  }
}
