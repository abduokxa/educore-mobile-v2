import 'package:flutter/material.dart';
import '../core/api.dart';
import '../features/docs.dart';
import '../features/pdf_view.dart';
import '../features/paysheet.dart';
import '../features/pick.dart';
import '../shell/nav.dart';
import '../ui/ui.dart';

int? pct(String? line) {
  final m = RegExp(r'(\d+)\s*(?:of|/)\s*(\d+)').firstMatch(line ?? '');
  if (m == null) return null;
  final total = int.parse(m.group(2)!);
  return total > 0 ? (int.parse(m.group(1)!) / total * 100).round() : null;
}

List _l(dynamic v) => (v as List?) ?? const [];

class ParentHome extends StatelessWidget {
  const ParentHome({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'parent/home',
        builder: (context, d, reload) {
          final kids = _l(d['kids']);
          final owing = kids.any((k) => k['tone'] != 'green');
          final banner = d['banner'] as String?;
          return Screen(onRefresh: reload, children: [
            HeroBlock(title: '${d['greeting']}', sub: d['today'] as String?, icon: 'sunny-outline'),
            if (banner != null)
              ECard(onPress: () => Nav.I.go('Fees'), children: [
                Row(children: [
                  IconBadge('alert-circle-outline', tint: tone('amber').fg, bg: tone('amber').bg),
                  const SizedBox(width: 12),
                  Expanded(child: Text(banner, style: Ty.body())),
                  Icn('chevron-forward', size: 18, tint: color.muted),
                ]),
              ]),
            ShortcutGrid([
              ShortcutItem('Fees', () => Nav.I.go('Fees'), hint: owing ? 'Balance due' : 'Paid'),
              ShortcutItem('Results', () => Nav.I.go('Results'), hint: 'Report card'),
              ShortcutItem('Attendance', () => Nav.I.go('Attendance')),
              ShortcutItem('Notices', () => Nav.I.go('Notices')),
            ]),
            Columns([
              for (final k in kids)
                Builder(builder: (context) {
                  final rate = pct(k['attendance'] as String?);
                  return ECard(children: [
                    Row(children: [
                      Avatar('${k['name']}', size: 48, solid: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${k['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.h2()),
                          Muted('${k['class']}${k['teacher'] != null ? ' · ${k['teacher']}' : ''}'),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Pill('${k['fees']}', toneName: '${k['tone']}'),
                    ]),
                    Column(children: [
                      LR(left: Text('Attendance this term', style: Ty.small()), right: Text('${k['attendance']}', style: Ty.custom(14, FontWeight.w700))),
                      if (rate != null) Bar(rate.toDouble(), tint: rate >= 85 ? color.brand : tone('amber').fg),
                    ]),
                    if (homeLayout == HomeLayout.cards)
                      Row(children: [
                        Expanded(child: AppButton('Fees', kind: BtnKind.soft, icon: 'wallet-outline', onPressed: () => Nav.I.go('Fees'))),
                        const SizedBox(width: 8),
                        Expanded(child: AppButton('Results', kind: BtnKind.soft, icon: 'ribbon-outline', onPressed: () => Nav.I.go('Results'))),
                      ]),
                  ]);
                }),
            ]),
            if (_l(d['notices']).isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('From the school'),
                const SizedBox(height: 8),
                ListGroup([for (final n in _l(d['notices'])) ListRow(icon: 'megaphone-outline', title: '${n['title']}', sub: n['when'] as String?, onPress: () => Nav.I.go('Notices', notice: '${n['id']}'))]),
              ]),
          ]);
        },
      );
}

class ParentFees extends StatelessWidget {
  const ParentFees({super.key});
  @override
  Widget build(BuildContext context) => PickGate(title: 'Fees', kids: true, builder: (context, c) => _FeesView(c));
}

class _FeesView extends StatelessWidget {
  final Choice choice;
  const _FeesView(this.choice);

  Future<void> _open(BuildContext context, String path, Map<String, String?> query, String name) async {
    try {
      await previewDocument(path, query, name);
    } catch (e) {
      if (context.mounted) await alertBox(context, 'Could not open the file', e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'parent/fees',
        query: {'child': choice.child, 'term': choice.term},
        builder: (context, d, reload) {
          final totals = d['totals'];
          final paidPct = (totals['billed'] as num) > 0 ? ((totals['paid'] as num) / (totals['billed'] as num) * 100).round() : 0;
          final balance = (totals['balance'] as num);
          final history = _l(d['history']);
          return Screen(onRefresh: reload, children: [
            PageTitle('Fees', sub: d['term'] as String?),
            choice.bar,
            ECard(children: [
              Text(balance > 0 ? 'Balance to pay' : 'Nothing to pay', style: Ty.small()),
              CountUp(to: balance / 100, render: (n) => naira((n * 100).round()), style: Ty.custom(34, FontWeight.w800, ls: -1, c: balance > 0 ? color.ink : color.brand)),
              Bar(paidPct.toDouble()),
              LR(left: Muted('Paid ${naira(totals['paid'] as num)}'), right: Muted('Billed ${naira(totals['billed'] as num)}')),
            ]),
            if (_l(d['bills']).isEmpty) const Empty(icon: 'wallet-outline', title: 'No bill for this term', body: 'When the school sends a bill for this child and term, it appears here.'),
            for (final b in _l(d['bills']))
              Slip(
                top: [
                  Row(children: [
                    Avatar('${b['student']}', size: 42),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${b['student']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.h3()), Muted('${b['class']} · Due ${b['due']}')])),
                    Pill('${b['status']}', toneName: '${b['tone']}'),
                  ]),
                  for (final l in _l(b['lines'])) LR(left: Text('${l['item']}', style: Ty.body(c: color.muted)), right: Text(naira(l['amount'] as num), style: Ty.body(w: FontWeight.w600))),
                ],
                children: [
                  LR(left: Text('Total', style: Ty.body(w: FontWeight.w700)), right: Text(naira(b['total'] as num), style: Ty.custom(18, FontWeight.w800))),
                  if (b['paid_note'] != null) Muted('${b['paid_note']}'),
                  if ((b['balance'] as num) > 0) AppButton('Pay ${naira(b['balance'] as num)}', icon: 'card-outline', onPressed: () => showPaySheet(context, '${b['id']}', reload)),
                  if (((b['optional'] as num?) ?? 0) > 0) AppButton('Other payments (${b['optional']})', icon: 'add-circle-outline', kind: BtnKind.soft, onPressed: () => showPaySheet(context, '${b['id']}', reload)),
                  DocActions(path: 'parent/bill', query: {'invoice': '${b['id']}'}, name: 'bill-${b['number'] ?? b['id']}', label: 'Bill (PDF)'),
                  if (b['receipt_id'] != null) DocActions(path: 'parent/receipts/${b['receipt_id']}', name: 'receipt-${b['receipt']}', label: 'Receipt ${b['receipt']} (PDF)'),
                ],
              ),
            if (d['child'] != null) DocActions(path: 'parent/statement', query: {'child': '${d['child']['id']}'}, name: 'fee-statement-${'${d['child']['name']}'.split(' ').first}', label: 'Fee statement (PDF)'),
            if (history.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Payments made'),
                const SizedBox(height: 8),
                ListGroup([
                  for (final h in history)
                    ListRow(
                      icon: 'receipt-outline',
                      title: '${naira(h['amount'] as num)} · ${h['child']}',
                      sub: '${h['date']} · ${h['receipt'] ?? ''}',
                      right: Icn('eye-outline', size: 20, tint: color.brand),
                      onPress: () => _open(context, 'parent/receipts/${h['id']}', {}, 'receipt-${h['receipt']}'),
                    ),
                ]),
              ]),
          ]);
        },
      );
}

class ParentResults extends StatelessWidget {
  const ParentResults({super.key});
  @override
  Widget build(BuildContext context) => PickGate(title: 'Results', kids: true, builder: (context, c) => ResultsScreen(path: 'parent/results', pdf: 'parent/results/pdf', title: 'Results', choice: c));
}

/// Every published result, by session and term. Used by the parent and the student.
class ResultsScreen extends StatelessWidget {
  final String path, pdf, title;
  final Choice choice;
  const ResultsScreen({super.key, required this.path, required this.pdf, required this.title, required this.choice});

