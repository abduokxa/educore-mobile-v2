import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/entitle.dart';
import '../features/gate.dart';
import '../ui/ui.dart';

List _l(dynamic v) => (v as List?) ?? const [];
void _fail(Object e, String title) => notify.err(title, e is ApiError ? e.message : null);

const _stateInfo = {
  'open': ('Open', 'green'), 'resume': ('In progress', 'amber'), 'done': ('Done', 'blue'), 'missed': ('Missed', 'red'), 'ended': ('Ended', 'grey'), 'soon': ('Not open yet', 'grey'),
};

/// Quick tests and scheduled exams. An exam can have written answers, a start time, shuffled questions and a pass mark, if the school's plan includes them.
class StudentTests extends StatefulWidget {
  const StudentTests({super.key});
  @override
  State<StudentTests> createState() => _StudentTestsState();
}

class _StudentTestsState extends State<StudentTests> {
  dynamic _taking, _review, _intro;

  Future<bool> _leave() => confirm(context, title: 'Leave the test?', message: 'Your answers so far are saved and the time keeps running. You can come back and continue.', yes: 'Leave', no: 'Stay', destructive: true);

  @override
  Widget build(BuildContext context) {
    if (_taking != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _leave()) setState(() => _taking = null);
        },
        child: WithBack(
          onBack: () async {
            if (await _leave()) setState(() => _taking = null);
          },
          label: 'Tests',
          child: _TakeTest(test: _taking, onDone: () => setState(() => _taking = null)),
        ),
      );
    }
    if (_review != null) return WithBack(onBack: () => setState(() => _review = null), label: 'Tests', child: _Review(data: _review));
    if (_intro != null) {
      return WithBack(
        onBack: () => setState(() => _intro = null),
        label: 'Tests',
        child: Screen(children: [
          PageTitle('${_intro['title']}', sub: '${_intro['subject'] ?? ''} · before you start'),
          ECard(children: [
            Text('${_intro['questions']} questions${_intro['timed'] == true ? ', ${_intro['minutes']} minutes' : ''}.', style: Ty.h3()),
            Text(_intro['timed'] == true ? 'The clock starts when you press Start and cannot be paused.' : 'Hand in before the exam closes.', style: Ty.body()),
            Text('You can take this exam once. Your answers are saved as you go, so if your connection drops you can continue. When time is up, what you have answered is handed in for you.', style: Ty.body()),
            if ((_intro['instructions'] as String?)?.isNotEmpty == true) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.tint, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('From your teacher', style: Ty.small(w: FontWeight.w800)), const SizedBox(height: 4), Text('${_intro['instructions']}', style: Ty.body())])),
          ]),
          AppButton('Start the exam', icon: 'play', onPressed: () async {
            final id = '${_intro['id']}';
            setState(() => _intro = null);
            await _begin(id);
          }),
        ]),
      );
    }
    return LoadView(
      path: 'student/tests',
      builder: (context, d, reload) {
        Future<void> look(String id) async {
          try {
            final r = await api('student/tests/$id/review');
            setState(() => _review = r);
          } catch (e) {
            _fail(e, 'Could not open the answers');
          }
        }

        return Screen(onRefresh: reload, children: [
          PageTitle(Ent.I.on('cbt.enabled') ? 'Tests and exams' : 'Tests', sub: 'Take a test when it is open, and see your answers after.'),
          if (_l(d['rows']).isEmpty) const Empty(icon: 'document-text-outline', title: 'Nothing for your class yet', body: 'They appear here when a teacher sets one.'),
          for (final t in _l(d['rows']))
            ECard(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconBadge(t['kind'] == 'exam' ? 'school-outline' : 'document-text-outline', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${t['title']}', style: Ty.h3()),
                    const SizedBox(height: 3),
                    Muted([t['subject'], '${t['questions']} questions', if (t['timed'] != false) '${t['minutes']} minutes', if (t['state'] == 'soon' && t['opens'] != null) 'opens ${t['opens']}' else if (t['closes'] != null) 'closes ${t['closes']}'].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
                  ]),
                ),
                if (t['kind'] == 'exam') const Pill('Exam', toneName: 'blue'),
              ]),
              LR(
                left: Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill(_stateInfo['${t['state']}']?.$1 ?? '${t['state']}', toneName: _stateInfo['${t['state']}']?.$2 ?? 'grey'),
                  if (t['result'] == 'marking') const Pill('Being marked', toneName: 'amber'),
                  if (t['result'] == 'held') const Pill('Result not released yet', toneName: 'amber'),
                  if (t['result'] == 'shown' && t['passed'] != null) Pill(t['passed'] == true ? 'Passed' : 'Below pass mark', toneName: t['passed'] == true ? 'green' : 'red'),
                ]),
                right: t['result'] == 'shown' ? Text.rich(TextSpan(children: [TextSpan(text: '${t['score']}', style: Ty.custom(18, FontWeight.w800)), TextSpan(text: ' / ${t['total']}', style: Ty.small())])) : null,
              ),
              if (t['state'] == 'open' || t['state'] == 'resume')
                AppButton(t['state'] == 'resume' ? 'Continue' : 'Start', icon: 'play', onPressed: () {
                  if (t['state'] == 'open' && t['kind'] == 'exam') {
                    setState(() => _intro = t);
                  } else {
                    _begin('${t['id']}');
                  }
                }),
              if (t['can_review'] == true) AppButton('See the answers', kind: BtnKind.soft, icon: 'eye-outline', onPressed: () => look('${t['id']}')),
            ]),
        ]);
      },
    );
  }

  Future<void> _begin(String id) async {
    try {
      final r = await api('student/tests/$id/start', method: 'POST');
      if (mounted) setState(() => _taking = {'id': id, ...Map<String, dynamic>.from(r as Map)});
    } catch (e) {
      _fail(e, 'Could not start the test');
    }
  }
}

