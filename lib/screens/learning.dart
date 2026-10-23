import 'package:flutter/gestures.dart';
import 'package:file_picker/file_picker.dart';
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
  PlatformFile? _file;
  int _size = 0;

  Future<void> _pick() async {
    try {
      final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'png', 'jpg', 'jpeg', 'zip']);
      if (r.isEmpty) return;
      final f = r.first;
      final size = await f.length() ?? 0;
      if (size > 20 * 1024 * 1024) {
        notify.err('That file is too big', 'The most is 20 MB.');
        return;
      }
      setState(() {
        _file = f;
        _size = size;
      });
    } catch (_) {
      notify.err('Could not open your files');
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(Future<void> Function() reload) async {
    setState(() => _busy = true);
    try {
      final r = await apiUpload('lms/learn/assignments/${widget.id}/submit', fields: {if (_text.text.trim().isNotEmpty) 'body': _text.text.trim()}, filePath: _file?.path);
      notify.ok('Handed in', '${r['message'] ?? 'Your work was sent.'}');
      setState(() => _file = null);
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
          final accepts = '${a['accepts']}';
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
            if (can) ...[
              if (accepts != 'file') Field(label: sub == null ? 'Your answer' : 'Change your answer', controller: _text, multiline: true, rows: 7, hint: 'Write your work here', onChanged: (_) => setState(() {})),
              if (accepts != 'text')
                ECard(icon: 'attach-outline', title: accepts == 'file' ? 'Attach your work' : 'Attach a file (optional)', children: [
                  if (_file != null) ListRow(icon: 'document-attach-outline', title: _file!.name, sub: '${(_size / 1024).round()} KB', right: Tap(label: 'Remove file', onTap: () => setState(() => _file = null), child: const Icn('close-circle', size: 22)))
                  else const Muted('PDF, Word, PowerPoint, Excel, text, a photo or a zip. Up to 20 MB.'),
                  AppButton(_file == null ? 'Choose a file' : 'Choose a different file', icon: 'folder-open-outline', kind: BtnKind.soft, onPressed: _pick),
                ]),
              AppButton(sub == null ? 'Hand in' : 'Hand in again', icon: 'paper-plane-outline', busy: _busy, disabled: _text.text.trim().isEmpty && _file == null, onPressed: () => _send(reload)),
            ],
          ]);
        },
      );
}

/// A teacher's learning on the phone: their courses, the assignments in each, and marking what students handed in.
class TeacherLearn extends StatefulWidget {
  const TeacherLearn({super.key});
  @override
  State<TeacherLearn> createState() => _TeacherLearnState();
}

class _TeacherLearnState extends State<TeacherLearn> {
  final List<_At> _stack = [const _At('home')];
  int _bump = 0;

  void _open(String kind, String id) => setState(() => _stack.add(_At(kind, id)));
  void _back() => setState(() {
        _stack.removeLast();
        _bump++;
      });

  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('lms.enabled')) return const LockedView(title: 'Learning', feature: 'lms.enabled');
    final at = _stack.last;
    final page = switch (at.kind) {
      'course' => _TCourse(key: ValueKey('c${at.id}$_bump'), id: at.id!, onOpen: (id) => _open('assignment', id)),
      'assignment' => _TAssignment(key: ValueKey('a${at.id}$_bump'), id: at.id!, onOpen: (id) => _open('mark', id)),
      'mark' => _TMark(key: ValueKey('m${at.id}'), id: at.id!, onDone: _back),
      _ => _THome(key: ValueKey('h$_bump'), onOpen: (id) => _open('course', id)),
    };
    if (_stack.length == 1) return page;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: WithBack(onBack: _back, label: switch (at.kind) { 'mark' => 'Assignment', 'assignment' => 'Course', _ => 'Learning' }, child: page),
    );
  }
}

