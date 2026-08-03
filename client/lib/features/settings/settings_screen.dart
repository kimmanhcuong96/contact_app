import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget { const SettingsScreen({super.key}); @override ConsumerState<SettingsScreen> createState() => _SettingsScreenState(); }
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool notifications = true;
  bool autoSync = true;
  String language = 'English';
  String theme = 'system';

  @override void initState() { super.initState(); Future.microtask(_load); }
  Future<void> _load() async {
    final rows = await ref.read(databaseProvider).select(ref.read(databaseProvider).appSettings).get();
    final values = {for (final row in rows) row.key: row.value};
    if (mounted) setState(() { notifications = values['notifications'] != 'false'; autoSync = values['autoSync'] != 'false'; language = values['language'] ?? 'English'; theme = values['theme'] ?? 'system'; });
  }

  Future<void> _store(String key, String value) async { await ref.read(databaseProvider).into(ref.read(databaseProvider).appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value)); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: ListView(padding: const EdgeInsets.all(16), children: [
    Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
    SwitchListTile(title: const Text('Notifications'), subtitle: const Text('Connection and profile update alerts'), value: notifications, onChanged: (value) { setState(() => notifications = value); _store('notifications', '$value'); }),
    SwitchListTile(title: const Text('Automatic sync'), subtitle: const Text('Sync encrypted changes when online'), value: autoSync, onChanged: (value) { setState(() => autoSync = value); _store('autoSync', '$value'); }),
    ListTile(title: const Text('Theme'), subtitle: Text(theme), trailing: const Icon(Icons.chevron_right), onTap: () async { final value = await showDialog<String>(context: context, builder: (context) => SimpleDialog(title: const Text('Theme'), children: ['system', 'light', 'dark'].map((value) => SimpleDialogOption(onPressed: () => Navigator.pop(context, value), child: Text(value))).toList())); if (value != null) { setState(() => theme = value); await _store('theme', value); ref.invalidate(themeModeProvider); } }),
    ListTile(title: const Text('Language'), subtitle: Text(language), trailing: const Icon(Icons.chevron_right), onTap: () async { final value = await showDialog<String>(context: context, builder: (context) => SimpleDialog(title: const Text('Language'), children: ['English', 'Tiếng Việt'].map((value) => SimpleDialogOption(onPressed: () => Navigator.pop(context, value), child: Text(value))).toList())); if (value != null) { setState(() => language = value); _store('language', value); } }),
    const Divider(), Text('Your data', style: Theme.of(context).textTheme.titleMedium),
    ListTile(leading: const Icon(Icons.upload_file), title: const Text('Export backup'), subtitle: const Text('Master profile and settings as JSON'), onTap: _export),
    ListTile(leading: const Icon(Icons.download), title: const Text('Import backup'), subtitle: const Text('Restore from NexBook JSON'), onTap: _import),
    ListTile(leading: const Icon(Icons.password), title: const Text('Change password'), onTap: _changePassword),
    const Divider(),
    ListTile(leading: const Icon(Icons.logout), title: const Text('Sign out'), onTap: () => ref.read(sessionProvider.notifier).logout()),
    ListTile(iconColor: Theme.of(context).colorScheme.error, textColor: Theme.of(context).colorScheme.error, leading: const Icon(Icons.delete_forever), title: const Text('Delete account'), onTap: _deleteAccount),
    const Padding(padding: EdgeInsets.all(16), child: Text('Profile content is encrypted on this device before upload. NexBook servers cannot read it.', textAlign: TextAlign.center)),
  ]));

  Future<void> _export() async { final value = await ref.read(profileRepositoryProvider).exportJson(); await Share.share(value, subject: 'NexBook encrypted-device backup'); }
  Future<void> _import() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Paste backup JSON'), content: TextField(controller: controller, minLines: 6, maxLines: 14), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Import'))]));
    controller.dispose();
    if (raw == null) return;
    try { await ref.read(profileRepositoryProvider).importJson(raw); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid backup: $error'))); }
  }
  Future<void> _deleteAccount() async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete account permanently?'), content: const Text('Your account, connections, encrypted blobs, device keys, and local data will be removed. This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (accepted == true) { await ref.read(apiClientProvider).dio.delete<void>('/me'); await ref.read(databaseProvider).clearAll(); await ref.read(secureStorageProvider).deleteAll(); ref.invalidate(sessionProvider); }
  }
  Future<void> _changePassword() async {
    final current = TextEditingController(); final next = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Change password'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')), const SizedBox(height: 12), TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password (10+ characters)'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Change'))]));
    if (accepted == true) { await ref.read(authRepositoryProvider).changePassword(current.text, next.text); await ref.read(sessionProvider.notifier).logout(); }
    current.dispose(); next.dispose();
  }
}
