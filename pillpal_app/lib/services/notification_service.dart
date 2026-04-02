import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize TimeZones natively
      tz_data.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // 2. Initialize Android Settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(initSettings);

      // 3. Request permissions for Android 13+
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();

      _isInitialized = true;
      log("NotificationService initialized successfully", name: "Notification");
    } catch (e) {
      log("Failed to initialize NotificationService: $e", name: "Notification");
    }
  }

  /// Calculates the next occurrence of the given time in the local timezone.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedule a daily alarm. Uses absolute hashes for unique integer IDs.
  Future<void> scheduleDailyMedicineReminder({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required int hour,
    required int minute,
  }) async {
    if (!_isInitialized) await init();

    final int notificationId = medicineId.hashCode;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_medicine_reminders', // channel id
      'Medicine Reminders', // channel name
      channelDescription: 'Daily alerts to take scheduled medicines',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    final tz.TZDateTime scheduleTime = _nextInstanceOfTime(hour, minute);

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Time to take $medicineName!',
        'Dosage: $dosage',
        scheduleTime,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );
      log("Scheduled ID $notificationId ($medicineName) at $hour:$minute daily",
          name: "Notification");
    } catch (e) {
      log("Failed to schedule notification: $e", name: "Notification");
    }
  }

  /// Cancels a specific existing medication schedule
  Future<void> cancelReminder(String medicineId) async {
    try {
      final int id = medicineId.hashCode;
      await _notificationsPlugin.cancel(id);
      log("Cancelled notification ID $id", name: "Notification");
    } catch (e) {
      log("Failed to cancel: $e", name: "Notification");
    }
  }
}
