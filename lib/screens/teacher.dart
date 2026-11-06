import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../features/pick.dart';
import '../shell/nav.dart';
import '../ui/ui.dart';

List _l(dynamic v) => (v as List?) ?? const [];

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'teacher/home',
        builder: (context, d, reload) {
          final register = d['register'];
          final todo = _l(d['todo']);
          return Screen(onRefresh: reload, children: [
            HeroBlock(title: 'My day', sub: d['today'] as String?, icon: 'today-outline'),
            ShortcutGrid([
              if (register != null) ShortcutItem('Register', () => Nav.I.go('Register'), hint: register['marked'] == true ? 'Marked' : (register['closed'] != null ? 'No school' : 'Not marked')),
              ShortcutItem('Scores', () => Nav.I.go('Scores')),
              ShortcutItem('Notices', () => Nav.I.go('Notices')),
            ]),
            ECard(title: 'To do today', icon: 'checkbox-outline', right: Pill(todo.isNotEmpty ? '${todo.length} to do' : 'All done', toneName: todo.isNotEmpty ? 'amber' : 'green'), children: [
              if (todo.isEmpty) const Muted('You are all caught up. Nothing is waiting for you today.'),
              for (var i = 0; i < todo.length; i++)
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (i > 0) const Padding(padding: EdgeInsets.only(bottom: 10), child: Rule()),
                  Tap(
                    label: '${todo[i]['title']}',
                    onTap: () => Nav.I.go(todo[i]['go'] == 'register' ? 'Register' : 'Scores'),
                    child: Row(children: [
                      IconBadge('${todo[i]['icon']}', size: 40, tint: tone('amber').fg, bg: tone('amber').bg),
                      const SizedBox(width: 12),
                      Expanded(child: TwoLine('${todo[i]['title']}', '${todo[i]['detail']}')),
                      Icn('chevron-forward', size: 18, tint: color.muted),
                    ]),
                  ),
                ]),
            ]),
            Columns([
              if (register != null)
                ECard(title: 'Register', icon: 'clipboard-outline', right: Pill(register['marked'] == true ? 'Marked' : (register['closed'] != null ? 'Closed' : 'Not marked'), toneName: register['marked'] == true ? 'green' : (register['closed'] != null ? 'grey' : 'amber')), children: [
                  Muted('${register['class']} · ${register['detail']}'),
                  if (register['marked'] != true && register['closed'] == null) AppButton('Mark the register', kind: BtnKind.soft, icon: 'checkmark-done-outline', onPressed: () => Nav.I.go('Register')),
                ]),
              ECard(title: "Today's lessons", icon: 'time-outline', children: [
                if (_l(d['periods']).isEmpty) const Muted('No lessons today.'),
                for (final p in _l(d['periods']))
                  LR(
                    left: p['is_break'] == true ? const Muted('Break') : TwoLine('${p['subject']}', '${p['class']} · ${p['room']}'),
                    right: Pill('${p['time']}', toneName: p['is_break'] == true ? 'grey' : 'blue'),
                  ),
              ]),
              ECard(title: 'Score entry', icon: 'create-outline', children: [
                for (final c in _l(d['classes']))
                  Builder(builder: (context) {
                    final students = (c['students'] as num);
                    final p = students > 0 ? ((c['entered'] as num) / students * 100).round() : 0;
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      LR(left: Text('${c['class']} · ${c['subject']}', style: Ty.body(w: FontWeight.w600)), right: Muted('${c['entered']}/${c['students']}')),
                      Bar(p.toDouble(), height: 5, tint: p == 100 ? color.brand : tone('amber').fg),
                    ]);
                  }),
              ]),
            ]),
          ]);
        },
      );
}

class TeacherRegister extends StatefulWidget {
  const TeacherRegister({super.key});
  @override
  State<TeacherRegister> createState() => _TeacherRegisterState();
}

