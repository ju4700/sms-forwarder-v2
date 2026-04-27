import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import 'home_screen.dart';
import 'logs_screen.dart';
import 'policy_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'SMS Forwarder',
    'Logs',
    'Policy',
  ];

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
