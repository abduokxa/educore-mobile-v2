import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/entitle.dart';
import '../features/gate.dart';
import '../features/pdf_view.dart';
import '../features/richtext.dart';
import '../ui/ui.dart';

List _l(dynamic v) => (v as List?) ?? const [];
void _fail(Object e, String title) => notify.err(title, e is ApiError ? e.message : null);

Color _tile(String? hex) {
  final h = (hex ?? '').replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? color.brand : Color(v);
}

/// Where a student is inside Learn: a list of courses, a course, a lesson, the assignments, one assignment.
class _At {
  final String kind;
  final String? id;
  const _At(this.kind, [this.id]);
}

/// The learning platform on the phone: courses, lessons, files and videos, and assignments. What shows follows the school's plan.
class StudentLearn extends StatefulWidget {
  final bool assignmentsFirst;
  const StudentLearn({super.key, this.assignmentsFirst = false});
  @override
  State<StudentLearn> createState() => _StudentLearnState();
}

class _StudentLearnState extends State<StudentLearn> {
  late final List<_At> _stack = [_At(widget.assignmentsFirst ? 'assignments' : 'home')];
  int _bump = 0;

  void _open(String kind, [String? id]) => setState(() => _stack.add(_At(kind, id)));
  void _swap(String kind, String id) => setState(() => _stack[_stack.length - 1] = _At(kind, id));
  void _back() => setState(() {
        _stack.removeLast();
        _bump++;
      });

  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('lms.enabled')) return const LockedView(title: 'Learn', feature: 'lms.enabled');
    final at = _stack.last;
    final page = switch (at.kind) {
      'course' => _Course(key: ValueKey('c${at.id}$_bump'), id: at.id!, onLesson: (id) => _open('lesson', id)),
      'lesson' => _Lesson(key: ValueKey('l${at.id}'), id: at.id!, onGo: (id) => _swap('lesson', id)),
      'assignments' => _Assignments(key: ValueKey('a$_bump'), onOpen: (id) => _open('assignment', id)),
      'assignment' => _Assignment(key: ValueKey('as${at.id}'), id: at.id!),
      _ => _Home(key: ValueKey('h$_bump'), onCourse: (id) => _open('course', id), onLesson: (id) => _open('lesson', id), onAssignments: () => _open('assignments')),
    };
    if (_stack.length == 1) return page;
    final label = switch (at.kind) { 'lesson' => 'Course', 'assignment' => 'Assignments', _ => 'Learn' };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: WithBack(onBack: _back, label: label, child: page),
    );
  }
}

class _Home extends StatelessWidget {
  final void Function(String) onCourse, onLesson;
  final VoidCallback onAssignments;
  const _Home({super.key, required this.onCourse, required this.onLesson, required this.onAssignments});
  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('lms.dashboard')) return const LockedView(title: 'Learn', feature: 'lms.dashboard');
    return LoadView(
      path: 'lms/learn',
      builder: (context, d, reload) {
        final stats = d['stats'] as Map;
        final cont = d['continue'] as Map?;
        final courses = _l(d['courses']);
        return Screen(onRefresh: reload, children: [
          const PageTitle('Learn', sub: 'Your courses, lessons and assignments.'),
          const ReadOnlyNote('lms.courses'),
          StatRow([
            Stat(icon: 'library-outline', label: 'Courses', value: '${stats['courses']}'),
            Stat(icon: 'checkmark-done-outline', label: 'Lessons done', value: '${stats['done']} / ${stats['lessons']}'),
            Stat(icon: 'trending-up-outline', label: 'Overall', value: '${stats['percent']}%'),
          ]),
          if (cont != null && cont['next'] != null)
            ECard(title: 'Continue where you stopped', icon: 'play-circle-outline', onPress: () => onLesson('${(cont['next'] as Map)['id']}'), children: [
              Text('${cont['title']}', style: Ty.h3()),
              Muted('Next: ${(cont['next'] as Map)['title']}'),
              Bar((cont['percent'] as num).toDouble()),
            ]),
          if (Ent.I.on('lms.assignments')) ListGroup([ListRow(icon: 'document-text-outline', title: 'Assignments', sub: 'Work to hand in, and your marks', onPress: onAssignments)]),
          if (courses.isEmpty) const Empty(icon: 'library-outline', title: 'No courses yet', body: 'When a teacher publishes a course for your class, it appears here.'),
          for (final c in courses)
            ECard(onPress: () => onCourse('${c['id']}'), children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: _tile('${c['colour']}'), borderRadius: BorderRadius.circular(14)), child: const Icn('book-outline', size: 24, tint: Colors.white)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${c['title']}', style: Ty.h3()), Muted([c['subject'], c['teacher']].where((x) => x != null && '$x'.isNotEmpty).join(' · '))])),
                Text('${c['percent']}%', style: Ty.custom(15, FontWeight.w800, c: color.brand)),
              ]),
              Bar((c['percent'] as num).toDouble()),
              Muted('${c['done']} of ${c['total']} lessons done'),
            ]),
        ]);
      },
    );
  }
}

