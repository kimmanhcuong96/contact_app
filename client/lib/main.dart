import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/providers.dart';
import 'core/localization/app_localizations.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/app_shell.dart';
import 'features/qr/scan_screen.dart';

void main() => runApp(const ProviderScope(child: NexBookApp()));

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  final router = GoRouter(
    initialLocation: '/home',
    redirect: (_, state) {
      final loggedIn = session.valueOrNull ?? false;
      if (!loggedIn && state.matchedLocation != '/login') return '/login';
      if (loggedIn && state.matchedLocation == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/home', builder: (_, __) => const AppShell()),
      GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class NexBookApp extends ConsumerWidget {
  const NexBookApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'NexBook',
        debugShowCheckedModeBanner: false,
        routerConfig: ref.watch(routerProvider),
        locale: ref.watch(localeProvider).valueOrNull,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff315cfd),
                brightness: Brightness.light),
            useMaterial3: true,
            inputDecorationTheme:
                const InputDecorationTheme(border: OutlineInputBorder())),
        darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff8ea5ff),
                brightness: Brightness.dark),
            useMaterial3: true),
        themeMode: ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system,
      );
}
