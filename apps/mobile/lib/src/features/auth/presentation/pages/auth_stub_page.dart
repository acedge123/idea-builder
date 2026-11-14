import '../../domain/auth_failure.dart';
import '../../domain/password_recovery.dart';
import '../../data/open_password_recovery.dart' as recovery;
import 'package:flutter/material.dart';
import '../../../readings/presentation/app_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../cubit/auth_cubit.dart';

enum _AuthFormMode { signIn, signUp }

class AuthStubPage extends StatefulWidget {
  const AuthStubPage({
    super.key,
    this.signInOnly = false,
    this.openPasswordRecovery = recovery.openPasswordRecovery,
  });
  final Future<bool> Function(Uri) openPasswordRecovery;
  final bool signInOnly;

  @override
  State<AuthStubPage> createState() => _AuthStubPageState();
}

class _AuthStubPageState extends State<AuthStubPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthFormMode _mode = _AuthFormMode.signIn;
  bool _openingRecovery = false;
  bool _upgradingGuest = false;
  String? _recoveryError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: const AppNavigation(index: 2),
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listenWhen: (previous, current) =>
              previous.submissionStatus != current.submissionStatus,
          listener: (context, state) {
            if (state.submissionStatus ==
                    AuthSubmissionStatus.emailConfirmationRequired &&
                state.infoMessage != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.infoMessage!)));
            }

            if (state.submissionStatus == AuthSubmissionStatus.success &&
                state.status == AuthStatus.authenticated &&
                state.user?.isAnonymous == false) {
              context.go(
                _mode == _AuthFormMode.signUp
                    ? (_upgradingGuest ? '/readings' : '/onboarding')
                    : '/',
              );
            }
          },
          builder: (context, state) {
            final hasAccount =
                state.status == AuthStatus.authenticated &&
                state.user?.isAnonymous == false;
            final isSubmitting =
                state.submissionStatus == AuthSubmissionStatus.submitting;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: <Widget>[
                Image.asset(
                  'assets/branding/music-dna-logo.png',
                  height: 56,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 16),
                Text(
                  hasAccount
                      ? 'Your account'
                      : _mode == _AuthFormMode.signIn
                      ? 'Sign in to MusicDNA'
                      : 'Begin your MusicDNA.',
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  hasAccount
                      ? 'Manage your account and return to your saved readings.'
                      : _mode == _AuthFormMode.signIn
                      ? 'Pick up your saved readings.'
                      : 'Save your readings and pick up where you left off.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                if (!hasAccount && !widget.signInOnly)
                  _ModeToggle(
                    mode: _mode,
                    enabled: !isSubmitting,
                    onChanged: _changeMode,
                  ),
                const SizedBox(height: 20),
                if (!hasAccount)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Account', style: theme.textTheme.labelSmall),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              enabled: !isSubmitting,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return 'Email is required.';
                                }
                                if (!email.contains('@')) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: ValueKey(_mode),
                              controller: _passwordController,
                              enabled: !isSubmitting,
                              obscureText: true,
                              autofillHints: _mode == _AuthFormMode.signIn
                                  ? const <String>[AutofillHints.password]
                                  : const <String>[AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              validator: (value) {
                                final password = value ?? '';
                                if (password.isEmpty) {
                                  return 'Password is required.';
                                }
                                if (_mode == _AuthFormMode.signUp &&
                                    password.length < 8) {
                                  return 'Use at least 8 characters.';
                                }
                                return null;
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isSubmitting || _openingRecovery
                                    ? null
                                    : _openRecovery,
                                child: Text(
                                  _openingRecovery
                                      ? 'Opening recovery…'
                                      : 'Forgot password?',
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: isSubmitting ? null : _submit,
                                child: Text(
                                  isSubmitting
                                      ? 'Working...'
                                      : _mode == _AuthFormMode.signIn
                                      ? 'Sign in'
                                      : 'Create account',
                                ),
                              ),
                            ),
                            if (state.errorMessage != null) ...<Widget>[
                              const SizedBox(height: 14),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  state.errorMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                              if (_mode == _AuthFormMode.signUp &&
                                  state.failureKind ==
                                      AuthFailureKind.emailInUse)
                                TextButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => _changeMode(_AuthFormMode.signIn),
                                  child: const Text('Sign in instead'),
                                ),
                            ],
                            if (_recoveryError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _recoveryError!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                            if (state.infoMessage != null) ...<Widget>[
                              const SizedBox(height: 14),
                              Text(
                                state.infoMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.mutedForeground,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (state.status == AuthStatus.authenticated &&
                    state.user != null) ...<Widget>[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Current session',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.user?.email ?? state.user!.id,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              FilledButton.tonal(
                                onPressed: () => context.go('/onboarding'),
                                child: const Text('Go to onboarding'),
                              ),
                              OutlinedButton(
                                onPressed: () => context.go('/ai-permission'),
                                child: const Text('AI permission'),
                              ),
                              OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => context.read<AuthCubit>().signOut(),
                                child: const Text('Sign out'),
                              ),
                              OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => _confirmDeleteAccount(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                ),
                                child: const Text('Delete account'),
                              ),
                            ],
                          ),
                          if (hasAccount && state.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                state.errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _changeMode(_AuthFormMode mode) {
    if (_mode == mode ||
        context.read<AuthCubit>().state.submissionStatus ==
            AuthSubmissionStatus.submitting) {
      return;
    }
    _passwordController.clear();
    context.read<AuthCubit>().clearFeedback();
    setState(() {
      _mode = mode;
      _recoveryError = null;
    });
  }

  Future<void> _openRecovery() async {
    if (_openingRecovery) return;
    setState(() {
      _openingRecovery = true;
      _recoveryError = null;
    });
    var opened = false;
    try {
      opened = await widget.openPasswordRecovery(PasswordRecovery.pageUri);
    } catch (_) {
      /* Platform errors also use controlled copy. */
    }
    if (!mounted) return;
    setState(() {
      _openingRecovery = false;
      if (!opened) {
        _recoveryError =
            'Couldn’t open password recovery. Visit musicdna.fm/auth?mode=forgot in your browser.';
      }
    });
  }

  void _submit() {
    if (context.read<AuthCubit>().state.submissionStatus ==
        AuthSubmissionStatus.submitting) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authCubit = context.read<AuthCubit>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_mode == _AuthFormMode.signIn) {
      authCubit.signIn(email: email, password: password);
      return;
    }

    _upgradingGuest = authCubit.state.user?.isAnonymous == true;
    authCubit.signUp(email: email, password: password);
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This deletes your MusicDNA account and associated session data. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final auth = context.read<AuthCubit>();
    await auth.deleteAccount();
    if (context.mounted &&
        auth.state.status == AuthStatus.unauthenticated &&
        auth.state.submissionStatus == AuthSubmissionStatus.success) {
      context.go('/');
    }
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onChanged,
    required this.enabled,
  });

  final _AuthFormMode mode;
  final bool enabled;
  final ValueChanged<_AuthFormMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeButton(
              label: 'Sign in',
              selected: mode == _AuthFormMode.signIn,
              onTap: enabled ? () => onChanged(_AuthFormMode.signIn) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              label: 'Sign up',
              selected: mode == _AuthFormMode.signUp,
              onTap: enabled ? () => onChanged(_AuthFormMode.signUp) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.ember : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppTheme.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
