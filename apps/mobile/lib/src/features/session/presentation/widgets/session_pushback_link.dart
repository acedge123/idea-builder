import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/session_cubit.dart';

/// Optional inline feedback, never a checkpoint or a score-changing vote.
class SessionPushbackLink extends StatefulWidget {
  const SessionPushbackLink({
    super.key,
    required this.state,
    required this.onSubmit,
  });
  final SessionState state;
  final ValueChanged<String> onSubmit;
  @override
  State<SessionPushbackLink> createState() => _SessionPushbackLinkState();
}

class _SessionPushbackLinkState extends State<SessionPushbackLink> {
  final _text = TextEditingController();
  bool _open = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final saved =
        state.pushbackReply ??
        state.exchanges
            .where(
              (e) =>
                  e.type == 'pushback' &&
                  (!state.isCheckpoint ||
                      e.answered == state.checkpointAnswered),
            )
            .lastOrNull
            ?.pushbackReply;
    if (saved != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(
            saved,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 20,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    if (!_open) {
      return TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.mutedForeground,
          textStyle: const TextStyle(
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
        onPressed: () => setState(() => _open = true),
        child: const Text("That's not me — push back"),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tell me where I'm wrong. Your picks still decide."),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            enabled: !state.pushbackSaving,
            decoration: const InputDecoration(labelText: 'Your reply'),
            onChanged: (_) => setState(() {}),
          ),
          OutlinedButton(
            onPressed: state.pushbackSaving || _text.text.trim().isEmpty
                ? null
                : () => widget.onSubmit(_text.text),
            child: Text(state.pushbackSaving ? 'Saving…' : 'Say it'),
          ),
          if (state.pushbackError != null)
            Semantics(
              liveRegion: true,
              child: Text(
                state.pushbackError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
