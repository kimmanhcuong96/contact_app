import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/localized_error.dart';
import '../profile/profile_screen.dart';
import '../connections/connections_screen.dart';
import '../connections/connection_requests_screen.dart';
import '../qr/qr_screen.dart';
import '../settings/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider);
    ref.watch(notificationRegistrationProvider);
    ref.listen(syncStatusProvider, (_, next) {
      final error = next.valueOrNull?.error;
      if (error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedError(context.l10n, error))),
      );
    });
    final screens = [
      QrScreen(onConnectionCreated: () => setState(() => index = 3)),
      const ProfileScreen(),
      const ConnectionsScreen(),
      const ConnectionRequestsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.qr_code_outlined),
                selectedIcon: const Icon(Icons.qr_code_2),
                label: context.l10n.t('qr')),
            NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: context.l10n.t('profile')),
            NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: context.l10n.t('contacts')),
            NavigationDestination(
                icon: _connectionIcon(ref, selected: false),
                selectedIcon: _connectionIcon(ref, selected: true),
                label: context.l10n.t('connections')),
            NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: context.l10n.t('settings')),
          ]),
    );
  }

  Widget _connectionIcon(WidgetRef ref, {required bool selected}) {
    final count = ref
            .watch(connectionsProvider)
            .valueOrNull
            ?.where((item) =>
                item.status == 'pending' && item.direction == 'incoming')
            .length ??
        0;
    final icon = Icon(selected ? Icons.person_add : Icons.person_add_outlined);
    return count == 0 ? icon : Badge.count(count: count, child: icon);
  }
}
