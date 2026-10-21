import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/net.dart';
import '../core/offline.dart';
import '../core/theme.dart';
import 'base.dart';

/// What the top bar of every screen needs to know: the school, the person, and where "Account" lives.
class ChromeData {
  final String? school, logo, brandColor, name, backLabel;
  final VoidCallback? onAccount, back;
  final Widget? term, banner;
  const ChromeData({this.school, this.logo, this.brandColor, this.name, this.onAccount, this.back, this.backLabel, this.term, this.banner});

  ChromeData withBack(VoidCallback back, String label) =>
      ChromeData(school: school, logo: logo, brandColor: brandColor, name: name, onAccount: onAccount, back: back, backLabel: label, term: term, banner: banner);
}

class Chrome extends InheritedWidget {
  final ChromeData data;
  const Chrome({super.key, required this.data, required super.child});
  static ChromeData of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<Chrome>()?.data ?? const ChromeData();
  @override
  bool updateShouldNotify(Chrome old) => true;
}

/// Gives the screens below a Back button that returns to [label].
class WithBack extends StatelessWidget {
  final VoidCallback onBack;
  final String label;
  final Widget child;
  const WithBack({super.key, required this.onBack, required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Chrome(data: Chrome.of(context).withBack(onBack, label), child: child);
}

class H1 extends StatelessWidget {
  final String text;
  final Color? tint;
  const H1(this.text, {super.key, this.tint});
  @override
  Widget build(BuildContext context) => Semantics(header: true, child: Text(text, style: Ty.h1(c: tint)));
}

class Muted extends StatelessWidget {
  final String text;
  final int? maxLines;
  const Muted(this.text, {super.key, this.maxLines});
  @override
  Widget build(BuildContext context) => Text(text, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: Ty.small());
}

/// A page title with its one-line description underneath.
class PageTitle extends StatelessWidget {
  final String title;
  final String? sub;
  const PageTitle(this.title, {super.key, this.sub});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        H1(title),
        if (sub != null && sub!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(sub!)),
      ]);
}

/// Tells the person when they are looking at a saved copy, or when writes are waiting to be sent.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});
  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  int _waiting = 0;
  final List<String> _notes = [];
  @override
  void initState() {
    super.initState();
    Offline.I.addListener(_check);
    Net.I.addListener(_rebuild);
    _check();
  }

  @override
  void dispose() {
    Offline.I.removeListener(_check);
    Net.I.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _check() async {
    final w = await Offline.I.pending();
    final n = await Offline.I.takeNotes();
    if (!mounted) return;
    setState(() {
      _waiting = w;
      _notes.addAll(n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stale = Net.I.online ? null : lastStaleAt;
    if (stale == null && _waiting == 0 && _notes.isEmpty) return const SizedBox.shrink();
    final warn = tone('amber');
    final when = stale == null ? null : DateTime.fromMillisecondsSinceEpoch(stale);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: warn.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1, right: 10), child: Icn('cloud-offline-outline', size: 20, tint: warn.fg)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (when != null) Text('You are offline. This is what was saved on ${when.day}/${when.month}/${when.year} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}.', style: Ty.custom(13.5, FontWeight.w600, c: warn.fg)),
            if (_waiting > 0) Text('$_waiting saved on this phone, waiting to be sent when you are back online.', style: Ty.custom(13.5, FontWeight.w600, c: warn.fg)),
            for (final n in _notes) Text(n, style: Ty.small(c: color.danger)),
          ]),
        ),
      ]),
    );
  }
}

/// The quiet bar at the top of every screen: where you are, and your account.
class TopBar extends StatelessWidget {
  const TopBar({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Chrome.of(context);
    if (c.school == null && c.name == null) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (c.back != null)
          Tap(
            label: 'Back to ${c.backLabel ?? 'the menu'}',
            onTap: c.back,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icn('chevron-back', size: 22, tint: color.brand),
                Text(c.backLabel ?? 'Back', style: Ty.custom(15, FontWeight.w700, c: color.brand)),
              ]),
            ),
          )
        else
          Flexible(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SchoolLogo(uri: c.logo, name: c.school ?? 'Educore', tint: c.brandColor, size: 34),
              const SizedBox(width: 10),
              Flexible(child: Text(c.school ?? 'Educore', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.h3())),
            ]),
          ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (c.term != null) c.term!,
          if (c.name != null) ...[
            const SizedBox(width: 10),
            Tap(label: 'Your account', onTap: c.onAccount, child: Avatar(c.name!, size: 36, solid: true)),
          ],
        ]),
      ]),
    );
  }
}

