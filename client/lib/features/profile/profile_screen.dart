import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/localized_error.dart';
import '../../core/providers.dart';
import '../../models/master_profile.dart';
import '../../models/sharing_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final master = ref.watch(masterProfileProvider);
    final sharing = ref.watch(sharingProfilesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('myProfile')), actions: [
        IconButton(
            tooltip: l10n.t('syncNow'),
            onPressed: () => _sync(context, ref),
            icon: const Icon(Icons.sync))
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        master.when(
            data: (value) => Card(
                child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.person),
                    ),
                    title: Text(value.fields['fullName']?.isNotEmpty == true
                        ? value.fields['fullName']!
                        : l10n.t('addYourDetails')),
                    subtitle: Text(
                        l10n.t('fieldsSaved', {'count': value.fields.length})),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _editMaster(context, ref, value))),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(localizedError(l10n, error))),
        const SizedBox(height: 20),
        Row(children: [
          Text(l10n.t('sharingProfiles'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  )),
          const Spacer(),
          IconButton(
              onPressed: () => _editSharing(context, ref),
              icon: const Icon(Icons.add))
        ]),
        Text(l10n.t('sharingProfilesHint'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        sharing.when(
            data: (items) => Column(
                children: items
                    .map((item) => Card(
                        child: ListTile(
                            title: Text(l10n.defaultProfileName(item.name)),
                            subtitle: Text(l10n.t('visibleFieldsVersion', {
                              'count': item.visibleFields.length,
                              'version': item.version,
                            })),
                            onTap: () =>
                                _editSharing(context, ref, current: item),
                            trailing: PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'duplicate') {
                                    await ref
                                        .read(profileRepositoryProvider)
                                        .saveSharing(item.copyWith(
                                            id: const Uuid().v4(),
                                            name: l10n.t('copySuffix', {
                                              'name': l10n
                                                  .defaultProfileName(item.name)
                                            }),
                                            version: 1));
                                  }
                                  if (action == 'delete') {
                                    await ref
                                        .read(profileRepositoryProvider)
                                        .deleteSharing(item.id);
                                  }
                                },
                                itemBuilder: (_) => [
                                      PopupMenuItem(
                                          value: 'duplicate',
                                          child: Text(l10n.t('duplicate'))),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text(l10n.t('delete')))
                                    ]))))
                    .toList()),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(localizedError(l10n, error))),
      ]),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(syncServiceProvider).syncNow();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.t('profilesSynced'))));
      }
    } catch (_) {
      // SyncService publishes the localized failure through the app shell.
    }
  }

  Future<void> _editMaster(
      BuildContext context, WidgetRef ref, MasterProfile current) async {
    final controllers = {
      for (final field in profileFieldKeys)
        field: TextEditingController(text: current.fields[field])
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('masterProfile')),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: profileFieldKeys
                .map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controllers[field],
                        decoration: InputDecoration(
                            labelText: context.l10n.profileField(field)),
                        maxLines: field == 'notes' ? 3 : 1,
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.t('saveLocally')))
        ],
      ),
    );
    if (saved == true) {
      await ref
          .read(profileRepositoryProvider)
          .saveMaster(MasterProfile(fields: {
            for (final entry in controllers.entries)
              if (entry.value.text.trim().isNotEmpty)
                entry.key: entry.value.text.trim()
          }));
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Future<void> _editSharing(BuildContext context, WidgetRef ref,
      {SharingProfile? current}) async {
    final name = TextEditingController(
        text: current == null
            ? null
            : context.l10n.defaultProfileName(current.name));
    final selected = {...?current?.visibleFields};
    final result = await showDialog<SharingProfile>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n
              .t(current == null ? 'newSharingProfile' : 'editSharingProfile')),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                    controller: name,
                    decoration:
                        InputDecoration(labelText: context.l10n.t('name'))),
                const SizedBox(height: 12),
                ...profileFieldKeys.map(
                  (field) => CheckboxListTile(
                    value: selected.contains(field),
                    title: Text(context.l10n.profileField(field)),
                    onChanged: (value) => setState(() => value == true
                        ? selected.add(field)
                        : selected.remove(field)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.t('cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                SharingProfile(
                  id: current?.id ?? const Uuid().v4(),
                  name: name.text.trim(),
                  visibleFields: selected,
                  version: (current?.version ?? 0) + 1,
                ),
              ),
              child: Text(context.l10n.t('save')),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (result != null && result.name.isNotEmpty) {
      await ref.read(profileRepositoryProvider).saveSharing(result);
    }
  }
}
