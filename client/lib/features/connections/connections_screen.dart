import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

final connectionSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Contacts'), actions: [IconButton(onPressed: () => ref.read(connectionRepositoryProvider).sync(), icon: const Icon(Icons.sync))]), floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context, ref), icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan')), body: ref.watch(connectionsProvider).when(
    data: (items) { final query = ref.watch(connectionSearchProvider).trim().toLowerCase(); final filtered = items.where((item) => (item.profileJson ?? item.peerUserId).toLowerCase().contains(query)).toList()..sort((a, b) => (a.profileJson ?? a.peerUserId).compareTo(b.profileJson ?? b.peerUserId)); return Column(children: [Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 0), child: SearchBar(hintText: 'Search name, nickname, or company', leading: const Icon(Icons.search), onChanged: (value) => ref.read(connectionSearchProvider.notifier).state = value)), Expanded(child: filtered.isEmpty ? const Center(child: Text('No contacts found. Scan a NexBook QR to connect.')) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: filtered.length, itemBuilder: (context, index) {
      final item = filtered[index];
      final decoded = item.profileJson == null ? null : jsonDecode(item.profileJson!) as Map<String, dynamic>;
      final fields = decoded?['fields'] as Map?;
      return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(fields?['fullName'] as String? ?? 'Private contact'), subtitle: Text(item.status == 'pending' ? 'Connection request · ${item.peerUserId}' : fields?['company'] as String? ?? item.peerUserId), trailing: PopupMenuButton<String>(onSelected: (action) => _action(context, ref, item, action), itemBuilder: (_) => [if (item.status == 'pending' && item.direction == 'incoming') const PopupMenuItem(value: 'accept', child: Text('Accept')), if (item.status == 'pending' && item.direction == 'incoming') const PopupMenuItem(value: 'reject', child: Text('Reject')), if (item.status == 'pending' && item.direction == 'outgoing') const PopupMenuItem(value: 'cancel', child: Text('Cancel request')), if (item.status == 'connected') const PopupMenuItem(value: 'assign', child: Text('Change sharing profile')), if (item.status == 'connected') const PopupMenuItem(value: 'disable', child: Text('Disable')), if (item.status == 'disabled') const PopupMenuItem(value: 'enable', child: Text('Enable')), const PopupMenuItem(value: 'delete', child: Text('Delete'))]));
    }))]); }, loading: () => const Center(child: CircularProgressIndicator()), error: (error, _) => Center(child: Text('Offline cache unavailable: $error')),
  ));

  Future<SharingProfileRow?> _chooseSharing(BuildContext context, WidgetRef ref) async {
    final rows = await ref.read(databaseProvider).select(ref.read(databaseProvider).sharingProfiles).get();
    if (!context.mounted || rows.isEmpty) return null;
    return showDialog<SharingProfileRow>(context: context, builder: (context) => SimpleDialog(title: const Text('Share which profile?'), children: rows.map((row) => SimpleDialogOption(onPressed: () => Navigator.pop(context, row), child: Text(jsonDecode(row.json)['name'] as String))).toList()));
  }
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final peerId = await context.push<String>('/scan');
    if (peerId == null || !context.mounted) return;
    final sharing = await _chooseSharing(context, ref);
    if (sharing == null) return;
    try { await ref.read(profileRepositoryProvider).sync(); await ref.read(connectionRepositoryProvider).request(peerId, sharing); } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); }
  }
  Future<void> _action(BuildContext context, WidgetRef ref, ConnectedProfileRow item, String action) async {
    try {
      if (action == 'delete') { await ref.read(connectionRepositoryProvider).delete(item.connectionId); return; }
      SharingProfileRow? sharing;
      if (action == 'accept' || action == 'assign') { sharing = await _chooseSharing(context, ref); if (sharing == null) return; await ref.read(profileRepositoryProvider).sync(); }
      await ref.read(connectionRepositoryProvider).act(item.connectionId, action, sharing: sharing, peerUserId: item.peerUserId);
    } catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); }
  }
}
