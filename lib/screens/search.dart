import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../shell/nav.dart';
import '../ui/ui.dart';

class Shortcut {
  final String label, tab;
  const Shortcut(this.label, this.tab);
}

/// Search what you may open: your students, and the screens of the app.
class Search extends StatefulWidget {
  final List<Shortcut> shortcuts;
  const Search({super.key, required this.shortcuts});
  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final _q = TextEditingController();
  List? _hits;
  Timer? _t;
  int _run = 0;

  @override
  void dispose() {
    _t?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    _t?.cancel();
    if (v.trim().length < 2) {
      setState(() => _hits = null);
      return;
    }
    final id = ++_run;
    _t = Timer(const Duration(milliseconds: 250), () async {
      try {
        final r = await api('search', query: {'q': v.trim()});
        if (mounted && id == _run) setState(() => _hits = r as List);
      } catch (_) {
        if (mounted && id == _run) setState(() => _hits = []);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final needle = _q.text.trim().toLowerCase();
    final pages = widget.shortcuts.where((s) => needle.isEmpty || s.label.toLowerCase().contains(needle)).toList();
    return Screen(children: [
      const PageTitle('Search', sub: 'Find a student or a screen.'),
      Field(icon: 'search-outline', label: 'Search', controller: _q, hint: 'Search students and screens', autocorrect: false, action: TextInputAction.search, onChanged: _changed),
      if ((_hits ?? []).isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Students'),
          const SizedBox(height: 8),
          ListGroup([for (final h in _hits!) ListRow(icon: 'person-outline', title: '${h['title']}', sub: '${h['detail']}', onPress: () => Nav.I.go('Register'))]),
        ]),
      if (_hits != null && _hits!.isEmpty && pages.isEmpty) Empty(icon: 'search-outline', title: 'Nothing found for “${_q.text}”', body: 'Check the spelling or try fewer letters.'),
      if (pages.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Go to'),
          const SizedBox(height: 8),
          ListGroup([for (final p in pages) ListRow(icon: iconFor(p.label), title: p.label, onPress: () => Nav.I.go(p.tab))]),
        ]),
    ]);
  }
}
