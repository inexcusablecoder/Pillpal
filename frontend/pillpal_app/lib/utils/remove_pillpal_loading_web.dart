// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Hides the HTML splash in [web/index.html] after Flutter has painted.
void removePillpalLoadingOverlay() {
  html.document.getElementById('pillpal-loading')?.remove();
}
