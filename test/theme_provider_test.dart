import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aroha_polar/core/theme/app_colors.dart';
import 'package:aroha_polar/core/theme/theme_provider.dart';
import 'package:aroha_polar/views/widgets/theme_toggle.dart';

double _contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('light and dark semantic palettes are defined', () {
    expect(AppThemeColors.light.canvas, isNot(AppThemeColors.dark.canvas));
    expect(
      AppThemeColors.light.onSurface,
      isNot(AppThemeColors.dark.onSurface),
    );
    expect(AppThemeColors.light.nominal, isNot(AppThemeColors.dark.nominal));
  });

  test('status mapping covers cargo, calls, and resource requests', () {
    for (final status in const [
      'packed',
      'shipped',
      'booked',
      'live',
      'approved',
      'fulfilled',
      'completed',
    ]) {
      expect(AppThemeColors.light.status(status), AppThemeColors.light.nominal);
      expect(AppThemeColors.dark.status(status), AppThemeColors.dark.nominal);
    }

    for (final status in const ['pending', 'planned', 'in-transit']) {
      expect(AppThemeColors.light.status(status), AppThemeColors.light.warning);
      expect(AppThemeColors.dark.status(status), AppThemeColors.dark.warning);
    }

    for (final status in const ['denied', 'cancelled']) {
      expect(
        AppThemeColors.light.status(status),
        AppThemeColors.light.critical,
      );
      expect(AppThemeColors.dark.status(status), AppThemeColors.dark.critical);
    }
  });

  test('status foregrounds adapt to the active mode', () {
    expect(
      AppThemeColors.light.onNominal,
      isNot(AppThemeColors.dark.onNominal),
    );
    expect(
      AppThemeColors.light.onWarning,
      isNot(AppThemeColors.dark.onWarning),
    );
    expect(
      AppThemeColors.light.onCritical,
      isNot(AppThemeColors.dark.onCritical),
    );
  });

  test('status foreground pairs meet normal-text contrast', () {
    for (final colors in [AppThemeColors.light, AppThemeColors.dark]) {
      expect(
        _contrastRatio(colors.onNominal, colors.nominal),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.onWarning, colors.warning),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.onCritical, colors.critical),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.onPrimaryContainer, colors.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('uses system brightness when no saved preference exists', () async {
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(
      preferences: preferences,
      platformBrightness: Brightness.light,
    );

    expect(provider.isDark, isFalse);
    expect(provider.themeMode, ThemeMode.light);
  });

  test('uses dark system brightness when no saved preference exists', () async {
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(
      preferences: preferences,
      platformBrightness: Brightness.dark,
    );

    expect(provider.isDark, isTrue);
    expect(provider.themeMode, ThemeMode.dark);
  });

  test('saved preference wins over system brightness', () async {
    SharedPreferences.setMockInitialValues({ThemeProvider.storageKey: true});
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(
      preferences: preferences,
      platformBrightness: Brightness.light,
    );

    expect(provider.isDark, isTrue);
    expect(provider.themeMode, ThemeMode.dark);
  });

  test('saved light preference wins over dark system brightness', () async {
    SharedPreferences.setMockInitialValues({ThemeProvider.storageKey: false});
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(
      preferences: preferences,
      platformBrightness: Brightness.dark,
    );

    expect(provider.isDark, isFalse);
    expect(provider.themeMode, ThemeMode.light);
  });

  test('toggle and setDark persist the explicit choice', () async {
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(
      preferences: preferences,
      platformBrightness: Brightness.light,
    );

    provider.toggle();
    expect(provider.isDark, isTrue);
    expect(provider.themeMode, ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.getBool(ThemeProvider.storageKey), isTrue);

    provider.setDark(false);
    expect(provider.isDark, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.getBool(ThemeProvider.storageKey), isFalse);
  });

  test('rapid toggles are serialized to the final in-memory choice', () async {
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(
      preferences: preferences,
      platformBrightness: Brightness.light,
    );

    provider.toggle();
    provider.toggle();
    provider.toggle();
    await Future<void>.delayed(Duration.zero);

    expect(provider.isDark, isTrue);
    expect(preferences.getBool(ThemeProvider.storageKey), isTrue);
  });

  testWidgets('theme toggle updates the active MaterialApp theme', (
    tester,
  ) async {
    final provider = ThemeProvider(platformBrightness: Brightness.light);
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: Consumer<ThemeProvider>(
          builder: (context, provider, _) => MaterialApp(
            theme: ThemeData(
              brightness: Brightness.light,
              extensions: const <ThemeExtension<dynamic>>[AppThemeColors.light],
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              extensions: const <ThemeExtension<dynamic>>[AppThemeColors.dark],
            ),
            themeMode: provider.themeMode,
            home: const Scaffold(body: Center(child: ThemeToggleButton())),
          ),
        ),
      ),
    );

    expect(provider.isDark, isFalse);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(
      Theme.of(tester.element(find.byType(ThemeToggleButton))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(provider.isDark, isTrue);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.byType(ThemeToggleButton))).brightness,
      Brightness.dark,
    );
  });
}
