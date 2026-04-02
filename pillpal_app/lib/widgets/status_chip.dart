import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/dose_log.dart';

class StatusChip extends StatelessWidget {
  final DoseStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case DoseStatus.taken:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.successLight;
        label = 'Taken';
        icon = Icons.check_circle_rounded;
      case DoseStatus.missed:
        bg = AppColors.danger.withValues(alpha: 0.15);
        fg = AppColors.dangerLight;
        label = 'Missed';
        icon = Icons.cancel_rounded;
      case DoseStatus.pending:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warningLight;
        label = 'Pending';
        icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
