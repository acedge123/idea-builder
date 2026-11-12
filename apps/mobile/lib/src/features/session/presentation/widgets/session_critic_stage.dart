import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/session_cubit.dart';

/// The only active content during a pick save / read wait; no hidden next cards.
class SessionCriticStage extends StatelessWidget {
  const SessionCriticStage({
    super.key,
    required this.state,
    required this.onRetryNext,
  });
  final SessionState state;
  final VoidCallback onRetryNext;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pairing = state.currentRound?.pairing;
    final picked = state.skipping || state.selectedSongId == null
        ? null
        : state.selectedSongId == pairing?.songA.id
        ? pairing?.songA
        : pairing?.songB;
    final line = state.criticMessage ?? state.criticWaitLine;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700);
    return Semantics(
      label: 'The Critic',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (picked != null) ...[
              Text(
                'YOU PICKED · ${picked.title}',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 24),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: AnimatedSwitcher(
                duration: duration,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Semantics(
                  key: ValueKey(line),
                  liveRegion: true,
                  child: line != null
                      ? Text(
                          line,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 30,
                            fontStyle: FontStyle.italic,
                            height: 1.25,
                          ),
                        )
                      : const LinearProgressIndicator(
                          semanticsLabel: 'The Critic is thinking',
                          color: AppTheme.gold,
                        ),
                ),
              ),
            ),
            if (state.nextPairingError != null) ...[
              const SizedBox(height: 16),
              Text(state.nextPairingError!, style: theme.textTheme.bodyMedium),
              TextButton(
                onPressed: state.nextPairingLoading ? null : onRetryNext,
                child: const Text('Retry loading matchup'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
