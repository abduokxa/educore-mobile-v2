import 'package:educore/core/term.dart';
import 'package:educore/core/theme.dart';
import 'package:educore/features/pick.dart';
import 'package:educore/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {double top = 40, double bottom = 24}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 800), padding: EdgeInsets.only(top: top, bottom: bottom)),
        child: Scaffold(body: child),
      ),
    );

void main() {
  setUp(() => applyTheme('educore', '#0B4A3B', false));

  testWidgets('a screen never scrolls under the status bar', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(Screen(bare: true, children: [for (var i = 0; i < 40; i++) SizedBox(height: 80, child: Text('row $i'))])));
    await tester.pumpAndSettle();
    final scroll = find.byType(SingleChildScrollView);
    // The scrolling area itself starts below the status bar, so scrolled content is clipped there, not drawn behind it.
    expect(tester.getTopLeft(scroll).dy, 40);
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pump();
    expect(tester.getTopLeft(scroll).dy, 40);
  });

  testWidgets('the last row can be scrolled clear of the system buttons', (tester) async {
    await tester.pumpWidget(host(Screen(bare: true, children: [for (var i = 0; i < 30; i++) SizedBox(height: 80, child: Text('row $i'))])));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('row 29')).dy, lessThanOrEqualTo(800 - 24));
  });

  group('choose, then continue', () {
    setUp(() {
      Terms.I.sessions = [
        SessionRow('s1', '2025/2026', true, [TermRow('t1', '1st Term', '1st Term 2025/2026', null, null, false, 'Finished'), TermRow('t2', '2nd Term', '2nd Term 2025/2026', null, null, true, 'Current')]),
        SessionRow('s0', '2024/2025', false, [TermRow('t0', '3rd Term', '3rd Term 2024/2025', null, null, false, 'Finished')]),
      ];
      Terms.I.current = 't2';
      Terms.I.loaded = true;
    });

    testWidgets('shows the form first, then the page for what was chosen', (tester) async {
      await tester.pumpWidget(host(PickGate(title: 'My results', builder: (context, c) => Text('showing ${c.summary}'))));
      await tester.pumpAndSettle();
      expect(find.text('What would you like to see?'), findsOneWidget);
      expect(find.textContaining('showing'), findsNothing);
      // The current session and term are already chosen; a tap on the term opens its list.
      await tester.tap(find.text('2nd Term (current)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1st Term'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('showing 2025/2026 · 1st Term'), findsOneWidget);
    });

    testWidgets('another session offers its own terms', (tester) async {
      await tester.pumpWidget(host(PickGate(title: 'My results', builder: (context, c) => Text('showing ${c.summary}'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025/2026 (current)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2024/2025'));
      await tester.pumpAndSettle();
      expect(find.text('3rd Term'), findsOneWidget);
      expect(find.text('2nd Term (current)'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('showing 2024/2025 · 3rd Term'), findsOneWidget);
    });

    testWidgets('Change goes back to the form', (tester) async {
      await tester.pumpWidget(host(PickGate(title: 'My results', builder: (context, c) => Column(children: [Text('showing ${c.summary}'), c.bar]))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('What would you like to see?'), findsOneWidget);
    });
  });

  group('searchable lists', () {
    List<({String value, String label})> people(int n) => [for (var i = 0; i < n; i++) (value: 'id$i', label: i == 3 ? 'John Adebayo' : 'Pupil number $i')];

    testWidgets('a few choices stay as chips', (tester) async {
      await tester.pumpWidget(host(Chips<String>(value: 'a', onChange: (_) {}, options: opts(const [('a', 'One'), ('b', 'Two'), ('c', 'Three')]))));
      expect(find.byType(SelectField<String>), findsNothing);
      expect(find.text('Two'), findsOneWidget);
    });

    testWidgets('many choices open a list that can be searched in any word order', (tester) async {
      String? chosen;
      await tester.pumpWidget(host(Chips<String>(title: 'Student', value: 'id0', onChange: (v) => chosen = v, options: people(40))));
      expect(find.byType(SelectField<String>), findsOneWidget);
      expect(find.text('Pupil number 0'), findsOneWidget);
      await tester.tap(find.byType(SelectField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Pupil number 5'), findsOneWidget); // in the list
      await tester.enterText(find.byType(TextField), 'ade john');
      await tester.pumpAndSettle();
      expect(find.text('Pupil number 5'), findsNothing);
      expect(find.text('John Adebayo'), findsOneWidget);
      await tester.tap(find.text('John Adebayo'));
      await tester.pumpAndSettle();
      expect(chosen, 'id3');
    });

    testWidgets('a search with no match says so', (tester) async {
      await tester.pumpWidget(host(Chips<String>(title: 'Student', value: 'id0', onChange: (_) {}, options: people(40))));
      await tester.tap(find.byType(SelectField<String>));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });
  });
}
