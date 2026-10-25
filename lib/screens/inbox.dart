import 'package:flutter/material.dart';
import '../core/api.dart';
import '../features/richtext.dart';
import '../shell/nav.dart';
import '../ui/ui.dart';

List _l(dynamic v) => (v as List?) ?? const [];
String _clip(String s, int n) => s.length > n ? s.substring(0, n) : s;

/// The screen a notice is about, from the page the server says it is: a tab, or a screen from the side menu written "page:key".
/// A page this person has no screen for leaves them on their notices.
String targetFor(String href) {
  final path = href.split('?').first.replaceAll(RegExp(r'/+$'), '');
  const exact = {
    '/teacher/attendance': 'Register', '/teacher/scores': 'Scores', '/teacher/class-results': 'page:class-results',
    '/parent/fees': 'Fees', '/parent/results': 'Results', '/parent/attendance': 'Attendance', '/parent': 'Home', '/student': 'Today', '/teacher': 'My day',
    '/student/results': 'Results', '/parent/notices': 'Notices', '/student/notices': 'Notices',
    '/student/tests': 'Tests', '/teacher/tests': 'page:mark-exams',
    '/parent/messages': 'page:chat', '/teacher/messages': 'page:chat', '/parent/meetings': 'page:meetings', '/teacher/meetings': 'page:meetings',
    '/parent/homework': 'page:homework', '/student/homework': 'page:homework', '/teacher/homework': 'page:homework',
    '/parent/calendar': 'page:calendar', '/student/calendar': 'page:calendar', '/teacher/calendar': 'page:calendar',
    '/parent/transport': 'page:transport', '/parent/boarding': 'page:boarding', '/parent/notifications': 'page:notice-settings',
    '/teacher/payslips': 'page:payslips', '/teacher/leave': 'page:leave',
    '/bursar': 'Today', '/bursar/defaulters': 'Owing', '/bursar/payments': 'Payments', '/bursar/payment': 'Payments', '/bursar/invoices': 'Bills',
    '/bursar/payslips': 'page:payslips', '/bursar/leave': 'page:leave', '/bursar/calendar': 'page:calendar',
  };
  if (exact.containsKey(path)) return exact[path]!;
  if (path.startsWith('/student/learn') || path.startsWith('/teacher/learning')) return 'Learn';
  return 'Notices';
}

/// A parent answers a notice from the notice itself: it goes to the class teacher as a message, the same as starting one in Messages.
class _ReplyBox extends StatefulWidget {
  final String title;
  const _ReplyBox({required this.title});
  @override
  State<_ReplyBox> createState() => _ReplyBoxState();
}

class _ReplyBoxState extends State<_ReplyBox> {
  bool _open = false, _sent = false;
  String _student = '';
  final _msg = TextEditingController();

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'parent/chats',
        onError: (_, _, _) => const SizedBox.shrink(),
        builder: (context, d, _) {
          final students = _l(d['students']);
          if (students.isEmpty) return const SizedBox.shrink();
          if (_sent) return const Muted('Your reply has been sent to the teacher.');
          if (!_open) return AppButton('Reply', icon: 'arrow-undo-outline', kind: BtnKind.soft, onPressed: () => setState(() => _open = true));
          final id = _student.isEmpty ? '${students.first['id']}' : _student;
          final who = students.cast<dynamic>().where((x) => '${x['id']}' == id).firstOrNull;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (students.length > 1) Chips<String>(value: id, onChange: (v) => setState(() => _student = v), options: [for (final x in students) (value: '${x['id']}', label: '${x['name']}')]),
            const SizedBox(height: 10),
            Field(label: who?['to'] != null ? 'Reply to ${who['to']}' : 'Your reply', controller: _msg, hint: 'Write your reply', multiline: true, maxLength: 1500, onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            AppButton('Send reply', icon: 'send', disabled: _msg.text.trim().isEmpty, onPressed: () async {
              try {
                await api('parent/chats', method: 'POST', body: {'student': id, 'subject': _clip('Re: ${widget.title}', 120), 'message': _msg.text});
                if (mounted) setState(() => _sent = true);
              } catch (e) {
                notify.err('Reply not sent', e is ApiError ? e.message : null);
              }
            }),
          ]);
        },
      );
}

