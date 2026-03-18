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
          primaryColor: const Color(0xFF667EEA),
          scaffoldBackgroundColor: const Color(0xFF111111),
          fontFamily: 'System',
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF667EEA),
            secondary: Color(0xFF764BA2),
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
    // Initialise app state (loads EventConfig from SQLite) after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().init();
      context.read<SyncState>().startMonitoring();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.watch<AppState>();
    final syncService = context.read<SyncService>();
    if (appState.isLoggedIn && !_syncStarted) {
      _syncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        syncService.start();
      });
    } else if (!appState.isLoggedIn && _syncStarted) {
      _syncStarted = false;
      syncService.stop();
    }
  }

  @override
  void dispose() {
    context.read<SyncService>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!appState.isLoggedIn) {
      return const WelcomeScreen();
    }

    return const IdleScreen();
  }
}
