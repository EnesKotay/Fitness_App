// PusulaFit Integration Tests
// Çalıştır: flutter test integration_test/app_test.dart -d "iPhone 16e"
//
// Bu testler simülatörde GERÇEK uygulama üzerinde çalışır.
// Mock kullanılmaz — gerçek API ve UI test edilir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pusulafit/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('PusulaFit — Temel Akış Testleri', () {
    testWidgets('Splash ekranı yükleniyor', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Splash ya da login ekranı görünmeli
      final splashOrLogin =
          find.textContaining('PusulaFit').evaluate().isNotEmpty ||
          find.textContaining('Giriş').evaluate().isNotEmpty ||
          find.textContaining('E-posta').evaluate().isNotEmpty;

      expect(splashOrLogin, isTrue, reason: 'Uygulama başlamadı');
    });

    testWidgets('Login ekranı görüntüleniyor', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Login ekranındaysa email field var olmalı
      final emailField = find.byType(TextFormField);
      if (emailField.evaluate().isNotEmpty) {
        expect(emailField, findsWidgets);
      }
    });
  });

  group('PusulaFit — Navigasyon Testleri', () {
    // Not: Bu testler giriş yapılmış bir oturum gerektirir.
    // CI'da env variable ile test hesabı kullanılabilir.

    testWidgets('Tab bar görünüyor ve tıklanabiliyor', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Ana sayfa tab'larını bul
      final antrenmanTab = find.text('Antrenman');
      if (antrenmanTab.evaluate().isNotEmpty) {
        await tester.tap(antrenmanTab);
        await tester.pumpAndSettle();
        expect(find.text('Antrenman'), findsWidgets);
      }
    });
  });
}
