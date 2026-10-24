import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import 'home_screen.dart';
import 'logs_screen.dart';
import 'messages/compose_screen.dart';
import 'messages/messages_screen.dart';
import 'policy_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  static const List<String> _titles = <String>[
    'SMS Forwarder',
    'Messages',
    'Logs',
    'Policy',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSendIntentHandling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.handleAppResumed();
    }
  }

  void _initSendIntentHandling() {
    widget.controller.smsCaptureService.registerSendIntentHandler((Map<String, String> data) {
      if (!mounted) return;
      _openComposeWithData(data);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final Map<String, String>? initial =
          await widget.controller.smsCaptureService.getInitialSendIntent();
      if (initial != null && mounted) {
        _openComposeWithData(initial);
      }
    });
  }

  void _openComposeWithData(Map<String, String> data) {
    final String address = data['address'] ?? '';
    final String body = data['body'] ?? '';
    if (address.isEmpty && body.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComposeScreen(
          store: widget.controller.messageStore,
          captureService: widget.controller.smsCaptureService,
          initialRecipient: address,
          initialBody: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_index]),
            centerTitle: false,
          ),
          body: IndexedStack(
            index: _index,
            children: <Widget>[
              HomeScreen(controller: widget.controller),
              MessagesScreen(controller: widget.controller),
              LogsScreen(controller: widget.controller),
              const PolicyScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (int index) {
              setState(() {
                _index = index;
              });
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum),
                label: 'Messages',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Logs',
              ),
              NavigationDestination(
                icon: Icon(Icons.policy_outlined),
                selectedIcon: Icon(Icons.policy),
                label: 'Policy',
              ),
            ],
          ),
        );
      },
    );
  }
}
