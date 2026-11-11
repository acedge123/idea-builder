import 'package:flutter/material.dart';
import '../../domain/entities/session_milestone.dart';

class SessionMilestoneView extends StatelessWidget {
  const SessionMilestoneView({
    super.key,
    required this.milestone,
    required this.onContinue,
    required this.onFinish,
  });
  final SessionMilestone milestone;
  final VoidCallback onContinue, onFinish;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            milestone.canFinish ? 'FOUR CHOICES IN' : 'HALFWAY THERE',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 12),
          Text(milestone.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),
          Text(milestone.summary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (milestone.canFinish)
                OutlinedButton(
                  onPressed: onFinish,
                  child: const Text('Read me now'),
                ),
              FilledButton(
                onPressed: onContinue,
                child: Text(milestone.continueLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
