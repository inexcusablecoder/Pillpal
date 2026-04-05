import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/medicine.dart';
import '../providers/medicine_provider.dart';
import '../services/browser_notify_stub.dart'
    if (dart.library.html) '../services/browser_notify_web.dart';

/// Watches active medicines and shows an in-app popup (and web OS notification)
/// when local time matches the scheduled dose. Required for **Flutter web** where
/// `flutter_local_notifications` does not run.
class MedicineReminderHost extends StatefulWidget {
  const MedicineReminderHost({super.key, required this.child});

  final Widget child;

  @override
  State<MedicineReminderHost> createState() => _MedicineReminderHostState();
}

class _MedicineReminderHostState extends State<MedicineReminderHost> {
  Timer? _timer;
  int? _trackedMinute;
  final Set<String> _firedThisMinute = {};
  /// One-shot reminder at this time (Snooze 10 min).
  final Map<String, DateTime> _snoozeFireAt = {};
  bool _dialogOpen = false;
  final List<Medicine> _queue = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MedicineProvider>().fetchMedicines();
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isDailyReminder(String frequency) {
    final f = frequency.toLowerCase().trim();
    return f == 'daily' || f.isEmpty;
  }

  /// Native `flutter_local_notifications` is wired for Android only; web/iOS/desktop
  /// use this in-app scheduler so reminders still fire.
  bool _useInAppReminders() {
    if (kIsWeb) return true;
    return defaultTargetPlatform != TargetPlatform.android;
  }

  void _tick() {
    if (!mounted || !_useInAppReminders()) return;
    final now = DateTime.now();
    if (_trackedMinute != now.minute) {
      _firedThisMinute.clear();
      _trackedMinute = now.minute;
    }

    final medProv = context.read<MedicineProvider>();
    if (!medProv.userAlarmRemindersEnabled) return;
    final meds =
        medProv.activeMedicines.where((m) => m.reminderEnabled).toList();

    for (final id in _snoozeFireAt.keys.toList()) {
      final at = _snoozeFireAt[id]!;
      if (now.isBefore(at)) continue;
      if (now.difference(at).inMinutes > 2) {
        _snoozeFireAt.remove(id);
        continue;
      }
      _snoozeFireAt.remove(id);
      Medicine? match;
      for (final m in meds) {
        if (m.id == id) {
          match = m;
          break;
        }
      }
      if (match != null) {
        _enqueueReminder(match);
      }
    }

    for (final med in meds) {
      if (!_isDailyReminder(med.frequency)) continue;
      if (med.scheduledTime.hour != now.hour ||
          med.scheduledTime.minute != now.minute) {
        continue;
      }
      if (_firedThisMinute.contains(med.id)) continue;
      _firedThisMinute.add(med.id);
      _enqueueReminder(med);
    }
  }

  void _enqueueReminder(Medicine med) {
    _queue.add(med);
    if (!_dialogOpen) {
      _showNext();
    }
  }

  Future<void> _showNext() async {
    if (!mounted || _queue.isEmpty) {
      _dialogOpen = false;
      return;
    }
    _dialogOpen = true;
    final med = _queue.removeAt(0);

    if (kIsWeb) {
      tryShowBrowserReminder(
        title: 'PillPal — ${med.name}',
        body: 'Time to take your dose (${med.dosage}).',
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Medicine reminder',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time to take ${med.name}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dosage: ${med.dosage}',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Scheduled: ${med.scheduledTimeString}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _snoozeFireAt[med.id] =
                    DateTime.now().add(const Duration(minutes: 10));
                Navigator.of(ctx).pop();
              },
              child: const Text('Snooze 10 min'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    _dialogOpen = false;
    _showNext();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