class _TeacherRegisterState extends State<TeacherRegister> {
  String? _class, _date;
  bool _form = false;

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'teacher/register',
        query: {'class': _class, 'date': _date},
        builder: (context, d, reload) {
          if (_form) return _RegisterBody(data: d, reload: reload, change: () => setState(() => _form = false));
          final classes = _l(d['classes']);
          final closed = d['closed'] as String?;
          return Screen(onRefresh: reload, children: [
            const PageTitle('Mark attendance', sub: 'Choose the class and the day, then continue to the student list.'),
            ECard(title: 'Which register?', icon: 'options-outline', gap: 14, children: [
              if (classes.length > 1)
                PickGroup('Class', Chips<String>(title: 'Class', select: true, value: '${d['class']['id']}', onChange: (v) => setState(() => _class = v), options: [for (final c in classes) (value: '${c['id']}', label: '${c['name']}')]))
              else
                PickGroup('Class', Text('${d['class']['name']}', style: Ty.body(w: FontWeight.w700))),
              DateField(label: 'Day', value: '${d['date']}', onChange: (v) => setState(() => _date = v)),
              if (d['locked'] == true) Muted('This register was already submitted.'),
              if (closed != null)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconBadge('calendar-outline', size: 36, tint: tone('amber').fg, bg: tone('amber').bg),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('No attendance to mark', style: Ty.body(w: FontWeight.w700)), const SizedBox(height: 2), Text(closed, style: Ty.small())])),
                ]),
            ]),
            AppButton(closed != null ? 'Look at this register' : 'Continue', icon: 'arrow-forward', onPressed: () => setState(() => _form = true)),
          ]);
        },
      );
}

class _RegisterBody extends StatefulWidget {
  final dynamic data;
  final Future<void> Function() reload;
  final VoidCallback change;
  const _RegisterBody({required this.data, required this.reload, required this.change});
  @override
  State<_RegisterBody> createState() => _RegisterBodyState();
}

class _RegisterBodyState extends State<_RegisterBody> {
  late Map<String, String> _marks = _from(widget.data);

  Map<String, String> _from(dynamic d) => {for (final s in _l(d['students'])) '${s['id']}': '${s['status']}'};

  @override
  void didUpdateWidget(_RegisterBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.data, widget.data)) _marks = _from(widget.data);
  }

  Future<void> _save(bool submit) async {
    final d = widget.data;
    try {
      final r = await api('teacher/register', method: 'POST', body: {'class': d['class']['id'], 'date': d['date'], 'marks': _marks, 'submit': submit, 'alert_parents': true});
      notify.ok('${r['message'] ?? 'Saved'}');
      await widget.reload();
    } catch (e) {
      notify.err('Could not save', e is ApiError ? (e.errors['marks']?.first ?? e.message) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final locked = d['locked'] == true;
    final closed = d['closed'] as String?;
    final readOnly = locked || closed != null;
    int n(String m) => _marks.values.where((x) => x == m).length;
    final tones = {'present': color.brand, 'late': tone('amber').fg, 'absent': color.danger};
    const label = {'present': 'P', 'late': 'L', 'absent': 'A'};
    return Screen(
      onRefresh: widget.reload,
      footer: readOnly
          ? null
          : Row(children: [
              Expanded(flex: 10, child: AppButton('Save draft', kind: BtnKind.plain, onPressed: () => _save(false))),
              const SizedBox(width: 10),
              Expanded(flex: 14, child: AppButton('Submit register', icon: 'checkmark-done', onPressed: () => _save(true))),
            ]),
      children: [
        PageTitle('Mark attendance', sub: '${d['class']['name']} · ${d['date']}'),
        ChangeBar(summary: '${d['class']['name']} · ${d['date']}', onChange: widget.change),
        if (locked)
          ECard(children: [Row(children: [const IconBadge('lock-closed-outline'), const SizedBox(width: 12), Expanded(child: Text('This register was submitted. Only School Admin can change it now.', style: Ty.body()))])]),
        if (closed != null)
          ECard(children: [Row(children: [IconBadge('calendar-outline', tint: tone('amber').fg, bg: tone('amber').bg), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('No attendance to mark', style: Ty.body(w: FontWeight.w700)), const SizedBox(height: 2), Text(closed, style: Ty.body())]))])]),
        StatRow([
          Stat(icon: 'checkmark-circle-outline', label: 'Present', value: n('present')),
          Stat(icon: 'time-outline', label: 'Late', value: n('late'), tint: tone('amber').fg),
          Stat(icon: 'close-circle-outline', label: 'Absent', value: n('absent'), tint: tone('red').fg),
        ]),
        if (!readOnly) AppButton('Mark everyone present', kind: BtnKind.soft, icon: 'people-outline', onPressed: () => setState(() => _marks = {for (final s in _l(d['students'])) '${s['id']}': 'present'})),
        ListGroup([
          for (final s in _l(d['students']))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Avatar('${s['name']}', size: 36),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.body(w: FontWeight.w600)),
                  if ('${s['admission_no'] ?? ''}'.isNotEmpty) Text('${s['admission_no']}', maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: Ty.custom(12, FontWeight.w500, c: color.muted)),
                ])),
                for (final m in const ['present', 'late', 'absent'])
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tap(
                      scale: 0.88,
                      label: '${s['name']}: $m',
                      onTap: readOnly ? null : () => setState(() => _marks['${s['id']}'] = m),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: _marks['${s['id']}'] == m ? tones[m] : Colors.transparent, borderRadius: BorderRadius.circular(14), border: Border.all(color: tones[m]!, width: 1.5)),
                        alignment: Alignment.center,
                        child: Text(label[m]!, style: Ty.custom(14, FontWeight.w800, c: _marks['${s['id']}'] == m ? Colors.white : tones[m])),
                      ),
                    ),
                  ),
              ]),
            ),
        ]),
      ],
    );
  }
}

