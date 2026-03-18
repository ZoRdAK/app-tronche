import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tronche/main.dart' as app;
import 'package:tronche/screens/booth/preview_screen.dart';
import 'package:tronche/screens/booth/qr_screen.dart';
import 'package:tronche/services/database_service.dart';
import 'package:tronche/models/event_config.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Helper to set up a fake logged-in state with photos
Future<void> _setupFakeEvent(DatabaseService db) async {
  final pinHash = sha256.convert(utf8.encode('1234')).toString();

  final config = EventConfig(
    serverEventId: 'demo-event-id',
    userEmail: 'karl.cosse@gmail.com',
    jwtToken: 'demo-token',
    refreshToken: 'demo-refresh',
    name1: 'Marie',
    name2: 'Thomas',
    eventDate: '2025-06-14',
    overlayTemplate: 'elegant',
    timerDuration: 3,
    adminPasswordHash: pinHash,
    shareCode: 'DEMO_SHARE_CODE',
    plan: 'premium',
  );
  await db.saveEventConfig(config);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Store Screenshots', () {

    // Screenshot 1: Welcome screen with logo
    testWidgets('01 - Welcome Screen', (tester) async {
      final db = DatabaseService();
      await db.clearEventConfig();

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await binding.takeScreenshot('01_welcome');
    });

    // Screenshot 2: Idle screen with slideshow of wedding photos
    testWidgets('02 - Booth Idle Screen', (tester) async {
      final db = DatabaseService();
      await _setupFakeEvent(db);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Let slideshow timer fire to show a photo
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await binding.takeScreenshot('02_idle');
    });

    // Screenshot 3: Camera screen with Photo/GIF toggle
    testWidgets('03 - Camera Screen', (tester) async {
      app.main();
      // Pump frames manually (pumpAndSettle won't work because slideshow timer keeps animating)
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap "Touchez pour commencer"
      final startBtn = find.textContaining('Touchez');
      expect(startBtn, findsOneWidget);
      await tester.tap(startBtn);

      // Wait for navigation animation to fully complete
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify we're on camera screen (look for Photo/GIF toggle or shutter)
      await tester.pump(const Duration(seconds: 1));

      await binding.takeScreenshot('03_camera');
    });

    // Screenshot 4: Preview screen (real screen with screenshot mode asset)
    testWidgets('04 - Photo Preview', (tester) async {
      app.main();
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Navigate directly to PreviewScreen (skip camera)
      final navContext = tester.element(find.byType(Scaffold).first);
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => const PreviewScreen(
            rawPhotoPath: 'screenshot_mode',
            compositedPhotoPath: 'screenshot_mode',
          ),
        ),
      );

      // Wait for navigation to complete
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await binding.takeScreenshot('04_preview');
    });

    // Screenshot 5: QR Code screen (real QrScreen)
    testWidgets('05 - QR Code Screen', (tester) async {
      app.main();
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Navigate directly to QrScreen
      final navContext = tester.element(find.byType(Scaffold).first);
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => const QrScreen(photoCode: 'DEMO_PHOTO_CODE'),
        ),
      );

      // Wait for navigation to complete
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await binding.takeScreenshot('05_qrcode');
    });

    // Screenshot 6: Admin Dashboard
    testWidgets('06 - Admin Dashboard', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Long press on branding logo to open admin
      final branding = find.byKey(const Key('branding_logo'));
      expect(branding, findsOneWidget);
      await tester.longPress(branding);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Enter PIN 1234
      for (final digit in ['1', '2', '3', '4']) {
        final btn = find.widgetWithText(TextButton, digit);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first);
          await tester.pump(const Duration(milliseconds: 400));
        }
      }

      await tester.pumpAndSettle(const Duration(seconds: 2));
      await binding.takeScreenshot('06_admin');
    });
  });
}
