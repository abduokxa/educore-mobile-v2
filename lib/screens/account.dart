import 'package:flutter/material.dart';
import '../features/offline_card.dart';
import '../core/api.dart';
import '../core/offline.dart';
import '../features/account_data.dart';
import '../features/lock.dart';
import '../features/push.dart';
import '../ui/ui.dart';

enum Mode { system, light, dark }

class AccountScreen extends StatefulWidget {
  final String name;
  final String? school, workspace;
  final bool requests;
  final Mode mode;
  final ValueChanged<Mode> onMode;
  final Future<void> Function() onSignOut;
  const AccountScreen({super.key, required this.name, this.school, this.workspace, required this.requests, required this.mode, required this.onMode, required this.onSignOut});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  PushState? _push;
  @override
  void initState() {
    super.initState();
    PushService.status().then((s) => mounted ? setState(() => _push = s) : null);
  }

  @override
  Widget build(BuildContext context) {
    final push = _push;
    return Screen(children: [
      const PageTitle('Account'),
      ECard(children: [
        Row(children: [
          Avatar(widget.name, size: 56, solid: true),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ty.custom(18, FontWeight.w700)), if (widget.school != null) Muted(widget.school!)])),
        ]),
      ]),
      const LockCard(),
      OfflineCard(workspace: widget.workspace),
      DataCard(workspace: widget.workspace, requests: widget.requests),
      ECard(title: 'Appearance', icon: 'color-palette-outline', children: [
        Chips<Mode>(value: widget.mode, onChange: widget.onMode, options: const [(value: Mode.system, label: 'Device'), (value: Mode.light, label: 'Light'), (value: Mode.dark, label: 'Dark')]),
      ]),
      if (push != null && push != PushState.unavailable)
        ECard(title: 'Notices on this phone', icon: 'notifications-outline', children: [
          Muted(push == PushState.on ? 'You will get school notices, bills, results and absence alerts as notifications.' : push == PushState.denied ? "Notifications are turned off for this app. Turn them on in your phone's settings to hear from the school." : 'Turn notifications on to hear from the school as soon as it writes.'),
          if (push == PushState.on)
            AppButton('Send me a test notice', kind: BtnKind.soft, icon: 'paper-plane-outline', onPressed: () async {
              final r = await PushService.sendTest();
              r.ok ? notify.ok(r.message) : notify.err(r.message);
            })
          else if (push == PushState.off)
            AppButton('Turn on notifications', icon: 'notifications-outline', onPressed: () async {
              final s = await PushService.enable();
              if (mounted) setState(() => _push = s);
            }),
        ]),
      AppButton('Sign out', kind: BtnKind.plain, icon: 'log-out-outline', onPressed: () async {
        // Signing out removes what is saved on the phone, so anything not yet sent would be lost.
        final waiting = await Offline.I.pending();
        if (waiting > 0 && context.mounted) {
          final go = await confirm(context, title: 'Sign out and lose $waiting saved ${waiting == 1 ? 'item' : 'items'}?', message: 'What you saved on this phone has not reached the school yet. Connect to the internet first, or it will be deleted.', yes: 'Sign out anyway', no: 'Stay signed in', destructive: true);
          if (!go) return;
        }
        await PushService.unregister();
        try {
          await api('auth/logout', method: 'POST');
        } catch (_) {/* already out */}
        await widget.onSignOut();
      }),
    ]);
  }
}

class RolePicker extends StatelessWidget {
  final Map<String, dynamic> session;
  final ValueChanged<Map<String, dynamic>> onPick;
  const RolePicker({super.key, required this.session, required this.onPick});
  @override
  Widget build(BuildContext context) {
    const icons = {'parent': 'people-outline', 'teacher': 'school-outline', 'student': 'happy-outline', 'bursar': 'wallet-outline'};
    final roles = (session['roles'] as List).where((r) => const ['parent', 'teacher', 'student', 'bursar'].contains(r['workspace'])).toList();
    return Screen(bare: true, children: [
      const SizedBox(height: 28),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        H1('Welcome, ${('${session['user']['name']}').split(' ').first}'),
        const SizedBox(height: 4),
        const Muted('Choose how you want to use the app now. You can switch later.'),
      ]),
      ListGroup([
        for (final r in roles)
          ListRow(
            icon: icons['${r['workspace']}'] ?? 'person-outline',
            title: 'Continue as ${r['name']}',
            sub: (r['description'] as String?) ?? '',
            onPress: () async => onPick(Map<String, dynamic>.from(await api('auth/role', method: 'POST', body: {'role': r['id']}) as Map)),
          ),
      ]),
    ]);
  }
}
