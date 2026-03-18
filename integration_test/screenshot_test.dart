import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tronche/main.dart' as app;
import 'package:tronche/services/database_service.dart';
import 'package:tronche/services/api_service.dart';
import 'package:tronche/models/event_config.dart';
import 'package:tronche/models/photo.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Store Screenshots', () {

    testWidgets('01 - Welcome Screen', (tester) async {
      // Clear any existing data
      final db = DatabaseService();
      await db.clearEventConfig();

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await binding.takeScreenshot('01_welcome');
    });

    testWidgets('02 - Login Screen', (tester) async {
      final db = DatabaseService();
      await db.clearEventConfig();

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap "J'ai déjà un compte"
      final loginLink = find.text("J'ai déjà un compte");
      await tester.tap(loginLink);
      await tester.pumpAndSettle();

      await binding.takeScreenshot('02_login');
    });

    testWidgets('03 - Event Setup Screen', (tester) async {
      final db = DatabaseService();
      await db.clearEventConfig();

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap "Créer mon photobooth"
      final createBtn = find.text('Créer mon photobooth');
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Fill in registration
      await tester.enterText(find.byType(TextFormField).at(0), 'demo@tronche.app');
      await tester.enterText(find.byType(TextFormField).at(1), 'DemoPass123!');
      await tester.enterText(find.byType(TextFormField).at(2), 'DemoPass123!');

      // We can't actually register (would create duplicate), so just screenshot the register screen
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03_register');
    });

    testWidgets('04 - Booth Idle Screen (with photos)', (tester) async {
      // Pre-populate database with event config and photos
      final db = DatabaseService();

      // Login via API to get real tokens
      final api = ApiService(db);
      final loginData = await api.login('karl.cosse@gmail.com', 'karlkarl');
      final token = loginData['accessToken'] as String;
      final refreshToken = loginData['refreshToken'] as String;
      final user = loginData['user'] as Map<String, dynamic>;

      // Get events
      final events = await api.getEvents();
      final event = events.first as Map<String, dynamic>;

      final pinHash = sha256.convert(utf8.encode('1234')).toString();

      final config = EventConfig(
        serverEventId: event['id'] as String,
        userEmail: 'karl.cosse@gmail.com',
        jwtToken: token,
        refreshToken: refreshToken,
        name1: event['name1'] as String? ?? 'Marie',
        name2: event['name2'] as String? ?? 'Thomas',
        eventDate: event['event_date'] as String? ?? '2025-06-14',
        overlayTemplate: event['overlay_template'] as String? ?? 'elegant',
        timerDuration: event['timer_duration'] as int? ?? 3,
        adminPasswordHash: pinHash,
        shareCode: event['share_code'] as String? ?? '',
        plan: user['plan'] as String? ?? 'free',
      );
      await db.saveEventConfig(config);

      // Copy sample photos to app documents dir and add to DB
      final appDir = Directory('/Users/karl/Dev/tronche/docs/screenshot');
      final files = appDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();

      int photoNum = 0;
      for (final file in files.take(4)) {
        photoNum++;
        final photo = Photo(
          localPath: file.path,
          thumbnailPath: file.path,
          photoCode: 'screenshot_photo_$photoNum',
          takenAt: DateTime(2025, 6, 14, 15, photoNum),
          isSynced: true,
          serverPhotoId: 'server_$photoNum',
          syncedAt: DateTime.now(),
        );
        await db.insertPhoto(photo);
      }

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should be on idle screen with slideshow
      await binding.takeScreenshot('04_idle');
    });

    testWidgets('05 - Camera Screen', (tester) async {
      // DB should still have config from previous test
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap "Touchez pour commencer"
      final startBtn = find.textContaining('Touchez');
      if (startBtn.evaluate().isNotEmpty) {
        await tester.tap(startBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      await binding.takeScreenshot('05_camera');
    });

    testWidgets('06 - Admin Dashboard', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Long press on "Tronche!" branding to open admin
      final branding = find.textContaining('Tronche');
      if (branding.evaluate().isNotEmpty) {
        await tester.longPress(branding.last);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // Enter PIN 1234
      final pinField = find.byType(TextField);
      if (pinField.evaluate().isEmpty) {
        // Might be custom keypad - tap 1, 2, 3, 4
        // Try finding number buttons
        for (final digit in ['1', '2', '3', '4']) {
          final btn = find.text(digit);
          if (btn.evaluate().isNotEmpty) {
            await tester.tap(btn.first);
            await tester.pumpAndSettle(const Duration(milliseconds: 300));
          }
        }
      }

      await tester.pumpAndSettle(const Duration(seconds: 2));
      await binding.takeScreenshot('06_admin');
    });
  });
}
