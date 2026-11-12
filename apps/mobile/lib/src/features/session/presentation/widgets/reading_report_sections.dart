import 'package:flutter/material.dart';
import '../../domain/entities/reading_report.dart';

class ReadingIdentity extends StatelessWidget {
  const ReadingIdentity({super.key, required this.report});
  final ReadingReport report;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final archetype = report.archetype;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (archetype != null) ...[
          Text(
            archetype.status == 'confirmed'
                ? 'Confirmed archetype'
                : 'Leaning toward',
            style: theme.labelSmall,
          ),
          Text(archetype.name, style: theme.headlineMedium),
          if (archetype.profileVersion != null)
            Text(
              'Saved profile v${archetype.profileVersion}',
              style: theme.labelSmall,
            ),
        ] else if (report.signatureName != null) ...[
          Text('Emerging signature', style: theme.labelSmall),
          Text(report.signatureName!, style: theme.headlineMedium),
          if (report.signatureHook != null)
            Text(report.signatureHook!, style: theme.bodyLarge),
          const Text('An early signature, not a confirmed archetype.'),
        ] else
          const Text('No archetype or signature saved with this reading.'),
        const SizedBox(height: 24),
      ],
    );
  }
}

class ReadingDimensions extends StatelessWidget {
  const ReadingDimensions({super.key, required this.report});
  final ReadingReport report;
  @override
  Widget build(BuildContext context) {
    final panel = report.panel;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Your Music DNA', style: theme.titleLarge),
        const SizedBox(height: 8),
        if (!report.panelAvailable || panel == null)
          const Text(
            'Your Music DNA panel is unavailable. Your saved reading is still shown above.',
          )
        else ...[
          if (panel.dimensions.isEmpty)
            const Text('These choices do not yet support a clear dimension.'),
          for (final dimension in panel.dimensions)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dimension.label, style: theme.titleMedium),
                  Text(
                    '${dimension.supporting} of ${dimension.relevant} relevant comparisons · ${dimension.confidence}',
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    label:
                        '${dimension.label}: ${dimension.supporting} of ${dimension.relevant} relevant comparisons, ${dimension.confidence}',
                    child: ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: dimension.strength,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.12),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            'Clear: stronger evidence. Leaning: a direction is forming. Early: provisional. Bars show evidence strength, not personality percentages.',
          ),
          if (panel.undecided.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Still undecided', style: theme.titleSmall),
            for (final label in panel.undecided) Text(label),
          ],
          if (panel.singleLane != null) ...[
            const SizedBox(height: 12),
            Text(
              'These choices stayed within ${panel.singleLane}. Other musical lanes remain untested.',
            ),
          ],
        ],
      ],
    );
  }
}

class ReadingEvidence extends StatelessWidget {
  const ReadingEvidence({super.key, required this.panel});
  final DnaPanel panel;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text('The evidence', style: Theme.of(context).textTheme.titleLarge),
      if (panel.receipts.isEmpty)
        const Text('No song receipts are available for this reading.'),
      for (final receipt in panel.displayReceipts)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (receipt.kind == 'contradiction')
                Text(
                  'The complication',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              MatchupReceipt(matchup: receipt.matchup),
              Text(receipt.note),
            ],
          ),
        ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('All ${panel.matchups.length} matchups'),
        children: [
          for (final entry in panel.matchups.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choice ${entry.$1 + 1}'),
                  MatchupReceipt(matchup: entry.$2),
                ],
              ),
            ),
          if (panel.matchups.length != panel.answered)
            Text(
              '${panel.matchups.length} matchup receipts are available for ${panel.answered} answered choices.',
            ),
        ],
      ),
    ],
  );
}

class MatchupReceipt extends StatelessWidget {
  const MatchupReceipt({super.key, required this.matchup});
  final DnaMatchup matchup;
  @override
  Widget build(BuildContext context) => Text(
    '${matchup.chosen} — ${matchup.chosenArtist} over ${matchup.rejected} — ${matchup.rejectedArtist}',
  );
}
