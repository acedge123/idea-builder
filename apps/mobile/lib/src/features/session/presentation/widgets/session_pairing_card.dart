import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/session_pairing.dart';

class SessionPairingCard extends StatelessWidget {
  const SessionPairingCard({
    super.key,
    required this.pairing,
    required this.isBusy,
    required this.selectedSongId,
    required this.onChoose,
    required this.onSkip,
  });

  final SessionPairing pairing;
  final bool isBusy;
  final String? selectedSongId;
  final ValueChanged<String> onChoose;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackChoices = constraints.maxWidth < 520;
        final first = SessionSongChoiceCard(
          song: pairing.songA,
          isBusy: isBusy,
          isSelected: selectedSongId == pairing.songA.id,
          hasSelection: selectedSongId != null,
          onChoose: () => onChoose(pairing.songA.id),
        );
        final second = SessionSongChoiceCard(
          song: pairing.songB,
          isBusy: isBusy,
          isSelected: selectedSongId == pairing.songB.id,
          hasSelection: selectedSongId != null,
          onChoose: () => onChoose(pairing.songB.id),
        );

        return Column(
          children: <Widget>[
            if (stackChoices)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[first, const SizedBox(height: 1), second],
              )
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: first),
                    const SizedBox(width: 12),
                    Expanded(child: second),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: isBusy || selectedSongId != null ? null : onSkip,
                child: const Text('Skip — I don’t know these'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SessionSongChoiceCard extends StatelessWidget {
  const SessionSongChoiceCard({
    super.key,
    required this.song,
    required this.isBusy,
    required this.isSelected,
    required this.hasSelection,
    required this.onChoose,
  });

  final SessionPairingSong song;
  final bool isBusy;
  final bool isSelected;
  final bool hasSelection;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDimmed = hasSelection && !isSelected;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final borderColor = isSelected
        ? AppTheme.gold
        : isBusy
        ? AppTheme.border
        : AppTheme.borderStrong;
    final backgroundColor = isSelected
        ? AppTheme.surfaceRaised
        : AppTheme.surface.withValues(alpha: isDimmed ? 0.45 : 1);

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !isBusy && (!hasSelection || isSelected),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy || (hasSelection && !isSelected) ? null : onChoose,
          borderRadius: BorderRadius.circular(3),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 112),
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: isDimmed ? 0.48 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          isSelected
                              ? '✓ Your choice'
                              : song.year?.toString() ?? 'Song',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      Text(
                        song.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        song.artist,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
