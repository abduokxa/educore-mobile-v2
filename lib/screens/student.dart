import 'package:flutter/material.dart';
import '../features/docs.dart';
import '../features/pick.dart';
import '../shell/nav.dart';
import '../ui/ui.dart';
import 'parent.dart';

List _l(dynamic v) => (v as List?) ?? const [];

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'student/home',
        builder: (context, d, reload) {
          final rate = pct(d['attendance']?['line'] as String?);
          final last = d['last_result'];
          return Screen(onRefresh: reload, children: [
            HeroBlock(title: '${d['greeting']}', sub: d['today'] as String?, icon: 'sparkles-outline'),
            ShortcutGrid([ShortcutItem('Notices', () => Nav.I.go('Notices'))]),
            Columns([
              ECard(title: "${d['day']}'s lessons", icon: 'time-outline', children: [
                if (_l(d['periods']).isEmpty) const Muted('No lessons today.'),
                for (final p in _l(d['periods'])) LR(left: TwoLine('${p['subject']}', '${p['teacher']}'), right: Pill('${p['time']}', toneName: 'blue')),
              ]),
              if (d['attendance'] != null)
                ECard(title: 'Attendance', icon: 'checkmark-done-outline', children: [
                  Text('${d['attendance']['line']}', style: Ty.h2()),
                  if (rate != null) Bar(rate.toDouble(), tint: rate >= 85 ? color.brand : tone('amber').fg),
                  Muted('${d['attendance']['note']}'),
                ]),
              if (last != null)
                ECard(title: 'Latest result', icon: 'ribbon-outline', children: [
                  Muted('${last['term']}'),
                  StatRow([Stat(icon: 'stats-chart-outline', label: 'Average', value: '${last['average']}'), Stat(icon: 'trophy-outline', label: 'Position', value: '${last['position']}')]),
                  if (last['term_id'] != null) DocActions(path: 'student/results/pdf', query: {'term': '${last['term_id']}'}, name: 'report-card-${last['term']}', label: 'Report card (PDF)'),
                ]),
              if (_l(d['loans']).isNotEmpty)
                ECard(title: 'Library books', icon: 'library-outline', children: [
                  for (final l in _l(d['loans'])) LR(left: TwoLine('${l['title']}', 'Due ${l['due']}'), right: Pill('${l['status']}', toneName: '${l['tone']}')),
                ]),
            ]),
            if (_l(d['notices']).isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('From the school'),
                const SizedBox(height: 8),
                ListGroup([for (final n in _l(d['notices'])) ListRow(icon: 'megaphone-outline', title: '${n['title']}', sub: n['when'] as String?, onPress: () => Nav.I.go('Notices', notice: '${n['id']}'))]),
              ]),
            if (_l(d['upcoming']).isNotEmpty)
              ListGroup([for (final u in _l(d['upcoming'])) ListRow(icon: 'calendar-outline', title: '${u['name']}', sub: '${u['dates']}${u['note'] != null ? ' · ${u['note']}' : ''}')]),
          ]);
        },
      );
}

class StudentResults extends StatelessWidget {
  const StudentResults({super.key});
  @override
  Widget build(BuildContext context) => PickGate(title: 'My results', builder: (context, c) => ResultsScreen(path: 'student/results', pdf: 'student/results/pdf', title: 'My results', choice: c));
}