class TeacherScores extends StatefulWidget {
  const TeacherScores({super.key});
  @override
  State<TeacherScores> createState() => _TeacherScoresState();
}

class _TeacherScoresState extends State<TeacherScores> {
  String? _class, _subject, _component;
  bool _form = false;

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'teacher/scores',
        query: {'class': _class, 'subject': _subject, 'component': _component},
        builder: (context, d, reload) {
          if (_form) return _ScoresBody(data: d, reload: reload, change: () => setState(() => _form = false));
          return _ScoresPick(
            data: d,
            reload: reload,
            pick: (c, s, k) => setState(() { _class = c; _subject = s; _component = k; }),
            go: () => setState(() => _form = true),
          );
        },
      );
}

/// The step before the student list: the class, the subject and the exam, then Continue.
class _ScoresPick extends StatelessWidget {
  final dynamic data;
  final Future<void> Function() reload;
  final void Function(String? cls, String? subject, String? component) pick;
  final VoidCallback go;
  const _ScoresPick({required this.data, required this.reload, required this.pick, required this.go});

  @override
  Widget build(BuildContext context) {
    final options = _l(data['options']);
    final cls = '${data['class']['id']}';
    final seen = <String>{};
    final classes = [for (final o in options) if (seen.add('${o['class_id']}')) o];
    final subjects = [for (final o in options) if ('${o['class_id']}' == cls) o];
    final comps = _l(data['components']);
    final comp = data['component'];
    return Screen(onRefresh: reload, children: [
      const PageTitle('Enter scores', sub: 'Choose the class, the subject and the exam, then continue to the student list.'),
      ECard(title: 'Which scores?', icon: 'options-outline', gap: 14, children: [
        PickGroup('Class', Chips<String>(title: 'Class', select: true, value: cls, onChange: (v) => pick(v, null, '${comp['key']}'), options: [for (final o in classes) (value: '${o['class_id']}', label: '${o['class']}')])),
        PickGroup('Subject', Chips<String>(title: 'Subject', select: true, value: '${data['subject']['id']}', onChange: (v) => pick(cls, v, '${comp['key']}'), options: [for (final o in subjects) (value: '${o['subject_id']}', label: '${o['subject']}')])),
        PickGroup('Exam', Chips<String>(title: 'Exam', value: '${comp['key']}', onChange: (v) => pick(cls, '${data['subject']['id']}', v), options: [for (final k in comps) (value: '${k['key']}', label: '${k['short']}')])),
        Muted(comp['open'] == true ? 'Open for entry${comp['due'] != null ? ', due ${comp['due']}' : ''}.' : 'Not open for entry yet. You can still look at the list.'),
      ]),
      AppButton('Continue', icon: 'arrow-forward', onPressed: go),
    ]);
  }
}

