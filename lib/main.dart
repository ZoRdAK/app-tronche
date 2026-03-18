import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config.dart';

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
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF667EEA),
        scaffoldBackgroundColor: const Color(0xFF111111),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF667EEA),
          secondary: Color(0xFF764BA2),
        ),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Tronche!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
