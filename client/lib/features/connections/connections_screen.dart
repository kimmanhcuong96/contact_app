import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/localized_error.dart';
import '../../core/providers.dart';

final connectionSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('contacts')),
        actions: [
          IconButton(
            onPressed: () => ref.read(connectionRepositoryProvider).sync(),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: ref.watch(connectionsProvider).when(
            data: (items) {
              final query =
                  ref.watch(connectionSearchProvider).trim().toLowerCase();
              final filtered = items
                  .where((item) => (item.profileJson ?? item.peerUserId)
                      .toLowerCase()
                      .contains(query))
                  .toList()
                ..sort((a, b) => (a.profileJson ?? a.peerUserId)
                    .compareTo(b.profileJson ?? b.peerUserId));
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: SearchBar(
                      hintText: l10n.t('searchContacts'),
                      leading: const Icon(Icons.search),
                      onChanged: (value) => ref
                          .read(connectionSearchProvider.notifier)
                          .state = value,
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text(l10n.t('noContacts')))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final decoded = item.profileJson == null
                                  ? null
                                  : jsonDecode(item.profileJson!)
                                      as Map<String, dynamic>;
                              final fields = decoded?['fields'] as Map?;
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                      child: Icon(Icons.person)),
                                  title: Text(fields?['fullName'] as String? ??
                                      l10n.t('privateContact')),
                                  subtitle: Text(item.status == 'pending'
                                      ? l10n.t('connectionRequest',
                                          {'id': item.peerUserId})
                                      : fields?['company'] as String? ??
                                          item.peerUserId),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) =>
                                        _action(context, ref, item, action),
                                    itemBuilder: (_) => [
                                      if (item.status == 'pending' &&
                                          item.direction == 'incoming')
                                        PopupMenuItem(
                                            value: 'accept',
                                            child: Text(l10n.t('accept'))),
                                      if (item.status == 'pending' &&
                                          item.direction == 'incoming')
                                        PopupMenuItem(
                                            value: 'reject',
                                            child: Text(l10n.t('reject'))),
                                      if (item.status == 'pending' &&
                                          item.direction == 'outgoing')
                                        PopupMenuItem(
                                            value: 'cancel',
                                            child:
                                                Text(l10n.t('cancelRequest'))),
                                      if (item.status == 'connected')
                                        PopupMenuItem(
                                            value: 'assign',
                                            child: Text(l10n
                                                .t('changeSharingProfile'))),
                                      if (item.status == 'connected')
                                        PopupMenuItem(
                                            value: 'disable',
                                            child: Text(l10n.t('disable'))),
                                      if (item.status == 'disabled')
                                        PopupMenuItem(
                                            value: 'enable',
                                            child: Text(l10n.t('enable'))),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text(l10n.t('delete'))),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                Center(child: Text(l10n.t('offlineCacheUnavailable'))),
          ),
    );
  }

  Future<SharingProfileRow?> _chooseSharing(
      BuildContext context, WidgetRef ref) async {
    final database = ref.read(databaseProvider);
    final rows = await database.select(database.sharingProfiles).get();
    if (!context.mounted || rows.isEmpty) return null;
    return showDialog<SharingProfileRow>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.t('shareWhichProfile')),
        children: rows
            .map((row) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, row),
                  child: Text(context.l10n.defaultProfileName(
                      jsonDecode(row.json)['name'] as String)),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref,
      ConnectedProfileRow item, String action) async {
    try {
      if (action == 'delete') {
        await ref.read(connectionRepositoryProvider).delete(item.connectionId);
        return;
      }
      SharingProfileRow? sharing;
      if (action == 'accept' || action == 'assign') {
        sharing = await _chooseSharing(context, ref);
        if (sharing == null) return;
      }
      await ref.read(connectionRepositoryProvider).act(
            item.connectionId,
            action,
            sharing: sharing,
            peerUserId: item.peerUserId,
          );
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context.l10n, error))));
}
