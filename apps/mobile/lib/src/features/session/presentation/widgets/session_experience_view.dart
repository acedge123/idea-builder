import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
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
    this.activeExchangeKey,
  });
  final List<SessionExchange> exchanges;
  final SessionRead? read;
  final bool busy;
  final ValueChanged<SessionReaction> onReaction;
  final String? reactionMessage;
  final SessionReaction? pendingReaction;
  final Key? activeExchangeKey;

  @override
  Widget build(BuildContext context) {
    final groups = groupSessionExchanges(exchanges);
    final latest = groups.lastOrNull;
    final historyHasRead = exchanges.any((e) => e.read != null);
    final canReact = read != null && latest?.hasReaction != true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groups.length > 1)
          ExpansionTile(
            key: const PageStorageKey('session-exchanges'),
            tilePadding: EdgeInsets.zero,
            title: Text('Earlier choices (${groups.length - 1})'),
            children: [
              for (final group in groups.take(groups.length - 1))
                SessionExchangeView(group: group),
            ],
          ),
        if (latest != null)
          SessionExchangeView(key: activeExchangeKey, group: latest),
        if (latest == null) SizedBox(key: activeExchangeKey),
        if (read != null && !historyHasRead) SessionReadView(read: read!),
        if (canReact) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reaction in SessionReaction.values)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  onPressed:
                      busy ||
                          (pendingReaction != null &&
                              pendingReaction != reaction)
                      ? null
                      : () => onReaction(reaction),
                  child: Text(
                    pendingReaction == reaction
                        ? 'Retry ${reactionLabel(reaction.wireName)}'
                        : reactionLabel(reaction.wireName),
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
}

String reactionLabel(String? kind) => switch (kind) {
  'thats_me' => "That's me",
  'not_quite' => 'Not quite',
  'harder' => 'Give me a harder one',
  _ => 'Reaction recorded',
};

class SessionExchangeView extends StatelessWidget {
  const SessionExchangeView({super.key, required this.group});
  final SessionExchangeGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in group.exchanges) ...[
            if (e.type == 'choice') ...[
              Text('YOUR CHOICE', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(
                '${e.chosen ?? 'Unavailable song'} over ${e.rejected ?? 'Unavailable song'}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
              ),
              if (e.feedback?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                for (final (index, line) in e.feedback!.split('\n').indexed)
                  if (line.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        line,
                        style: index == 0
                            ? theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 24,
                                height: 1.15,
                              )
                            : theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                      ),
                    ),
              ],
              if (e.evidenceSource == 'legacy_unavailable' ||
                  e.evidenceSource == 'invalid_snapshot')
                const Text('Historical evidence unavailable'),
            ],
            if (e.read != null) SessionReadView(read: e.read!),
            if (e.type == 'skip') const Text('Pairing skipped'),
            if (e.type == 'reaction') Text(reactionLabel(e.reaction)),
          ],
        ],
      ),
    );
  }
}

class SessionReadView extends StatelessWidget {
  const SessionReadView({super.key, required this.read});
  final SessionRead read;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // These are presentation labels for explicit server states, never a Dart
    // inference about support, confidence or eligibility.
    final label = switch ((read.direction, read.tier)) {
      ('revising', _) => 'Revising the read',
      ('contested', _) => 'A choice argues back',
      (_, 'read') => 'A tendency in these choices',
      (_, 'theory') => 'Working theory',
      _ => 'Still listening',
    };
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.ember, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          ),
          const SizedBox(height: 12),
          if (read.previousClaim?.isNotEmpty == true) ...[
            Text(
              'Earlier: ${read.previousClaim}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          Semantics(
            liveRegion: true,
            child: Text(
              read.thesis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 20,
                height: 1.3,
              ),
            ),
          ),
          if (read.changedBy?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              'Changed by ${read.changedBy}.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
            ),
          ],
          if (read.question?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              read.question!,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
