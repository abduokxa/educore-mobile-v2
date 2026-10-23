/// The words learning and exams use for this person's school and class level ("e-class" or "learning area", "assignment" or
/// "classwork"). The school sends them with the session. Text is written with tokens like {course}, {Lessons} or {exam}, and [w]
/// fills them in; a capital first letter capitalises the word and a trailing s asks for the plural.
class Words {
  Words._();
  /// What shows before the school's words arrive (the secondary set).
  static const Map<String, List<String>> _fallback = {
    'course': ['e-class', 'e-classes'], 'topic': ['topic', 'topics'], 'lesson': ['lesson', 'lessons'], 'assignment': ['assignment', 'assignments'], 'learn': ['e-learning', 'e-learning'], 'learning': ['e-learning', 'e-learning'],
    'test': ['test', 'tests'], 'exam': ['exam', 'exams'], 'cbt': ['computer-based exam', 'computer-based exams'],
  };
  static Map<String, List<String>> _map = _fallback;

  static void set(Map? session) {
    final raw = (session?['school'] as Map?)?['words'];
    _map = raw is Map && raw.isNotEmpty ? {for (final e in raw.entries) '${e.key}': [for (final x in (e.value as List)) '$x']} : _fallback;
  }

  static String fmt(String text) {
    if (!text.contains('{')) return text;
    return text.replaceAllMapped(RegExp(r'\{([A-Za-z]+)\}'), (m) {
      final name = m[1]!;
      var key = name[0].toLowerCase() + name.substring(1);
      var plural = false;
      if (!_map.containsKey(key) && key.endsWith('s') && _map.containsKey(key.substring(0, key.length - 1))) {
        key = key.substring(0, key.length - 1);
        plural = true;
      }
      final pair = _map[key];
      if (pair == null || pair.length < 2) return m[0]!;
      final w = pair[plural ? 1 : 0];
      return RegExp(r'[A-Z]').hasMatch(name[0]) && w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w;
    });
  }
}

/// Fill the {tokens} in a sentence with this school's words.
String w(String text) => Words.fmt(text);
