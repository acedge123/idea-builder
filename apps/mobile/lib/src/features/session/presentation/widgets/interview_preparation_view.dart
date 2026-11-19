import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/critic_stage_policy.dart';

class InterviewPreparationView extends StatelessWidget {
  const InterviewPreparationView({super.key, this.line, this.onLineShown});
  final String? line;
  final ValueChanged<String>? onLineShown;
  @override
  Widget build(BuildContext context) {
    final displayed = line;
    if (displayed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onLineShown?.call(displayed);
      });
    }
    final theme = Theme.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: CriticStagePolicy.preparingTitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!reduced) ...[
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
                    CriticStagePolicy.preparingTitle,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: Text(
                line ?? '',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                  fontStyle: FontStyle.italic,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
