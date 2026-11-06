import 'package:flutter/material.dart';
import '../core/api.dart';
import '../features/docs.dart';
import '../ui/ui.dart';

List _l(dynamic v) => (v as List?) ?? const [];

void _fail(Object e, String title) => notify.err(title, e is ApiError ? e.message : null);

/// The extra screens live in the side menu so the bottom bar stays readable. Each item is shown only when its feature is on.
class MoreItem {
  final String key, label, hint;
  final WidgetBuilder screen;
  const MoreItem(this.key, this.label, this.hint, this.screen);
}

/// A date as a small calendar leaf: the month on top, the day below. Falls back to an icon when the text is not a date.
class Leaf extends StatelessWidget {
  final String text;
  const Leaf(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})').firstMatch(text);
    if (m == null) return const IconBadge('calendar-outline', size: 46);
    return Container(
      width: 46,
      decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: double.infinity, color: color.brand, padding: const EdgeInsets.symmetric(vertical: 2), alignment: Alignment.center, child: Text(m[2]!.toUpperCase(), style: Ty.custom(10.5, FontWeight.w800, c: color.onBrand))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(m[1]!, style: Ty.custom(18, FontWeight.w800))),
      ]),
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'calendar',
        builder: (context, d, reload) => Screen(onRefresh: reload, children: [
          PageTitle('School calendar', sub: d['label'] as String?),
          if (_l(d['rows']).isEmpty) const Empty(icon: 'calendar-clear-outline', title: 'Nothing planned this month', body: 'Events, holidays and exams appear here.'),
          for (final e in _l(d['rows']))
            ECard(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Leaf('${e['starts']}'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e['title']}', style: Ty.h3()),
                    const SizedBox(height: 4),
                    Muted('${e['starts']}${e['ends'] != null && e['ends'] != e['starts'] ? ' to ${e['ends']}' : ''}'),
                    if (e['description'] != null && '${e['description']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${e['description']}', style: Ty.body(c: color.muted))),
                  ]),
                ),
                const SizedBox(width: 8),
                Pill('${e['kind']}', toneName: 'blue'),
              ]),
            ]),
          if (_l(d['upcoming']).isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Coming up'),
              const SizedBox(height: 8),
              ListGroup([for (final e in _l(d['upcoming'])) ListRow(icon: 'time-outline', title: '${e['title']}', sub: '${e['starts']}')]),
            ]),
        ]),
      );
}

class _HomeworkList extends StatelessWidget {
  final String path;
  const _HomeworkList(this.path);
  @override
  Widget build(BuildContext context) => LoadView(
        path: path,
        builder: (context, d, reload) {
          Widget row(dynamic h) {
            final overdue = h['overdue'] == true;
            final dueIn = (h['due_in'] as num?) ?? 0;
            final tn = overdue ? 'red' : dueIn <= 1 ? 'amber' : 'green';
            final t = tone(tn);
            return ECard(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconBadge(iconFor('${h['subject'] ?? 'homework'}'), size: 44, tint: t.fg, bg: t.bg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${h['title']}', style: Ty.h3()),
                    const SizedBox(height: 4),
                    Muted([h['subject'], h['class'], h['teacher']].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
                    if (h['instructions'] != null && '${h['instructions']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${h['instructions']}', style: Ty.body(c: color.muted))),
                  ]),
                ),
              ]),
              LR(left: Muted('Due ${h['due']}'), right: Pill(overdue ? 'Past due' : dueIn == 0 ? 'Due today' : '$dueIn day${dueIn == 1 ? '' : 's'} left', toneName: tn)),
            ]);
          }

          final upcoming = _l(d['upcoming'] ?? d['rows']);
          return Screen(onRefresh: reload, children: [
            PageTitle('Homework', sub: upcoming.isNotEmpty ? '${upcoming.length} to do' : null),
            if (upcoming.isEmpty) const Empty(icon: 'happy-outline', title: 'No homework to do', body: 'Enjoy the free time. New homework shows up here.') else ...upcoming.map(row),
            if (_l(d['recent']).isNotEmpty) const SectionTitle('Recently due'),
            ..._l(d['recent']).map(row),
          ]);
        },
      );
}

