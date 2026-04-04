import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/medicine.dart';
import '../../providers/medicine_provider.dart';
import '../../services/web_reminder.dart';
import '../../widgets/medicine_card.dart';
import 'add_medicine_screen.dart';
import '../../providers/localization_provider.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineProvider>().fetchMedicines();
    });
  }

  @override
  Widget build(BuildContext context) {
    final meds = context.watch<MedicineProvider>();
    final loc = context.watch<LocalizationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => meds.fetchMedicines(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.translate('my_medicines'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${meds.medicines.length} ${loc.translate('medicine_plural')}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => _openAddMedicine(context),
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (kIsWeb)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Browser: dose reminders use a desktop notification at the scheduled time. '
                                    'Keep this tab open. Allow notifications (button below or Profile). '
                                    'Use the Android app for full background alarms.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final ok = await requestBrowserNotificationPermission();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Notifications allowed for this site.'
                                          : 'Use the lock icon in the address bar → Site settings → Notifications → Allow.',
                                    ),
                                    backgroundColor:
                                        ok ? AppColors.success : AppColors.warning,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.notifications_active_outlined, size: 18),
                              label: const Text('Allow browser notifications'),
                            ),
                          ],
                        ),
                      ),
                    if (kIsWeb && !meds.userAlarmRemindersEnabled) const SizedBox(height: 10),
                    if (!meds.userAlarmRemindersEnabled)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notifications_off_outlined,
                                color: AppColors.danger, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Reminders are off. Open Profile and turn on “Alarm reminders”.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (meds.isLoading && meds.medicines.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (meds.medicines.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(context).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final med = meds.medicines[index];
                      return MedicineCard(
                        medicine: med,
                        onTap: () => _openEditMedicine(context, med),
                        onToggle: () => _toggleActive(med),
                        onDelete: () => _confirmDelete(context, med),
                      ).animate(delay: Duration(milliseconds: 200 + index * 60)).fadeIn().slideX(begin: 0.1);
                    },
                    childCount: meds.medicines.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            loc.translate('no_meds_title'),
            style: const TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            loc.translate('no_meds_subtitle'),
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openAddMedicine(context),
            icon: const Icon(Icons.add),
            label: Text(loc.translate('add_medicine')),
          ),
        ],
      ),
    );
  }

  void _openAddMedicine(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
  }

  void _openEditMedicine(BuildContext context, Medicine med) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddMedicineScreen(medicine: med)),
    );
  }

  void _toggleActive(Medicine med) {
    context.read<MedicineProvider>().updateMedicine(
          med.id,
          active: !med.active,
        );
  }

  void _confirmDelete(BuildContext context, Medicine med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to delete "${med.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MedicineProvider>().deleteMedicine(med.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