  @override
  Widget build(BuildContext context) => LoadView(
        path: path,
        query: {'child': choice.child, 'term': choice.term},
        builder: (context, d, reload) {
          final c = d['card'];
          final subjects = c == null ? const [] : _l(c['subjects']);
          final each = c != null && subjects.isNotEmpty ? (c['max_total'] as num) / subjects.length : 100;
          final history = _l(d['history']);
          return Screen(onRefresh: reload, children: [
            PageTitle(title, sub: '${d['child']['name']}'),
            choice.bar,
            if (d['hold'] != null)
              Empty(icon: 'lock-closed-outline', title: 'Results are on hold', body: '${d['hold']['message']}')
            else if (c == null)
              Empty(icon: 'ribbon-outline', title: 'No published results yet', body: (d['pending_note'] as String?) ?? 'Results appear here once the school publishes them.')
            else ...[
              HeroBlock(
                title: '${c['average']}%',
                sub: '${c['line']}',
                icon: 'ribbon-outline',
                child: Row(children: [
                  _heroFigure('${c['grand_total']}', ' / ${c['max_total']}', 'Total score'),
                  if (c['show_position'] == true) ...[const SizedBox(width: 20), _heroFigure('${c['position_text']}', '', 'Position')],
                ]),
              ),
              DocActions(path: pdf, query: {'child': choice.child ?? '${d['child']['id']}', 'term': choice.term}, name: 'report-card-${d['child']['name']}-${c['term']}', label: 'Report card (PDF)'),
              ECard(title: 'Subjects', icon: 'book-outline', children: [
                for (var i = 0; i < subjects.length; i++)
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (i > 0) const Padding(padding: EdgeInsets.only(bottom: 6), child: Rule()),
                    LR(
                      left: Text('${subjects[i]['name']}', style: Ty.body(w: FontWeight.w600)),
                      right: Row(mainAxisSize: MainAxisSize.min, children: [Text('${subjects[i]['total']}', style: Ty.custom(17, FontWeight.w800)), const SizedBox(width: 12), Stamp('${subjects[i]['grade']}', size: 36)]),
                    ),
                    Bar(((num.tryParse('${subjects[i]['total']}') ?? 0) / each * 100).clamp(0, 100).toDouble(), height: 5, tint: tone(gradeTone('${subjects[i]['grade']}')).fg),
                  ]),
              ]),
              if (c['teacher_comment'] != null) ECard(title: 'Class teacher', icon: 'chatbox-ellipses-outline', children: [Text('${c['teacher_comment']}', style: Ty.body().copyWith(fontStyle: FontStyle.italic))]),
            ],
            if (history.length > 1)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('All results'),
                const SizedBox(height: 8),
                ListGroup([
                  for (final h in history)
                    ListRow(
                      icon: 'ribbon-outline',
                      title: '${h['term']} · ${h['session']}',
                      sub: '${h['class']} · ${h['average']}%${h['position'] != null ? ' · ${h['position']}' : ''}',
                      right: h['term_id'] == c?['term_id'] ? const Pill('Showing', toneName: 'green') : Icn('chevron-forward', size: 18, tint: color.muted),
                      onPress: () => choice.select('${h['session']}', '${h['term_id']}'),
                    ),
                ]),
              ]),
          ]);
        },
      );

  Widget _heroFigure(String big, String small, String label) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [TextSpan(text: big, style: Ty.custom(17, FontWeight.w800, c: color.onBrand)), TextSpan(text: small, style: Ty.custom(13, FontWeight.w600, c: color.onBrand.withValues(alpha: 0.7)))])),
        Text(label, style: Ty.caption(c: color.onBrand.withValues(alpha: 0.75))),
      ]);
}

