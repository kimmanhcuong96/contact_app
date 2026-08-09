import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers.dart';

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contact});

  final ConnectedProfileRow contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(connectedProfileProvider(contact.connectionId));
    final liveContact = current.valueOrNull ?? contact;
    final fields = _fields(liveContact);
    final profileError = _profileError(liveContact);
    final name = fields['fullName'] ??
        (liveContact.peerUsername == null
            ? l10n.t('privateContact')
            : '@${liveContact.peerUsername}');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('contactDetails'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: CircleAvatar(
              radius: 38,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onSecondaryContainer,
              child: const Icon(Icons.person, size: 38),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (liveContact.peerUsername != null &&
              name != '@${liveContact.peerUsername}') ...[
            const SizedBox(height: 4),
            Text(
              '@${liveContact.peerUsername}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            l10n.t('sharedInformation'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (profileError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l10n.t('sharedInformationUnavailable'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            )
          else if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l10n.t('noSharedInformation'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...fields.entries.map((entry) {
              final target = contactActionUri(entry.key, entry.value);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_fieldIcon(entry.key)),
                title: Text(l10n.profileField(entry.key)),
                subtitle: SelectionArea(child: Text(entry.value)),
                trailing: target == null
                    ? null
                    : const Icon(Icons.open_in_new, size: 20),
                onTap: target == null ? null : () => _launch(context, target),
              );
            }),
        ],
      ),
    );
  }

  Map<String, String> _fields(ConnectedProfileRow contact) {
    if (contact.profileJson == null) return const {};
    try {
      final decoded = jsonDecode(contact.profileJson!) as Map<String, dynamic>;
      final raw = decoded['fields'] as Map? ?? const {};
      return {
        for (final entry in raw.entries)
          if (entry.value?.toString().trim().isNotEmpty == true)
            entry.key.toString(): entry.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  String? _profileError(ConnectedProfileRow contact) {
    if (contact.profileJson == null) return null;
    try {
      final decoded = jsonDecode(contact.profileJson!) as Map<String, dynamic>;
      return decoded['error'] as String?;
    } catch (_) {
      return 'invalid_profile';
    }
  }

  IconData _fieldIcon(String field) => switch (field) {
        'phone' => Icons.phone_outlined,
        'email' => Icons.email_outlined,
        'address' => Icons.location_on_outlined,
        'birthday' => Icons.cake_outlined,
        'company' || 'position' => Icons.business_outlined,
        'website' ||
        'facebook' ||
        'linkedIn' ||
        'instagram' ||
        'telegram' ||
        'whatsApp' ||
        'zalo' ||
        'github' =>
          Icons.link,
        'notes' => Icons.notes_outlined,
        _ => Icons.badge_outlined,
      };

  Future<void> _launch(BuildContext context, Uri target) async {
    try {
      if (await launchUrl(target, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show the same actionable message for unsupported or malformed targets.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('error.cannotOpenLink'))),
      );
    }
  }
}

Uri? contactActionUri(String field, String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return switch (field) {
    'phone' => Uri(scheme: 'tel', path: trimmed),
    'email' => Uri(scheme: 'mailto', path: trimmed),
    'address' => Uri.https(
        'www.google.com',
        '/maps/search/',
        {'api': '1', 'query': trimmed},
      ),
    'facebook' => _socialUri(trimmed, 'https://facebook.com/'),
    'instagram' => _socialUri(trimmed, 'https://instagram.com/'),
    'linkedIn' => _socialUri(trimmed, 'https://linkedin.com/in/'),
    'telegram' => _socialUri(trimmed, 'https://t.me/'),
    'whatsApp' => _socialUri(
        trimmed.replaceAll(RegExp(r'[^0-9]'), ''),
        'https://wa.me/',
      ),
    'zalo' => _socialUri(trimmed, 'https://zalo.me/'),
    'github' => _socialUri(trimmed, 'https://github.com/'),
    'website' => _webUri(trimmed),
    _ => null,
  };
}

Uri _socialUri(String value, String base) {
  if (value.startsWith('@')) return Uri.parse('$base${value.substring(1)}');
  if (value.contains('.') || value.contains('/')) return _webUri(value);
  return Uri.parse('$base$value');
}

Uri _webUri(String value) {
  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) return parsed;
  return Uri.parse('https://$value');
}
