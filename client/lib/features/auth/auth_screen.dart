import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return Scaffold(
      body: Center(
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
                    const Icon(Icons.shield_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text('NexBook',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text('Your contacts. Your keys.',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    TextField(
                        controller: username,
                        autocorrect: false,
                        decoration: InputDecoration(
                            labelText: 'Username',
                            helperText: register
                                ? '3–32 characters: letters, numbers, . or _'
                                : 'Existing accounts may temporarily use email')),
                    if (register) ...[
                      const SizedBox(height: 12),
                      TextField(
                          controller: recoveryEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'Recovery email',
                              helperText:
                                  'Only used if you forget your password')),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Password (10+ characters)')),
                    if (register) ...[
                      const SizedBox(height: 12),
                      TextField(
                          controller: passwordConfirmation,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Re-enter password')),
                    ],
                    const SizedBox(height: 16),
                    if (session.hasError)
                      Text(session.error.toString(),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: session.isLoading ? null : _submit,
                        child: session.isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(register ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    if (!register)
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                              onPressed: _forgot,
                              child: const Text('Forgot password?')),
                        ],
                      ),
                    TextButton(
                      onPressed: () => setState(() => register = !register),
                      child: Text(register
                          ? 'Already have an account?'
                          : 'Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (register) {
      if (password.text != passwordConfirmation.text) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match.')));
        return;
      }
      await ref.read(sessionProvider.notifier).register(username.text,
          recoveryEmail.text, password.text, passwordConfirmation.text);
    } else {
      await ref
          .read(sessionProvider.notifier)
          .login(username.text, password.text);
    }
  }

  Future<void> _forgot() async {
    final email = await _ask('Recovery email');
    if (email == null || email.isEmpty) return;
    final response =
        await ref.read(authRepositoryProvider).forgotPassword(email);
    if (!mounted) return;
    final token = await _ask('Reset token',
        initialValue: response['developmentToken'] as String?);
    if (token == null || !mounted) return;
    final nextPassword = await _ask('New password', obscure: true);
    if (nextPassword != null) {
      await ref.read(authRepositoryProvider).resetPassword(token, nextPassword);
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
                    autofocus: true),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Continue'))
                ]));
    controller.dispose();
    return value;
  }
}
