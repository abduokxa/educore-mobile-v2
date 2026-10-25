import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'api.dart';
import 'offline.dart';
import 'prefetch.dart';

const _periodic = 'educore.sync.periodic';
const _soon = 'educore.sync.soon';

/// The phone wakes the app's sync by itself, even when the app was never opened: once a connection is there, writes saved with no signal
/// are sent, and the lists and documents are refreshed behind the scenes (see Prefetch).
///   - Android: a periodic job about every 15 minutes plus a one-time job that runs as soon as there is a connection.
///   - iPhone: iOS decides when, usually when the phone is charging or on Wi-Fi, so it can be later than on Android.
@pragma('vm:entry-point')
void backgroundEntry() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      if (!await restore()) return true; // signed out: nothing to do
      await Offline.I.loadFlag();
      if (!Offline.I.enabled || !Offline.I.background) return true; // the owner has not given this school background sync
      final sent = await syncOutbox();
      final session = await recallSession();
      String? role;
      if (session is Map) role = (session['active_role'] as Map?)?['workspace'] as String?;
      if (role != null) await Prefetch.run(role: role, force: task == _soon);
      if (sent > 0) await _tell('Saved items sent', sent == 1 ? 'The school has received what you saved on this phone.' : 'The school has received the $sent items you saved on this phone.');
      return true;
    } catch (_) {
      return false; // try again later
    }
  });
}

Future<void> _tell(String title, String body) async {
  try {
    final p = FlutterLocalNotificationsPlugin();
    await p.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification'), iOS: DarwinInitializationSettings()));
    await p.show(
      id: 7001,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('default', 'School notices', importance: Importance.defaultImportance, icon: '@drawable/ic_notification'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  } catch (_) {/* notifications are not allowed: the items were still sent */}
}

class BackgroundSync {
  static bool _ready = false;
  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await Workmanager().initialize(backgroundEntry);
      _ready = true;
    } catch (e) {
      debugPrint('Background sync is not available: $e');
    }
  }

  /// After signing in (and each time the app starts signed in): the regular job.
  static Future<void> start() async {
    if (!Offline.I.background) return;
    await init();
    if (!_ready) return;
    try {
      await Workmanager().registerPeriodicTask(
        _periodic,
        _periodic,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {}
  }

  /// Something was saved on the phone, or the app is leaving: send it the moment there is a connection, app open or not.
  static Future<void> nudge() async {
    if (!Offline.I.background) return;
    await init();
    if (!_ready) return;
    try {
      await Workmanager().registerOneOffTask(
        _soon,
        _soon,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        initialDelay: const Duration(seconds: 3),
      );
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!_ready) return;
    try {
      await Workmanager().cancelAll();
    } catch (_) {}
  }
}