class ParentAttendance extends StatelessWidget {
  const ParentAttendance({super.key});
  @override
  Widget build(BuildContext context) => PickGate(title: 'Attendance', kids: true, builder: (context, c) => _AttendanceView(c));
}

class _AttendanceView extends StatelessWidget {
  final Choice choice;
  const _AttendanceView(this.choice);
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'parent/attendance',
        query: {'child': choice.child, 'term': choice.term},
        builder: (context, d, reload) {
          final c = d['counts'];
          final days = (c['school_days'] as num);
          final rate = days > 0 ? ((c['present'] as num) / days * 100).round() : null;
          return Screen(onRefresh: reload, children: [
            PageTitle('Attendance', sub: '${d['child']['name']} · ${d['term']}'),
            choice.bar,
            ECard(children: [
              LR(left: Text('Present this term', style: Ty.small()), right: rate != null ? Text('$rate%', style: Ty.custom(20, FontWeight.w800)) : null),
              if (rate != null) Bar(rate.toDouble(), tint: rate >= 85 ? color.brand : tone('amber').fg),
            ]),
            StatRow([
              Stat(icon: 'checkmark-circle-outline', label: 'Present', value: '${c['present']}', hint: 'of ${c['school_days']} days'),
              Stat(icon: 'close-circle-outline', label: 'Absent', value: '${c['absent']}', tint: tone('red').fg),
              Stat(icon: 'time-outline', label: 'Late', value: '${c['late']}', tint: tone('amber').fg),
            ]),
            if (_l(d['absences']).isNotEmpty)
              ECard(title: 'Absences', icon: 'calendar-outline', children: [
                for (final a in _l(d['absences'])) LR(left: TwoLine('${a['date']}', '${a['reason']}'), right: Pill('${a['status']}', toneName: '${a['tone']}')),
              ]),
          ]);
        },
      );
}