class _ScoresBody extends StatefulWidget {
  final dynamic data;
  final Future<void> Function() reload;
  final VoidCallback change;
  const _ScoresBody({required this.data, required this.reload, required this.change});
  @override
  State<_ScoresBody> createState() => _ScoresBodyState();
}

class _ScoresBodyState extends State<_ScoresBody> {
  late Map<String, TextEditingController> _c = _make(widget.data);
  dynamic _preview;

  Map<String, TextEditingController> _make(dynamic d) {
    final key = d['component']['key'];
    return {for (final r in _l(d['rows'])) '${r['id']}': TextEditingController(text: r['scores'][key] == null ? '' : '${r['scores'][key]}')};
  }

  @override
  void didUpdateWidget(_ScoresBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.data, widget.data)) {
      for (final c in _c.values) {
        c.dispose();
      }
      _c = _make(widget.data);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _showPreview() async {
    final d = widget.data;
    try {
      final p = await api('teacher/scores/preview', query: {'class': '${d['class']['id']}', 'subject': '${d['subject']['id']}'});
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      notify.err('Could not load the sheet', e is ApiError ? e.message : null);
    }
  }

  Future<void> _save(bool submit) async {
    final d = widget.data;
    final scores = {for (final e in _c.entries) e.key: e.value.text.trim().isEmpty ? null : num.tryParse(e.value.text.trim().replaceAll(',', '.'))};
    try {
      final r = await api('teacher/scores', method: 'POST', body: {'class': d['class']['id'], 'subject': d['subject']['id'], 'component': d['component']['key'], 'scores': scores, 'comments': {}, 'submit': submit});
      notify.ok('${r['message'] ?? 'Saved'}');
      await widget.reload();
    } catch (e) {
      notify.err('Please check the scores', e is ApiError ? (e.errors['scores']?.first ?? e.message) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final comp = d['component'];
    final open = comp['open'] == true && d['locked'] != true;
    final entered = _c.values.where((c) => c.text.trim().isNotEmpty).length;
    final total = (d['total'] as num);
    return Screen(
      onRefresh: widget.reload,
      footer: open
          ? Row(children: [
              Expanded(flex: 10, child: AppButton('Save draft', kind: BtnKind.plain, onPressed: () => _save(false))),
              const SizedBox(width: 10),
              Expanded(flex: 14, child: AppButton(d['decline_note'] != null ? 'Resubmit' : 'Submit', icon: 'send', onPressed: () => _save(true))),
            ])
          : null,
      children: [
        PageTitle('Enter scores', sub: '${d['class']['name']} · ${d['subject']['name']}'),
        ChangeBar(summary: '${d['class']['name']} · ${d['subject']['name']} · ${comp['short']}', onChange: widget.change),
        if (d['decline_note'] != null) ECard(title: 'Sent back by School Admin', icon: 'return-up-back-outline', children: [Text('${d['decline_note']}', style: Ty.body())]),
        ECard(
          title: '${comp['short']}',
          icon: 'create-outline',
          children: [Align(alignment: Alignment.centerLeft, child: Pill(d['locked'] == true ? 'Submitted' : open ? 'Open · due ${comp['due']}' : 'Not open', toneName: d['locked'] == true ? 'blue' : open ? 'green' : 'grey')), Muted('Out of ${comp['max']} · $entered of ${d['total']} entered'), Bar(total > 0 ? entered / total * 100 : 0, height: 6)],
        ),
        ListGroup([
          for (final r in _l(d['rows']))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                SizedBox(width: 24, child: Text('${r['no']}', style: Ty.custom(14, FontWeight.w700, c: color.muted))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.body(w: FontWeight.w600)),
                  if ('${r['admission_no'] ?? ''}'.isNotEmpty) Text('Adm. no. ${r['admission_no']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.small()),
                ])),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _c['${r['id']}'],
                    enabled: open,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    textAlign: TextAlign.end,
                    style: Ty.custom(16, FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: '-',
                      isDense: true,
                      filled: true,
                      fillColor: open ? color.bg : Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.line)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.brand, width: 2)),
                    ),
                  ),
                ),
              ]),
            ),
        ]),
        AppButton(_preview != null ? 'Hide full sheet' : 'Preview full sheet', kind: BtnKind.soft, icon: _preview != null ? 'eye-off-outline' : 'eye-outline', onPressed: () async {
          if (_preview != null) {
            setState(() => _preview = null);
          } else {
            await _showPreview();
          }
        }),
        if (_preview != null) _SheetCard(p: _preview),
      ],
    );
  }
}