class ParentHomework extends StatelessWidget {
  const ParentHomework({super.key});
  @override
  Widget build(BuildContext context) => const _HomeworkList('parent/homework');
}

class StudentHomework extends StatelessWidget {
  const StudentHomework({super.key});
  @override
  Widget build(BuildContext context) => const _HomeworkList('student/homework');
}

class TeacherHomework extends StatelessWidget {
  const TeacherHomework({super.key});
  @override
  Widget build(BuildContext context) => const _HomeworkList('teacher/homework');
}

class ParentTransport extends StatelessWidget {
  const ParentTransport({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'parent/transport',
        builder: (context, d, reload) => Screen(onRefresh: reload, children: [
          const PageTitle('School bus'),
          if (_l(d['rows']).isEmpty) const Empty(icon: 'bus-outline', title: 'No bus information'),
          for (final r in _l(d['rows']))
            ECard(children: [
              Row(children: [Avatar('${r['child']}', size: 42), const SizedBox(width: 12), Expanded(child: Text('${r['child']}', style: Ty.h3())), if (r['rides'] == true) const Pill('Rides the bus', toneName: 'green')]),
              if (r['rides'] == true)
                Column(children: [
                  LR(left: const Muted('Route'), right: Text('${r['route']}', style: Ty.body(w: FontWeight.w600))),
                  LR(left: const Muted('Stop'), right: Text('${r['stop'] ?? '-'}${r['time'] != null ? ' · ${r['time']}' : ''}', style: Ty.body(w: FontWeight.w600))),
                  if (r['vehicle'] != null) LR(left: const Muted('Vehicle'), right: Text('${r['vehicle']}', style: Ty.body(w: FontWeight.w600))),
                  if (r['driver'] != null) LR(left: const Muted('Driver'), right: Text('${r['driver']}${r['driver_phone'] != null ? ' · ${r['driver_phone']}' : ''}', style: Ty.body(w: FontWeight.w600))),
                ])
              else
                const Muted('Does not use the school bus.'),
            ]),
        ]),
      );
}

class ParentBoarding extends StatelessWidget {
  const ParentBoarding({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'parent/boarding',
        builder: (context, d, reload) => Screen(onRefresh: reload, children: [
          const PageTitle('Boarding'),
          if (_l(d['rows']).isEmpty) const Empty(icon: 'bed-outline', title: 'No boarders', body: 'None of your children are boarders.'),
          for (final r in _l(d['rows']))
            ECard(children: [
              Row(children: [Avatar('${r['child']}', size: 42), const SizedBox(width: 12), Expanded(child: Text('${r['child']}', style: Ty.h3())), r['exeat'] == true ? const Pill('Out on exeat', toneName: 'amber') : const Pill('In the hostel', toneName: 'green')]),
              LR(left: const Muted('Hostel'), right: Text('${r['hostel']} · ${r['room']}', style: Ty.body(w: FontWeight.w600))),
              if (r['house_master'] != null) LR(left: const Muted('House master'), right: Text('${r['house_master']}', style: Ty.body(w: FontWeight.w600))),
            ]),
        ]),
      );
}

/// Messages between parents and teachers: the same screen serves both, only the path prefix differs.
class Chat extends StatefulWidget {
  final String base;
  const Chat({super.key, required this.base});
  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  String? _open;
  bool _composing = false;

