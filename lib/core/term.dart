import 'package:flutter/foundation.dart';
import 'api.dart';
import 'storage.dart';

class TermRow {
  final String id, name, label, status;
  final String? starts, ends;
  final bool isCurrent;
  TermRow(this.id, this.name, this.label, this.starts, this.ends, this.isCurrent, this.status);
  factory TermRow.from(Map<String, dynamic> j) => TermRow(j['id'] as String, '${j['name']}', '${j['label']}', j['starts'] as String?, j['ends'] as String?, j['is_current'] == true, '${j['status'] ?? ''}');
}

class SessionRow {
  final String id, name;
  final bool isCurrent;
  final List<TermRow> terms;
  SessionRow(this.id, this.name, this.isCurrent, this.terms);
}

/// The session and term everything in the app is looking at. Chosen once; every screen follows it until the person goes back to the current one.
class Terms extends ChangeNotifier {
  Terms._();
  static final Terms I = Terms._();

  String? current;
  String? viewing;
  List<SessionRow> sessions = [];
  bool loaded = false;

  String get _key => 'viewed_term:${currentAddress()}';

  /// The term (with its session) the app is looking at right now.
  ({TermRow row, String session, bool past})? get shown {
    if (!loaded) return null;
    final id = viewing ?? current;
    for (final s in sessions) {
      for (final t in s.terms) {
        if (t.id == id) return (row: t, session: s.name, past: viewing != null && viewing != current);
      }
    }
    return null;
  }

  void _parse(dynamic d) {
    current = d['current'] as String?;
    sessions = (d['sessions'] as List)
        .map((s) => SessionRow(s['id'] as String, '${s['name']}', s['is_current'] == true, (s['terms'] as List).map((t) => TermRow.from(t as Map<String, dynamic>)).toList()))
        .toList();
    loaded = true;
  }

  bool _has(String? id) => id != null && sessions.any((s) => s.terms.any((t) => t.id == id));

  /// Before the first screen is drawn: the term the person chose last time, so the saved copies of their screens are the right ones.
  Future<void> prime() async {
    setTermHeader(await Secure.get(_key));
  }

  /// Called after signing in: remembers the person's choice from last time, and loads the sessions and terms.
  Future<void> load() async {
    final saved = await Secure.get(_key);
    setTermHeader(saved);
    // What was loaded last time is used at once; the school's answer replaces it a moment later.
    final old = peek('terms');
    if (old != null && !loaded) {
      _parse(old);
      viewing = _has(saved) && saved != current ? saved : null;
      notifyListeners();
    }
    try {
      final d = await api('terms');
      _parse(d);
      if (saved != null && !_has(saved)) {
        setTermHeader(null);
        await Secure.delete(_key);
      }
      viewing = _has(saved) && saved != current ? saved : null;
      setTermHeader(viewing);
    } catch (_) {
      loaded = false;
      viewing = null;
      setTermHeader(null);
    }
    notifyListeners();
  }

  void reset() {
    loaded = false;
    sessions = [];
    current = null;
    viewing = null;
    setTermHeader(null);
    notifyListeners();
  }

  /// Look at another term, or pass null to go back to the current one.
  void choose(String? id) {
    if (!loaded) return;
    final next = id != null && id != current ? id : null;
    viewing = next;
    setTermHeader(next);
    next != null ? Secure.set(_key, next) : Secure.delete(_key);
    notifyListeners();
  }
}
