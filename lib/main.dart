import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppController controller = AppController();
  await controller.initialize();
  runApp(SmsForwarderApp(controller: controller));
}

class SmsForwarderApp extends StatelessWidget {
  const SmsForwarderApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Forwarder',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        scaffoldBackgroundColor: const Color(0xFFF3F8FF),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ),
      home: HomeScreen(controller: controller),
    );
  }
}
