import '../models/dose_log.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';

class StatusChip extends StatelessWidget {
  final DoseStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case DoseStatus.taken:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.successLight;
        label = loc.translate('taken');
        icon = Icons.check_circle_rounded;
      case DoseStatus.missed:
        bg = AppColors.danger.withValues(alpha: 0.15);
        fg = AppColors.dangerLight;
        label = loc.translate('missed');
        icon = Icons.cancel_rounded;
      case DoseStatus.pending:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warningLight;
        label = loc.translate('pending');
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
