import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests only normal runtime permissions.
///
/// El-Nemr Language deliberately avoids broad all-files access.
/// Local browsing uses Android's Storage Access Framework/MediaStore so users
/// keep control over which folders the app can access.
Future<void> requestStartupPermissions(BuildContext context) async {
  if (!Platform.isAndroid) return;
  try {
    await Permission.videos.request();
    await Permission.notification.request();
  } catch (_) {
    // Best-effort. File pickers and playback flows can request scoped access
    // later when the user explicitly chooses a local source.
  }
}
