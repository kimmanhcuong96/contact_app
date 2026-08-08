import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/app_localizations.dart';

class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({super.key, required this.contact});

  final ConnectedProfileRow contact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = _fields;
    final name = fields['fullName'] ??
        (contact.peerUsername == null
            ? l10n.t('privateContact')
            : '@${contact.peerUsername}');
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
          if (contact.peerUsername != null &&
              name != '@${contact.peerUsername}') ...[
            const SizedBox(height: 4),
            Text(
              '@${contact.peerUsername}',
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
          if (fields.isEmpty)
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
            ...fields.entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_fieldIcon(entry.key)),
                title: Text(l10n.profileField(entry.key)),
                subtitle: SelectionArea(child: Text(entry.value)),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, String> get _fields {
    if (contact.profileJson == null) return const {};
    final decoded = jsonDecode(contact.profileJson!) as Map<String, dynamic>;
    final raw = decoded['fields'] as Map? ?? const {};
    return {
      for (final entry in raw.entries)
        if (entry.value?.toString().trim().isNotEmpty == true)
          entry.key.toString(): entry.value.toString(),
    };
  }

  IconData _fieldIcon(String field) => switch (field) {
        'phone' => Icons.phone_outlined,
        'email' => Icons.email_outlined,
        'address' => Icons.location_on_outlined,
        'birthday' => Icons.cake_outlined,
        'company' || 'position' => Icons.business_outlined,
        'website' || 'linkedIn' || 'instagram' => Icons.link,
        'notes' => Icons.notes_outlined,
        _ => Icons.badge_outlined,
      };
}
