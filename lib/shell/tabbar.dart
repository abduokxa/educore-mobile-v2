import 'package:flutter/material.dart';
import '../core/words.dart';
import '../ui/ui.dart';
import 'nav.dart';

const _icons = <String, (String, String)>{
  'Home': ('home-outline', 'home'), 'Fees': ('wallet-outline', 'wallet'), 'Results': ('ribbon-outline', 'ribbon'), 'Attendance': ('checkmark-done-outline', 'checkmark-done'),
  'Notices': ('notifications-outline', 'notifications'), 'Account': ('person-outline', 'person'), 'Learn': ('book-outline', 'book'), 'Tests': ('document-text-outline', 'document-text'),
  'My day': ('today-outline', 'today'), 'Register': ('clipboard-outline', 'clipboard'), 'Scores': ('create-outline', 'create'), 'Today': ('today-outline', 'today'),
};

/// The outline icon of a tab, for the side menu.
String tabIcon(String tab) => (_icons[tab] ?? ('ellipse-outline', 'ellipse')).$1;

/// Screens that exist as tabs (so they can be opened from the bell or a shortcut) but are not shown in the bar.
const _hidden = ['Notices'];

/// What a tab is called on screen: the learning ones use the school's own words, and Account is the Profile.
String tabLabel(String tab) => switch (tab) {
      'Learn' => Nav.I.role == 'teacher' ? w('{Learning}') : w('{Learn}'),
      'Tests' => w('{Tests}'),
      'Account' => 'Profile',
      _ => tab,
    };

class _Item extends StatelessWidget {
  final String name;
  final bool active;
  final VoidCallback onTap;
  const _Item({required this.name, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final (off, on) = _icons[name] ?? ('ellipse-outline', 'ellipse');
    return Expanded(
      child: Tap(
        scale: 0.92,
        label: tabLabel(name),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 60,
              height: 32,
              child: Stack(alignment: Alignment.center, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  width: active ? 60 : 24,
                  height: 32,
                  decoration: BoxDecoration(color: active ? color.tint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                ),
                Icn(active ? on : off, size: 22, tint: active ? color.brand : color.muted),
              ]),
            ),
            const SizedBox(height: 2),
            Text(tabLabel(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.custom(11, active ? FontWeight.w700 : FontWeight.w500, c: active ? color.brand : color.muted)),
          ]),
        ),
      ),
    );
  }
}

/// The bottom bar: five at most, an icon for each, and the current one in a pill that slides in. Notices live on the bell at the top.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Nav.I,
        builder: (context, _) {
          final nav = Nav.I;
          if (nav.locked) return const SizedBox.shrink();
          // Out of the way while someone types, so forms can use the room above the keyboard.
          if (MediaQuery.viewInsetsOf(context).bottom > 0) return const SizedBox.shrink();
          final shown = nav.tabs.where((t) => !_hidden.contains(t)).toList();
          final l = Layout.of(context);
          return Container(
            color: color.bg,
            padding: EdgeInsets.fromLTRB(12, 6, 12, MediaQuery.paddingOf(context).bottom < 10 ? 10 : MediaQuery.paddingOf(context).bottom),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: l.maxWidth < 520 ? l.maxWidth : 520),
                child: Container(
                  decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: color.line), boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, 6))]),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [for (final t in shown) _Item(name: t, active: nav.page == null && nav.current == t, onTap: () => nav.go(t))]),
                ),
              ),
            ),
          );
        },
      );
}
