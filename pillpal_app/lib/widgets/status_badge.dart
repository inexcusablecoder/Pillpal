import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'taken':   return AppTheme.taken;
      case 'missed':  return AppTheme.missed;
      default:        return AppTheme.pending;
    }
  }

  String get _label {
    switch (status) {
      case 'taken':   return 'Taken';
      case 'missed':  return 'Missed';
      default:        return 'Pending';
    }
  }

  IconData get _icon {
    switch (status) {
      case 'taken':   return Icons.check_circle_rounded;
      case 'missed':  return Icons.cancel_rounded;
      default:        return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withAlpha(76)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 13),
          const SizedBox(width: 4),
          Text(
            _label,
            style: GoogleFonts.poppins(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