/// One attempt. The school keeps the real clock; this one is only a guide. Answers are kept safe on the server every few seconds.
class _TakeTest extends StatefulWidget {
  final dynamic test;
  final VoidCallback onDone;
  const _TakeTest({required this.test, required this.onDone});
  @override
  State<_TakeTest> createState() => _TakeTestState();
}

class _TakeTestState extends State<_TakeTest> {
  late int _left = (widget.test['seconds_left'] as num).toInt();
  late final bool _timed = widget.test['timed'] != false;
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _text = {};
  bool _busy = false, _sent = false, _dirty = false;
  String _saved = '';
  late final StreamSubscription<int> _tick;
  Timer? _saver;

  @override
  void initState() {
    super.initState();
    final saved = widget.test['saved'];
    if (saved is Map) {
      saved.forEach((k, v) {
        _answers['$k'] = v;
        if (v is String) _text['$k'] = TextEditingController(text: v);
      });
    }
    _tick = Stream<int>.periodic(const Duration(seconds: 1), (i) => i).listen((_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_timed && _left <= 0) _submit();
    });
    _saver = Timer.periodic(const Duration(seconds: 6), (_) => _save());
  }

  @override
  void dispose() {
    _tick.cancel();
    _saver?.cancel();
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_dirty || _sent) return;
    _dirty = false;
    try {
      await api('student/tests/${widget.test['id']}/save', method: 'PUT', body: {'answers': _answers});
      if (mounted) setState(() => _saved = 'saved');
    } catch (_) {
      _dirty = true;
      if (mounted) setState(() => _saved = 'offline');
    }
  }

  Future<void> _submit() async {
    if (_sent) return;
    _sent = true;
    setState(() => _busy = true);
    try {
      final r = await api('student/tests/${widget.test['id']}/submit', method: 'POST', body: {'answers': _answers});
      notify.ok('Submitted', '${r['message']}');
    } catch (e) {
      _sent = false;
      _fail(e, 'Could not submit');
      if (mounted) setState(() => _busy = false);
      return;
    }
    widget.onDone();
  }

  bool _has(String id) => _answers[id] != null && '${_answers[id]}'.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final qs = _l(widget.test['questions']);
    final answered = qs.where((q) => _has('${q['id']}')).length;
    final mm = (_left < 0 ? 0 : _left) ~/ 60, ss = (_left < 0 ? 0 : _left) % 60;
    return Screen(
      footer: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Bar(qs.isNotEmpty ? answered / qs.length * 100 : 0, height: 6),
        const SizedBox(height: 8),
        AppButton('Submit ($answered of ${qs.length} answered)', icon: 'checkmark-done', busy: _busy, onPressed: _submit),
      ]),
      children: [
        PageTitle('${widget.test['title']}'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_timed) Pill('Time left $mm:${ss.toString().padLeft(2, '0')}', toneName: _left < 60 ? 'red' : 'amber'),
          if (_saved == 'saved') const Pill('Saved', toneName: 'green'),
          if (_saved == 'offline') const Pill('Not saved: check your connection', toneName: 'red'),
        ]),
        for (var n = 0; n < qs.length; n++)
          ECard(children: [
            Text('${n + 1}. ${qs[n]['body']}', style: Ty.h3()),
            if (qs[n]['type'] == 'theory')
              Field(
                label: 'Your answer',
                controller: _text.putIfAbsent('${qs[n]['id']}', () => TextEditingController()),
                multiline: true,
                rows: 6,
                onChanged: (v) => setState(() {
                  _answers['${qs[n]['id']}'] = v;
                  _dirty = true;
                }),
              )
            else
              for (var i = 0; i < _l(qs[n]['options']).length; i++)
                Builder(builder: (context) {
                  final on = _answers['${qs[n]['id']}'] == i;
                  return Tap(
                    scale: 0.985,
                    label: 'Option ${String.fromCharCode(65 + i)}',
                    onTap: () => setState(() {
                      _answers['${qs[n]['id']}'] = i;
                      _dirty = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: on ? color.tint : color.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? color.brand : color.line, width: 1.5)),
                      child: Row(children: [
                        Container(width: 28, height: 28, decoration: BoxDecoration(color: on ? color.brand : color.bg, shape: BoxShape.circle), alignment: Alignment.center, child: Text(String.fromCharCode(65 + i), style: Ty.custom(13, FontWeight.w800, c: on ? color.onBrand : color.muted))),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${_l(qs[n]['options'])[i]}', style: Ty.body())),
                      ]),
                    ),
                  );
                }),
          ]),
      ],
    );
  }
}

