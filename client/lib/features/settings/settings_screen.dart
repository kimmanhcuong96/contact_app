import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/localized_error.dart';
import '../../core/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool notifications = true;
  bool autoSync = true;
  String language = 'en';
  String theme = 'system';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final database = ref.read(databaseProvider);
    final rows = await database.select(database.appSettings).get();
    final values = {for (final row in rows) row.key: row.value};
    if (mounted) {
      setState(() {
        notifications = values['notifications'] != 'false';
        autoSync = values['autoSync'] != 'false';
        language = switch (values['language']) {
          'vi' || 'Vietnamese' || 'Tiếng Việt' => 'vi',
          'zh' || 'Chinese' || '中文' => 'zh',
          'ja' || 'Japanese' || '日本語' => 'ja',
          'en' || 'English' => 'en',
          _ => detectDefaultLocale(
                  WidgetsBinding.instance.platformDispatcher.locales)
              .languageCode,
        };
        theme = values['theme'] ?? 'system';
      });
    }
  }

  Future<void> _store(String key, String value) async {
    final database = ref.read(databaseProvider);
    await database.into(database.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          l10n.t('account'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        ref.watch(accountProvider).when(
            data: (account) => Column(children: [
                  ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: Text(l10n.t('username')),
                      subtitle: Text(account['username'] as String)),
                  ListTile(
                      leading: const Icon(Icons.mark_email_read_outlined),
                      title: Text(l10n.t('recoveryEmail')),
                      subtitle: Text(account['recoveryEmail'] as String),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editRecoveryEmail(
                          account['recoveryEmail'] as String)),
                ]),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => ListTile(
                title: Text(l10n.t('couldNotLoadAccount')),
                trailing: IconButton(
                    onPressed: () => ref.invalidate(accountProvider),
                    icon: const Icon(Icons.refresh)))),
        const Divider(),
        Text(l10n.t('preferences'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                )),
        SwitchListTile(
            title: Text(l10n.t('notifications')),
            subtitle: Text(l10n.t('notificationsHint')),
            value: notifications,
            onChanged: (value) {
              setState(() => notifications = value);
              _store('notifications', '$value');
            }),
        SwitchListTile(
            title: Text(l10n.t('automaticSync')),
            subtitle: Text(l10n.t('automaticSyncHint')),
            value: autoSync,
            onChanged: (value) {
              setState(() => autoSync = value);
              _store('autoSync', '$value');
            }),
        ListTile(
            title: Text(l10n.t('theme')),
            subtitle: Text(l10n.themeName(theme)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _chooseTheme),
        ListTile(
            title: Text(l10n.t('language')),
            subtitle: Text(l10n.languageDisplayName(language)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _chooseLanguage),
        const Divider(),
        Text(l10n.t('yourData'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                )),
        ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l10n.t('exportBackup')),
            subtitle: Text(l10n.t('exportBackupHint')),
            onTap: _export),
        ListTile(
            leading: const Icon(Icons.download),
            title: Text(l10n.t('importBackup')),
            subtitle: Text(l10n.t('importBackupHint')),
            onTap: _import),
        ListTile(
            leading: const Icon(Icons.password),
            title: Text(l10n.t('changePassword')),
            onTap: _changePassword),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.t('signOut')),
            onTap: () => ref.read(sessionProvider.notifier).logout()),
        ListTile(
            iconColor: Theme.of(context).colorScheme.error,
            textColor: Theme.of(context).colorScheme.error,
            leading: const Icon(Icons.delete_forever),
            title: Text(l10n.t('deleteAccount')),
            onTap: _deleteAccount),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.t('privacyNotice'), textAlign: TextAlign.center)),
      ]),
    );
  }

  Future<void> _chooseTheme() async {
    final value = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
            title: Text(context.l10n.t('theme')),
            children: ['system', 'light', 'dark']
                .map((value) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, value),
                    child: Text(context.l10n.themeName(value))))
                .toList()));
    if (value != null) {
      setState(() => theme = value);
      await _store('theme', value);
      ref.invalidate(themeModeProvider);
    }
  }

  Future<void> _chooseLanguage() async {
    final value = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
            title: Text(context.l10n.t('language')),
            children: ['en', 'vi', 'zh', 'ja']
                .map((value) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, value),
                    child: Row(children: [
                      Text(context.l10n.languageFlag(value),
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(context.l10n.languageName(value)),
                    ])))
                .toList()));
    if (value != null) {
      setState(() => language = value);
      await _store('language', value);
      ref.invalidate(localeProvider);
    }
  }

  Future<void> _export() async {
    final subject = context.l10n.t('backupSubject');
    final value = await ref.read(profileRepositoryProvider).exportJson();
    await Share.share(value, subject: subject);
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.l10n.t('pasteBackupJson')),
                content: TextField(
                    controller: controller, minLines: 6, maxLines: 14),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.t('cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: Text(context.l10n.t('import')))
                ]));
    controller.dispose();
    if (raw == null) return;
    try {
      await ref.read(profileRepositoryProvider).importJson(raw);
    } catch (_) {
      if (mounted) _show(context.l10n.t('invalidBackup'));
    }
  }

  Future<void> _deleteAccount() async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.l10n.t('deleteAccountQuestion')),
                content: Text(context.l10n.t('deleteAccountWarning')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.t('cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.t('delete')))
                ]));
    if (accepted == true) {
      try {
        await ref.read(apiClientProvider).dio.delete<void>('/me');
        await ref.read(databaseProvider).clearAll();
        await ref.read(secureStorageProvider).deleteAll();
        ref.invalidate(sessionProvider);
      } catch (error) {
        if (mounted) _show(localizedError(context.l10n, error));
      }
    }
  }

  Future<void> _changePassword() async {
    final l10n = context.l10n;
    final current = TextEditingController();
    final next = TextEditingController();
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.l10n.t('changePassword')),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: current,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: context.l10n.t('currentPassword'))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: next,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: context.l10n.t('newPasswordMin')))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.t('cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.t('change')))
                ]));
    if (accepted == true) {
      if (next.text.length < 10) {
        _show(l10n.t('error.weakPassword'));
      } else {
        try {
          await ref
              .read(authRepositoryProvider)
              .changePassword(current.text, next.text);
          await ref.read(sessionProvider.notifier).logout();
        } catch (error) {
          if (mounted) _show(localizedError(context.l10n, error));
        }
      }
    }
    current.dispose();
    next.dispose();
  }

  Future<void> _editRecoveryEmail(String currentEmail) async {
    final l10n = context.l10n;
    final email = TextEditingController(text: currentEmail);
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.l10n.t('changeRecoveryEmail')),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          labelText: context.l10n.t('recoveryEmail'))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: password,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: context.l10n.t('currentPassword'))),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.t('cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.t('save'))),
                ]));
    if (accepted == true) {
      if (!_isValidEmail(email.text)) {
        _show(l10n.t('error.invalidEmail'));
      } else if (password.text.isEmpty) {
        _show(l10n.t('error.invalidPassword'));
      } else {
        try {
          await ref
              .read(authRepositoryProvider)
              .updateRecoveryEmail(email.text, password.text);
          ref.invalidate(accountProvider);
          if (mounted) _show(context.l10n.t('recoveryEmailUpdated'));
        } catch (error) {
          if (mounted) _show(localizedError(context.l10n, error));
        }
      }
    }
    email.dispose();
    password.dispose();
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  void _show(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
