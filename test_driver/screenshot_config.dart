// Configuration for automated App Store screenshots.
// Place sample wedding photos in docs/sample-photos/
// Then run: dart test_driver/take_screenshots.dart

const screenshotConfig = {
  'eventName1': 'Marie',
  'eventName2': 'Thomas',
  'eventDate': '2025-06-14',
  'overlayTemplate': 'elegant',
  'timerDuration': 3,
  'adminPin': '1234',
};

// Screenshots to capture (in order):
// 1. Welcome screen (with logo)
// 2. Camera screen (with sample photo injected as background)
// 3. Countdown (3...2...1)
// 4. Preview (photo with overlay)
// 5. QR Code screen
// 6. Admin dashboard (with stats)
