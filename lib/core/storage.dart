import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Keychain / Keystore for small secrets (the sign-in token, the chosen school). Anything it cannot reach is simply not remembered.
class Secure {
  static const _s = FlutterSecureStorage();

  static Future<String?> get(String key) async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String key, String value) async {
    try {
      await _s.write(key: key, value: value);
    } catch (_) {}
  }

  static Future<void> delete(String key) async {
    try {
      await _s.delete(key: key);
    } catch (_) {}
  }
}

/// Larger saved copies (screens, the session, the offline outbox) live in ordinary app storage.
class Store {
  static SharedPreferences? _p;
  static Future<SharedPreferences> get _prefs async => _p ??= await SharedPreferences.getInstance();

  static Future<String?> get(String key) async {
    try {
      return (await _prefs).getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String key, String value) async {
    try {
      await (await _prefs).setString(key, value);
    } catch (_) {}
  }

  static Future<void> remove(String key) async {
    try {
      await (await _prefs).remove(key);
    } catch (_) {}
  }

  static Future<void> removeAll(Iterable<String> keys) async {
    for (final k in keys) {
      await remove(k);
    }
  }
}
