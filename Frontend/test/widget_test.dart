import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness/features/auth/screens/login_screen.dart';
import 'package:fitness/features/auth/screens/settings_help_screen.dart';
import 'package:fitness/features/auth/screens/settings_theme_screen.dart';
import 'test_helpers/app_test_wrappers.dart';

/// Temel ekran smoke testleri — widget ağacının hatasız render edildiğini doğrular.
void main() {
  group('LoginScreen smoke test', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      // Login ekranında temel alanlar görünmeli
      expect(find.text('FitMentor'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);
    });
  });

  group('SettingsHelpScreen smoke test', () {
    testWidgets('renders FAQ and support email', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsHelpScreen()));
      expect(find.text('Yardım'), findsOneWidget);
      expect(find.text('Sık Sorulan Sorular'), findsOneWidget);
      expect(find.text('Destek E-posta'), findsOneWidget);
    });
  });

  group('SettingsThemeScreen smoke test', () {
    testWidgets('renders theme options', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsThemeScreen()));
      expect(find.text('Tema ve Görünüm'), findsOneWidget);
      expect(find.text('Koyu'), findsOneWidget);
    });
  });
}
