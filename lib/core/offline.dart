import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage.dart';

/// Weak-network support (feature: offline_mobile).
/// - Every list the app loads is kept on the phone, so it can still be read with no signal.
/// - Registers and scores saved with no signal wait in an outbox and are sent when the phone is back online.
/// Both only run when the school has the feature switched on.
class Queued {
  final String id, path, method;
  final dynamic body;
  final int at;
  Queued(this.id, this.path, this.method, this.body, this.at);
  Map<String, dynamic> toJson() => {'id': id, 'path': path, 'method': method, 'body': body, 'at': at};
  factory Queued.fromJson(Map<String, dynamic> j) => Queued(j['id'] as String, j['path'] as String, j['method'] as String, j['body'], j['at'] as int);
}

sealed class SendResult {}

class Sent extends SendResult {}

class StillOffline extends SendResult {}

class Refused extends SendResult {
  final String note;
  Refused(this.note);
}

class Offline extends ChangeNotifier {
  Offline._();
  static final Offline I = Offline._();

  bool enabled = false;
  String school = '';
  bool _flushing = false;

  /// Writes that are safe to repeat: saving the same register or scores twice gives the same result.
  static const _queueable = {'teacher/register', 'teacher/scores'};
  static const _maxAge = Duration(days: 14);

  void setEnabled(bool on, String address) {
    enabled = on;
    school = address;
    notifyListeners();
    // Remember the choice so the next start, which may be offline, can still use the saved copy of the person's session.
    Secure.set('offline_enabled', on ? '1|$address' : '0');
  }

  /// Read the remembered choice before the first request of a cold start.
  Future<void> loadFlag() async {
    final v = await Secure.get('offline_enabled');
    if (v != null && v.startsWith('1|')) {
      enabled = true;
      school = v.substring(2);
    }
  }

  String _cacheKey(String path, String qs) => 'cache:$school:$path$qs';
  String get _outbox => 'outbox:$school';
  String get _notes => 'outbox-notes:$school';

  Future<void> cachePut(String path, String qs, dynamic data) async {
    if (!enabled) return;
    await Store.set(_cacheKey(path, qs), jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'data': data}));
  }

  Future<({dynamic data, int at})?> cacheGet(String path, String qs) async {
    if (!enabled) return null;
    try {
      final raw = await Store.get(_cacheKey(path, qs));
      if (raw == null) return null;
      final v = jsonDecode(raw) as Map<String, dynamic>;
      final at = v['at'] as int;
      if (DateTime.now().millisecondsSinceEpoch - at > _maxAge.inMilliseconds) return null;
      return (data: v['data'], at: at);
    } catch (_) {
      return null;
    }
  }

  bool canQueue(String path, String method) => enabled && method == 'POST' && _queueable.contains(path);

  Future<List<Queued>> _read() async {
    try {
      final raw = await Store.get(_outbox);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Queued.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Queued> rows) async {
    await Store.set(_outbox, jsonEncode(rows.map((r) => r.toJson()).toList()));
    notifyListeners();
  }

  String _same(dynamic b) => b is Map ? jsonEncode([b['class'], b['date'], b['subject'], b['component']]) : '';

  /// Keep a write for later. A newer save of the same thing replaces the older one.
  Future<void> enqueue(String path, String method, dynamic body) async {
    final rows = (await _read()).where((r) => !(r.path == path && _same(r.body) == _same(body))).toList();
    rows.add(Queued('${DateTime.now().millisecondsSinceEpoch}-${rows.length}', path, method, body, DateTime.now().millisecondsSinceEpoch));
    await _write(rows);
  }

  Future<int> pending() async => (await _read()).length;

  /// Things that could not be sent because the school refused them. Shown once, then cleared.
  Future<List<String>> takeNotes() async {
    try {
      final raw = await Store.get(_notes);
      await Store.remove(_notes);
      return raw == null ? [] : (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Send what is waiting, oldest first. Stops at the first network failure; a write the school refuses
  /// (for example a register already submitted) is dropped with a note so it cannot block the rest.
  Future<int> flush(Future<SendResult> Function(Queued q) send) async {
    if (!enabled || _flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final rows = await _read();
      final left = <Queued>[];
      final notes = <String>[];
      for (var i = 0; i < rows.length; i++) {
        final r = await send(rows[i]);
        if (r is Sent) {
          sent++;
          continue;
        }
        if (r is StillOffline) {
          left.addAll(rows.sublist(i));
          break;
        }
        if (r is Refused) notes.add(r.note);
      }
      await _write(left);
      if (notes.isNotEmpty) {
        final old = await Store.get(_notes);
        final all = [...(old == null ? <String>[] : (jsonDecode(old) as List).cast<String>()), ...notes];
        await Store.set(_notes, jsonEncode(all));
      }
    } finally {
      _flushing = false;
    }
    return sent;
  }
}
