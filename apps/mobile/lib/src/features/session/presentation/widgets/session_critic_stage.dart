import '../../domain/entities/critic_stage_policy.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/session_cubit.dart';

/// The only active content during a pick save / read wait; no hidden next cards.
class SessionCriticStage extends StatelessWidget {
  const SessionCriticStage({
    super.key,
    required this.state,
    required this.onRetryNext,
    this.onLineShown,
  });
  final SessionState state;
  final VoidCallback onRetryNext;
  final ValueChanged<String>? onLineShown;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pairing = state.currentRound?.pairing;
    final picked = state.skipping || state.selectedSongId == null
        ? null
        : state.selectedSongId == pairing?.songA.id
        ? pairing?.songA
        : pairing?.songB;
    final pickedTitle = state.skipping
        ? null
        : state.criticPickedTitle ?? picked?.title;
    final line = state.criticMessage ?? state.criticWaitLine;
    final finalReading = state.status == SessionStatus.revealing;
    if (line != null && state.criticMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onLineShown?.call(line);
      });
    }
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
            if (pickedTitle != null) ...[
              Text(
                'YOU PICKED · $pickedTitle',
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
            if (finalReading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!MediaQuery.disableAnimationsOf(context)) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      CriticStagePolicy.writingTitle,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ],
            if (!finalReading && state.nextPairingError != null) ...[
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
