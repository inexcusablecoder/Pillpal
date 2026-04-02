import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/medicine.dart';
import '../../providers/medicine_provider.dart';
import '../../widgets/medicine_card.dart';
import 'add_medicine_screen.dart';

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
                        const Text(
                          'My Medicines',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${meds.medicines.length} medicine${meds.medicines.length == 1 ? '' : 's'}',
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
          const Text(
            'No medicines yet',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add your first medicine',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openAddMedicine(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Medicine'),
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
