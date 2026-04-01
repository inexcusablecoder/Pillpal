import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../services/api_service.dart';
import '../../models/log_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../medicines/add_medicine_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _firestoreService = FirestoreService();
  final _api = ApiService();
  int _currentIndex = 0;
  bool _startupDone = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _runStartup();
  }

  Future<void> _runStartup() async {
    try {
      await _api.logsStartup();
    } catch (_) {
      // Offline or API down: UI still loads from Firestore cache.
    }
    if (mounted) setState(() => _startupDone = true);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        uid: _uid,
        firestoreService: _firestoreService,
        api: _api,
        greeting: _greeting,
        startupDone: _startupDone,
      ),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withAlpha(38),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppTheme.primary),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primary),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
              ).then((_) => _runStartup()),
              icon: const Icon(Icons.add),
              label: const Text('Add Medicine'),
            )
          : null,
    );
  }
}

class _HomeTab extends StatelessWidget {
  final String uid;
  final FirestoreService firestoreService;
  final ApiService api;
  final String greeting;
  final bool startupDone;

  const _HomeTab({
    required this.uid,
    required this.firestoreService,
    required this.api,
    required this.greeting,
    required this.startupDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(greeting,
                                  style: const TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                              Text(
                                FirebaseAuth.instance.currentUser?.displayName
                                        ?.split(' ').first ??
                                    'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            DateFormat('dd MMM').format(DateTime.now()),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Stats row
                    StreamBuilder<List<LogEntry>>(
                      stream: firestoreService.getTodayLogsStream(uid),
                      builder: (context, snapshot) {
                        final logs = snapshot.data ?? [];
                        final pending =
                            logs.where((l) => l.isPending).length;
                        final taken = logs.where((l) => l.isTaken).length;
                        final missed = logs.where((l) => l.isMissed).length;
                        return Row(
                          children: [
                            _StatChip(
                                label: 'Pending',
                                value: pending,
                                color: AppTheme.pending),
                            const SizedBox(width: 8),
                            _StatChip(
                                label: 'Taken',
                                value: taken,
                                color: Colors.white),
                            const SizedBox(width: 8),
                            _StatChip(
                                label: 'Missed',
                                value: missed,
                                color: AppTheme.missed),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Medicine list
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: !startupDone
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: CircularProgressIndicator(
                              color: AppTheme.primary),
                        ),
                      ),
                    )
                  : StreamBuilder<List<LogEntry>>(
                      stream: firestoreService.getTodayLogsStream(uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 60),
                                child: CircularProgressIndicator(
                                    color: AppTheme.primary),
                              ),
                            ),
                          );
                        }

                        final logs = snapshot.data ?? [];

                        if (logs.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 60),
                                child: Column(
                                  children: [
                                    const Icon(Icons.medication_outlined,
                                        size: 64, color: AppTheme.primary),
                                    const SizedBox(height: 16),
                                    Text("No medicines for today",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    Text(
                                        "Tap '+ Add Medicine' to get started",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _MedicineCard(
                              log: logs[i],
                              onMarkTaken: () async {
                                try {
                                  await api.markTaken(
                                    logId: logs[i].id,
                                    medicineId: logs[i].medicineId,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('✅ Marked as taken!')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                            childCount: logs.length,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final LogEntry log;
  final VoidCallback onMarkTaken;

  const _MedicineCard({required this.log, required this.onMarkTaken});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          // Icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _statusColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.medication_rounded,
                color: _statusColor, size: 26),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.medicineName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${log.dosage}  ·  ${log.scheduledTime}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                StatusBadge(status: log.status),
              ],
            ),
          ),

          // Mark Taken Button
          if (log.isPending)
            GestureDetector(
              onTap: onMarkTaken,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Take',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (log.status) {
      case 'taken':   return AppTheme.taken;
      case 'missed':  return AppTheme.missed;
      default:        return AppTheme.pending;
    }
  }
}
