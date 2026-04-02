import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/dose_log.dart';
import 'glass_card.dart';
import 'status_chip.dart';

class DoseCard extends StatelessWidget {
  final DoseLog dose;
  final VoidCallback? onTake;
  final bool isActioning;

  const DoseCard({
    super.key,
    required this.dose,
    this.onTake,
    this.isActioning = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Pill icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: _iconGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicineName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      dose.scheduledTimeString,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status / Action
          if (dose.isPending)
            _buildTakeButton()
          else
            StatusChip(status: dose.status),
        ],
      ),
    );
  }

  Widget _buildTakeButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isActioning ? null : onTake,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: isActioning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Take',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  LinearGradient get _iconGradient {
    switch (dose.status) {
      case DoseStatus.taken:
        return const LinearGradient(
          colors: [AppColors.success, Color(0xFF059669)],
        );
      case DoseStatus.missed:
        return const LinearGradient(
          colors: [AppColors.danger, Color(0xFFDC2626)],
        );
      case DoseStatus.pending:
        return AppColors.primaryGradient;
    }
  }
}