class _NoticeBody extends StatelessWidget {
  final String path, id;
  const _NoticeBody({required this.path, required this.id});
  @override
  Widget build(BuildContext context) => LoadView(
        path: '$path/$id',
        onError: (_, e, _) => Padding(padding: const EdgeInsets.all(18), child: Muted(e)),
        builder: (context, n, _) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), children: [
          Text('${n['title']}', style: Ty.h3()),
          const SizedBox(height: 6),
          Muted([n['when'], n['time'], n['audience']].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
          const SizedBox(height: 10),
          RichText2('${n['text']}'),
          if (path.startsWith('parent/')) ...[const SizedBox(height: 10), _ReplyBox(title: '${n['title']}')],
        ]),
      );
}

/// The school's notices, each opened on its own in a sheet.
class _SchoolNotices extends StatefulWidget {
  final String path;
  final String? openId;
  const _SchoolNotices({required this.path, this.openId});
  @override
  State<_SchoolNotices> createState() => _SchoolNoticesState();
}

class _SchoolNoticesState extends State<_SchoolNotices> {
  String? _shown;
  @override
  void didUpdateWidget(_SchoolNotices old) {
    super.didUpdateWidget(old);
    _maybeOpen();
  }

  @override
  void initState() {
    super.initState();
    _maybeOpen();
  }

  void _maybeOpen() {
    final id = widget.openId;
    if (id == null || id == _shown) return;
    _shown = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(id);
    });
  }

  void _open(String id) => showAppSheet<void>(context, title: 'Notice', tall: true, builder: (_) => _NoticeBody(path: widget.path, id: id));

  @override
  Widget build(BuildContext context) => LoadView(
        path: widget.path,
        onError: (_, _, _) => const SizedBox.shrink(),
        builder: (context, d, _) {
          final rows = _l(d['data']);
          if (rows.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('From the school'),
            const SizedBox(height: 8),
            ListGroup([for (final n in rows) ListRow(icon: 'megaphone-outline', title: '${n['title']}', sub: '${n['when'] ?? ''}${n['text'] != null && '${n['text']}'.isNotEmpty ? ' · ${n['text']}' : ''}', onPress: () => _open('${n['id']}'))]),
          ]);
        },
      );
}

class Inbox extends StatefulWidget {
  final String? notices;
  const Inbox({super.key, this.notices});
  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  String? _open, _openNotice;
  bool _marked = false;

  @override
  void initState() {
    super.initState();
    Nav.I.addListener(_take);
    _take();
  }

  @override
  void dispose() {
    Nav.I.removeListener(_take);
    super.dispose();
  }

  void _take() {
    if (Nav.I.current != 'Notices') return;
    final n = Nav.I.takeNotice();
    if (n != null && mounted) setState(() => _openNotice = n);
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'inbox',
        builder: (context, d, reload) {
          if (!_marked && (d['unread'] as num? ?? 0) > 0) {
            _marked = true;
            api('inbox/read', method: 'POST').then<dynamic>((v) => v).catchError((_) => null);
          }
          final items = _l(d['items']);
          return Screen(onRefresh: reload, children: [
            const PageTitle('Notices', sub: 'What the school has told you lately.'),
            if (widget.notices != null) _SchoolNotices(path: widget.notices!, openId: _openNotice),
            if (items.isEmpty && widget.notices == null) const Empty(icon: 'notifications-off-outline', title: 'You are up to date', body: 'New notices from the school will show up here.'),
            for (final i in items)
              ECard(
                onPress: () {
                  final href = i['href'] as String?;
                  if (href != null) {
                    Nav.I.goTo(targetFor(href));
                  } else {
                    setState(() => _open = _open == i['id'] ? null : '${i['id']}');
                  }
                },
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconBadge(i['read'] == true ? 'mail-open-outline' : 'mail-unread-outline', size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text('${i['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ty.h3())), if (i['read'] != true) const Pill('New', toneName: 'green')]),
                        const SizedBox(height: 4),
                        RichText2('${i['body']}', maxLines: _open == '${i['id']}' ? null : 3, muted: true),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('${i['when']}', style: Ty.caption()),
                          if (i['href'] != null) ...[Text(' · ', style: Ty.caption()), Text('Open', style: Ty.caption(c: color.brand)), const SizedBox(width: 4), Icn('arrow-forward', size: 12, tint: color.brand)]
                          else if ('${i['body']}'.length > 120 && _open != '${i['id']}') Text(' · Read more', style: Ty.caption(c: color.brand)),
                        ]),
                      ]),
                    ),
                  ]),
                ],
              ),
          ]);
        },
      );
}