  @override
  Widget build(BuildContext context) {
    final parent = widget.base == 'parent';
    if (_open != null) {
      return WithBack(onBack: () => setState(() => _open = null), label: 'Messages', child: _Thread(base: widget.base, id: _open!));
    }
    return LoadView(
      path: '${widget.base}/chats',
      builder: (context, d, reload) {
        if (_composing) {
          return WithBack(
            onBack: () => setState(() => _composing = false),
            label: 'Messages',
            child: _NewChat(base: widget.base, students: _l(d['students']), onDone: (id) => setState(() { _composing = false; _open = id; })),
          );
        }
        return Screen(onRefresh: reload, children: [
          PageTitle('Messages', sub: parent ? "Talk to your child's teacher." : 'Talk to parents.'),
          AppButton('New message', icon: 'create-outline', disabled: _l(d['students']).isEmpty, onPressed: () => setState(() => _composing = true)),
          if (_l(d['rows']).isEmpty)
            const Empty(icon: 'chatbubbles-outline', title: 'No conversations yet', body: 'Start one with the button above.')
          else
            ListGroup([
              for (final t in _l(d['rows']))
                ListRow(
                  icon: 'chatbubble-ellipses-outline',
                  title: '${t['subject'] ?? 'Conversation'}',
                  sub: [t['with'], t['preview']].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                  badge: (t['unread'] as num? ?? 0) > 0 ? Pill('${t['unread']} new', toneName: 'blue') : null,
                  onPress: () => setState(() => _open = '${t['id']}'),
                ),
            ]),
        ]);
      },
    );
  }
}

class ParentChat extends StatelessWidget {
  const ParentChat({super.key});
  @override
  Widget build(BuildContext context) => const Chat(base: 'parent');
}

class TeacherChat extends StatelessWidget {
  const TeacherChat({super.key});
  @override
  Widget build(BuildContext context) => const Chat(base: 'teacher');
}

class _Thread extends StatefulWidget {
  final String base, id;
  const _Thread({required this.base, required this.id});
  @override
  State<_Thread> createState() => _ThreadState();
}

class _ThreadState extends State<_Thread> {
  final _text = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: '${widget.base}/chats/${widget.id}',
        builder: (context, d, reload) {
          Future<void> send() async {
            if (_text.text.trim().isEmpty) return;
            setState(() => _busy = true);
            try {
              await api('${widget.base}/chats/${widget.id}/reply', method: 'POST', body: {'message': _text.text.trim()});
              _text.clear();
              await reload();
            } catch (e) {
              _fail(e, 'Message not sent');
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }

          return Screen(
            onRefresh: reload,
            footer: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Field(controller: _text, hint: 'Write a reply', multiline: true, rows: 1, maxLength: 1500, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Tap(
                  label: 'Send',
                  onTap: _busy || _text.text.trim().isEmpty ? null : send,
                  child: Opacity(
                    opacity: _text.text.trim().isEmpty ? 0.4 : 1,
                    child: Container(width: 52, height: 52, decoration: BoxDecoration(color: color.brand, shape: BoxShape.circle), alignment: Alignment.center, child: Icn('send', size: 20, tint: color.onBrand)),
                  ),
                ),
              ),
            ]),
            children: [
              PageTitle('${d['subject']}', sub: [d['with'], d['student']].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
              for (final m in _l(d['messages']))
                Align(
                  alignment: m['mine'] == true ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: m['mine'] == true ? color.brand : color.card,
                        border: m['mine'] == true ? null : Border.all(color: color.line),
                        borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(m['mine'] == true ? 18 : 4), bottomRight: Radius.circular(m['mine'] == true ? 4 : 18)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Align(alignment: Alignment.centerLeft, child: Text('${m['body']}', style: Ty.body(c: m['mine'] == true ? color.onBrand : color.ink))),
                        const SizedBox(height: 3),
                        Text('${m['when']}', style: Ty.caption(c: (m['mine'] == true ? color.onBrand : color.muted).withValues(alpha: 0.75))),
                      ]),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _NewChat extends StatefulWidget {
  final String base;
  final List students;
  final ValueChanged<String> onDone;
  const _NewChat({required this.base, required this.students, required this.onDone});
  @override
  State<_NewChat> createState() => _NewChatState();
}

class _NewChatState extends State<_NewChat> {
  late String _student = widget.students.isEmpty ? '' : '${widget.students.first['id']}';
  final _subject = TextEditingController(), _message = TextEditingController();
  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final to = widget.students.cast<dynamic>().where((s) => '${s['id']}' == _student).firstOrNull?['to'];
    return Screen(
      footer: AppButton('Send message', icon: 'send', disabled: _student.isEmpty || _subject.text.trim().length < 3 || _message.text.trim().isEmpty, onPressed: () async {
        try {
          final r = await api('${widget.base}/chats', method: 'POST', body: {'student': _student, 'subject': _subject.text, 'message': _message.text});
          widget.onDone('${r['id']}');
        } catch (e) {
          _fail(e, 'Message not sent');
        }
      }),
      children: [
        PageTitle('New message', sub: to != null ? 'Goes to $to' : null),
        if (widget.students.length > 1)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('About which child', style: Ty.small(w: FontWeight.w600)),
            const SizedBox(height: 6),
            Chips<String>(title: 'Student', select: true, value: _student, onChange: (v) => setState(() => _student = v), options: [for (final s in widget.students) (value: '${s['id']}', label: '${s['name']}')]),
          ]),
        Field(icon: 'text-outline', label: 'Subject', controller: _subject, hint: 'What is it about?', maxLength: 120, onChanged: (_) => setState(() {})),
        Field(label: 'Message', controller: _message, hint: 'Write your message', multiline: true, maxLength: 1500, onChanged: (_) => setState(() {})),
      ],
    );
  }
}

/// A teacher offers meeting times; parents book them.
class TeacherMeetings extends StatelessWidget {
  const TeacherMeetings({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'teacher/meetings',
        builder: (context, d, reload) => Screen(onRefresh: reload, children: [
          const PageTitle('Parent meetings', sub: 'Offer times. Parents of your pupils book them.'),
          AppButton('Offer times', icon: 'add-circle-outline', onPressed: () => showAppSheet<void>(context, title: 'Offer times', tall: true, builder: (_) => _OfferTimes(onDone: reload))),
          if (_l(d['rows']).isEmpty)
            const Empty(icon: 'calendar-outline', title: 'No times offered', body: 'Use the button above to open a morning or afternoon.')
          else
            ListGroup([
              for (final r in _l(d['rows']))
                ListRow(
                  icon: r['booked'] == true ? 'person-circle-outline' : 'time-outline',
                  title: '${r['date']}, ${r['from']} to ${r['to']}',
                  sub: r['booked'] == true ? '${r['parent']}${r['student'] != null ? ' about ${r['student']}' : ''}${r['note'] != null ? ' · ${r['note']}' : ''}' : (r['place'] ?? (r['past'] == true ? 'Passed' : 'Open')) as String,
                  badge: r['booked'] == true ? const Pill('Booked', toneName: 'green') : null,
                  onPress: r['past'] == true
                      ? null
                      : () async {
                          final ok = await confirm(context, title: r['booked'] == true ? 'Cancel this meeting?' : 'Remove this time?', message: r['booked'] == true ? '${r['parent']} will be told.' : '', yes: r['booked'] == true ? 'Cancel meeting' : 'Remove', destructive: true);
                          if (!ok) return;
                          try {
                            await api('teacher/meetings/${r['id']}', method: 'DELETE');
                            await reload();
                          } catch (e) {
                            _fail(e, 'Could not remove');
                          }
                        },
                ),
            ]),
        ]),
      );
}

class _OfferTimes extends StatefulWidget {
  final Future<void> Function() onDone;
  const _OfferTimes({required this.onDone});
  @override
  State<_OfferTimes> createState() => _OfferTimesState();
}

class _OfferTimesState extends State<_OfferTimes> {
  String _date = '', _minutes = '15';
  final _from = TextEditingController(text: '09:00'), _until = TextEditingController(text: '11:00'), _place = TextEditingController();
  @override
  void dispose() {
    _from.dispose();
    _until.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = RegExp(r'^\d{2}:\d{2}$');
    return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 14), children: [
      DateField(label: 'Date', value: _date, onChange: (v) => setState(() => _date = v), min: formatDate(DateTime.now())),
      const SizedBox(height: 12),
      Field(label: 'From (24-hour, like 09:00)', controller: _from, hint: '09:00', maxLength: 5, keyboardType: TextInputType.datetime, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      Field(label: 'Until', controller: _until, hint: '11:00', maxLength: 5, keyboardType: TextInputType.datetime, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      Chips<String>(value: _minutes, onChange: (v) => setState(() => _minutes = v), options: [for (final m in const ['10', '15', '20', '30']) (value: m, label: '$m min')]),
      const SizedBox(height: 12),
      Field(label: 'Place (optional)', controller: _place, hint: 'Staff room', maxLength: 120),
      const SizedBox(height: 12),
      AppButton('Add times', icon: 'checkmark', disabled: parseDate(_date) == null || !time.hasMatch(_from.text) || !time.hasMatch(_until.text), onPressed: () async {
        try {
          final r = await api('teacher/meetings', method: 'POST', body: {'date': isoDate(_date), 'from': _from.text, 'until': _until.text, 'minutes': int.parse(_minutes), 'place': _place.text.trim().isEmpty ? null : _place.text.trim()});
          notify.ok('${r['message']}');
          if (context.mounted) Navigator.pop(context);
          await widget.onDone();
        } catch (e) {
          _fail(e, 'Could not add times');
        }
      }),
    ]);
  }
}

/// A parent books one of the times offered by their children's teachers.
class ParentMeetings extends StatelessWidget {
  const ParentMeetings({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'parent/meetings',
        builder: (context, d, reload) {
          final students = _l(d['students']);
          return Screen(onRefresh: reload, children: [
            const PageTitle('Meet a teacher', sub: 'Book a time. The teacher is told straight away.'),
            if (_l(d['mine']).isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Your meetings'),
                const SizedBox(height: 8),
                ListGroup([
                  for (final r in _l(d['mine']))
                    ListRow(
                      icon: 'calendar-outline',
                      title: '${r['teacher']}',
                      sub: '${r['when']}${r['student'] != null ? ' · ${r['student']}' : ''}',
                      onPress: r['past'] == true
                          ? null
                          : () async {
                              if (!await confirm(context, title: 'Cancel this meeting?', message: '${r['teacher']}, ${r['when']}', yes: 'Cancel meeting', destructive: true)) return;
                              try {
                                await api('parent/meetings/${r['id']}/cancel', method: 'POST');
                                await reload();
                              } catch (e) {
                                _fail(e, 'Could not cancel');
                              }
                            },
                    ),
                ]),
              ]),
            const SectionTitle('Times you can book'),
            if (_l(d['open']).isEmpty)
              const Empty(icon: 'calendar-outline', title: 'Nothing open right now', body: 'When a teacher offers meeting times they appear here.')
            else
              ListGroup([
                for (final r in _l(d['open']))
                  ListRow(
                    icon: 'time-outline',
                    title: '${r['date']}, ${r['from']} to ${r['to']}',
                    sub: '${r['teacher']}${r['place'] != null ? ' · ${r['place']}' : ''}',
                    onPress: () => showAppSheet<void>(context, title: 'Book this time', tall: true, builder: (_) => _BookSlot(slot: r, students: students, onDone: reload)),
                  ),
              ]),
          ]);
        },
      );
}

class _BookSlot extends StatefulWidget {
  final dynamic slot;
  final List students;
  final Future<void> Function() onDone;
  const _BookSlot({required this.slot, required this.students, required this.onDone});
  @override
  State<_BookSlot> createState() => _BookSlotState();
}

class _BookSlotState extends State<_BookSlot> {
  late String _student = widget.students.isEmpty ? '' : '${widget.students.first['id']}';
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 14), children: [
        Muted('${widget.slot['teacher']}: ${widget.slot['when']}'),
        const SizedBox(height: 12),
        if (widget.students.length > 1) ...[Chips<String>(title: 'Student', select: true, value: _student, onChange: (v) => setState(() => _student = v), options: [for (final x in widget.students) (value: '${x['id']}', label: '${x['name']}')]), const SizedBox(height: 12)],
        Field(label: 'What would you like to talk about? (optional)', controller: _note, multiline: true, maxLength: 300),
        const SizedBox(height: 12),
        AppButton('Book', icon: 'checkmark', onPressed: () async {
          try {
            final r = await api('parent/meetings/${widget.slot['id']}/book', method: 'POST', body: {'student': _student, 'note': _note.text.trim().isEmpty ? null : _note.text.trim()});
            notify.ok('${r['message']}');
          } catch (e) {
            _fail(e, 'Could not book');
          }
          if (context.mounted) Navigator.pop(context);
          await widget.onDone();
        }),
      ]);
}

class TeacherLeave extends StatefulWidget {
  const TeacherLeave({super.key});
  @override
  State<TeacherLeave> createState() => _TeacherLeaveState();
}

class _TeacherLeaveState extends State<TeacherLeave> {
  String _type = 'annual', _from = '', _to = '';
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'me/leave',
        builder: (context, d, reload) {
          final b = d['balance'];
          final used = (b['entitled'] as num) > 0 ? ((b['used'] as num) / (b['entitled'] as num) * 100).round() : 0;
          final types = (d['types'] as Map).entries.map((e) => (value: '${e.key}', label: '${e.value}')).toList();
          return Screen(onRefresh: reload, children: [
            const PageTitle('Leave', sub: 'Ask for leave and see what was decided.'),
            ECard(title: 'Annual leave this year', icon: 'airplane-outline', children: [
              Text.rich(TextSpan(children: [TextSpan(text: '${b['left']} ', style: Ty.custom(26, FontWeight.w800, ls: -0.5)), TextSpan(text: 'of ${b['entitled']} days left', style: Ty.small())])),
              Bar(used.toDouble(), tint: used > 85 ? tone('amber').fg : color.brand),
              Muted('${b['used']} used'),
            ]),
            ECard(title: 'Ask for leave', icon: 'create-outline', children: [
              Chips<String>(value: _type, onChange: (v) => setState(() => _type = v), options: types),
              DateField(label: 'First day', value: _from, onChange: (v) => setState(() {
                _from = v;
                final a = parseDate(v), c = parseDate(_to);
                if (a != null && c != null && c.isBefore(a)) _to = v;
              })),
              DateField(label: 'Last day', value: _to, onChange: (v) => setState(() => _to = v), min: _from.isEmpty ? null : _from),
              Field(label: 'Reason (optional)', controller: _reason, hint: 'Anything School Admin should know', maxLength: 300),
              AppButton('Send request', icon: 'send', disabled: _from.isEmpty || _to.isEmpty, onPressed: () async {
                try {
                  await api('me/leave', method: 'POST', body: {'type': _type, 'from': _from, 'to': _to, 'reason': _reason.text.isEmpty ? null : _reason.text});
                  setState(() { _from = ''; _to = ''; _reason.clear(); });
                  await reload();
                  notify.ok('Request sent', 'School Admin will decide on it.');
                } catch (e) {
                  _fail(e, 'Request not sent');
                }
              }),
            ]),
            if (_l(d['rows']).isNotEmpty) const SectionTitle('Your requests'),
            for (final l in _l(d['rows']))
              ECard(children: [
                LR(left: Text('${l['type']} · ${l['days']} day${l['days'] == 1 ? '' : 's'}', style: Ty.h3()), right: Pill('${l['status']}', toneName: '${l['tone']}')),
                Muted('${l['from']} to ${l['to']}'),
                if (l['note'] != null) Muted('${l['note']}'),
                if (l['status'] == 'Pending')
                  AppButton('Cancel request', kind: BtnKind.plain, onPressed: () async {
                    try {
                      await api('me/leave/${l['id']}/cancel', method: 'POST');
                      await reload();
                    } catch (e) {
                      _fail(e, 'Could not cancel');
                    }
                  }),
              ]),
          ]);
        },
      );
}

