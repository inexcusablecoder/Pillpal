import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _medicineChannelId = 'medicine_reminders';
  static const _refillChannelId = 'refill_alerts';

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Notification tap handled in main.dart via navigatorKey
      },
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedules a daily local notification for a medicine at its scheduled time.
  Future<void> scheduleMedicineReminder({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
  }) async {
    final parts = scheduledTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // Use medicineId hash as notification ID (must be int)
    final notifId = medicineId.hashCode.abs() % 100000;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      notifId,
      'Time for your medicine! 💊',
      'Take your $medicineName $dosage now',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _medicineChannelId,
          'Medicine Reminders',
          channelDescription: 'Daily reminders to take your medicines',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  /// Cancels a scheduled notification for a medicine (e.g., when medicine is deleted).
  Future<void> cancelMedicineReminder(String medicineId) async {
    final notifId = medicineId.hashCode.abs() % 100000;
    await _plugin.cancel(notifId);
  }

  /// Shows an immediate notification for refill alert.
  Future<void> showRefillAlert(String medicineName, int pillCount) async {
    await _plugin.show(
      medicineName.hashCode.abs() % 100000 + 90000,
      '⚠️ Medicine running low',
      '$medicineName has only $pillCount pill(s) left. Time to refill!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _refillChannelId,
          'Refill Alerts',
          channelDescription: 'Alerts when medicine stock is running low',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
