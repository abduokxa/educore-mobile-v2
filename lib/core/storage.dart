import 'dart:convert';
import 'package:cryptography/cryptography.dart';
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


/// Everything the phone keeps for offline use (saved screens, the outbox, saved documents) is sealed with a key that lives in the
/// Keychain / Keystore, so the files and preferences on their own are not readable. Text is kept as "enc1:" and base64.
class Vault {
  static final _aes = AesGcm.with256bits();
  static Future<SecretKey>? _key;

  static Future<SecretKey> _k() => _key ??= () async {
        final saved = await Secure.get('vault_key');
        if (saved != null) {
          try {
            return SecretKey(base64Decode(saved));
          } catch (_) {/* unreadable: make a new one */}
        }
        final fresh = await _aes.newSecretKey();
        await Secure.set('vault_key', base64Encode(await fresh.extractBytes()));
        return fresh;
      }();

  static Future<List<int>> sealBytes(List<int> plain) async => (await _aes.encrypt(plain, secretKey: await _k())).concatenation();

  /// Null when the data cannot be opened (the key was lost, or it was changed).
  static Future<List<int>?> openBytes(List<int> sealed) async {
    try {
      return await _aes.decrypt(SecretBox.fromConcatenation(sealed, nonceLength: 12, macLength: 16), secretKey: await _k());
    } catch (_) {
      return null;
    }
  }

  static Future<String> seal(String plain) async => 'enc1:${base64Encode(await sealBytes(utf8.encode(plain)))}';

  /// Text saved before sealing existed is read as it is.
  static Future<String?> open(String raw) async {
    if (!raw.startsWith('enc1:')) return raw;
    try {
      final b = await openBytes(base64Decode(raw.substring(5)));
      return b == null ? null : utf8.decode(b);
    } catch (_) {
      return null;
    }
  }

  /// For tests: forget the key held in memory.
  static void forget() => _key = null;
}

/// Larger saved copies (screens, the session, the offline outbox) live in ordinary app storage.
class Store {
  static SharedPreferences? _p;

  /// For tests: forget the preferences held in memory, so a fresh set can be loaded.
  static void forget() => _p = null;
  static Future<SharedPreferences> get _prefs async => _p ??= await SharedPreferences.getInstance();

  static Future<String?> get(String key) async {
    try {
      final raw = (await _prefs).getString(key);
      return raw == null ? null : await Vault.open(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String key, String value) async {
    try {
      await (await _prefs).setString(key, await Vault.seal(value));
    } catch (_) {}
  }

  static Future<void> remove(String key) async {
    try {
      await (await _prefs).remove(key);
    } catch (_) {}
  }

  /// Remove every saved value whose name starts with [prefix].
  static Future<void> removeWithPrefix(String prefix) async {
    try {
      final p = await _prefs;
      for (final k in p.getKeys().where((k) => k.startsWith(prefix)).toList()) {
        await p.remove(k);
      }
    } catch (_) {}
  }

  static Future<void> removeAll(Iterable<String> keys) async {
    for (final k in keys) {
      await remove(k);
    }
  }
}
