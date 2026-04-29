import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up global error handlers to prevent crashes from crashing the entire app
  FlutterError.onError = (FlutterErrorDetails details) {
    // ignore: avoid_print
    print('Flutter error: ${details.exception}\n${details.stack}');
    // Continue running the app even if there's an error
  };
  
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
      builder: (BuildContext context, Widget? child) {
        // Catch unhandled UI errors and show friendly error screen
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.warning_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'UI Error',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please restart the app.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        };
        return child ?? Container();
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009BFF),
          primary: const Color(0xFF009BFF),
          secondary: const Color(0xFF3DB7FF),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F9FF),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF009BFF),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: const Color(0xFF009BFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF009BFF),
            side: const BorderSide(color: Color(0xFF009BFF), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFB7DFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFB7DFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF009BFF), width: 1.6),
          ),
        ),
      ),
      home: AppShell(controller: controller),
    );
  }
}