class _Review extends StatelessWidget {
  final dynamic data;
  const _Review({required this.data});
  @override
  Widget build(BuildContext context) => Screen(children: [
        PageTitle('${data['title']}', sub: 'You scored ${data['score']} out of ${data['total']}${data['percent'] != null ? ' (${data['percent']}%)' : ''}'),
        if (data['passed'] != null) Align(alignment: Alignment.centerLeft, child: Pill(data['passed'] == true ? 'Passed' : 'Below the pass mark of ${data['pass_mark']}%', toneName: data['passed'] == true ? 'green' : 'red')),
        for (var n = 0; n < _l(data['questions']).length; n++)
          Builder(builder: (context) {
            final q = _l(data['questions'])[n];
            final theory = q['type'] == 'theory';
            return ECard(children: [
              Row(children: [
                Expanded(child: Text('${n + 1}. ${q['body']}', style: Ty.h3())),
                if (theory && q['got'] != null) Pill('${q['got']} of ${q['marks']}', toneName: q['got'] == q['marks'] ? 'green' : (q['got'] == 0 ? 'red' : 'amber')),
              ]),
              if (theory) ...[
                Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.line)), child: Text((q['answer'] as String?)?.isNotEmpty == true ? '${q['answer']}' : 'You did not answer this one.', style: Ty.body())),
                if ((q['guide'] as String?)?.isNotEmpty == true) Text('What the teacher looked for: ${q['guide']}', style: Ty.small()),
              ] else
                for (var i = 0; i < _l(q['options']).length; i++)
                  Builder(builder: (context) {
                    final right = i == q['correct'];
                    final wrong = i == q['chosen'] && !right;
                    final t = tone(right ? 'green' : wrong ? 'red' : 'grey');
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: right || wrong ? t.bg : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icn(right ? 'checkmark-circle' : wrong ? 'close-circle' : 'ellipse-outline', size: 20, tint: right || wrong ? t.fg : color.muted),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${String.fromCharCode(65 + i)}. ${_l(q['options'])[i]}${wrong ? '  (your answer)' : ''}', style: Ty.body(c: right || wrong ? t.fg : color.ink, w: right || wrong ? FontWeight.w700 : FontWeight.w400))),
                      ]),
                    );
                  }),
              if ((q['comment'] as String?)?.isNotEmpty == true) Text('Teacher\'s comment: ${q['comment']}', style: Ty.body(w: FontWeight.w600)),
              if ((q['explanation'] as String?)?.isNotEmpty == true) Text('Explanation: ${q['explanation']}', style: Ty.small()),
            ]);
          }),
      ]);
}

