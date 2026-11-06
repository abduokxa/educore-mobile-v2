import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../core/api.dart';
import 'version.dart';

bool _crashlytics = false;
int _sent = 0;
final Set<String> _seen = {};

/// Tell the platform owner when something breaks in the app. Each kind of error is sent once, and never more than a handful a session.
Future<void> reportError(String name, String message, [String? where]) async {
  final key = '$name|$message|${where ?? ''}';
  if (_seen.contains(key) || _sent >= 8 || message.isEmpty || !signedIn) return;
  _seen.add(key);
  _sent += 1;
  String clip(String s, int n) => s.length > n ? s.substring(0, n) : s;
  try {
    await api('app-errors', method: 'POST', body: {'name': clip(name, 80), 'message': clip(message, 500), 'where': where == null ? null : clip(where, 300), 'url': 'mobile app', 'version': await appVersion()});
  } catch (_) {}
}

/// Crash reports to Firebase Crashlytics (release builds only), so crashes the platform could never see (the app closing by itself, native
/// errors) are visible too. Quiet if Firebase is not set up: the app then still reports through [reportError].
Future<void> startCrashReporting() async {
  if (kIsWeb || !kReleaseMode) return;
  try {
    await Firebase.initializeApp();
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    _crashlytics = true;
  } catch (e) {
    debugPrint('Crashlytics is off: $e');
  }
}

/// Catch errors nobody handled, report them, and let the app carry on.
void startErrorReporting() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_crashlytics) FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    reportError(details.exception.runtimeType.toString(), details.exceptionAsString(), details.stack?.toString().split('\n').first);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_crashlytics) FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    reportError(error.runtimeType.toString(), '$error', stack.toString().split('\n').first);
    return kReleaseMode;
  };
}
