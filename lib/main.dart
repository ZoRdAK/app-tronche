import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'providers/app_state.dart';
import 'providers/photo_state.dart';
import 'providers/sync_state.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/booth/idle_screen.dart';
import 'screens/admin/admin_gate_screen.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const TroncheApp());
}

class TroncheApp extends StatelessWidget {
  const TroncheApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared instances so SyncService is accessible from admin screens.
    final db = DatabaseService();
    final api = ApiService(db);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => PhotoState()),
        ChangeNotifierProvider(create: (_) => SyncState()),
        ProxyProvider2<PhotoState, SyncState, SyncService>(
          update: (_, photoState, syncState, __) => SyncService(
            db: db,
            api: api,
            photoState: photoState,
            syncState: syncState,
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.primaryPink,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'System',
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryPink,
            secondary: AppColors.orange,
          ),
        ),
        home: const AppRoot(),
        routes: {
          '/admin': (_) => const AdminGateScreen(),
        },
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _syncStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<AppState>().init();
      if (!mounted) return;
      context.read<SyncState>().startMonitoring();
      _checkSync();
    });
  }

  void _checkSync() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final syncService = context.read<SyncService>();
    if (appState.isLoggedIn && !_syncStarted) {
      _syncStarted = true;
      syncService.start();
    } else if (!appState.isLoggedIn && _syncStarted) {
      _syncStarted = false;
      syncService.stop();
    }
  }

  @override
  void dispose() {
    try { context.read<SyncService>().stop(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Check sync state after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSync());

    if (!appState.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 180,
                errorBuilder: (_, __, ___) => const Text(
                  'Tronche!',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryPink,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppColors.primaryPink),
            ],
          ),
        ),
      );
    }

    if (!appState.isLoggedIn) {
      return const WelcomeScreen();
    }

    return const IdleScreen();
  }
}
