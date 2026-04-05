// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Same hostname as the Flutter web app (e.g. localhost vs 127.0.0.1).
/// Calling 127.0.0.1 from a page served as localhost breaks in some browsers
/// (different origin + private-network rules); keep API host aligned with the page.
String webApiBaseOrigin() {
  final host = html.window.location.hostname;
  final safeHost =
      (host == null || host.isEmpty) ? '127.0.0.1' : host;
  return 'http://$safeHost:8000';
}
