import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/localized_error.dart';
import '../../core/providers.dart';
import '../../models/sharing_profile.dart';
import 'contact_detail_screen.dart';

final connectionSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  final _selected = <String>{};
  bool _selectionMode = false;

  bool get _selecting => _selectionMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profiles = ref.watch(sharingProfilesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                tooltip: l10n.t('cancel'),
                onPressed: _clearSelection,
                icon: const Icon(Icons.close),
              )
            : null,
        title: Text(_selecting
            ? l10n.t('selectedCount', {'count': _selected.length})
            : l10n.t('contacts')),
        actions: [
          if (_selecting)
            IconButton(
              tooltip: l10n.t('selectAll'),
              onPressed: () => _selectAll(ref.read(connectionsProvider)),
              icon: const Icon(Icons.select_all),
            )
          else
            IconButton(
              tooltip: l10n.t('selectMultiple'),
              onPressed: _startSelection,
              icon: const Icon(Icons.checklist),
            ),
          if (!_selecting)
            IconButton(
              tooltip: l10n.t('syncNow'),
              onPressed: _sync,
              icon: const Icon(Icons.sync),
            ),
        ],
      ),
      body: ref.watch(connectionsProvider).when(
            data: (items) => _buildContacts(items, profiles),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                Center(child: Text(l10n.t('offlineCacheUnavailable'))),
          ),
      bottomNavigationBar:
          _selecting ? _BulkActions(onAction: _bulkAction) : null,
    );
  }

  Widget _buildContacts(
      List<ConnectedProfileRow> items, List<SharingProfile> profiles) {
    final l10n = context.l10n;
    final query = ref.watch(connectionSearchProvider).trim().toLowerCase();
    final contacts = items
        .where((item) => item.status != 'pending')
        .where((item) =>
            '${item.profileJson ?? ''} ${item.peerUsername ?? ''} ${item.peerUserId}'
                .toLowerCase()
                .contains(query))
        .toList();
    final profileById = {for (final profile in profiles) profile.id: profile};
    final groups = <String?, List<ConnectedProfileRow>>{};
    for (final contact in contacts) {
      groups.putIfAbsent(contact.assignedProfileId, () => []).add(contact);
    }
    for (final group in groups.values) {
      group.sort((a, b) => _contactName(a)
          .toLowerCase()
          .compareTo(_contactName(b).toLowerCase()));
    }
    final sectionIds = groups.keys.toList()
      ..sort((a, b) => _sectionName(a, profileById)
          .toLowerCase()
          .compareTo(_sectionName(b, profileById).toLowerCase()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: SearchBar(
            hintText: l10n.t('searchContacts'),
            leading: const Icon(Icons.search),
            onChanged: (value) =>
                ref.read(connectionSearchProvider.notifier).state = value,
          ),
        ),
        Expanded(
          child: contacts.isEmpty
              ? Center(child: Text(l10n.t('noContacts')))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: sectionIds.length,
                  itemBuilder: (context, index) {
                    final sectionId = sectionIds[index];
                    final sectionContacts = groups[sectionId]!;
                    return _ContactSection(
                      title: _sectionName(sectionId, profileById),
                      contacts: sectionContacts,
                      selected: _selected,
                      selectionMode: _selectionMode,
                      onTap: _contactTap,
                      onLongPress: _toggleSelection,
                      onAction: _singleAction,
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _sectionName(
      String? profileId, Map<String, SharingProfile> profileById) {
    final profile = profileById[profileId];
    return profile == null
        ? context.l10n.t('unassignedProfile')
        : context.l10n.defaultProfileName(profile.name);
  }

  String _contactName(ConnectedProfileRow item) {
    if (item.profileJson != null) {
      try {
        final decoded = jsonDecode(item.profileJson!) as Map<String, dynamic>;
        final fields = decoded['fields'] as Map?;
        final fullName = fields?['fullName']?.toString().trim();
        if (fullName?.isNotEmpty == true) return fullName!;
      } catch (_) {
        // Fall back to the account username for malformed cached profiles.
      }
    }
    return item.peerUsername == null
        ? item.peerUserId
        : '@${item.peerUsername}';
  }

  void _contactTap(ConnectedProfileRow item) {
    if (_selecting) {
      _toggleSelection(item);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ContactDetailScreen(contact: item),
    ));
  }

  void _toggleSelection(ConnectedProfileRow item) {
    setState(() {
      if (!_selected.add(item.connectionId)) {
        _selected.remove(item.connectionId);
      }
    });
  }

  void _clearSelection() => setState(() {
        _selected.clear();
        _selectionMode = false;
      });

  void _startSelection() => setState(() => _selectionMode = true);

  void _selectAll(AsyncValue<List<ConnectedProfileRow>> value) {
    final ids = value.valueOrNull
            ?.where((item) => item.status != 'pending')
            .map((item) => item.connectionId) ??
        const Iterable<String>.empty();
    setState(() {
      _selected
        ..clear()
        ..addAll(ids);
    });
  }

  List<ConnectedProfileRow> _selectedContacts() =>
      ref
          .read(connectionsProvider)
          .valueOrNull
          ?.where((item) => _selected.contains(item.connectionId))
          .toList() ??
      const [];

  Future<void> _bulkAction(String action) async {
    final items = _selectedContacts();
    if (items.isEmpty) return;
    try {
      if (action == 'assign') {
        if (items.any((item) => item.status != 'connected')) {
          _showMessage(context.l10n.t('selectConnectedOnly'));
          return;
        }
        final sharing = await _chooseSharing();
        if (sharing == null) return;
        await ref
            .read(connectionRepositoryProvider)
            .actMany(items, 'assign', sharing: sharing);
      } else if (action == 'disable') {
        final connected =
            items.where((item) => item.status == 'connected').toList();
        await ref
            .read(connectionRepositoryProvider)
            .actMany(connected, 'disable');
      } else if (action == 'delete') {
        if (!await _confirmBulkDelete(items.length)) return;
        await ref.read(connectionRepositoryProvider).deleteMany(items);
      }
      if (mounted) _clearSelection();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _singleAction(ConnectedProfileRow item, String action) async {
    try {
      if (action == 'delete') {
        await ref.read(connectionRepositoryProvider).delete(item.connectionId);
        return;
      }
      SharingProfileRow? sharing;
      if (action == 'assign') {
        sharing = await _chooseSharing();
        if (sharing == null) return;
      }
      await ref.read(connectionRepositoryProvider).act(
            item.connectionId,
            action,
            sharing: sharing,
            peerUserId: item.peerUserId,
          );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<SharingProfileRow?> _chooseSharing() async {
    final database = ref.read(databaseProvider);
    final rows = await database.select(database.sharingProfiles).get();
    rows.sort((a, b) {
      final aName = SharingProfile.decode(a.json).name.toLowerCase();
      final bName = SharingProfile.decode(b.json).name.toLowerCase();
      return aName.compareTo(bName);
    });
    if (!mounted || rows.isEmpty) return null;
    return showDialog<SharingProfileRow>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.t('shareWhichProfile')),
        children: rows
            .map((row) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, row),
                  child: Text(context.l10n.defaultProfileName(
                      SharingProfile.decode(row.json).name)),
                ))
            .toList(),
      ),
    );
  }

  Future<bool> _confirmBulkDelete(int count) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.t('deleteSelectedContacts')),
          content: Text(context.l10n
              .t('deleteSelectedContactsConfirm', {'count': count})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.t('delete')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _sync() async {
    try {
      await ref.read(connectionRepositoryProvider).sync();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedError(context.l10n, error))),
      );

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.title,
    required this.contacts,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  final String title;
  final List<ConnectedProfileRow> contacts;
  final Set<String> selected;
  final bool selectionMode;
  final ValueChanged<ConnectedProfileRow> onTap;
  final ValueChanged<ConnectedProfileRow> onLongPress;
  final void Function(ConnectedProfileRow, String) onAction;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Badge.count(count: contacts.length),
              ],
            ),
          ),
          ...contacts.map((item) => _ContactTile(
                item: item,
                selected: selected.contains(item.connectionId),
                selectionMode: selectionMode,
                onTap: () => onTap(item),
                onLongPress: () => onLongPress(item),
                onAction: (action) => onAction(item, action),
              )),
          const SizedBox(height: 10),
        ],
      );
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.item,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  final ConnectedProfileRow item;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Map? fields;
    if (item.profileJson != null) {
      try {
        fields = (jsonDecode(item.profileJson!)
            as Map<String, dynamic>)['fields'] as Map?;
      } catch (_) {
        fields = null;
      }
    }
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: selectionMode
            ? Checkbox(value: selected, onChanged: (_) => onTap())
            : CircleAvatar(
                backgroundColor: item.status == 'connected'
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: item.status == 'connected'
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                child: const Icon(Icons.person),
              ),
        title: Text(fields?['fullName'] as String? ??
            (item.peerUsername == null
                ? l10n.t('privateContact')
                : '@${item.peerUsername}')),
        subtitle: Text(fields?['company'] as String? ??
            (item.peerUsername == null
                ? item.peerUserId
                : '@${item.peerUsername}')),
        onTap: onTap,
        onLongPress: onLongPress,
        trailing: selectionMode
            ? null
            : PopupMenuButton<String>(
                onSelected: onAction,
                itemBuilder: (_) => [
                  if (item.status == 'connected')
                    PopupMenuItem(
                      value: 'assign',
                      child: Text(l10n.t('changeSharingProfile')),
                    ),
                  if (item.status == 'connected')
                    PopupMenuItem(
                      value: 'disable',
                      child: Text(l10n.t('disable')),
                    ),
                  if (item.status == 'disabled')
                    PopupMenuItem(
                      value: 'enable',
                      child: Text(l10n.t('enable')),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.t('delete')),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BulkActions extends StatelessWidget {
  const _BulkActions({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _BulkAction(
                icon: Icons.drive_file_move_outline,
                label: context.l10n.t('changeProfile'),
                onTap: () => onAction('assign'),
              ),
              _BulkAction(
                icon: Icons.link_off,
                label: context.l10n.t('disable'),
                onTap: () => onAction('disable'),
              ),
              _BulkAction(
                icon: Icons.delete_outline,
                label: context.l10n.t('delete'),
                onTap: () => onAction('delete'),
              ),
            ],
          ),
        ),
      );
}

class _BulkAction extends StatelessWidget {
  const _BulkAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
}
