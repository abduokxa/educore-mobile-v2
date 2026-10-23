import 'package:flutter/material.dart';
import '../core/api.dart';
import '../ui/ui.dart';
import 'nav.dart';

const _icons = <String, (String, String)>{
  'Home': ('home-outline', 'home'), 'Fees': ('wallet-outline', 'wallet'), 'Results': ('ribbon-outline', 'ribbon'), 'Attendance': ('checkmark-done-outline', 'checkmark-done'),
  'Notices': ('notifications-outline', 'notifications'), 'More': ('grid-outline', 'grid'), 'Account': ('person-outline', 'person'),
  'My day': ('today-outline', 'today'), 'Register': ('clipboard-outline', 'clipboard'), 'Scores': ('create-outline', 'create'), 'Today': ('today-outline', 'today'),
};

/// Screens that exist as tabs (so they can be opened from a shortcut) but are not shown in the bar.
const _hidden = ['Attendance', 'Account'];

class _Item extends StatelessWidget {
  final String name;
  final bool active;
  final int badge;
  final VoidCallback onTap;
  const _Item({required this.name, required this.active, required this.badge, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final (off, on) = _icons[name] ?? ('ellipse-outline', 'ellipse');
    return Expanded(
      child: Tap(
        scale: 0.92,
        label: badge > 0 ? '$name, $badge new' : name,
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
                if (badge > 0)
                  Positioned(
                    top: 0,
                    right: 8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: color.danger, borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: Text(badge > 9 ? '9+' : '$badge', style: Ty.custom(9, FontWeight.w800, c: Colors.white)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 2),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.custom(11, active ? FontWeight.w700 : FontWeight.w500, c: active ? color.brand : color.muted)),
          ]),
        ),
      ),
    );
  }
}

/// The bottom bar: five at most, an icon for each, the current one in a pill that slides in, and unread notices on Notices.
class AppTabBar extends StatefulWidget {
  const AppTabBar({super.key});
  @override
  State<AppTabBar> createState() => _AppTabBarState();
}

class _AppTabBarState extends State<AppTabBar> {
  int _unread = 0;
  String _lastFor = '';

  void _loadUnread() {
    if (!Nav.I.tabs.contains('Notices')) return;
    api('inbox').then<dynamic>((d) {
      if (mounted) setState(() => _unread = Nav.I.current == 'Notices' ? 0 : ((d['unread'] as num?) ?? 0).toInt());
      return null;
    }).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Nav.I,
        builder: (context, _) {
          final nav = Nav.I;
          if (nav.locked) return const SizedBox.shrink();
          if (_lastFor != nav.current) {
            _lastFor = nav.current;
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnread());
          }
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
                  child: Row(children: [for (final t in shown) _Item(name: t, active: nav.current == t, badge: t == 'Notices' ? _unread : 0, onTap: () => nav.go(t))]),
                ),
              ),
            ),
          );
        },
      );
}
