import 'words.dart';

/// What this school's plan allows, read from the session the school sent. The school decides; the app only shows it.
/// A feature that is on but "read-only" can be looked at but not changed (the subscription has ended).
class Ent {
  Ent._();
  static final Ent I = Ent._();

  Map _modules = const {};
  Map _states = const {};

  void set(Map? session) {
    final school = session?['school'] as Map?;
    _modules = (school?['modules'] as Map?) ?? const {};
    _states = (school?['entitlements'] as Map?) ?? const {};
    Words.set(session);
  }

  bool on(String key) => _modules[key] == true;
  bool readonly(String key) => on(key) && (_states[key] as Map?)?['m'] == 'readonly';
  bool writable(String key) => on(key) && !readonly(key);
  String? reason(String key) => (_states[key] as Map?)?['r'] as String?;
}
