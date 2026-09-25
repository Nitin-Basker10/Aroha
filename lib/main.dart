import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/polar_data_service.dart';
import 'services/supabase_service.dart';
import 'views/auth/login_router_screen.dart';
import 'views/main_layout_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ThemeProvider? activeThemeProvider;

  // Backend is additive — app boots offline-first if unreachable. The error
  // fallback is theme-aware once the provider has been created; before that
  // it safely falls back to the operating-system brightness.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final mode = activeThemeProvider?.themeMode ?? ThemeMode.system;
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    final colors = isDark ? AppThemeColors.dark : AppThemeColors.light;

    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: Scaffold(
        backgroundColor: colors.canvas,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.critical),
            ),
            child: Text(
              'TACTICAL SYSTEM FAULT // ${details.exception}',
              style: TextStyle(color: colors.onSurface, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  };

  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {
    // A storage failure must not prevent the app from launching.
  }

  final platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final themeProvider = ThemeProvider(
    preferences: preferences,
    platformBrightness: platformBrightness,
  );
  activeThemeProvider = themeProvider;

  runApp(ArohaPolarApp(themeProvider: themeProvider));
  // Kick off backend init without blocking the UI.
  unawaited(SupabaseService.init());
}

class ArohaPolarApp extends StatelessWidget {
  final ThemeProvider? themeProvider;

  const ArohaPolarApp({super.key, this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Polling starts here rather than in the constructor so tests that
        // construct PolarDataService directly never touch the network.
        ChangeNotifierProvider(
          create: (_) => PolarDataService()..startNporPolling(),
        ),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationService()..init()),
        ChangeNotifierProvider(
          create: (_) =>
              themeProvider ??
              ThemeProvider(
                platformBrightness: WidgetsBinding
                    .instance
                    .platformDispatcher
                    .platformBrightness,
              ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AROHA — Polar Expedition Command',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const RootNavigationCoordinator(),
          );
        },
      ),
    );
  }
}

class RootNavigationCoordinator extends StatelessWidget {
  const RootNavigationCoordinator({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isAuthenticated) {
      return LoginRouterScreen(
        onAuthenticated: () {
          // AuthService already notifies listeners on login, which triggers a
          // rebuild showing MainLayoutScreen.
        },
      );
    }

    return MainLayoutScreen(
      onLogout: () {
        auth.logout();
      },
    );
  }
}