class TeacherPayslips extends StatelessWidget {
  const TeacherPayslips({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'me/payslips',
        builder: (context, d, reload) => Screen(onRefresh: reload, children: [
          const PageTitle('Payslips', sub: "Private to you. Each one appears when the month's pay is released."),
          if (_l(d['rows']).isEmpty) const Empty(icon: 'receipt-outline', title: 'No payslips yet', body: "Your payslip shows here after each month's pay is released."),
          for (final p in _l(d['rows']))
            Container(
              decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: color.line)),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  color: color.brand,
                  padding: const EdgeInsets.all(18),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['month']}', style: Ty.custom(18, FontWeight.w700, c: color.onBrand)), Text('Payslip', style: Ty.custom(12, FontWeight.w400, c: color.onBrand.withValues(alpha: 0.8)))]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Take-home', style: Ty.custom(12, FontWeight.w400, c: color.onBrand.withValues(alpha: 0.8))), Text(naira(p['net'] as num), style: Ty.custom(24, FontWeight.w800, c: color.onBrand, ls: -0.5))]),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Earnings', style: Ty.caption()),
                    LR(left: Text('Basic pay', style: Ty.body()), right: Text(naira(p['basic'] as num), style: Ty.body())),
                    for (final l in _l(p['lines']['allowances'])) LR(left: Text('${l['name'] ?? l['label']}', style: Ty.body()), right: Text(naira(l['amount'] as num), style: Ty.body())),
                    LR(left: Text('Gross pay', style: Ty.body(w: FontWeight.w700)), right: Text(naira(p['gross'] as num), style: Ty.body(w: FontWeight.w700))),
                    const Rule(),
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text('Deductions', style: Ty.caption())),
                    if (_l(p['lines']['deductions']).isEmpty) const Muted('None this month'),
                    for (final l in _l(p['lines']['deductions'])) LR(left: Text('${l['name'] ?? l['label']}', style: Ty.body()), right: Text('- ${naira(l['amount'] as num)}', style: Ty.body())),
                    LR(left: Text('Total deductions', style: Ty.body(w: FontWeight.w700)), right: Text('- ${naira(p['deductions'] as num)}', style: Ty.body(w: FontWeight.w700))),
                    const SizedBox(height: 10),
                    DocActions(path: 'me/payslips/${p['id']}/pdf', name: 'payslip-${p['month']}', label: 'Payslip (PDF)'),
                  ]),
                ),
              ]),
            ),
        ]),
      );
}

