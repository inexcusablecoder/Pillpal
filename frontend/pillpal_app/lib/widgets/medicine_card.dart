import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/medicine.dart';
import '../providers/localization_provider.dart';
import 'glass_card.dart';

class MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const MedicineCard({
    super.key,
    required this.medicine,
    this.onTap,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pill icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: medicine.active
                      ? AppColors.primaryGradient
                      : const LinearGradient(
                          colors: [AppColors.surfaceLight, AppColors.surfaceLight],
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: TextStyle(
                        color: medicine.active
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      medicine.dosage,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Active toggle
              Switch.adaptive(
                value: medicine.active,
                onChanged: (_) => onToggle?.call(),
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row: time, frequency, pill count
          Row(
            children: [
              _infoChip(Icons.schedule, medicine.scheduledTimeString),
              const SizedBox(width: 8),
              _infoChip(Icons.repeat, medicine.frequency),
              if (medicine.pillCount != null) ...[
                const SizedBox(width: 8),
                _infoChip(Icons.inventory_2_outlined, '${medicine.pillCount} ${loc.translate('pills')}'),
              ],
              const Spacer(),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
