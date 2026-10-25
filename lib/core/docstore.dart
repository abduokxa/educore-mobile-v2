import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'api.dart';
import 'offline.dart';
import 'storage.dart';

/// Documents (receipts, bills, report cards, statements, payslips) kept on the phone, sealed, so they open with no signal.
/// They are fetched quietly in the background (see Prefetch) as soon as there is a connection, not when the person asks.
class DocStore {
  static const _maxFiles = 220;
  static const _maxBytes = 90 * 1024 * 1024;

  static String _school() => currentAddress();
  static String _indexKey() => 'docs:index:${_school()}';

  /// What identifies a document: its path and options, the same text the download would use.
  static String keyOf(String path, Map<String, String?> query) {
    final q = query.entries.where((e) => e.value != null && e.value != '').toList()..sort((a, b) => a.key.compareTo(b.key));
    return '$path?${q.map((e) => '${e.key}=${e.value}').join('&')}';
  }

  static String _fileId(String key) {
    // Not a cryptographic hash: just a short, stable file name for the key.
    var h = 0x811c9dc5;
    for (final c in '${_school()}|$key'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return '${h.toRadixString(16).padLeft(8, '0')}-${key.length}';
  }

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/saved-docs');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<Map<String, dynamic>> _index() async {
    try {
      final raw = await Store.get(_indexKey());
      return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeIndex(Map<String, dynamic> i) => Store.set(_indexKey(), jsonEncode(i));

  /// How long ago a document was saved, or null when it is not.
  static Future<Duration?> age(String key) async {
    final e = (await _index())[key];
    return e == null ? null : DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(e['at'] as int));
  }

  static Future<bool> has(String path, Map<String, String?> query) async => (await _index()).containsKey(keyOf(path, query));

  /// A saved document, opened into a temporary file the viewer can read. Null when there is none.
  static Future<File?> find(String path, Map<String, String?> query, String name) async {
    try {
      final i = await _index();
      final e = i[keyOf(path, query)];
      if (e == null) return null;
      final f = File('${(await _dir()).path}/${e['file']}');
      if (!await f.exists()) return null;
      final plain = await Vault.openBytes(await f.readAsBytes());
      if (plain == null) return null;
      final tmp = await getTemporaryDirectory();
      final out = File('${tmp.path}/${_safe(name)}.pdf');
      await out.writeAsBytes(plain, flush: true);
      return out;
    } catch (_) {
      return null;
    }
  }

  static String _safe(String name) {
    final s = name.replaceAll(RegExp(r'[^\w.-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'document' : s;
  }

  static Future<void> save(String path, Map<String, String?> query, List<int> bytes, String name) async {
    if (!Offline.I.docs) return;
    try {
      final key = keyOf(path, query);
      final id = _fileId(key);
      final f = File('${(await _dir()).path}/$id');
      final sealed = await Vault.sealBytes(bytes);
      await f.writeAsBytes(sealed, flush: true);
      final i = await _index();
      i[key] = {'file': id, 'name': name, 'at': DateTime.now().millisecondsSinceEpoch, 'size': sealed.length};
      await _trim(i);
      await _writeIndex(i);
    } catch (_) {/* storage full: the document is simply not kept */}
  }

  /// Oldest first goes when there are too many files or too many bytes.
  static Future<void> _trim(Map<String, dynamic> i) async {
    int total() => i.values.fold<int>(0, (a, e) => a + ((e['size'] as num?)?.toInt() ?? 0));
    while (i.length > _maxFiles || total() > _maxBytes) {
      final oldest = i.entries.reduce((a, b) => (a.value['at'] as int) <= (b.value['at'] as int) ? a : b);
      try {
        final f = File('${(await _dir()).path}/${oldest.value['file']}');
        if (await f.exists()) await f.delete();
      } catch (_) {}
      i.remove(oldest.key);
    }
  }

  static Future<({int count, int bytes, DateTime? last})> summary() async {
    final i = await _index();
    var last = 0, bytes = 0;
    for (final e in i.values) {
      bytes += (e['size'] as num?)?.toInt() ?? 0;
      if ((e['at'] as int) > last) last = e['at'] as int;
    }
    return (count: i.length, bytes: bytes, last: last == 0 ? null : DateTime.fromMillisecondsSinceEpoch(last));
  }

  /// Signing out removes everything kept for this school.
  static Future<void> clear() async {
    try {
      final d = await _dir();
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
    await Store.remove(_indexKey());
  }
}