class _Course extends StatelessWidget {
  final String id;
  final void Function(String) onLesson;
  const _Course({super.key, required this.id, required this.onLesson});
  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('lms.courses')) return const LockedView(title: 'Course', feature: 'lms.courses');
    return LoadView(
      path: 'lms/learn/courses/$id',
      builder: (context, d, reload) {
        final c = d['course'] as Map;
        Widget lessons(List rows) => ListGroup([
              for (final l in rows)
                ListRow(
                  icon: l['done'] == true ? 'checkmark-circle' : (l['video'] == true ? 'videocam-outline' : 'document-text-outline'),
                  title: '${l['title']}',
                  sub: [if (l['minutes'] != null) '${l['minutes']} min', if (l['video'] == true) 'Video'].join(' · '),
                  onPress: Ent.I.on('lms.lessons') ? () => onLesson('${l['id']}') : null,
                ),
            ]);
        return Screen(onRefresh: reload, children: [
          PageTitle('${c['title']}', sub: [c['subject'], c['teacher']].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
          if ((c['summary'] as String?)?.isNotEmpty == true) Text('${c['summary']}', style: Ty.body()),
          ECard(children: [Row(children: [Expanded(child: Muted('${c['done']} of ${c['total']} lessons done')), Text('${c['percent']}%', style: Ty.custom(15, FontWeight.w800, c: color.brand))]), Bar((c['percent'] as num).toDouble())]),
          if (d['finished'] == true) const ECard(icon: 'ribbon-outline', title: 'Course complete', children: [Text('You have finished every lesson. Well done.')]),
          for (final t in _l(d['topics'])) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SectionTitle('${t['title']}'), const SizedBox(height: 8), lessons(_l(t['lessons']))]),
          if (_l(d['loose']).isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (_l(d['topics']).isNotEmpty) ...[const SectionTitle('More lessons'), const SizedBox(height: 8)], lessons(_l(d['loose']))]),
          if (_l(d['topics']).isEmpty && _l(d['loose']).isEmpty) const Empty(icon: 'document-text-outline', title: 'No lessons yet', body: 'Your teacher has not published a lesson in this course.'),
        ]);
      },
    );
  }
}

/// Lesson text: blank lines make paragraphs; "# " and "## " make headings; "- " a list; **bold**, _italic_ and web addresses work inside a line.
class LessonText extends StatelessWidget {
  final String text;
  const LessonText(this.text, {super.key});

  List<InlineSpan> _inline(String t, TextStyle base) {
    final out = <InlineSpan>[];
    final re = RegExp(r'(\*\*[^*]+\*\*|_[^_]+_|https?://[^\s<]*[^\s<.,;:!?)\]}' "'" r'"])');
    var at = 0;
    for (final m in re.allMatches(t)) {
      if (m.start > at) out.add(TextSpan(text: t.substring(at, m.start)));
      final s = m.group(0)!;
      if (s.startsWith('**')) {
        out.add(TextSpan(text: s.substring(2, s.length - 2), style: const TextStyle(fontWeight: FontWeight.w800)));
      } else if (s.startsWith('_')) {
        out.add(TextSpan(text: s.substring(1, s.length - 1), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        out.add(TextSpan(text: s, style: TextStyle(color: color.brand, decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () => openLink(s)));
      }
      at = m.end;
    }
    if (at < t.length) out.add(TextSpan(text: t.substring(at)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = text.replaceAll('\r\n', '\n').split(RegExp(r'\n{2,}')).map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
    final body = Ty.body().copyWith(height: 1.65);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final b in blocks)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Builder(builder: (context) {
            final lines = b.split('\n');
            if (RegExp(r'^#{1,2}\s').hasMatch(b) && lines.length == 1) {
              final h2 = b.startsWith('##');
              final t = b.replaceFirst(RegExp(r'^#{1,2}\s*'), '');
              return Text.rich(TextSpan(children: _inline(t, body)), style: h2 ? Ty.h3() : Ty.h2());
            }
            if (lines.every((l) => RegExp(r'^[-*]\s+').hasMatch(l)) || lines.every((l) => RegExp(r'^\d+[.)]\s+').hasMatch(l))) {
              final numbered = RegExp(r'^\d').hasMatch(lines.first);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 24, child: Text(numbered ? '${i + 1}.' : '•', style: body)),
                      Expanded(child: Text.rich(TextSpan(children: _inline(lines[i].replaceFirst(RegExp(r'^([-*]|\d+[.)])\s+'), ''), body)), style: body)),
                    ]),
                  ),
              ]);
            }
            return Text.rich(TextSpan(children: _inline(lines.join('\n'), body)), style: body);
          }),
        ),
    ]);
  }
}

