import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/localized_error.dart';
import '../../core/providers.dart';

class ConnectionRequestsScreen extends ConsumerWidget {
  const ConnectionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('connections')),
        actions: [
          IconButton(
            tooltip: l10n.t('syncNow'),
            onPressed: () => _sync(context, ref),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: ref.watch(connectionsProvider).when(
            data: (items) {
              final incoming = items
                  .where((item) =>
                      item.status == 'pending' && item.direction == 'incoming')
                  .toList();
              final outgoing = items
                  .where((item) =>
                      item.status == 'pending' && item.direction == 'outgoing')
                  .toList();
              if (incoming.isEmpty && outgoing.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => _sync(context, ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * .22),
                      Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 52,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Center(child: Text(l10n.t('noConnectionRequests'))),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => _sync(context, ref),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (incoming.isNotEmpty) ...[
                      _SectionTitle(
                        title: l10n.t('incomingRequests'),
                        count: incoming.length,
                      ),
                      const SizedBox(height: 8),
                      ...incoming.map((item) => _RequestTile(
                            item: item,
                            incoming: true,
                            onAccept: () => _act(context, ref, item, 'accept'),
                            onReject: () => _act(context, ref, item, 'reject'),
                          )),
                    ],
                    if (incoming.isNotEmpty && outgoing.isNotEmpty)
                      const SizedBox(height: 20),
                    if (outgoing.isNotEmpty) ...[
                      _SectionTitle(
                        title: l10n.t('sentRequests'),
                        count: outgoing.length,
                      ),
                      const SizedBox(height: 8),
                      ...outgoing.map((item) => _RequestTile(
                            item: item,
                            incoming: false,
                            onCancel: () => _act(context, ref, item, 'cancel'),
                          )),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(localizedError(l10n, error)),
            ),
          ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(connectionRepositoryProvider).sync();
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _act(BuildContext context, WidgetRef ref,
      ConnectedProfileRow item, String action) async {
    try {
      SharingProfileRow? sharing;
      if (action == 'accept') {
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

  void _showError(BuildContext context, Object error) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedError(context.l10n, error))),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Badge.count(count: count),
        ],
      );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.item,
    required this.incoming,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  final ConnectedProfileRow item;
  final bool incoming;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.tertiaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onTertiaryContainer,
                  child: Icon(incoming
                      ? Icons.person_add_outlined
                      : Icons.outgoing_mail),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incoming
                            ? l10n.t('incomingRequest')
                            : l10n.t('sentRequest'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.peerUsername == null
                            ? item.peerUserId
                            : '@${item.peerUsername}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (incoming)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.t('accept')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close),
                      label: Text(l10n.t('reject')),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.t('cancelRequest')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
