import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/localization/app_localizations.dart';
import '../profile/profile_screen.dart';
import '../connections/connections_screen.dart';
import '../qr/qr_screen.dart';
import '../settings/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;
  static const screens = [
    ProfileScreen(),
    ConnectionsScreen(),
    QrScreen(),
    SettingsScreen()
  ];
  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider);
    ref.watch(notificationRegistrationProvider);
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: screens)),
      bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: context.l10n.t('profile')),
            NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: context.l10n.t('contacts')),
            NavigationDestination(
                icon: const Icon(Icons.qr_code), label: context.l10n.t('myQr')),
            NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: context.l10n.t('settings')),
          ]),
    );
  }
}