class _Lesson extends StatefulWidget {
  final String id;
  final void Function(String) onGo;
  const _Lesson({super.key, required this.id, required this.onGo});
  @override
  State<_Lesson> createState() => _LessonState();
}

class _LessonState extends State<_Lesson> {
  bool _busy = false;
  bool? _done;

  Future<void> _open(Map m) async {
    final url = m['url'] as String?;
    if (url == null) return;
    final title = '${m['title']}';
    final mime = '${m['mime'] ?? ''}';
    if (m['file'] == true && (mime.contains('pdf') || title.toLowerCase().endsWith('.pdf'))) {
      await previewDocument(url, const {}, title, title: title);
    } else {
      await openLink(url);
    }
  }

  Future<void> _complete(bool done, Future<void> Function() reload) async {
    setState(() => _busy = true);
    try {
      final r = await api('lms/learn/lessons/${widget.id}/complete', method: 'POST', body: {'done': done});
      _done = done;
      notify.ok('${r['message']}');
      await reload();
    } catch (e) {
      _fail(e, 'Could not save');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('lms.lessons')) return const LockedView(title: 'Lesson', feature: 'lms.lessons');
    return LoadView(
      path: 'lms/learn/lessons/${widget.id}',
      builder: (context, d, reload) {
        final l = d['lesson'] as Map;
        final can = (d['can'] as Map)['progress'] == true;
        final done = _done ?? l['done'] == true;
        final prev = d['prev'] as Map?, next = d['next'] as Map?;
        final video = l['video_url'] as String?;
        final mats = _l(d['materials']);
        return Screen(onRefresh: reload, children: [
          PageTitle('${l['title']}', sub: [(d['course'] as Map)['title'], if (l['topic'] != null) l['topic'], 'Lesson ${d['position']} of ${d['of']}'].join(' · ')),
          if (Ent.I.readonly('lms.progress')) const ReadOnlyNote('lms.progress'),
          if (video != null && video.isNotEmpty) AppButton('Watch the video', icon: 'play-circle-outline', kind: BtnKind.soft, onPressed: () => openLink(video)),
          if ((l['body'] as String?)?.isNotEmpty == true) LessonText('${l['body']}'),
          if (mats.isNotEmpty)
            ECard(title: 'Files and links', icon: 'attach-outline', children: [
              for (final m in mats) ListRow(icon: m['kind'] == 'video' ? 'videocam-outline' : (m['file'] == true ? 'document-attach-outline' : 'link-outline'), title: '${m['title']}', sub: m['file'] == true ? '${m['kind']}' : 'Link', onPress: () => _open(m as Map)),
            ]),
          if (can) AppButton(done ? 'Marked as done' : 'Mark as done', icon: done ? 'checkmark-circle' : 'checkmark-circle-outline', kind: done ? BtnKind.soft : BtnKind.primary, busy: _busy, onPressed: () => _complete(!done, reload)),
          Row(children: [
            Expanded(child: prev == null ? const SizedBox.shrink() : AppButton('Previous', icon: 'chevron-back', kind: BtnKind.plain, onPressed: () => widget.onGo('${prev['id']}'))),
            if (prev != null && next != null) const SizedBox(width: 10),
            Expanded(child: next == null ? const SizedBox.shrink() : AppButton('Next lesson', icon: 'chevron-forward', onPressed: () => widget.onGo('${next['id']}'))),
          ]),
        ]);
      },
    );
  }
}

const _states = {
  'todo': ('To do', 'blue'), 'overdue': ('Overdue', 'red'), 'submitted': ('Handed in', 'green'), 'late': ('Handed in late', 'amber'), 'graded': ('Marked', 'green'), 'missed': ('Missed', 'red'),
};