/// Every screen: safe area, the top bar, content that rises into place, pull to refresh, and a readable column on tablets.
class Screen extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool center, bare;
  final Widget? footer;
  const Screen({super.key, required this.children, this.onRefresh, this.center = false, this.bare = false, this.footer});

  @override
  Widget build(BuildContext context) {
    final l = Layout.of(context);
    final chrome = Chrome.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final body = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(l.gutter, top + 6, l.gutter, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: l.maxWidth),
          child: Column(mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!bare) const TopBar(),
            if (!bare && chrome.banner != null) Padding(padding: const EdgeInsets.only(top: 16), child: chrome.banner),
            const _Gap(child: OfflineBanner()),
            for (var i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 && bare ? 0 : 16), child: Reveal(index: i, child: children[i])),
          ]),
        ),
      ),
    );
    return Container(
      color: color.bg,
      child: Column(children: [
        Expanded(
          child: onRefresh == null
              ? body
              : RefreshIndicator(color: color.brand, backgroundColor: color.card, onRefresh: onRefresh!, child: body),
        ),
        if (footer != null)
          Container(
            decoration: BoxDecoration(color: color.card, border: Border(top: BorderSide(color: color.line, width: 0.6))),
            padding: EdgeInsets.fromLTRB(l.gutter, 10, l.gutter, 10),
            child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: l.maxWidth), child: footer)),
          ),
      ]),
    );
  }
}

class _Gap extends StatelessWidget {
  final Widget child;
  const _Gap({required this.child});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 4), child: child);
}

/// A card. Give it `onPress` and it becomes a button that sinks when pressed.
class ECard extends StatelessWidget {
  final String? title, icon;
  final Widget? right;
  final VoidCallback? onPress;
  final List<Widget> children;
  final double gap;
  const ECard({super.key, this.title, this.icon, this.right, this.onPress, this.children = const [], this.gap = 10});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(kRadius + 4), border: Border.all(color: color.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null || right != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              if (icon != null) ...[IconBadge(icon!, size: 34), const SizedBox(width: 10)],
              Expanded(child: title != null ? Text(title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ty.h3()) : const SizedBox()),
              ?right,
            ]),
          ),
        for (var i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(top: (i == 0 && title == null && right == null) ? 0 : gap), child: children[i]),
      ]),
    );
    return onPress == null ? body : Tap(scale: 0.985, onTap: onPress, child: body);
  }
}

/// Something on the left and something on the right of one line.
class LR extends StatelessWidget {
  final Widget left;
  final Widget? right;
  const LR({super.key, required this.left, this.right});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: left),
          if (right != null) ...[const SizedBox(width: 10), right!],
        ]),
      );
}

/// Two lines of text in a column: a bold one over a muted one.
class TwoLine extends StatelessWidget {
  final String top;
  final String? bottom;
  final bool boldTop;
  const TwoLine(this.top, this.bottom, {super.key, this.boldTop = true});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(top, style: Ty.body(w: boldTop ? FontWeight.w600 : FontWeight.w400)),
        if (bottom != null && bottom!.isNotEmpty) Muted(bottom!),
      ]);
}

class Rule extends StatelessWidget {
  const Rule({super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Divider(height: 1, thickness: 0.6, color: color.line));
}

/// A figure with a label and an icon: attendance, balance, average.
class Stat extends StatelessWidget {
  final String icon, label;
  final Object value;
  final String? hint;
  final Color? tint;
  const Stat({super.key, required this.icon, required this.label, required this.value, this.hint, this.tint});
  @override
  Widget build(BuildContext context) {
    final t = tint ?? color.brand;
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, size: 34, tint: t, bg: t.withValues(alpha: 0.12)),
        const SizedBox(height: 8),
        Text('$value', style: Ty.custom(22, FontWeight.w800, ls: -0.4)),
        Text(label, style: Ty.small()),
        if (hint != null) Text(hint!, style: Ty.caption()),
      ]),
    );
  }
}

/// Stats side by side, sharing the width.
class StatRow extends StatelessWidget {
  final List<Widget> stats;
  const StatRow(this.stats, {super.key});
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < stats.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: stats[i])],
        ]),
      );
}

