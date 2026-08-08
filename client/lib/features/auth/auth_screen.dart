import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/localized_error.dart';
import '../../core/providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final username = TextEditingController();
  final recoveryEmail = TextEditingController();
  final password = TextEditingController();
  final passwordConfirmation = TextEditingController();
  bool register = false;

  @override
  void dispose() {
    username.dispose();
    recoveryEmail.dispose();
    password.dispose();
    passwordConfirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              SizedBox(
                height: 190,
                child: ColoredBox(
                  color: theme.brightness == Brightness.light
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerLow,
                ),
              ),
            ],
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          child: const Icon(Icons.shield_rounded, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'NexBook',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.t('tagline'),
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 24),
                        TextField(
                          controller: username,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: l10n.t('username'),
                            helperText: register
                                ? l10n.t('usernameHint')
                                : l10n.t('legacyLoginHint'),
                          ),
                        ),
                        if (register) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: recoveryEmail,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: l10n.t('recoveryEmail'),
                              helperText: l10n.t('recoveryEmailHint'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          decoration:
                              InputDecoration(labelText: l10n.t('passwordMin')),
                        ),
                        if (register) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordConfirmation,
                            obscureText: true,
                            decoration: InputDecoration(
                                labelText: l10n.t('reenterPassword')),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (session.hasError)
                          Text(
                            localizedError(l10n, session.error),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: session.isLoading ? null : _submit,
                            child: session.isLoading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(register
                                    ? l10n.t('createAccount')
                                    : l10n.t('signIn')),
                          ),
                        ),
                        if (!register)
                          TextButton(
                            onPressed: _forgot,
                            child: Text(l10n.t('forgotPassword')),
                          ),
                        TextButton(
                          onPressed: _switchAuthMode,
                          child: Text(register
                              ? l10n.t('alreadyHaveAccount')
                              : l10n.t('createAnAccount')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    _clearMessages();
    final l10n = context.l10n;
    final normalizedUsername = username.text.trim();
    if (normalizedUsername.isEmpty) {
      _show(l10n.t('error.usernameRequired'));
      return;
    }
    if (register) {
      if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._]{2,31}$')
          .hasMatch(normalizedUsername)) {
        _show(l10n.t('error.invalidUsername'));
        return;
      }
      if (!_isValidEmail(recoveryEmail.text)) {
        _show(l10n.t('error.invalidEmail'));
        return;
      }
      if (password.text.length < 10) {
        _show(l10n.t('error.weakPassword'));
        return;
      }
      if (password.text != passwordConfirmation.text) {
        _show(l10n.t('error.passwordMismatch'));
        return;
      }
      final created = await ref.read(sessionProvider.notifier).register(
          username.text,
          recoveryEmail.text,
          password.text,
          passwordConfirmation.text);
      if (created && mounted) {
        recoveryEmail.clear();
        password.clear();
        passwordConfirmation.clear();
        setState(() => register = false);
        _show(context.l10n.t('accountCreatedSignIn'));
      }
    } else {
      if (password.text.length < 10) {
        _show(l10n.t('error.weakPassword'));
        return;
      }
      await ref
          .read(sessionProvider.notifier)
          .login(username.text, password.text);
      if (ref.read(sessionProvider).hasError) password.clear();
    }
  }

  Future<void> _forgot() async {
    _clearMessages();
    final l10n = context.l10n;
    final email = await _ask(l10n.t('recoveryEmail'));
    if (email == null || email.isEmpty) return;
    if (!_isValidEmail(email)) {
      _show(l10n.t('error.invalidEmail'));
      return;
    }
    try {
      final response =
          await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      final token = await _ask(l10n.t('resetToken'),
          initialValue: response['developmentToken'] as String?);
      if (token == null || !mounted) return;
      final nextPassword = await _ask(l10n.t('newPassword'), obscure: true);
      if (nextPassword == null) return;
      if (nextPassword.length < 10) {
        _show(l10n.t('error.weakPassword'));
        return;
      }
      await ref.read(authRepositoryProvider).resetPassword(token, nextPassword);
    } catch (error) {
      if (mounted) _show(localizedError(context.l10n, error));
    }
  }

  Future<String?> _ask(String label,
      {String? initialValue, bool obscure = false}) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.t('continue')),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  void _switchAuthMode() {
    _clearMessages();
    setState(() => register = !register);
  }

  void _clearMessages() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ref.read(sessionProvider.notifier).clearMessage();
  }

  void _show(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