class _THome extends StatelessWidget {
  final void Function(String) onOpen;
  const _THome({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('lms.dashboard')) return const LockedView(title: 'Learning', feature: 'lms.dashboard');
    return LoadView(
      path: 'lms/teach',
      builder: (context, d, reload) {
        final s = d['stats'] as Map;
        final courses = _l(d['courses']);
        final assignments = (d['can'] as Map)['assignments'] == true && Ent.I.on('lms.assignments');
        return Screen(onRefresh: reload, children: [
          const PageTitle('Learning', sub: 'Your courses. Build lessons on the website; mark assignments here.'),
          const ReadOnlyNote('lms.courses'),
          StatRow([
            Stat(icon: 'library-outline', label: 'Courses', value: '${s['courses']}'),
            Stat(icon: 'document-text-outline', label: 'Lessons live', value: '${s['lessons']}'),
            Stat(icon: 'people-outline', label: 'Active this week', value: '${s['active_students']} / ${s['students']}'),
          ]),
          if (courses.isEmpty) const Empty(icon: 'library-outline', title: 'No courses yet', body: 'Create a course on the school website and it will show here.'),
          for (final c in courses)
            ECard(onPress: assignments ? () => onOpen('${c['id']}') : null, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: _tile('${c['colour']}'), borderRadius: BorderRadius.circular(14)), child: const Icn('book-outline', size: 24, tint: Colors.white)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${c['title']}', style: Ty.h3()), Muted([c['subject'], (c['classes'] as List?)?.join(', ')].where((x) => x != null && '$x'.isNotEmpty).join(' · '))])),
                if (c['status'] != 'published') Pill(c['status'] == 'draft' ? 'Draft' : 'Archived', toneName: c['status'] == 'draft' ? 'amber' : 'grey'),
              ]),
              Muted('${c['lessons'] ?? 0} lessons'),
            ]),
        ]);
      },
    );
  }
}

class _TCourse extends StatelessWidget {
  final String id;
  final void Function(String) onOpen;
  const _TCourse({super.key, required this.id, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    if (!Ent.I.on('lms.assignments')) return const LockedView(title: 'Assignments', feature: 'lms.assignments');
    return LoadView(
      path: 'lms/courses/$id/assignments',
      builder: (context, d, reload) {
        final rows = _l(d['assignments']);
        return Screen(onRefresh: reload, children: [
          const PageTitle('Assignments', sub: 'Tap one to see who handed in.'),
          if (rows.isEmpty) const Empty(icon: 'document-text-outline', title: 'No assignments yet', body: 'Set one on the school website.'),
          for (final a in rows)
            ECard(onPress: a['status'] == 'draft' ? null : () => onOpen('${a['id']}'), children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${a['title']}', style: Ty.h3()), Muted(a['due'] != null ? 'Due ${a['due']}' : 'No deadline')])),
                Pill(a['status'] == 'draft' ? 'Draft' : (a['status'] == 'closed' ? 'Closed' : 'Open'), toneName: a['status'] == 'draft' ? 'amber' : (a['status'] == 'closed' ? 'grey' : 'green')),
              ]),
              Muted('${a['submitted']} of ${d['students']} handed in · ${a['graded']} marked'),
              if ((a['submitted'] as num) > (a['graded'] as num)) Pill('${(a['submitted'] as num) - (a['graded'] as num)} to mark', toneName: 'amber'),
            ]),
        ]);
      },
    );
  }
}

