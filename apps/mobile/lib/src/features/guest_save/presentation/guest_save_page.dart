import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../domain/guest_save_repository.dart';
import 'guest_save_cubit.dart';

class GuestSavePage extends StatelessWidget {
  const GuestSavePage({
    required this.repository,
    required this.sessionId,
    required this.version,
    super.key,
  });
  final GuestSaveRepository repository;
  final String sessionId;
  final int version;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GuestSaveCubit(repository)..load(sessionId, version),
    child: const _GuestSaveForm(),
  );
}

class _GuestSaveForm extends StatefulWidget {
  const _GuestSaveForm();
  @override
  State<_GuestSaveForm> createState() => _GuestSaveFormState();
}

class _GuestSaveFormState extends State<_GuestSaveForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signInWithoutSaving() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Sign in without saving?'),
        content: const Text(
          'Signing in replaces this guest session. This reading will not move to your existing account, and you may lose access to it. Return to your reading to keep it with a new account instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep my guest session'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Sign in without saving'),
          ),
        ],
      ),
    );
    if (mounted && proceed == true) context.push('/auth?mode=sign-in-only');
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<GuestSaveCubit, GuestSaveState>(
    listener: (_, state) {
      if (state.step == GuestSaveStep.saved) _password.clear();
    },
    builder: (context, state) {
      final cubit = context.read<GuestSaveCubit>();
      final reading = state.reading;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Keep your reading'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to my reading',
            onPressed: state.busy
                ? null
                : () => context.go(reading?.readingPath ?? '/'),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Keep this reading.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              if (state.step == GuestSaveStep.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.step == GuestSaveStep.unavailable)
                const Text(
                  'The original guest session is unavailable on this device. Return to the device where you made this reading. Signing into another account cannot claim it.',
                )
              else if (state.step == GuestSaveStep.saved) ...[
                Semantics(
                  liveRegion: true,
                  child: Text('Saved to your account.'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go(reading!.readingPath),
                  child: const Text('Back to my reading'),
                ),
              ] else ...[
                const Text(
                  'Your reading is private and stored. Keep access across devices by turning this guest session into an account.',
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.step == GuestSaveStep.email)
                        TextFormField(
                          controller: _email,
                          enabled: !state.busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) =>
                              value != null &&
                                  RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(value.trim())
                              ? null
                              : 'Enter a valid email address.',
                        ),
                      if (state.step == GuestSaveStep.confirmation) ...[
                        const Text(
                          'Check your email and open the confirmation link on this device, then continue. Email submission alone has not saved the reading to an account.',
                        ),
                        TextButton(
                          onPressed: state.busy ? null : cubit.changeEmail,
                          child: const Text('Resend or use another email'),
                        ),
                      ],
                      if (state.step == GuestSaveStep.password)
                        TextFormField(
                          controller: _password,
                          enabled: !state.busy,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'Set your password',
                          ),
                          validator: (value) => (value?.length ?? 0) >= 8
                              ? null
                              : 'Use at least 8 characters.',
                        ),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: state.busy
                            ? null
                            : () {
                                if (!_formKey.currentState!.validate()) return;
                                switch (state.step) {
                                  case GuestSaveStep.email:
                                    cubit.requestEmail(_email.text);
                                  case GuestSaveStep.confirmation:
                                    cubit.checkConfirmation();
                                  case GuestSaveStep.password:
                                    cubit.finish(_password.text);
                                  default:
                                    break;
                                }
                              },
                        child: Text(
                          state.busy
                              ? 'Checking…'
                              : switch (state.step) {
                                  GuestSaveStep.email =>
                                    'Send confirmation email',
                                  GuestSaveStep.confirmation =>
                                    "I've confirmed my email",
                                  _ => 'Save to my account',
                                },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Already have an account?'),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        "Saving a guest reading to an existing account isn't available yet. Don't sign out of this guest session to save it; return to your reading or use a new email.",
                      ),
                    ),
                    TextButton(
                      onPressed: state.busy ? null : _signInWithoutSaving,
                      child: const Text('Sign in without saving this reading'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => context.go(reading!.readingPath),
                  child: const Text('Not now — back to my reading'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
