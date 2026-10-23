import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/entitle.dart';
import '../core/words.dart';
import '../features/gate.dart';
import '../shell/nav.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_taking != null) return _TakeTest(test: _taking, onDone: () => setState(() => _taking = null));
    if (_review != null) return WithBack(onBack: () => setState(() => _review = null), label: w('{Tests}'), child: _Review(data: _review));
    if (_intro != null) {
      return WithBack(
        onBack: () => setState(() => _intro = null),
        label: w('{Tests}'),
        child: Screen(children: [
          PageTitle('${_intro['title']}', sub: '${_intro['subject'] ?? ''} · before you start'),
          ECard(children: [
            Text('${_intro['questions']} questions${_intro['timed'] == true ? ', ${_intro['minutes']} minutes' : ''}.', style: Ty.h3()),
            Text(_intro['timed'] == true ? 'The clock starts when you press Start and cannot be paused.' : w('Hand in before the {exam} closes.'), style: Ty.body()),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: tone('amber').bg, borderRadius: BorderRadius.circular(14)),
              child: Text(w('Stay on this screen. If you go to another app, press back, lock the phone or lose your connection for more than a few seconds, the {test} ends and what you have answered is handed in.'), style: Ty.body(c: tone('amber').fg, w: FontWeight.w700)),
            ),
            Text(w('You can take this {test} once. Put your phone on silent so a call does not take you away.'), style: Ty.body()),
            if ((_intro['instructions'] as String?)?.isNotEmpty == true) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.tint, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('From your teacher', style: Ty.small(w: FontWeight.w800)), const SizedBox(height: 4), Text('${_intro['instructions']}', style: Ty.body())])),
          ]),
          AppButton(w('Start the {exam}'), icon: 'play', onPressed: () async {
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
          PageTitle(Ent.I.on('cbt.enabled') ? w('{Tests} and {exams}') : w('{Tests}'), sub: w('Take a {test} when it is open, and see your answers after.')),
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
                if (t['kind'] == 'exam') Pill(w('{Exam}'), toneName: 'blue'),
              ]),
              LR(
                left: Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill(_stateInfo['${t['state']}']?.$1 ?? '${t['state']}', toneName: _stateInfo['${t['state']}']?.$2 ?? 'grey'),
                  if (t['ended_by'] == 'left') const Pill('You left, so it was handed in', toneName: 'amber'),
                  if (t['result'] == 'marking') const Pill('Being marked', toneName: 'amber'),
                  if (t['result'] == 'held') const Pill('Result not released yet', toneName: 'amber'),
                  if (t['result'] == 'shown' && t['passed'] != null) Pill(t['passed'] == true ? 'Passed' : 'Below pass mark', toneName: t['passed'] == true ? 'green' : 'red'),
                ]),
                right: t['result'] == 'shown' ? Text.rich(TextSpan(children: [TextSpan(text: '${t['score']}', style: Ty.custom(18, FontWeight.w800)), TextSpan(text: ' / ${t['total']}', style: Ty.small())])) : null,
              ),
              if (t['state'] == 'open' || t['state'] == 'resume')
                AppButton(t['state'] == 'resume' ? 'Continue' : 'Start', icon: 'play', onPressed: () {
                  setState(() => _intro = t);
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
      _fail(e, w('Could not start the {test}'));
    }
  }
}

/// One attempt, taken without leaving it. There is no tab bar and no menu; going out of the app, pressing back or locking the phone
/// ends the {test} and hands in what was answered. The school keeps the real clock, and notices by itself if this screen stops
/// reporting (the app is closed, the phone dies), so that ends it too.
class _TakeTest extends StatefulWidget {
  final dynamic test;
  final VoidCallback onDone;
  const _TakeTest({required this.test, required this.onDone});
  @override
  State<_TakeTest> createState() => _TakeTestState();
}

class _TakeTestState extends State<_TakeTest> with WidgetsBindingObserver {
  late int _left = (widget.test['seconds_left'] as num).toInt();
  late final bool _timed = widget.test['timed'] != false;
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _text = {};
  bool _busy = false, _over = false, _left_ = false, _dirty = false, _offline = false;
  int _at = 0;
  late final StreamSubscription<int> _tick;
  Timer? _saver, _away;

