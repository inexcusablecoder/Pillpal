import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.missed),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AuthService().signOut();
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: FirestoreService().getUserStream(_uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final user = snapshot.data;
          final name = user?.displayName ??
              FirebaseAuth.instance.currentUser?.displayName ??
              'User';
          final email = user?.email ??
              FirebaseAuth.instance.currentUser?.email ??
              '';
          final adherence = user?.adherenceScore ?? 0;
          final streak = user?.streakCount ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(email,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 28),

                // Stats row
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.track_changes_rounded,
                      label: 'Adherence',
                      value: '$adherence%',
                      color: adherence >= 80
                          ? AppTheme.taken
                          : adherence >= 50
                              ? AppTheme.pending
                              : AppTheme.missed,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Streak',
                      value: '$streak days',
                      color: streak > 0 ? AppTheme.pending : AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Adherence Progress Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('30-Day Adherence',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: adherence / 100,
                          minHeight: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            adherence >= 80
                                ? AppTheme.taken
                                : adherence >= 50
                                    ? AppTheme.pending
                                    : AppTheme.missed,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('$adherence% of medicines taken on time',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info tile
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration,
                  child: Column(
                    children: [
                      _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email),
                      const Divider(height: 24),
                      _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Member since',
                          value: user?.createdAt != null
                              ? '${user!.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'
                              : 'N/A'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }
}
