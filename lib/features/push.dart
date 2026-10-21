import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/api.dart';
import '../core/net.dart';
import '../core/storage.dart';

/// Whether this phone can and does receive notices: on, switched off in the phone's settings, not registered yet, or not possible here.
enum PushState { on, off, denied, unavailable }

const _key = 'push_token';
const _channel = AndroidNotificationChannel('default', 'School notices', description: 'Notices, bills, results and absence alerts from the school', importance: Importance.high);

/// Phone notifications through Firebase (FCM). The Notices tab always works; this adds the buzz on the phone.
/// Without Firebase on the device (no google-services.json in the build, the web, a simulator) it reports "unavailable"
/// and the Account page hides the card.
class PushService {
  static bool _ready = false;
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static void Function(String? href)? _onOpen;

  /// Starts Firebase, shows notices that arrive while the app is open, and opens the right screen when one is tapped.
  /// [onOpen] gets the page the notice is about (like /parent/fees), or null.
  static Future<void> init({required void Function(String? href) onOpen}) async {
    _onOpen = onOpen;
    if (_ready || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;
      await _local.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification'), iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false)),
        onDidReceiveNotificationResponse: (r) => _onOpen?.call(r.payload),
      );
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
      // While the app is open the phone does not draw FCM notices itself, so draw it, and refresh the screens (a receipt, a new result).
      FirebaseMessaging.onMessage.listen((m) {
        Refresh.I.bump();
        final n = m.notification;
        if (n == null) return;
        _local.show(
          id: m.hashCode,
          title: n.title,
          body: n.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(_channel.id, _channel.name, channelDescription: _channel.description, importance: Importance.high, priority: Priority.high, icon: '@drawable/ic_notification'),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: m.data['href'] as String?,
        );
      });
      // Tapped while the app was in the background, or closed.
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _onOpen?.call(m.data['href'] as String?));
      final first = await fm.getInitialMessage();
      if (first != null) _onOpen?.call(first.data['href'] as String?);
      // The classic FCM address is used (the server sends to it with Firebase's HTTP v1 API); the newer Installation-ID calls are not needed.
      // ignore: deprecated_member_use
      fm.onTokenRefresh.listen((_) => register());
      _ready = true;
    } catch (e) {
      debugPrint('Push is not available: $e');
    }
  }

  /// Ask permission, get this phone's Firebase address and tell the school's server. Fails quietly.
  static Future<void> register() async {
    if (!_ready) return;
    try {
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // ignore: deprecated_member_use
      final token = await fm.getToken();
      if (token == null) return;
      await api('devices', method: 'POST', body: {'token': token, 'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'});
      await Secure.set(_key, token);
    } catch (_) {/* push is a bonus; the Notices tab still works */}
  }

  static Future<PushState> status() async {
    if (!_ready) return PushState.unavailable;
    try {
      final s = (await FirebaseMessaging.instance.getNotificationSettings()).authorizationStatus;
      if (s == AuthorizationStatus.denied) return PushState.denied;
      if (s == AuthorizationStatus.notDetermined) return PushState.off;
      return (await Secure.get(_key)) != null ? PushState.on : PushState.off;
    } catch (_) {
      return PushState.unavailable;
    }
  }

  /// Ask again (or register again) and report how it went. A phone that said no for good must be changed in its settings.
  static Future<PushState> enable() async {
    await register();
    return status();
  }

  /// Ask the school's server to send this phone a test notice.
  static Future<({bool ok, String message})> sendTest() async {
    try {
      final r = await api('devices/test', method: 'POST');
      return (ok: r['ok'] == true, message: '${r['message']}');
    } catch (e) {
      return (ok: false, message: e is ApiError ? e.message : 'Could not send the test notice.');
    }
  }

  static Future<void> unregister() async {
    try {
      final token = await Secure.get(_key);
      if (token != null) await api('devices', method: 'DELETE', body: {'token': token});
      await Secure.delete(_key);
    } catch (_) {}
  }
}
