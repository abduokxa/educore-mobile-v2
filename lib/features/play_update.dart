import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// What Google Play says about this install. Only an install that came from Play can be updated in the app; an APK installed by hand
/// (or any other phone) answers "unknown" and the caller opens the download link instead.
class PlayUpdate {
  final bool available, flexible, immediate;
  final int priority;
  const PlayUpdate({this.available = false, this.flexible = false, this.immediate = false, this.priority = 0});

  static const none = PlayUpdate();

  /// A priority of 4 or 5 (set when the release is made in Play Console) means the update is important enough to take over the screen.
  bool get urgent => priority >= 4;
}

Future<PlayUpdate> checkPlayUpdate() async {
  if (kIsWeb || !Platform.isAndroid) return PlayUpdate.none;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) return PlayUpdate.none;
    return PlayUpdate(available: true, flexible: info.flexibleUpdateAllowed, immediate: info.immediateUpdateAllowed, priority: info.updatePriority);
  } catch (e) {
    debugPrint('Play update check: $e'); // not installed from Play, or Play is not available
    return PlayUpdate.none;
  }
}

/// Update inside the app. An urgent or required update is full-screen and finishes by itself; any other is downloaded while the person
/// carries on, then installed (the app restarts). Returns false when Play could not do it, so the caller can open the store page.
Future<bool> startPlayUpdate(PlayUpdate u, {bool must = false}) async {
  try {
    if ((must || u.urgent) && u.immediate) {
      return await InAppUpdate.performImmediateUpdate() == AppUpdateResult.success;
    }
    if (u.flexible) {
      if (await InAppUpdate.startFlexibleUpdate() != AppUpdateResult.success) return false;
      await InAppUpdate.completeFlexibleUpdate();
      return true;
    }
    if (u.immediate) return await InAppUpdate.performImmediateUpdate() == AppUpdateResult.success;
  } catch (e) {
    debugPrint('Play update: $e');
  }
  return false;
}