/// Every student with each assessment, the total and the grade, as the School Admin will review it.
class _SheetCard extends StatelessWidget {
  final dynamic p;
  const _SheetCard({required this.p});
  @override
  Widget build(BuildContext context) {
    final status = '${p['status']}';
    final comps = _l(p['components']);
    return ECard(
      title: '${p['subject']} · ${p['class']}',
      icon: 'grid-outline',
      right: Pill(status == 'approved' ? 'Approved' : status == 'submitted' ? 'Waiting' : 'Not submitted', toneName: status == 'approved' ? 'green' : status == 'submitted' ? 'amber' : 'grey'),
      children: [
        Muted('${p['stats']['entered']} of ${p['stats']['students']} entered · average ${p['stats']['average'] ?? '-'} · pass mark ${p['pass_mark']}'),
        for (var i = 0; i < _l(p['rows']).length; i++)
          Builder(builder: (context) {
            final r = _l(p['rows'])[i];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (i > 0) const Padding(padding: EdgeInsets.only(bottom: 4), child: Rule()),
              LR(
                left: TwoLine('${r['no']}. ${r['name']}', comps.map((c) => '${c['short']} ${r['scores'][c['key']] ?? '-'}').join('   ')),
                right: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${r['total'] ?? '-'}', style: Ty.custom(15, FontWeight.w800)),
                  if (r['grade'] != null && '${r['grade']}'.isNotEmpty) ...[const SizedBox(width: 8), Stamp('${r['grade']}', size: 30)],
                ]),
              ),
            ]);
          }),
      ],
    );
  }
}

/// The class teacher's own class results, once they are open to them.
class TeacherClassResults extends StatelessWidget {
  const TeacherClassResults({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'teacher/class-results',
        onError: (context, error, retry) {
          if (RegExp('not the class teacher', caseSensitive: false).hasMatch(error)) {
            return const Screen(children: [PageTitle('Class results'), Empty(icon: 'people-outline', title: 'You are not a class teacher', body: 'This page is for teachers who look after a class. Your own subjects are under Scores.')]);
          }
          return Loading(error: error, retry: retry);
        },
        builder: (context, d, reload) {
          if (d['ready'] != true) {
            return Screen(onRefresh: reload, children: [PageTitle('Class results', sub: d['class']?['name'] as String?), Empty(icon: 'hourglass-outline', title: 'Not open yet', body: d['message'] as String?)]);
          }
          final subjects = _l(d['subjects']);
          return Screen(onRefresh: reload, children: [
            PageTitle('Class results', sub: '${d['class']['name']} · ${d['term']?['name']}'),
            Align(alignment: Alignment.centerLeft, child: Pill('${d['status']}', toneName: d['status'] == 'Approved' || d['status'] == 'Published' ? 'green' : 'amber')),
            ListGroup([
              for (final r in _l(d['rows']))
                ListRow(
                  title: '${r['name']}',
                  sub: [for (var i = 0; i < subjects.length; i++) '${subjects[i]['code']} ${(r['cells'] as List)[i] ?? '-'}'].join('  '),
                  right: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [Text('${r['average']}', style: Ty.custom(15, FontWeight.w800)), Muted('${r['position']}')]),
                ),
            ]),
          ]);
        },
      );
}