/// A grouped list: rows with an icon, a title, a line under it and a chevron, divided by hairlines.
class ListGroup extends StatelessWidget {
  final List<Widget> children;
  const ListGroup(this.children, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.line)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 0.6, thickness: 0.6, color: color.line),
            children[i],
          ],
        ]),
      );
}

class ListRow extends StatelessWidget {
  final String? icon, sub;
  final String title;
  final Widget? right, badge;
  final VoidCallback? onPress;
  const ListRow({super.key, this.icon, required this.title, this.sub, this.right, this.badge, this.onPress});
  @override
  Widget build(BuildContext context) => Tap(
        scale: 0.985,
        onTap: onPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              if (icon != null) ...[IconBadge(icon!, size: 38), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ty.h3(size: 15.5)),
                  if (sub != null && sub!.isNotEmpty) Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ty.small()),
                ]),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge!],
              if (right != null) ...[const SizedBox(width: 8), right!] else if (onPress != null) ...[const SizedBox(width: 8), Icn('chevron-forward', size: 18, tint: color.muted)],
            ]),
          ),
        ),
      );
}

/// The one bold block of a home screen: the brand colour on ruled exercise-book paper, with a margin line, a greeting, and what matters today.
class HeroBlock extends StatelessWidget {
  final String title;
  final String? sub, icon;
  final Widget? child;
  const HeroBlock({super.key, required this.title, this.sub, this.icon, this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: color.brand,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _RulesPainter(color.onBrand))),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 20, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: EdgeInsets.only(right: icon != null ? 44 : 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(header: true, child: Text(title, style: Ty.h1(c: color.onBrand))),
                    if (sub != null && sub!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub!, style: Ty.small(c: color.onBrand.withValues(alpha: 0.85)))),
                  ]),
                ),
                if (child != null) Padding(padding: const EdgeInsets.only(top: 14), child: child),
              ]),
            ),
            if (icon != null) Positioned(right: 18, top: 16, child: Opacity(opacity: 0.92, child: Icn(icon!, size: 28, tint: color.onBrand))),
          ]),
        ),
      );
}

class _RulesPainter extends CustomPainter {
  final Color ink;
  _RulesPainter(this.ink);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = ink.withValues(alpha: 0.13)
      ..strokeWidth = 0.8;
    for (var y = 38.0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    canvas.drawLine(const Offset(16, 0), Offset(16, size.height), Paint()
      ..color = const Color(0xFFFF8A80).withValues(alpha: 0.55)
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_RulesPainter old) => old.ink != ink;
}

String gradeTone(String g) => RegExp(r'^[AB]', caseSensitive: false).hasMatch(g) ? 'green' : RegExp(r'^C', caseSensitive: false).hasMatch(g) ? 'blue' : RegExp(r'^[DE]', caseSensitive: false).hasMatch(g) ? 'amber' : 'red';

/// A grade as a teacher's stamp: a square with the letter, slightly tilted, in the colour of how it went.
class Stamp extends StatelessWidget {
  final String grade;
  final double size;
  const Stamp(this.grade, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final t = tone(gradeTone(grade));
    return Semantics(
      label: 'Grade $grade',
      child: Transform.rotate(
        angle: -0.087,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(size * 0.22), border: Border.all(color: t.fg, width: 2)),
          alignment: Alignment.center,
          child: Text(grade, style: Ty.custom(size * 0.46, FontWeight.w800, c: t.fg)),
        ),
      ),
    );
  }
}

/// A slip: a card with a torn-off edge, for bills and receipts.
class Slip extends StatelessWidget {
  final List<Widget> top, children;
  const Slip({super.key, this.top = const [], this.children = const []});
  @override
  Widget build(BuildContext context) {
    Widget notch(bool left) => Positioned(
          left: left ? -10 : null,
          right: left ? null : -10,
          top: 0,
          child: Container(width: 18, height: 18, decoration: BoxDecoration(color: color.bg, shape: BoxShape.circle, border: Border.all(color: color.line))),
        );
    return Container(
      decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: color.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(top, 10))),
        SizedBox(
          height: 18,
          child: Stack(alignment: Alignment.center, children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter(color.line))),
            notch(true),
            notch(false),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(children, 10))),
      ]),
    );
  }
}

List<Widget> _spaced(List<Widget> items, double gap) => [for (var i = 0; i < items.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : gap), child: items[i])];

class _DashPainter extends CustomPainter {
  final Color c;
  _DashPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.c != c;
}