class _Assignments extends StatelessWidget {
  final void Function(String) onOpen;
  const _Assignments({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('lms.assignments')) return const LockedView(title: 'Assignments', feature: 'lms.assignments');
    return LoadView(
      path: 'lms/learn/assignments',
      builder: (context, d, reload) {
        final rows = _l(d['assignments']);
        final s = d['stats'] as Map;
        return Screen(onRefresh: reload, children: [
          const PageTitle('Assignments', sub: 'Work from your courses.'),
          const ReadOnlyNote('lms.assignments'),
          StatRow([Stat(icon: 'time-outline', label: 'To do', value: '${s['todo']}'), Stat(icon: 'paper-plane-outline', label: 'Handed in', value: '${s['submitted']}'), Stat(icon: 'ribbon-outline', label: 'Marked', value: '${s['graded']}')]),
          if (rows.isEmpty) const Empty(icon: 'document-text-outline', title: 'No assignments yet', body: 'They appear here when a teacher sets one.'),
          for (final a in rows)
            ECard(onPress: () => onOpen('${a['id']}'), children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${a['title']}', style: Ty.h3()), Muted([a['course_title'], if (a['due'] != null) 'Due ${a['due']}'].where((x) => x != null && '$x'.isNotEmpty).join(' · '))])),
                if (a['state'] == 'graded') Text.rich(TextSpan(children: [TextSpan(text: _n(a['score']), style: Ty.custom(18, FontWeight.w800)), TextSpan(text: ' / ${a['max']}', style: Ty.small())])),
              ]),
              Align(alignment: Alignment.centerLeft, child: Pill(_states['${a['state']}']?.$1 ?? '${a['state']}', toneName: _states['${a['state']}']?.$2 ?? 'grey')),
            ]),
        ]);
      },
    );
  }
}

String _n(dynamic v) {
  if (v == null) return '–';
  final n = num.tryParse('$v') ?? 0;
  return n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);
}

class _Assignment extends StatefulWidget {
  final String id;
  const _Assignment({super.key, required this.id});
  @override
  State<_Assignment> createState() => _AssignmentState();
}

class _AssignmentState extends State<_Assignment> {
  final _text = TextEditingController();
  bool _busy = false, _seeded = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(Future<void> Function() reload) async {
    setState(() => _busy = true);
    try {
      final r = await api('lms/learn/assignments/${widget.id}/submit', method: 'POST', body: {'body': _text.text.trim()});
      notify.ok('Handed in', '${r['message'] ?? 'Your work was sent.'}');
      await reload();
    } catch (e) {
      _fail(e, 'Could not hand in');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'lms/learn/assignments/${widget.id}',
        builder: (context, d, reload) {
          final a = d['assignment'] as Map;
          final sub = d['submission'] as Map?;
          final can = (d['can'] as Map)['submit'] == true;
          if (!_seeded) {
            _seeded = true;
            _text.text = '${sub?['body'] ?? ''}';
          }
          final fileOnly = a['accepts'] == 'file';
          return Screen(onRefresh: reload, children: [
            PageTitle('${a['title']}', sub: [a['course_title'], if (a['due'] != null) 'Due ${a['due']}', 'Out of ${a['max']}'].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
            Align(alignment: Alignment.centerLeft, child: Pill(_states['${a['state']}']?.$1 ?? '${a['state']}', toneName: _states['${a['state']}']?.$2 ?? 'grey')),
            const ReadOnlyNote('lms.assignments'),
            if ((a['instructions'] as String?)?.isNotEmpty == true) ECard(title: 'Instructions', icon: 'reader-outline', children: [RichText2('${a['instructions']}')]),
            if (sub != null && sub['status'] == 'graded')
              ECard(title: 'Your mark', icon: 'ribbon-outline', children: [
                Text.rich(TextSpan(children: [TextSpan(text: _n(sub['score']), style: Ty.custom(28, FontWeight.w800)), TextSpan(text: ' / ${a['max']}', style: Ty.small())])),
                if ((sub['feedback'] as String?)?.isNotEmpty == true && d['feedback'] == true) ...[Text('Teacher\'s feedback', style: Ty.small(w: FontWeight.w700)), Text('${sub['feedback']}', style: Ty.body())],
              ]),
            if (sub != null && sub['status'] != 'graded') ECard(title: 'You handed this in', icon: 'checkmark-circle-outline', children: [Muted('${sub['submitted']}${sub['late'] == true ? ' (late)' : ''}')]),
            if (sub != null && sub['file'] != null) ECard(children: [ListRow(icon: 'document-attach-outline', title: '${(sub['file'] as Map)['name']}', sub: 'Your file', onPress: () => openLink('${(sub['file'] as Map)['url']}'))]),
            if (can && !fileOnly) ...[
              Field(label: sub == null ? 'Your answer' : 'Change your answer', controller: _text, multiline: true, rows: 7, hint: 'Write your work here'),
              AppButton(sub == null ? 'Hand in' : 'Hand in again', icon: 'paper-plane-outline', busy: _busy, disabled: _text.text.trim().isEmpty && _busy, onPressed: () => _send(reload)),
            ],
            if (can && fileOnly) const ECard(icon: 'attach-outline', title: 'This one needs a file', children: [Text('Your teacher asked for a file. Hand it in from the school website for now.')]),
          ]);
        },
      );
}
