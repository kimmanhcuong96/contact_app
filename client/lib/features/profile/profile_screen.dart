import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers.dart';
import '../../models/master_profile.dart';
import '../../models/sharing_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final master = ref.watch(masterProfileProvider);
    final sharing = ref.watch(sharingProfilesProvider);
    return Scaffold(appBar: AppBar(title: const Text('My profile'), actions: [IconButton(tooltip: 'Sync now', onPressed: () => _sync(context, ref), icon: const Icon(Icons.sync))]), body: ListView(padding: const EdgeInsets.all(16), children: [
      master.when(data: (value) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(value.fields['fullName']?.isNotEmpty == true ? value.fields['fullName']! : 'Add your details'), subtitle: Text('${value.fields.length} fields saved locally'), trailing: const Icon(Icons.edit), onTap: () => _editMaster(context, ref, value))), loading: () => const LinearProgressIndicator(), error: (error, _) => Text('$error')),
      const SizedBox(height: 20), Row(children: [Text('Sharing profiles', style: Theme.of(context).textTheme.titleLarge), const Spacer(), IconButton(onPressed: () => _editSharing(context, ref), icon: const Icon(Icons.add))]),
      Text('Each profile is encrypted independently. Only selected fields are included.', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 8),
      sharing.when(data: (items) => Column(children: items.map((item) => Card(child: ListTile(title: Text(item.name), subtitle: Text('${item.visibleFields.length} visible fields · v${item.version}'), onTap: () => _editSharing(context, ref, current: item), trailing: PopupMenuButton<String>(onSelected: (action) async {
        if (action == 'duplicate') await ref.read(profileRepositoryProvider).saveSharing(item.copyWith(id: const Uuid().v4(), name: '${item.name} copy', version: 1));
        if (action == 'delete') await ref.read(profileRepositoryProvider).deleteSharing(item.id);
      }, itemBuilder: (_) => const [PopupMenuItem(value: 'duplicate', child: Text('Duplicate')), PopupMenuItem(value: 'delete', child: Text('Delete'))])))).toList()), loading: () => const LinearProgressIndicator(), error: (error, _) => Text('$error')),
    ]));
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async { try { await ref.read(profileRepositoryProvider).sync(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Encrypted profiles synced'))); } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync queued: $error'))); } }

  Future<void> _editMaster(BuildContext context, WidgetRef ref, MasterProfile current) async {
    final controllers = {for (final field in profileFieldLabels.keys) field: TextEditingController(text: current.fields[field])};
    final saved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Master profile'), content: SizedBox(width: 520, child: ListView(shrinkWrap: true, children: profileFieldLabels.entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controllers[entry.key], decoration: InputDecoration(labelText: entry.value), maxLines: entry.key == 'notes' ? 3 : 1))).toList())), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save locally'))]));
    if (saved == true) await ref.read(profileRepositoryProvider).saveMaster(MasterProfile(fields: {for (final entry in controllers.entries) if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text.trim()}));
    for (final controller in controllers.values) { controller.dispose(); }
  }

  Future<void> _editSharing(BuildContext context, WidgetRef ref, {SharingProfile? current}) async {
    final name = TextEditingController(text: current?.name);
    final selected = {...?current?.visibleFields};
    final result = await showDialog<SharingProfile>(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: Text(current == null ? 'New sharing profile' : 'Edit sharing profile'), content: SizedBox(width: 480, child: ListView(shrinkWrap: true, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), const SizedBox(height: 12), ...profileFieldLabels.entries.map((entry) => CheckboxListTile(value: selected.contains(entry.key), title: Text(entry.value), onChanged: (value) => setState(() => value == true ? selected.add(entry.key) : selected.remove(entry.key))) ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, SharingProfile(id: current?.id ?? const Uuid().v4(), name: name.text.trim(), visibleFields: selected, version: (current?.version ?? 0) + 1)), child: const Text('Save'))])));
    name.dispose();
    if (result != null && result.name.isNotEmpty) await ref.read(profileRepositoryProvider).saveSharing(result);
  }
}