/// A teacher marks the written answers of an exam on the phone: the exams with answers waiting, who handed in, and a score for each answer.
class TeacherMarking extends StatefulWidget {
  const TeacherMarking({super.key});
  @override
  State<TeacherMarking> createState() => _TeacherMarkingState();
}

class _TeacherMarkingState extends State<TeacherMarking> {
  dynamic _exam, _attempt;
  int _bump = 0;

  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('cbt.manual_grading')) return const LockedView(title: 'Mark exams', feature: 'cbt.manual_grading');
    if (_attempt != null) {
      return WithBack(
        onBack: () => setState(() {
          _attempt = null;
          _bump++;
        }),
        label: 'Students',
        child: _MarkAttempt(key: ValueKey('${_exam['id']}${_attempt['id']}'), test: '${_exam['id']}', attempt: '${_attempt['id']}'),
      );
    }
    if (_exam != null) {
      return WithBack(
        onBack: () => setState(() {
          _exam = null;
          _bump++;
        }),
        label: 'Exams',
        child: LoadView(
          key: ValueKey('a${_exam['id']}$_bump'),
          path: 'teacher/tests/${_exam['id']}/attempts',
          builder: (context, d, reload) => Screen(onRefresh: reload, children: [
            PageTitle('${d['test']}', sub: 'Choose a student to mark.'),
            if (_l(d['rows']).isEmpty) const Empty(icon: 'people-outline', title: 'No one has handed in yet'),
            ListGroup([
              for (final r in _l(d['rows']))
                ListRow(
                  icon: r['status'] == 'marking' ? 'create-outline' : 'checkmark-circle',
                  title: '${r['student']}',
                  sub: 'Handed in ${r['submitted']}',
                  badge: r['status'] == 'marking' ? const Pill('To mark', toneName: 'amber') : Pill('${r['score']} / ${r['total']}', toneName: 'green'),
                  onPress: () => setState(() => _attempt = r),
                ),
            ]),
          ]),
        ),
      );
    }
    return LoadView(
      key: ValueKey('e$_bump'),
      path: 'teacher/tests',
      query: const {'kind': 'exam', 'per_page': '50'},
      builder: (context, d, reload) {
        final rows = _l(d['data']).where((t) => (t['taken'] ?? 0) > 0).toList();
        return Screen(onRefresh: reload, children: [
          const PageTitle('Mark exams', sub: 'Exams that students have handed in.'),
          if (rows.isEmpty) const Empty(icon: 'create-outline', title: 'Nothing to mark', body: 'Exams appear here once students hand in.'),
          ListGroup([
            for (final t in rows)
              ListRow(
                icon: 'school-outline',
                title: '${t['title']}',
                sub: '${t['class']} · ${t['subject']} · ${t['taken']} handed in',
                badge: (t['to_mark'] ?? 0) > 0 ? Pill('${t['to_mark']} to mark', toneName: 'amber') : null,
                onPress: () => setState(() => _exam = t),
              ),
          ]),
        ]);
      },
    );
  }
}