/// What to show when there is nothing yet: say what it is, and what to do.
class Empty extends StatelessWidget {
  final String icon, title;
  final String? body;
  final Widget? action;
  const Empty({super.key, this.icon = 'file-tray-outline', required this.title, this.body, this.action});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.line)),
        child: Column(children: [
          IconBadge(icon, size: 56),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: Ty.h3()),
          if (body != null && body!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(body!, textAlign: TextAlign.center, style: Ty.small())),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 10), child: action),
        ]),
      );
}

/// Picks the icon for a shortcut or menu entry from its name.
String iconFor(String label) {
  final l = label.toLowerCase();
  const map = <(String, String)>[
    ('fee|bill|pay', 'wallet-outline'), ('result|score|grade', 'ribbon-outline'), ('attend|register', 'checkmark-done-outline'), ('notice|inbox|alert', 'notifications-outline'),
    ('message|chat', 'chatbubbles-outline'), ('meeting|meet', 'people-circle-outline'), ('help', 'help-buoy-outline'), ('homework', 'book-outline'), ('calendar|day|today', 'calendar-outline'),
    ('bus|transport', 'bus-outline'), ('board|hostel', 'bed-outline'), ('test|exam', 'document-text-outline'), ('leave', 'airplane-outline'), ('payslip|pay slip', 'receipt-outline'),
    ('class', 'people-outline'), ('search', 'search-outline'), ('setting|account', 'settings-outline'), ('more', 'grid-outline'), ('home', 'home-outline'),
  ];
  for (final m in map) {
    if (RegExp(m.$1).hasMatch(l)) return m.$2;
  }
  return 'ellipse-outline';
}

class ShortcutItem {
  final String label;
  final String? hint, icon;
  final VoidCallback go;
  const ShortcutItem(this.label, this.go, {this.hint, this.icon});
}

/// Shortcuts under the greeting. Grid look: big square buttons. Tiles look: colourful blocks. List look: plain rows. Cards look: nothing extra (the cards are the home).
class ShortcutGrid extends StatelessWidget {
  final List<ShortcutItem> items;
  const ShortcutGrid(this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    if (homeLayout == HomeLayout.cards || items.isEmpty) return const SizedBox.shrink();
    if (homeLayout == HomeLayout.list) {
      return ListGroup([for (final it in items) ListRow(icon: it.icon ?? iconFor(it.label), title: it.label, sub: it.hint, onPress: it.go)]);
    }
    final tiles = homeLayout == HomeLayout.tiles;
    const tints = [Color(0xFFE7F1EE), Color(0xFFFDE68A), Color(0xFFBFDBFE), Color(0xFFFBCFE8), Color(0xFFDDD6FE), Color(0xFFFED7AA)];
    final l = Layout.of(context);
    return LayoutBuilder(builder: (ctx, c) {
      final per = l.tablet ? 4 : 2;
      final w = (c.maxWidth - 10 * (per - 1)) / per;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < items.length; i++)
          SizedBox(
            width: w,
            child: Tap(
              label: items[i].label,
              onTap: items[i].go,
              child: Container(
                constraints: const BoxConstraints(minHeight: 96),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: tiles ? (i == 0 ? color.tint : tints[i % tints.length]) : color.card, borderRadius: BorderRadius.circular(20), border: tiles ? null : Border.all(color: color.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icn(items[i].icon ?? iconFor(items[i].label), size: 24, tint: tiles ? const Color(0xFF1B1B1B) : color.brand),
                  const SizedBox(height: 18),
                  Text(items[i].label, style: Ty.custom(15, FontWeight.w700, c: tiles ? const Color(0xFF1B1B1B) : color.ink)),
                  if (items[i].hint != null) Text(items[i].hint!, style: Ty.custom(12.5, FontWeight.w400, c: tiles ? const Color(0xFF333333) : color.muted)),
                ]),
              ),
            ),
          ),
      ]);
    });
  }
}

/// Cards in one column on phones and two on tablets.
class Columns extends StatelessWidget {
  final List<Widget> children;
  const Columns(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    final l = Layout.of(context);
    if (!l.tablet || children.length < 2) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 14), child: children[i])]);
    }
    return LayoutBuilder(builder: (ctx, c) {
      final w = (c.maxWidth - 14) / 2;
      return Wrap(spacing: 14, runSpacing: 14, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}

/// A small heading for a block of rows.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: Ty.h3());
}
