import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/medicine_provider.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/medicines/medicines_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/vitals/vitals_screen.dart';
import '../widgets/ai_chat_widget.dart';
import '../widgets/app_nav_bar.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool? _lastUserAlarmFlag;

  final _screens = const [
    DashboardScreen(),
    MedicinesScreen(),
    HistoryScreen(),
    VitalsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final enabled = auth.user?.alarmRemindersEnabled ?? false;
    if (_lastUserAlarmFlag != enabled) {
      _lastUserAlarmFlag = enabled;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<MedicineProvider>().setUserAlarmRemindersEnabled(enabled);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: AiChatWidget(),
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