class _MarkAttempt extends StatefulWidget {
  final String test, attempt;
  const _MarkAttempt({super.key, required this.test, required this.attempt});
  @override
  State<_MarkAttempt> createState() => _MarkAttemptState();
}

class _MarkAttemptState extends State<_MarkAttempt> {
  final Map<String, TextEditingController> _score = {}, _note = {};
  bool _busy = false, _seeded = false;

  @override
  void dispose() {
    for (final c in [..._score.values, ..._note.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(Future<void> Function() reload) async {
    final marks = <String, dynamic>{};
    _score.forEach((id, c) {
      if (c.text.trim().isNotEmpty) marks[id] = {'score': int.tryParse(c.text.trim()) ?? 0, 'comment': _note[id]?.text.trim() ?? ''};
    });
    if (marks.isEmpty) {
      notify.err('Nothing to save', 'Enter a score for at least one answer.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await api('teacher/tests/${widget.test}/attempts/${widget.attempt}', method: 'PUT', body: {'marks': marks});
      notify.ok('Saved', '${r['message']}');
      await reload();
    } catch (e) {
      _fail(e, 'Could not save');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'teacher/tests/${widget.test}/attempts/${widget.attempt}',
        builder: (context, d, reload) {
          final qs = _l(d['questions']);
          if (!_seeded) {
            _seeded = true;
            for (final q in qs) {
              _score['${q['id']}'] = TextEditingController(text: q['score'] == null ? '' : '${q['score']}');
              _note['${q['id']}'] = TextEditingController(text: '${q['comment'] ?? ''}');
            }
          }
          return Screen(onRefresh: reload, footer: AppButton('Save marks', icon: 'checkmark-done', busy: _busy, onPressed: () => _save(reload)), children: [
            PageTitle('${d['student']}', sub: d['status'] == 'graded' ? 'Marked: ${d['score']} out of ${d['total']}' : 'Still to mark'),
            for (var n = 0; n < qs.length; n++)
              ECard(children: [
                Row(children: [Expanded(child: Text('${n + 1}. ${qs[n]['body']}', style: Ty.h3())), Muted('${qs[n]['marks']} marks')]),
                if (qs[n]['type'] == 'theory') ...[
                  Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.line)), child: Text((qs[n]['answer'] as String?)?.isNotEmpty == true ? '${qs[n]['answer']}' : 'Not answered', style: Ty.body())),
                  if ((qs[n]['guide'] as String?)?.isNotEmpty == true) Text('Marking guide: ${qs[n]['guide']}', style: Ty.small()),
                ] else
                  for (var i = 0; i < _l(qs[n]['options']).length; i++)
                    Text('${String.fromCharCode(65 + i)}. ${_l(qs[n]['options'])[i]}${i == qs[n]['correct'] ? '  (correct)' : ''}${i == qs[n]['chosen'] ? '  ← chosen' : ''}', style: Ty.body(w: i == qs[n]['correct'] ? FontWeight.w700 : FontWeight.w400)),
                Field(label: 'Score out of ${qs[n]['marks']}${qs[n]['auto'] == true ? ' (marked by the system)' : ''}', controller: _score['${qs[n]['id']}'], keyboardType: TextInputType.number),
                Field(label: 'Comment for the student (optional)', controller: _note['${qs[n]['id']}'], multiline: true, rows: 2),
              ]),
          ]);
        },
      );
}
