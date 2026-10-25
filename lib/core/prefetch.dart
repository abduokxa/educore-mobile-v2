import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'docstore.dart';
import 'offline.dart';
import 'storage.dart';

class _Stop implements Exception {}

/// Gets what a person is likely to need with no signal, quietly, while there is a connection: the main screens, the lists behind them
/// and the documents (receipts, bills, report cards, payslips). It runs after signing in, when the connection comes back, when the app
/// is opened after a while, and from the phone's background schedule even if the app is closed. Nothing waits on it: screens open from
/// what is already saved, and it never shows a spinner.
class Prefetch {
  static bool _running = false;

  /// Switched on by the screenshot and widget tests, which must not start a long background save.
  static bool paused = false;
  static const _every = Duration(minutes: 25);
  static const _perPage = '15';

  /// Changes whenever a run finishes, so the Profile screen can show when things were last saved.
  static final ValueNotifier<DateTime?> last = ValueNotifier(null);

  static String _lastKey() => 'prefetch:last:${currentAddress()}';

  static Future<DateTime?> lastRun() async {
    final v = await Store.get(_lastKey());
    final ms = v == null ? null : int.tryParse(v);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static bool get running => _running;

  /// [role] is parent, teacher, student or bursar. A run started within the last 25 minutes is skipped unless [force] is set.
  static Future<void> run({required String role, bool force = false}) async {
    if (paused || _running || !Offline.I.enabled || !signedIn) return;
    final was = await lastRun();
    if (!force && was != null && DateTime.now().difference(was) < _every) return;
    _running = true;
    try {
      await _plan(role);
      final now = DateTime.now();
      await Store.set(_lastKey(), '${now.millisecondsSinceEpoch}');
      last.value = now;
    } on _Stop {
      // The connection went away part-way: what was saved so far stays, and the next run carries on.
    } catch (e) {
      debugPrint('Prefetch: $e');
    } finally {
      _running = false;
    }
  }

  // ---- helpers -------------------------------------------------------------------------------------------------------

  /// One read. A failure the school answers (a feature switched off, nothing there) is ignored; losing the connection stops the run.
  static Future<dynamic> _get(String path, [Map<String, String?>? query]) async {
    try {
      final d = await api(path, query: query);
      // With no connection the saved copy comes back instead of an error: that is the sign to stop.
      if (lastStaleAt != null) throw _Stop();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      return d;
    } on ApiError catch (e) {
      if (e.status == 0) throw _Stop();
      return null;
    }
  }

  /// A document fetched and kept. Receipts never change, so a saved one is left alone; the others are fetched again when older than six hours.
  static Future<void> _doc(String path, [Map<String, String?> query = const {}, String name = 'document']) async {
    if (!Offline.I.docs) return;
    final key = DocStore.keyOf(path, query);
    final age = await DocStore.age(key);
    final steady = path.contains('receipt');
    if (age != null && (steady || age < const Duration(hours: 6))) return;
    try {
      final res = await http.get(Uri.parse(fileUrl(path, query)), headers: authHeaders()).timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) {
        await DocStore.save(path, query, res.bodyBytes, name);
      } else if (res.statusCode >= 500) {
        return;
      }
    } catch (_) {
      throw _Stop();
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  static List _l(dynamic v) => (v is List) ? v : const [];

  static Map<String, String?> _page(int n, {String? tab}) => {'page': '$n', 'per_page': _perPage, 'tab': ?tab};

  // ---- what each role gets ---------------------------------------------------------------------------------------------

  static Future<void> _plan(String role) async {
    final terms = await _get('terms');
    final current = terms is Map ? terms['current'] as String? : null;
    switch (role) {
      case 'parent':
        return _parent(current);
      case 'teacher':
        return _teacher();
      case 'student':
        return _student(current);
      case 'bursar':
        return _bursar();
    }
  }

  static Future<void> _common() async {
    await _get('inbox');
    await _get('calendar');
  }

  static Future<void> _parent(String? current) async {
    await _get('parent/home');
    final kids = _l((await _get('parent/kids'))?['kids']);
    await _get('parent/notices');
    await _common();
    await _get('parent/chats');
    await _get('parent/meetings');
    await _get('parent/notifications');
    for (final k in kids) {
      final child = '${k['id']}';
      if (current != null) {
        final fees = await _get('parent/fees', {'child': child, 'term': current});
        for (final b in [..._l(fees?['bills']), ..._l(fees?['past_bills'])]) {
          await _doc('parent/bill', {'invoice': '${b['id']}'}, 'bill-${b['number'] ?? b['id']}');
          if (b['receipt_id'] != null) await _doc('parent/receipts/${b['receipt_id']}', const {}, 'receipt-${b['receipt']}');
        }
        await _doc('parent/statement', {'child': child}, 'fee-statement');
        await _get('parent/attendance', {'child': child, 'term': current});
      }
      // The report card of this term, and of the last few terms the school has published a result for.
      final now = current == null ? null : await _get('parent/results', {'child': child, 'term': current});
      if (current != null && now != null && now['card'] != null) await _doc('parent/results/pdf', {'child': child, 'term': current}, 'report-card');
      for (final h in _l(now?['history']).take(4)) {
        final t = '${h['term_id']}';
        if (t == current) continue;
        final r = await _get('parent/results', {'child': child, 'term': t});
        if (r != null && r['card'] != null) await _doc('parent/results/pdf', {'child': child, 'term': t}, 'report-card');
      }
    }
  }

  static Future<void> _student(String? current) async {
    await _get('student/home');
    await _get('student/notices');
    await _common();
    final now = current == null ? null : await _get('student/results', {'term': current});
    if (current != null && now != null && now['card'] != null) await _doc('student/results/pdf', {'term': current}, 'report-card');
    for (final h in _l(now?['history']).take(4)) {
      final t = '${h['term_id']}';
      if (t == current) continue;
      final r = await _get('student/results', {'term': t});
      if (r != null && r['card'] != null) await _doc('student/results/pdf', {'term': t}, 'report-card');
    }
  }

  static Future<void> _teacher() async {
    await _get('teacher/home');
    await _common();
    await _get('teacher/chats');
    await _get('teacher/meetings');
    // Today's register of every class, so a register can be marked with no signal.
    final reg = await _get('teacher/register');
    if (reg is Map) {
      for (final c in _l(reg['classes']).take(16)) {
        await _get('teacher/register', {'class': '${c['id']}', 'date': '${reg['date']}'});
      }
    }
    // The score lists: each class and subject, each exam open for entry.
    final scores = await _get('teacher/scores');
    if (scores is Map) {
      for (final o in _l(scores['options']).take(30)) {
        final base = {'class': '${o['class_id']}', 'subject': '${o['subject_id']}'};
        final one = await _get('teacher/scores', {...base, 'component': null});
        for (final c in _l(one?['components'])) {
          if (c['open'] == true) await _get('teacher/scores', {...base, 'component': '${c['key']}'});
        }
      }
    }
    final slips = await _get('me/payslips');
    for (final p in _l(slips?['rows'] ?? slips?['data']).take(3)) {
      await _doc('me/payslips/${p['id']}/pdf', const {}, 'payslip-${p['month']}');
    }
  }

  static Future<void> _bursar() async {
    await _get('bursar');
    await _common();
    final seen = <String>{};
    // Who owes: the first pages of each tab, and the bill of the first few.
    for (final tab in ['all', 'overdue', 'part', 'unpaid']) {
      for (var n = 1; n <= (tab == 'all' ? 3 : 1); n++) {
        final d = await _get('defaulters', _page(n, tab: tab));
        if (d == null || n >= ((d['meta']?['last_page'] as num?) ?? 1)) {
          if (d != null) await _bills(_l(d['data']).take(8), seen);
          break;
        }
        await _bills(_l(d['data']).take(8), seen);
      }
    }
    // Every bill: the first pages, each tab.
    for (final tab in ['all', 'overdue', 'unpaid', 'part', 'paid']) {
      for (var n = 1; n <= (tab == 'all' ? 3 : 1); n++) {
        final d = await _get('invoices', _page(n, tab: tab));
        if (d == null) break;
        await _bills(_l(d['data']).take(8), seen);
        if (n >= ((d['meta']?['last_page'] as num?) ?? 1)) break;
      }
    }
    // Payments and their receipts.
    for (var n = 1; n <= 3; n++) {
      final d = await _get('payments', _page(n));
      if (d == null) break;
      for (final p in _l(d['data']).take(12)) {
        if (p['has_receipt'] == true) await _doc('payments/${p['id']}/receipt', const {}, 'receipt-${p['receipt']}');
      }
      if (n >= ((d['meta']?['last_page'] as num?) ?? 1)) break;
    }
    final slips = await _get('me/payslips');
    for (final p in _l(slips?['rows'] ?? slips?['data']).take(3)) {
      await _doc('me/payslips/${p['id']}/pdf', const {}, 'payslip-${p['month']}');
    }
  }

  /// The detail and the PDF of a bill, once each.
  static Future<void> _bills(Iterable rows, Set<String> seen) async {
    for (final r in rows) {
      final id = '${r['id']}';
      if (!seen.add(id)) continue;
      await _get('invoices/$id');
      await _doc('invoices/$id/pdf', const {}, 'bill-${r['number'] ?? id}');
    }
  }
}