/// Plain text from the little markdown the docs are written in.
String _plain(String md) => md.replaceAll(RegExp(r'^## ', multiLine: true), '').replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1]!).replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!).replaceAll(RegExp(r'^- ', multiLine: true), '• ');

/// The documentation written for this role, for the phone app.
class HelpDocs extends StatefulWidget {
  const HelpDocs({super.key});
  @override
  State<HelpDocs> createState() => _HelpDocsState();
}

class _HelpDocsState extends State<HelpDocs> {
  String? _open;
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'docs',
        builder: (context, d, reload) {
          final needle = _q.text.trim().toLowerCase();
          final list = _l(d['articles']).where((a) => (a['platforms'] as List).contains('app') && (needle.isEmpty || '${a['title']} ${a['category']} ${a['body']}'.toLowerCase().contains(needle))).toList();
          return Screen(onRefresh: reload, children: [
            const PageTitle('Help', sub: 'How things work, in plain words.'),
            Field(icon: 'search-outline', label: 'Search help', controller: _q, hint: 'Type a word, like fees or password', autocorrect: false, onChanged: (_) => setState(() {})),
            if (list.isEmpty) const Empty(icon: 'help-buoy-outline', title: 'Nothing found', body: 'Try a different word.'),
            for (final a in list)
              ECard(onPress: () => setState(() => _open = _open == '${a['id']}' ? null : '${a['id']}'), children: [
                Row(children: [
                  const IconBadge('document-text-outline', size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${a['title']}', style: Ty.h3()), Muted('${a['category']}')])),
                  Icn(_open == '${a['id']}' ? 'chevron-up' : 'chevron-down', size: 18, tint: color.muted),
                ]),
                if (_open == '${a['id']}') Text(_plain('${a['body']}'), style: Ty.body().copyWith(height: 1.6)),
              ]),
          ]);
        },
      );
}
