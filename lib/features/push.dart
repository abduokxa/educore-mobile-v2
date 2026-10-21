import '../core/api.dart';
import '../core/storage.dart';

/// Whether this phone can and does receive notices: on, switched off in the phone's settings, not registered yet, or not possible here.
enum PushState { on, off, denied, unavailable }

const _key = 'push_token';

/// Notices from the school also arrive in the Notices tab inside the app. Phone notifications need a Firebase project
/// (see the README): until the app is built with one, this reports "unavailable" and the Account page hides the card.
class PushService {
  /// Set by the Firebase glue when it is present; null means this build has no push.
  static Future<String?> Function()? tokenProvider;

  static Future<void> register() async {
    final get = tokenProvider;
    if (get == null) return;
    try {
      final token = await get();
      if (token == null) return;
      await api('devices', method: 'POST', body: {'token': token, 'platform': 'android', 'kind': 'fcm'});
      await Secure.set(_key, token);
    } catch (_) {/* push is a bonus; the Notices tab still works */}
  }

  static Future<PushState> status() async {
    if (tokenProvider == null) return PushState.unavailable;
    return (await Secure.get(_key)) != null ? PushState.on : PushState.off;
  }

  static Future<PushState> enable() async {
    await register();
    return status();
  }

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
