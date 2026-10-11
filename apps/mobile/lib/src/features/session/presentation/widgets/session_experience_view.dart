import 'package:flutter/material.dart';

import '../../domain/entities/session_experience.dart';

class SessionExperienceView extends StatelessWidget {
  const SessionExperienceView({
    super.key,
    required this.exchanges,
    this.read,
    required this.busy,
    required this.onReaction,
    this.reactionMessage,
    this.pendingReaction,
  });
  final List<SessionExchange> exchanges;
  final SessionRead? read;
  final bool busy;
  final ValueChanged<SessionReaction> onReaction;
  final String? reactionMessage;
  final SessionReaction? pendingReaction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exchanges.isNotEmpty)
          ExpansionTile(
            key: const PageStorageKey('session-exchanges'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Earlier exchanges'),
            children: [
              for (final e in exchanges)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.type == 'choice') ...[
                          Text(
                            '${e.chosen ?? 'Unavailable song'} over ${e.rejected ?? 'Unavailable song'}',
                          ),
                          if (e.feedback?.isNotEmpty == true) Text(e.feedback!),
                          if (e.evidenceSource == 'legacy_unavailable')
                            const Text('Historical evidence unavailable'),
                        ],
                        if (e.read != null) SessionReadView(read: e.read!),
                        if (e.type == 'skip') const Text('Pairing skipped'),
                        if (e.type == 'reaction')
                          Text(_reactionLabel(e.reaction)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (read != null) ...[
          const SizedBox(height: 16),
          SessionReadView(read: read!),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reaction in SessionReaction.values)
                OutlinedButton(
                  onPressed:
                      busy ||
                          (pendingReaction != null &&
                              pendingReaction != reaction)
                      ? null
                      : () => onReaction(reaction),
                  child: Text(
                    pendingReaction == reaction
                        ? 'Retry ${_reactionLabel(reaction.wireName)}'
                        : _reactionLabel(reaction.wireName),
                  ),
                ),
            ],
          ),
        ],
        if (reactionMessage?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(reactionMessage!)),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  static String _reactionLabel(String? kind) => switch (kind) {
    'thats_me' => "That's me",
    'not_quite' => 'Not quite',
    'harder' => 'Go harder',
    _ => 'Reaction recorded',
  };
}

class SessionReadView extends StatelessWidget {
  const SessionReadView({super.key, required this.read});
  final SessionRead read;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (read.previousClaim?.isNotEmpty == true) ...[
        Text('Previous read', style: Theme.of(context).textTheme.labelLarge),
        Text(read.previousClaim!),
        if (read.changedBy != null) Text(read.changedBy!),
        const SizedBox(height: 8),
      ],
      Semantics(
        liveRegion: true,
        child: Text(read.thesis, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (read.hook?.isNotEmpty == true) Text(read.hook!),
      if (read.newInterpretation?.isNotEmpty == true &&
          read.newInterpretation != read.thesis)
        Text(read.newInterpretation!),
      if (read.supporting != null && read.tested != null)
        Text(
          '${read.supporting} supporting / ${read.tested} tested'
          '${read.contradicting == null ? '' : ' / ${read.contradicting} contradicting'}',
        ),
      if (read.question?.isNotEmpty == true) Text(read.question!),
    ],
  );
}