  String get _id => '${widget.test['id']}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Nav.I.lock(true); });
    final saved = widget.test['saved'];
    if (saved is Map) {
      saved.forEach((k, v) {
        _answers['$k'] = v;
        if (v is String) _text['$k'] = TextEditingController(text: v);
      });
    }
    _tick = Stream<int>.periodic(const Duration(seconds: 1), (i) => i).listen((_) {
      if (!mounted || _over) return;
      setState(() => _left--);
      if (_timed && _left <= 0) _submit();
    });
    _saver = Timer.periodic(const Duration(seconds: 5), (_) => _beat());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Nav.I.lock(false);
    _tick.cancel();
    _saver?.cancel();
    _away?.cancel();
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Going to another app, the home screen or a locked phone ends it. A pulled-down shade gets a few seconds' grace.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_over) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _leave();
      case AppLifecycleState.inactive:
        _away?.cancel();
        _away = Timer(const Duration(seconds: 3), _leave);
      case AppLifecycleState.resumed:
        _away?.cancel();
    }
  }

  /// Tells the school the student is still here, and keeps the answers safe.
  Future<void> _beat() async {
    if (_over) return;
    final send = _dirty;
    _dirty = false;
    try {
      await api('student/tests/$_id/save', method: 'PUT', body: send ? {'answers': _answers} : {});
      if (mounted && _offline) setState(() => _offline = false);
    } catch (e) {
      if (send) _dirty = true;
      if (e is ApiError && e.status == 422 && mounted) {
        setState(() {
          _over = true;
          _left_ = true;
        });
        return;
      }
      if (mounted && !_offline) setState(() => _offline = true);
    }
  }

  /// The student went out of the {test}: it is handed in as it stands.
  Future<void> _leave() async {
    if (_over) return;
    _over = true;
    _away?.cancel();
    if (mounted) setState(() => _left_ = true);
    try {
      await api('student/tests/$_id/leave', method: 'POST', body: {'answers': _answers});
    } catch (_) {/* the school hands it in by itself a few seconds later */}
  }

  Future<void> _submit() async {
    if (_over || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await api('student/tests/$_id/submit', method: 'POST', body: {'answers': _answers});
      _over = true;
      notify.ok('Submitted', '${r['message']}');
    } catch (e) {
      _fail(e, 'Could not submit');
      if (mounted) setState(() => _busy = false);
      return;
    }
    widget.onDone();
  }

  Future<void> _tryLeave() async {
    if (_over) return;
    if (await confirm(context, title: w('Leave the {test}?'), message: w('Leaving ends the {test} now and hands in what you have answered. You cannot open it again.'), yes: 'Leave and hand in', no: 'Stay', destructive: true)) {
      await _leave();
    }
  }

  bool _has(String id) => _answers[id] != null && '${_answers[id]}'.trim().isNotEmpty;

  /// The final hand-in: always asks first, and says how many questions are still not answered.
  Future<void> _finish(int total, int answered) async {
    if (_over || _busy) return;
    final left = total - answered;
    final msg = left == 0 ? 'You have answered all $total questions.' : 'You have answered $answered of $total questions. $left ${left == 1 ? 'is' : 'are'} not answered.';
    final ok = await confirm(context, title: w('Hand in your {test}?'), message: '$msg ${w('Once you hand in, you cannot change your answers or open this {test} again.')}', yes: 'Yes, hand in', no: 'Keep going');
    if (ok && mounted) await _submit();
  }

  /// A small panel with every question number: filled for answered, outlined for not answered. Tapping one goes to it.
  Future<void> _showQuestions(List qs) {
    return showAppSheet<void>(
      context,
      title: 'Your questions',
      builder: (ctx) {
        final answered = qs.where((q) => _has('${q['id']}')).length;
        return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < qs.length; i++)
              Tap(
                scale: 0.92,
                label: 'Question ${i + 1}, ${_has('${qs[i]['id']}') ? 'answered' : 'not answered'}',
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _at = i);
                },
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _has('${qs[i]['id']}') ? color.brand : color.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: i == _at ? color.brand : (_has('${qs[i]['id']}') ? color.brand : color.line), width: i == _at ? 3 : 1.5),
                  ),
                  child: Text('${i + 1}', style: Ty.custom(15, FontWeight.w800, c: _has('${qs[i]['id']}') ? color.onBrand : color.muted)),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 16, height: 16, decoration: BoxDecoration(color: color.brand, borderRadius: BorderRadius.circular(5))),
            const SizedBox(width: 8),
            Text('Answered ($answered)', style: Ty.body()),
            const SizedBox(width: 20),
            Container(width: 16, height: 16, decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(5), border: Border.all(color: color.line, width: 1.5))),
            const SizedBox(width: 8),
            Text('Not answered (${qs.length - answered})', style: Ty.body()),
          ]),
          const SizedBox(height: 8),
          Text('Tap a number to go to that question. The clock keeps running.', style: Ty.body(c: color.muted)),
          const SizedBox(height: 16),
          AppButton('Final submit', icon: 'checkmark-done', onPressed: () {
            Navigator.of(ctx).pop();
            _finish(qs.length, answered);
          }),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_left_) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onDone();
        },
        child: Screen(bare: true, children: [
          const SizedBox(height: 60),
          const Empty(icon: 'lock-closed-outline', title: 'You left', body: ''),
          Text(w('You left the {test}, so it was handed in with what you had answered. It cannot be opened again, and your teacher can see this.'), textAlign: TextAlign.center, style: Ty.body()),
          AppButton(w('Back to your {tests}'), icon: 'arrow-back', onPressed: widget.onDone),
        ]),
      );
    }
    final qs = _l(widget.test['questions']);
    final answered = qs.where((q) => _has('${q['id']}')).length;
    final mm = (_left < 0 ? 0 : _left) ~/ 60, ss = (_left < 0 ? 0 : _left) % 60;
    final q = qs[_at];
    final id = '${q['id']}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _tryLeave();
      },
      child: Screen(
        bare: true,
        footer: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Bar(qs.isNotEmpty ? answered / qs.length * 100 : 0, height: 6),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: AppButton('Previous', icon: 'chevron-back', kind: BtnKind.plain, disabled: _at == 0, onPressed: () => setState(() => _at--))),
            const SizedBox(width: 10),
            Expanded(
              child: _at < qs.length - 1 ? AppButton('Next question', icon: 'chevron-forward', onPressed: () => setState(() => _at++)) : AppButton('Final submit', icon: 'checkmark-done', busy: _busy, onPressed: () => _finish(qs.length, answered)),
            ),
          ]),
        ]),
        children: [
          Row(children: [
            Expanded(child: Text('${widget.test['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ty.h3())),
            if (_timed) Pill('$mm:${ss.toString().padLeft(2, '0')}', toneName: _left < 60 ? 'red' : 'amber'),
          ]),
          if (_offline) const Pill('Not saved: check your connection', toneName: 'red'),
          Row(children: [
            Tap(
              scale: 0.96,
              label: 'Show all questions',
              onTap: () => _showQuestions(qs),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: color.line, width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icn('grid-outline', size: 16, tint: color.brand),
                  const SizedBox(width: 8),
                  Text('Questions ${_at + 1}/${qs.length}', style: Ty.custom(13, FontWeight.w800, c: color.brand)),
                ]),
              ),
            ),
            const Spacer(),
            Text('$answered answered · ${qs.length - answered} not answered', style: Ty.custom(12, FontWeight.w600, c: color.muted)),
          ]),
          ECard(title: 'Question ${_at + 1} of ${qs.length}', right: Muted('${q['marks']} mark${q['marks'] == 1 ? '' : 's'}'), children: [
            Text('${q['body']}', style: Ty.h3()),
            if (q['type'] == 'theory')
              Field(
                label: 'Your answer',
                controller: _text.putIfAbsent(id, () => TextEditingController()),
                multiline: true,
                rows: 8,
                onChanged: (v) => setState(() {
                  _answers[id] = v;
                  _dirty = true;
                }),
              )
            else
              for (var i = 0; i < _l(q['options']).length; i++)
                Builder(builder: (context) {
                  final on = _answers[id] == i;
                  return Tap(
                    scale: 0.985,
                    label: 'Option ${String.fromCharCode(65 + i)}',
                    onTap: () => setState(() {
                      _answers[id] = i;
                      _dirty = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: on ? color.tint : color.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? color.brand : color.line, width: 1.5)),
                      child: Row(children: [
                        Container(width: 28, height: 28, decoration: BoxDecoration(color: on ? color.brand : color.bg, shape: BoxShape.circle), alignment: Alignment.center, child: Text(String.fromCharCode(65 + i), style: Ty.custom(13, FontWeight.w800, c: on ? color.onBrand : color.muted))),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${_l(q['options'])[i]}', style: Ty.body())),
                      ]),
                    ),
                  );
                }),
          ]),
        ],
      ),
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
    if (!Ent.I.on('cbt.manual_grading')) return LockedView(title: w('Mark {exams}'), feature: 'cbt.manual_grading');
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
        label: w('{Exams}'),
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
          PageTitle(w('Mark {exams}'), sub: w('{Exams} that students have handed in.')),
          if (rows.isEmpty) Empty(icon: 'create-outline', title: 'Nothing to mark', body: w('{Exams} appear here once students hand in.')),
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
