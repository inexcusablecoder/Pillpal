// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Desktop notification when the tab may be in the background (web only).
void tryShowBrowserReminder({required String title, required String body}) {
  if (!html.Notification.supported) return;
  final perm = html.Notification.permission;
  if (perm == 'granted') {
    html.Notification(title, body: body, tag: 'pillpal-reminder');
  } else if (perm == 'default') {
    html.Notification.requestPermission().then((p) {
      if (p == 'granted') {
        html.Notification(title, body: body, tag: 'pillpal-reminder');
      }
    });
  }
}
