import 'package:flutter/material.dart';

import '../../domain/entities/session_reveal.dart';
import '../cubit/session_cubit.dart';

class SessionResultView extends StatelessWidget {
  const SessionResultView({
    super.key,
    required this.state,
    required this.shareUrl,
    required this.onPublish,
    required this.onRevoke,
    required this.onVerify,
    required this.onCopy,
    required this.onSignIn,
    this.onPushBack,
  });
  final SessionState state;
  final String? shareUrl;
  final VoidCallback onPublish, onRevoke, onVerify, onCopy, onSignIn;
  final VoidCallback? onPushBack;

  @override
  Widget build(BuildContext context) {
    final reveal = state.reveal!;
    final result = reveal.result!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE READ · VERSION ${result.version}',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 12),
        Text(
          result.headline,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 26,
            height: 1.35,
          ),
        ),
        if (result.reveal != null) ...[
          if (result.reveal!.twist?.isNotEmpty == true) ...[
            const SizedBox(height: 24),
            Text('The twist', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.reveal!.twist!, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: 24),
          Text('The challenge', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(result.reveal!.challenge, style: theme.textTheme.bodyLarge),
        ],
        if (result.reveal == null && result.supportingChoices.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('The choices behind it', style: theme.textTheme.titleMedium),
          for (final support in result.supportingChoices.take(2))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(support.tradeoff, style: theme.textTheme.bodyLarge),
                  for (final example in support.examples.toSet().take(2))
                    Text(example),
                ],
              ),
            ),
        ],
        if (result.reveal == null &&
            !result.supportingChoices.any(
              (support) => support.examples.isNotEmpty,
            )) ...[
          const SizedBox(height: 16),
          const Text(
            'No supporting song examples were included with this saved reading.',
          ),
        ],
        if (result.reveal == null && result.tensionClaim != null) ...[
          const SizedBox(height: 24),
          Text('Still unresolved', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(result.tensionClaim!),
          if (result.tensionNotes?.isNotEmpty == true)
            Text(result.tensionNotes!),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (onPushBack != null)
              FilledButton.icon(
                onPressed: onPushBack,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Argue with me'),
              ),
            if (shareUrl == null && state.publication?.isPublic != true)
              OutlinedButton.icon(
                onPressed: state.sharing ? null : onPublish,
                icon: const Icon(Icons.ios_share),
                label: const Text('Share this read'),
              ),
            if (shareUrl != null)
              IconButton.filledTonal(
                onPressed: state.sharing ? null : onCopy,
                tooltip: 'Copy share link',
                icon: const Icon(Icons.copy),
              ),
            if (state.publication?.isPublic == true && !state.shareVerified)
              TextButton.icon(
                onPressed: state.sharing ? null : onVerify,
                icon: const Icon(Icons.refresh),
                label: const Text('Verify link'),
              ),
            // Remains available after an uncertain publish/revoke response.
            if (state.shareMayBePublic)
              TextButton.icon(
                onPressed: state.sharing ? null : onRevoke,
                icon: const Icon(Icons.link_off),
                label: const Text('Stop sharing'),
              ),
          ],
        ),
        if (state.sharing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        if (shareUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(shareUrl!),
          ),
        if (state.shareError != null) ...[
          const SizedBox(height: 12),
          Text(state.shareError!, semanticsLabel: state.shareError!),
          if (state.requiresReauthentication)
            TextButton(onPressed: onSignIn, child: const Text('Sign in again')),
        ],
        const SizedBox(height: 16),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(result.reveal == null ? 'Full reading' : 'The receipts'),
          children: [_FullReading(reveal: reveal)],
        ),
      ],
    );
  }
}

class _FullReading extends StatelessWidget {
  const _FullReading({required this.reveal});
  final SessionReveal reveal;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reveal.archetypeName != null)
          Text(
            reveal.archetypeName!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (reveal.result != null) ...[
          if (reveal.result!.reveal != null)
            Text(
              '${reveal.result!.reveal!.answered} answered pairings. Skips are not evidence; each trait counts only its declared tests.',
            ),
          Text(reveal.result!.headline),
          for (final support in reveal.result!.supportingChoices) ...[
            Text(support.tradeoff),
            Text(
              '${support.supporting} supporting choices · ${support.tested} tested',
            ),
            for (final example in support.examples) Text(example),
          ],
        ],
        Text(reveal.interpretation),
        if (reveal.result?.auditText?.isNotEmpty == true &&
            reveal.result!.auditText != reveal.result!.headline &&
            reveal.result!.auditText != reveal.interpretation) ...[
          const SizedBox(height: 12),
          Text(
            'The choices behind the read',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(reveal.result!.auditText!),
        ],
        for (final claim in reveal.allowedClaims) ...[
          const SizedBox(height: 12),
          Text(claim.tradeoff),
          Text(
            '${claim.supportingChoices}/${claim.testedTotal} supporting choices',
          ),
          for (final example in claim.examples)
            Text('${example.chosen} over ${example.rejected}'),
        ],
        for (final counter in reveal.counterarguments) ...[
          const SizedBox(height: 12),
          Text(counter.claim),
          Text(counter.notes),
        ],
      ],
    ),
  );
}
