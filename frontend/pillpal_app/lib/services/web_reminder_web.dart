// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

/// One-shot timers per medicine; reschedules daily. Requires tab to stay open.
final Map<String, Timer> _timers = {};

/// Next fire time for today's [hour]:[minute] dose window (1 minute wide).
/// Fixes edge case: at 2:55:30 with dose 2:55 AM, old logic jumped to *tomorrow*.
DateTime _nextOccurrence(int hour, int minute) {
  final now = DateTime.now();
  final slotStart = DateTime(now.year, now.month, now.day, hour, minute);
  final slotEnd = slotStart.add(const Duration(minutes: 1));

  if (now.isBefore(slotStart)) {
    return slotStart;
  }
  if (now.isBefore(slotEnd)) {
    return now.add(const Duration(seconds: 2));
  }
  return slotStart.add(const Duration(days: 1));
}

Future<void> _showBrowserNotification(String title, String body) async {
  if (!html.Notification.supported) return;
  var perm = html.Notification.permission;
  if (perm == 'default') {
    perm = await html.Notification.requestPermission();
  }
  if (perm != 'granted') return;
  html.Notification(title, body: body, tag: 'pillpal-dose');
}

void scheduleWebReminder({
  required String medicineId,
  required String medicineName,
  required String dosage,
  required int hour,
  required int minute,
}) {
  cancelWebReminder(medicineId);
  final next = _nextOccurrence(hour, minute);
  var delay = next.difference(DateTime.now());
  if (delay.inMilliseconds < 500) {
    delay = const Duration(seconds: 2);
  }
  _timers[medicineId] = Timer(delay, () async {
    await _showBrowserNotification(
      'Time to take $medicineName',
      'Dosage: $dosage',
    );
    scheduleWebReminder(
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      hour: hour,
      minute: minute,
    );
  });
}

void cancelWebReminder(String medicineId) {
  _timers[medicineId]?.cancel();
  _timers.remove(medicineId);
}

/// Shows the browser’s “allow notifications?” prompt when still in default state.
Future<bool> requestBrowserNotificationPermission() async {
  if (!html.Notification.supported) return false;
  var perm = html.Notification.permission;
  if (perm == 'default') {
    perm = await html.Notification.requestPermission();
  }
  return perm == 'granted';
}
