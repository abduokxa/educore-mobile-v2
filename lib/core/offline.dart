import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'background.dart';
import 'storage.dart';

/// Weak-network support (feature: offline_mobile).
/// - Every list the app loads is kept on the phone, so it can still be read with no signal.
/// - Registers and scores saved with no signal wait in an outbox and are sent when the phone is back online.
/// Both only run when the school has the feature switched on.
/// "5 minutes ago", "2 hours ago", "yesterday", or the date.
String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'} ago';
  if (d.inHours < 24) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  return '${t.day}/${t.month}/${t.year}';
}

class Queued {
  final String id, path, method;
  final dynamic body;
  final int at;

  /// A line for the person: what this saved write is ("₦25,000 from Amina Bello").
  final String? label;
  Queued(this.id, this.path, this.method, this.body, this.at, [this.label]);
  Map<String, dynamic> toJson() => {'id': id, 'path': path, 'method': method, 'body': body, 'at': at, 'label': label};
  factory Queued.fromJson(Map<String, dynamic> j) => Queued(j['id'] as String, j['path'] as String, j['method'] as String, j['body'], j['at'] as int, j['label'] as String?);
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

  /// The platform owner switches each of these per school: [enabled] is saved screens and registers/scores waiting to be sent;
  /// [docs] keeps receipts, bills and report cards on the phone; [background] lets the phone save and send by itself, app open or not;
  /// [payments] lets a bursar record a payment with no signal.
  bool enabled = false, docs = false, background = false, payments = false;
  String school = '';
  bool _flushing = false;

  /// Writes that are safe to repeat: saving the same register or scores twice gives the same result, and a payment carries a key
  /// from the phone, so the school records it once however many times it is sent.
  static const _queueable = {'teacher/register', 'teacher/scores', 'payments'};
  static const _maxAge = Duration(days: 14);

  void setEnabled(bool on, String address, {bool? docs, bool? background, bool? payments}) {
    enabled = on;
    school = address;
    this.docs = on && (docs ?? on);
    this.background = on && (background ?? on);
    this.payments = on && (payments ?? on);
    notifyListeners();
    // Remember the choices so the next start, which may be offline, and the phone's background job know them before asking the school.
    Secure.set('offline_enabled', on ? '2|$address|${this.docs ? 1 : 0}${this.background ? 1 : 0}${this.payments ? 1 : 0}' : '0');
  }

  /// Read the remembered choices before the first request of a cold start.
  Future<void> loadFlag() async {
    final v = await Secure.get('offline_enabled');
    if (v == null) return;
    if (v.startsWith('2|')) {
      final parts = v.split('|');
      enabled = true;
      school = parts[1];
      final f = parts.length > 2 ? parts[2] : '000';
      docs = f.isNotEmpty && f[0] == '1';
      background = f.length > 1 && f[1] == '1';
      payments = f.length > 2 && f[2] == '1';
    } else if (v.startsWith('1|')) {
      // Saved by an older version of the app: it had everything on.
      enabled = docs = background = payments = true;
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

  /// Remove every saved screen and anything waiting to be sent, for this school. Done when the person signs out.
  Future<void> wipe() async {
    await Store.removeWithPrefix('cache:$school:');
    await Store.removeAll([_outbox, _notes, 'prefetch:last:$school']);
    notifyListeners();
  }

  bool canQueue(String path, String method) => enabled && method == 'POST' && _queueable.contains(path) && (path != 'payments' || payments);

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

  /// What makes two saved writes "the same thing": a payment is its key; a register or a score list is its class, day, subject and exam.
  String _same(dynamic b) {
    if (b is! Map) return '';
    if (b['client_key'] != null) return 'key:${b['client_key']}';
    return jsonEncode([b['class'], b['date'], b['subject'], b['component']]);
  }

  /// Keep a write for later. A newer save of the same thing replaces the older one.
  Future<void> enqueue(String path, String method, dynamic body, {String? label}) async {
    final rows = (await _read()).where((r) => !(r.path == path && _same(r.body) == _same(body))).toList();
    rows.add(Queued('${DateTime.now().millisecondsSinceEpoch}-${rows.length}', path, method, body, DateTime.now().millisecondsSinceEpoch, label));
    await _write(rows);
    // Even if the app is closed before the signal comes back, the phone sends it then.
    if (background) unawaited(BackgroundSync.nudge());
  }

  /// The writes waiting for [path], oldest first.
  Future<List<Queued>> waiting(String path) async => (await _read()).where((r) => r.path == path).toList();

  /// Take a saved write back, so it is not sent.
  Future<void> discard(String id) async => _write((await _read()).where((r) => r.id != id).toList());

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
