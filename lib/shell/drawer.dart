import 'package:flutter/material.dart';
import '../core/term.dart';
import '../features/termsheet.dart';
import '../screens/extras.dart';
import '../ui/ui.dart';
import 'nav.dart';
import 'tabbar.dart';
import 'unread.dart';

/// The menu button at the left of the top bar. Hidden while a test is being taken.
class MenuButton extends StatelessWidget {
  final VoidCallback onOpen;
  const MenuButton({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Nav.I,
        builder: (context, _) => Nav.I.locked
            ? const SizedBox.shrink()
            : Tap(
                label: 'Open the menu',
                onTap: onOpen,
                child: SizedBox(width: 40, height: 44, child: Icn('menu-outline', size: 26, tint: color.ink)),
              ),
      );
}

/// The notices bell at the right of the top bar, with how many are unread. Hidden while a test is being taken.
class NoticeBell extends StatelessWidget {
  const NoticeBell({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Nav.I, Unread.I]),
        builder: (context, _) {
          if (Nav.I.locked || !Nav.I.tabs.contains('Notices')) return const SizedBox.shrink();
          final n = Unread.I.count;
          final active = Nav.I.page == null && Nav.I.current == 'Notices';
          return Tap(
            label: n > 0 ? 'Notices, $n new' : 'Notices',
            onTap: () => Nav.I.go('Notices'),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: active ? color.tint : color.card, shape: BoxShape.circle, border: Border.all(color: active ? color.brand : color.line))),
                Icn(active ? 'notifications' : 'notifications-outline', size: 21, tint: active ? color.brand : color.ink),
                if (n > 0)
                  Positioned(
                    top: 1,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: color.danger, borderRadius: BorderRadius.circular(9), border: Border.all(color: color.bg, width: 1.5)),
                      alignment: Alignment.center,
                      child: Text(n > 9 ? '9+' : '$n', style: Ty.custom(9.5, FontWeight.w800, c: Colors.white)),
                    ),
                  ),
              ]),
            ),
          );
        },
      );
}

/// The side menu: the school and the session at the top, then every screen the person can open, then their profile.
class AppDrawer extends StatelessWidget {
  final String school, person, roleLabel;
  final String? logo, brand;
  final List<MoreItem> more;
  const AppDrawer({super.key, required this.school, required this.person, required this.roleLabel, this.logo, this.brand, required this.more});

  void _close(BuildContext context) => Navigator.of(context).pop();

  Widget _row(BuildContext context, {required String icon, required String label, String? sub, required bool active, int badge = 0, required VoidCallback onTap}) => Tap(
        scale: 0.985,
        label: badge > 0 ? '$label, $badge new' : label,
        onTap: () {
          _close(context);
          onTap();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: active ? color.tint : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icn(icon, size: 22, tint: active ? color.brand : color.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.custom(15.5, active ? FontWeight.w800 : FontWeight.w600, c: active ? color.brand : color.ink)),
                if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.caption()),
              ]),
            ),
            if (badge > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: color.danger, borderRadius: BorderRadius.circular(11)),
                alignment: Alignment.center,
                child: Text(badge > 99 ? '99+' : '$badge', style: Ty.custom(11.5, FontWeight.w800, c: Colors.white)),
              ),
          ]),
        ),
      );

  Widget _heading(String text) => Padding(padding: const EdgeInsets.fromLTRB(12, 18, 12, 6), child: Text(text.toUpperCase(), style: Ty.custom(11.5, FontWeight.w800, c: color.muted, ls: 0.8)));

  /// The session and term being looked at; tap to change it.
  Widget _term(BuildContext context) => ListenableBuilder(
        listenable: Terms.I,
        builder: (context, _) {
          final t = Terms.I.shown;
          if (t == null) return const SizedBox.shrink();
          final past = t.past ? tone('amber') : null;
          final fg = past?.fg ?? color.brand;
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Tap(
              label: 'Showing ${t.row.label}. Tap to change the session or term.',
              onTap: () {
                _close(context);
                final ctx = navigatorKey.currentContext;
                if (ctx != null) showAppSheet(ctx, title: 'Session and term', tall: true, builder: (_) => const TermSheet());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: past?.bg ?? color.tint, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icn('calendar-outline', size: 20, tint: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.past ? 'Looking at an earlier term' : 'Session and term', style: Ty.caption(c: fg)),
                      Text('${t.row.name.replaceAll(' Term', '')} · ${shortSession(t.session)}', style: Ty.custom(15.5, FontWeight.w800, c: fg)),
                    ]),
                  ),
                  Icn('chevron-down', size: 16, tint: fg),
                ]),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ListenableBuilder(
      listenable: Listenable.merge([Nav.I, Unread.I]),
      builder: (context, _) {
        final nav = Nav.I;
        if (nav.locked) return const SizedBox.shrink();
        final tabs = nav.tabs.where((t) => t != 'Account').toList();
        final tabKeys = nav.tabs.map((t) => t.toLowerCase()).toSet();
        final extra = [for (final i in more) if (!tabKeys.contains(i.key.toLowerCase())) i];
        return Drawer(
          width: width * 0.86 > 340 ? 340 : width * 0.86,
          backgroundColor: color.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(26))),
          child: SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(12, 14, 12, 8), children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                    child: Row(children: [
                      SchoolLogo(uri: logo, name: school, tint: brand, size: 44),
                      const SizedBox(width: 12),
                      Expanded(child: Text(school, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ty.h3(size: 17))),
                    ]),
                  ),
                  _term(context),
                  _heading('Menu'),
                  for (final t in tabs)
                    _row(context,
                        icon: tabIcon(t),
                        label: tabLabel(t),
                        active: nav.page == null && nav.current == t,
                        badge: t == 'Notices' ? Unread.I.count : 0,
                        onTap: () => nav.go(t)),
                  if (extra.isNotEmpty) _heading('More'),
                  for (final i in extra) _row(context, icon: iconFor(i.label), label: i.label, sub: i.hint, active: nav.page == i.key, onTap: () => nav.openPage(i.key)),
                ]),
              ),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: color.line))),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Tap(
                  scale: 0.985,
                  label: 'Your profile',
                  onTap: () {
                    _close(context);
                    nav.go('Account');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(children: [
                      Avatar(person, size: 40, solid: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(person, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.h3(size: 15.5)),
                          Text('$roleLabel · Profile and settings', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.caption()),
                        ]),
                      ),
                      Icn('chevron-forward', size: 18, tint: color.muted),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
