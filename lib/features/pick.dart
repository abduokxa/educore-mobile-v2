import 'package:flutter/material.dart';
import '../core/term.dart';
import '../ui/ui.dart';

/// What the person chose on the "choose, then continue" step.
class Choice {
  final String? child, childName;
  final String session, term, termName;
  final VoidCallback change;
  final void Function(String session, String term) select;
  const Choice({this.child, this.childName, required this.session, required this.term, required this.termName, required this.change, required this.select});

  String get summary => [?childName, session, termName].where((x) => x.isNotEmpty).join(' · ');

  /// A line under the page title saying what is shown, with a way back to the form.
  Widget get bar => Row(children: [
        Icn('options-outline', size: 16, tint: color.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.small(w: FontWeight.w600))),
        Tap(
          label: 'Change child, session or term',
          onTap: change,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: color.tint, borderRadius: BorderRadius.circular(18)),
            alignment: Alignment.center,
            child: Text('Change', style: Ty.custom(13, FontWeight.w800, c: color.brand)),
          ),
        ),
      ]);
}

/// The step before results, fees and attendance: pick the child (when there is more than one), the session and the term,
/// then Continue. Only after that does the page itself load, so nobody lands on the wrong child or term.
class PickGate extends StatefulWidget {
  final String title;
  final bool kids;
  final Widget Function(BuildContext context, Choice choice) builder;
  const PickGate({super.key, required this.title, this.kids = false, required this.builder});
  @override
  State<PickGate> createState() => _PickGateState();
}

class _PickGateState extends State<PickGate> {
  Choice? _chosen;
  String? _child, _session, _term;

  Choice _make(String? child, String? childName, SessionRow s, TermRow t) => Choice(
        child: child,
        childName: childName,
        session: s.name,
        term: t.id,
        termName: t.name,
        change: () => setState(() => _chosen = null),
        select: (session, term) {
          final next = Terms.I.sessions.where((x) => x.name == session).firstOrNull;
          final tm = next?.terms.where((x) => x.id == term).firstOrNull;
          if (next != null && tm != null) setState(() => _chosen = _make(child, childName, next, tm));
        },
      );

  Widget _form(List kids) {
    final sessions = Terms.I.sessions;
    final startId = Terms.I.viewing ?? Terms.I.current;
    final first = sessions.where((s) => s.terms.any((t) => t.id == startId)).firstOrNull ?? sessions.where((s) => s.isCurrent).firstOrNull ?? sessions.first;
    final s = sessions.where((x) => x.name == _session).firstOrNull ?? first;
    final t = s.terms.where((x) => x.id == _term).firstOrNull ?? s.terms.where((x) => x.id == startId).firstOrNull ?? s.terms.first;
    final kid = kids.cast<dynamic>().where((k) => k['id'] == _child).firstOrNull ?? (kids.isEmpty ? null : kids.first);
    return Screen(children: [
      PageTitle(widget.title, sub: 'Choose what you want to see, then continue.'),
      ECard(title: 'What would you like to see?', icon: 'options-outline', gap: 14, children: [
        if (widget.kids && kids.length > 1)
          _group('Child', Chips<String>(title: 'Child', select: true, value: '${kid['id']}', onChange: (v) => setState(() => _child = v), options: [for (final k in kids) (value: '${k['id']}', label: '${k['name']}')])),
        if (widget.kids && kids.length == 1) _group('Child', Text('${kids.first['name']}', style: Ty.body(w: FontWeight.w700))),
        _group('Session', Chips<String>(title: 'Session', select: true, value: s.name, onChange: (v) => setState(() { _session = v; _term = null; }), options: [for (final x in sessions) (value: x.name, label: x.isCurrent ? '${x.name} (current)' : x.name)])),
        _group('Term', Chips<String>(title: 'Term', select: true, value: t.id, onChange: (v) => setState(() => _term = v), options: [for (final x in s.terms) (value: x.id, label: x.isCurrent ? '${x.name} (current)' : x.name)])),
      ]),
      AppButton('Continue', icon: 'arrow-forward', disabled: widget.kids && kid == null, onPressed: () => setState(() => _chosen = _make(widget.kids ? '${kid['id']}' : null, widget.kids ? '${kid['name']}' : null, s, t))),
    ]);
  }

  Widget _group(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Ty.small(w: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ]);

  @override
  Widget build(BuildContext context) {
    final c = _chosen;
    if (c != null) return widget.builder(context, c);
    return ListenableBuilder(
      listenable: Terms.I,
      builder: (context, _) {
        if (!Terms.I.loaded || Terms.I.sessions.isEmpty) return const Center(child: Spinner(size: 26));
        if (!widget.kids) return _form(const []);
        return LoadView(path: 'parent/kids', builder: (context, d, reload) => _form((d['kids'] as List?) ?? const []));
      },
    );
  }
}

/// A line under a page title saying what is shown, with a button back to the choose-then-continue form.
class ChangeBar extends StatelessWidget {
  final String summary, label;
  final VoidCallback onChange;
  const ChangeBar({super.key, required this.summary, required this.onChange, this.label = 'Change'});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icn('options-outline', size: 16, tint: color.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ty.small(w: FontWeight.w600))),
        Tap(
          label: label,
          onTap: onChange,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: color.tint, borderRadius: BorderRadius.circular(18)),
            alignment: Alignment.center,
            child: Text('Change', style: Ty.custom(13, FontWeight.w800, c: color.brand)),
          ),
        ),
      ]);
}

/// A labelled group on a pick form.
class PickGroup extends StatelessWidget {
  final String label;
  final Widget child;
  const PickGroup(this.label, this.child, {super.key});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Ty.small(w: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ]);
}