/// How the school reaches this parent: the channel, which optional notices to receive, and what was sent lately.
class ParentNotices extends StatefulWidget {
  const ParentNotices({super.key});
  @override
  State<ParentNotices> createState() => _ParentNoticesState();
}

class _ParentNoticesState extends State<ParentNotices> {
  String _channel = 'whatsapp';
  List<String> _off = [];
  dynamic _seen;

  @override
  Widget build(BuildContext context) => LoadView(
        path: 'parent/notifications',
        builder: (context, d, reload) {
          if (!identical(_seen, d)) {
            _seen = d;
            _channel = '${d['channel']}';
            _off = _l(d['events']).where((e) => e['on'] != true).map((e) => '${e['key']}').toList();
          }
          final hasEmail = d['has_email'] == true;
          Future<void> save() async {
            try {
              final r = await api('parent/notifications', method: 'PUT', body: {'channel': _channel, 'off': _off});
              notify.ok('Saved', '${r['message']}');
              await reload();
            } catch (e) {
              notify.err('Could not save', e is ApiError ? e.message : 'Try again.');
            }
          }

          return Screen(onRefresh: reload, children: [
            const PageTitle('Notice settings', sub: 'Choose how the school reaches you.'),
            ECard(title: 'How should we reach you?', icon: 'paper-plane-outline', children: [
              Chips<String>(
                value: _channel,
                onChange: (v) => setState(() { if (v != 'email' || hasEmail) _channel = v; }),
                options: [(value: 'whatsapp', label: 'WhatsApp'), (value: 'sms', label: 'SMS'), if (hasEmail) (value: 'email', label: 'Email')],
              ),
              if (!hasEmail) const Muted('The school has no email address for you.'),
            ]),
            ECard(title: 'Optional notices', icon: 'notifications-outline', children: [
              for (final e in _l(d['events'])) CheckRow(label: '${e['label']}', value: !_off.contains(e['key']), onChange: (on) => setState(() => on ? _off.remove(e['key']) : _off.add('${e['key']}'))),
              const Muted('Bills, overdue notices, absence alerts and clinic visits are always sent.'),
            ]),
            AppButton('Save changes', icon: 'checkmark', onPressed: save),
            ECard(title: 'Recent messages from the school', icon: 'mail-outline', children: [
              if (_l(d['recent']).isEmpty) const Muted('Nothing has been sent to you yet.'),
              for (final m in _l(d['recent']))
                LR(
                  left: TwoLine('${m['title']}', '${m['when']} · ${m['channel']}'),
                  right: Pill(m['status'] == 'failed' ? 'Not delivered' : m['status'] == 'queued' ? 'Sending' : 'Sent', toneName: m['status'] == 'failed' ? 'red' : m['status'] == 'queued' ? 'amber' : 'green'),
                ),
            ]),
          ]);
        },
      );
}
