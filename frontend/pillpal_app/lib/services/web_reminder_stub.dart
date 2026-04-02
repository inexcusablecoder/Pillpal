/// Mobile / VM — real scheduling uses [NotificationService].
void scheduleWebReminder({
  required String medicineId,
  required String medicineName,
  required String dosage,
  required int hour,
  required int minute,
}) {}

void cancelWebReminder(String medicineId) {}

/// No-op on mobile; web implementation requests Notification API access.
Future<bool> requestBrowserNotificationPermission() async => false;
