import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../core/storage.dart';
import '../ui/ui.dart';

const _key = 'bio_lock';

/// How long the app may sit in the background before it asks again.
const _away = Duration(seconds: 60);
final LocalAuthentication _auth = LocalAuthentication();

/// Does this phone have a fingerprint, face or screen lock that can unlock the app?
Future<bool> biometricAvailable() async {
  try {
    return (await _auth.isDeviceSupported()) && (await _auth.canCheckBiometrics);
  } catch (_) {
    return false;
  }
}

Future<bool> lockEnabled() async => (await Secure.get(_key)) == '1';
Future<void> _setLockEnabled(bool on) => Secure.set(_key, on ? '1' : '0');

/// Ask the phone to confirm it is the owner. The phone's own PIN or pattern is accepted when the finger or face does not work.
Future<bool> confirmOwner([String prompt = 'Unlock Educore']) async {
  try {
    return await _auth.authenticate(localizedReason: prompt);
  } catch (_) {
    return false;
  }
}

/// Keeps track of whether the app should be covered by the lock screen: when it starts, and after it has been away for a minute.
class AppLock extends ChangeNotifier with WidgetsBindingObserver {
  bool locked = false;
  bool _signedIn = false;
  DateTime? _left;

  void start() => WidgetsBinding.instance.addObserver(this);

  Future<void> setSignedIn(bool v) async {
    if (v == _signedIn) return;
    _signedIn = v;
    if (v && await lockEnabled() && await biometricAvailable()) {
      locked = true;
      notifyListeners();
    }
    if (!v && locked) {
      locked = false;
      notifyListeners();
    }
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final s = state;
    if (!_signedIn) return;
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      _left ??= DateTime.now();
      return;
    }
    if (s == AppLifecycleState.resumed) {
      final gone = _left == null ? Duration.zero : DateTime.now().difference(_left!);
      _left = null;
      if (gone >= _away && await lockEnabled() && await biometricAvailable()) {
        locked = true;
        notifyListeners();
      }
    }
  }
}

/// Covers the whole app until the owner is confirmed. Asks straight away; the button asks again.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock, onSignOut;
  final String? school;
  const LockScreen({super.key, required this.onUnlock, required this.onSignOut, this.school});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 350), _ask);
  }

  Future<void> _ask() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await confirmOwner();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlock();
  }

  @override
  Widget build(BuildContext context) => Container(
        color: color.bg,
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Pop(child: Container(width: 96, height: 96, decoration: BoxDecoration(color: color.tint, shape: BoxShape.circle), child: Icn('finger-print', size: 48, tint: color.brand))),
              const SizedBox(height: 18),
              Text('Educore is locked', textAlign: TextAlign.center, style: Ty.display()),
              const SizedBox(height: 6),
              Muted('${widget.school != null ? '${widget.school}. ' : ''}Confirm it is you to carry on.'),
              const SizedBox(height: 18),
              AppButton('Unlock', icon: 'lock-open-outline', busy: _busy, onPressed: _ask),
              const SizedBox(height: 10),
              AppButton('Sign out instead', icon: 'log-out-outline', kind: BtnKind.plain, onPressed: widget.onSignOut),
            ]),
          ),
        ),
      );
}

/// The switch on the Account page. Turning it on asks once, so it cannot be switched on by someone who only has the unlocked phone in passing.
class LockCard extends StatefulWidget {
  const LockCard({super.key});
  @override
  State<LockCard> createState() => _LockCardState();
}

class _LockCardState extends State<LockCard> {
  bool _can = false, _on = false;
  @override
  void initState() {
    super.initState();
    biometricAvailable().then((v) => mounted ? setState(() => _can = v) : null);
    lockEnabled().then((v) => mounted ? setState(() => _on = v) : null);
  }

  Future<void> _change(bool on) async {
    if (!await confirmOwner(on ? 'Confirm to turn the lock on' : 'Confirm to turn the lock off')) {
      notify.err('Not changed', 'We could not confirm it is you.');
      return;
    }
    await _setLockEnabled(on);
    if (mounted) setState(() => _on = on);
    notify.ok(on ? 'App lock is on' : 'App lock is off');
  }

  @override
  Widget build(BuildContext context) {
    if (!_can) return const SizedBox.shrink();
    return ECard(title: 'App lock', icon: 'finger-print', children: [
      const Muted('Ask for your fingerprint, face or phone lock when you open Educore, and when you come back to it after a minute away.'),
      Chips<bool>(value: _on, onChange: _change, options: const [(value: false, label: 'Off'), (value: true, label: 'On')]),
    ]);
  }
}
