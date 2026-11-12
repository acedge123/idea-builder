import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/session_experience.dart';
import '../critic_display.dart';

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
    this.showReactionControls = true,
    this.showHistory = true,
    this.showCurrentRead = true,
  });
  final List<SessionExchange> exchanges;
  final SessionRead? read;
  final bool busy;
  final ValueChanged<SessionReaction> onReaction;
  final String? reactionMessage;
  final SessionReaction? pendingReaction;
  final Key? activeExchangeKey;
  final bool showReactionControls;
  final bool showHistory;
  final bool showCurrentRead;

  @override
  Widget build(BuildContext context) {
    final groups = groupSessionExchanges(exchanges);
    final latest = groups.lastOrNull;
    final currentRead =
        read ?? exchanges.where((e) => e.read != null).lastOrNull?.read;
    final latestFeedback = latest?.exchanges
        .where((e) => e.feedback?.isNotEmpty == true)
        .lastOrNull
        ?.feedback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHistory)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Interview history'),
              onPressed: groups.isEmpty && currentRead == null
                  ? null
                  : () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (context) => FractionallySizedBox(
                        heightFactor: 0.85,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Interview history'),
                                ),
                                IconButton(
                                  tooltip: 'Close history',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            for (final group in groups)
                              SessionExchangeView(group: group),
                            if (currentRead != null &&
                                !exchanges.any((e) => e.read == currentRead))
                              SessionReadView(read: currentRead),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        if (showCurrentRead)
          KeyedSubtree(
            key: activeExchangeKey,
            child: reactionMessage?.isNotEmpty == true
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        reactionMessage!,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  )
                : currentRead != null
                ? SessionReadView(read: currentRead, compact: true)
                : latestFeedback != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      latestFeedback,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        if (showCurrentRead &&
            latest?.hasReaction == true &&
            reactionMessage?.isNotEmpty != true)
          Text(
            reactionLabel(
              latest!.exchanges.lastWhere((e) => e.type == 'reaction').reaction,
            ),
          ),
        if (showReactionControls)
          SessionReactionControls(
            exchanges: exchanges,
            read: read,
            busy: busy,
            pendingReaction: pendingReaction,
            onReaction: onReaction,
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Secondary to the current song choice; opening this never submits feedback.
class SessionReactionControls extends StatelessWidget {
  const SessionReactionControls({
    super.key,
    required this.exchanges,
    required this.read,
    required this.busy,
    required this.onReaction,
    this.pendingReaction,
  });
  final List<SessionExchange> exchanges;
  final SessionRead? read;
  final bool busy;
  final SessionReaction? pendingReaction;
  final ValueChanged<SessionReaction> onReaction;

  @override
  Widget build(BuildContext context) {
    final latest = groupSessionExchanges(exchanges).lastOrNull;
    if (read == null || latest?.hasReaction == true) {
      return const SizedBox.shrink();
    }
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppTheme.mutedForeground,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
    return ExpansionTile(
      key: ValueKey(('react', latest?.exchanges.first.at, pendingReaction)),
      tilePadding: EdgeInsets.zero,
      dense: true,
      minTileHeight: 48,
      shape: const Border(),
      collapsedShape: const Border(),
      textColor: AppTheme.mutedForeground,
      collapsedTextColor: AppTheme.mutedForeground,
      iconColor: AppTheme.mutedForeground,
      collapsedIconColor: AppTheme.mutedForeground,
      initiallyExpanded: pendingReaction != null,
      title: Text('React to the Critic', style: labelStyle),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final reaction in SessionReaction.values)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.mutedForeground,
                    textStyle: labelStyle,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

String reactionLabel(String? kind) => switch (kind) {
  'thats_me' => "That's me",
  'not_quite' => 'Not quite',
  'harder' => 'Prove it',
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
  const SessionReadView({super.key, required this.read, this.compact = false});
  final SessionRead read;
  final bool compact;

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
          if (!compact)
            Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
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
              compact ? compactCriticRead(read.thesis) : read.thesis,
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
          if (!compact &&
              read.auditText?.isNotEmpty == true &&
              read.auditText != read.thesis) ...[
            const SizedBox(height: 12),
            Text(
              'The choices behind the read',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(read.auditText!),
          ],
        ],
      ),
    );
  }
}