class _TAssignment extends StatelessWidget {
  final String id;
  final void Function(String) onOpen;
  const _TAssignment({super.key, required this.id, required this.onOpen});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'lms/assignments/$id',
        builder: (context, d, reload) {
          final a = d['assignment'] as Map;
          final s = d['summary'] as Map;
          final rows = _l(d['rows']);
          const tones = {'missing': ('Not handed in', 'red'), 'submitted': ('To mark', 'amber'), 'late': ('Late, to mark', 'amber'), 'graded': ('Marked', 'green')};
          return Screen(onRefresh: reload, children: [
            PageTitle('${a['title']}', sub: [if (a['due'] != null) 'Due ${a['due']}', 'Out of ${a['max']}'].join(' · ')),
            StatRow([Stat(icon: 'paper-plane-outline', label: 'Handed in', value: '${s['submitted']} / ${s['students']}'), Stat(icon: 'ribbon-outline', label: 'Marked', value: '${s['graded']}'), Stat(icon: 'stats-chart-outline', label: 'Average', value: s['average'] == null ? '–' : _n(s['average']))]),
            ListGroup([
              for (final r in rows)
                ListRow(
                  title: '${r['student']}',
                  sub: '${r['class'] ?? ''}${r['submission'] != null && r['submission']['score'] != null ? ' · ${_n(r['submission']['score'])} / ${a['max']}' : ''}',
                  badge: Pill(tones['${r['state']}']?.$1 ?? '${r['state']}', toneName: tones['${r['state']}']?.$2 ?? 'grey'),
                  onPress: r['submission'] == null ? null : () => onOpen('${(r['submission'] as Map)['id']}|$id'),
                ),
            ]),
          ]);
        },
      );
}

class _TMark extends StatefulWidget {
  final String id;
  final VoidCallback onDone;
  const _TMark({super.key, required this.id, required this.onDone});
  @override
  State<_TMark> createState() => _TMarkState();
}

class _TMarkState extends State<_TMark> {
  final _score = TextEditingController(), _note = TextEditingController();
  bool _busy = false, _seeded = false;
  late final String _sub = widget.id.split('|').first, _assignment = widget.id.split('|').last;

  @override
  void dispose() {
    _score.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(num max) async {
    final v = num.tryParse(_score.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0 || v > max) {
      notify.err('Check the score', 'Enter a number from 0 to $max.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await api('lms/submissions/$_sub/grade', method: 'POST', body: {'score': v, 'feedback': _note.text.trim()});
      notify.ok('Marked', '${r['message']}');
      widget.onDone();
    } catch (e) {
      _fail(e, 'Could not save');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'lms/assignments/$_assignment',
        builder: (context, d, reload) {
          final a = d['assignment'] as Map;
          final row = _l(d['rows']).cast<Map>().firstWhere((r) => r['submission'] != null && (r['submission'] as Map)['id'] == _sub, orElse: () => {});
          final sub = row['submission'] as Map?;
          if (sub == null) return const Screen(children: [Empty(icon: 'document-text-outline', title: 'Nothing handed in')]);
          if (!_seeded) {
            _seeded = true;
            _score.text = sub['score'] == null ? '' : _n(sub['score']);
            _note.text = '${sub['feedback'] ?? ''}';
          }
          final max = (a['max'] as num);
          final canMark = Ent.I.writable('lms.feedback');
          return Screen(footer: canMark ? AppButton('Save mark', icon: 'checkmark-done', busy: _busy, onPressed: () => _save(max)) : null, children: [
            PageTitle('${row['student']}', sub: '${a['title']} · ${sub['submitted']}${sub['late'] == true ? ' (late)' : ''}'),
            if (!canMark) const ReadOnlyNote('lms.feedback'),
            if ((sub['body'] as String?)?.isNotEmpty == true) ECard(title: 'Their answer', icon: 'reader-outline', children: [Text('${sub['body']}', style: Ty.body())]),
            if (sub['file'] != null) ECard(children: [ListRow(icon: 'document-attach-outline', title: '${(sub['file'] as Map)['name']}', sub: 'Tap to open', onPress: () => _openFile('${(sub['file'] as Map)['url']}', '${(sub['file'] as Map)['name']}'))]),
            if (canMark) ...[
              Field(label: 'Score out of ${_n(max)}', controller: _score, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              Field(label: 'Feedback for the student', controller: _note, multiline: true, rows: 4, hint: 'What went well, what to improve'),
            ],
          ]);
        },
      );

  Future<void> _openFile(String url, String name) async {
    if (name.toLowerCase().endsWith('.pdf')) {
      await previewDocument(url, const {}, name, title: name);
    } else {
      await openLink(url);
    }
  }
}
