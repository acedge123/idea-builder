import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Indeterminate activity, never a fabricated percent or completed model stage.
class MusicThinkingView extends StatefulWidget {
  const MusicThinkingView({
    super.key,
    required this.title,
    this.body,
    this.compact = false,
  });
  final String title;
  final String? body;
  final bool compact;
  @override
  State<MusicThinkingView> createState() => _MusicThinkingViewState();
}

class _MusicThinkingViewState extends State<MusicThinkingView>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _reducedMotion = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: widget.title,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(widget.compact ? 16 : 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                height: widget.compact ? 24 : 48,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(7, (i) {
                      final wave = _reducedMotion
                          ? 0.5
                          : (math.sin(_pulse.value * math.pi * 2 + i * 0.8) +
                                    1) /
                                2;
                      return Container(
                        width: 4,
                        height:
                            (widget.compact ? 8 : 12) +
                            wave * (widget.compact ? 14 : 30),
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: i.isEven ? AppTheme.gold : AppTheme.ember,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(height: widget.compact ? 12 : 20),
            ExcludeSemantics(
              child: Text(
                widget.title,
                style: widget.compact
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.headlineMedium,
              ),
            ),
            if (widget.body != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PairingThinkingView extends StatelessWidget {
  const PairingThinkingView({super.key, required this.savingChoice});
  final bool savingChoice;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MusicThinkingView(
        title: savingChoice
            ? 'Saving your choice'
            : 'Finding your next pairing',
        body: savingChoice
            ? 'The next songs will appear here.'
            : 'Getting two songs ready for you.',
        compact: true,
      ),
      const SizedBox(height: 18),
      ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < 2; i++)
              Container(
                height: 144,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      color: AppTheme.surfaceRaised,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: 120,
                            color: AppTheme.surfaceRaised,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 8,
                            width: 80,
                            color: AppTheme.surfaceRaised,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
