import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../ui/ui.dart';

enum _Step { who, code, done }

/// Pull a 6-digit code out of whatever was pasted: a bare code, "123 456", "123-456" or a whole SMS or email.
String? extractCode(String text) {
  final joined = text.replaceAllMapped(RegExp(r'(\d)[\s-]+(?=\d)'), (m) => m[1]!);
  final run = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(joined);
  if (run != null) return run[0];
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return digits.length == 6 ? digits : null;
}

({double pct, String label, bool ok}) strength(String pw) {
  var score = 0;
  if (pw.length >= 8) score++;
  if (RegExp(r'[a-z]', caseSensitive: false).hasMatch(pw) && RegExp(r'\d').hasMatch(pw)) score++;
  if (pw.length >= 12 || RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
  final ok = pw.length >= 8 && RegExp(r'[a-z]', caseSensitive: false).hasMatch(pw) && RegExp(r'\d').hasMatch(pw);
  return (pct: pw.isEmpty ? 0 : (score / 3 * 100).clamp(12, 100).toDouble(), label: pw.isEmpty ? '' : score <= 1 ? 'Too easy to guess' : score == 2 ? 'Good' : 'Strong', ok: ok);
}

/// A badge with a soft ring behind it.
class _Halo extends StatelessWidget {
  final String icon;
  final bool done;
  const _Halo(this.icon, {this.done = false});
  @override
  Widget build(BuildContext context) => Pop(
        child: Center(
          child: Container(width: 88, height: 88, decoration: BoxDecoration(color: color.tint, shape: BoxShape.circle), child: Icn(icon, size: 40, tint: color.brand)),
        ),
      );
}

/// Three steps; the bar fills as you go.
class _Progress extends StatelessWidget {
  final _Step step;
  const _Progress(this.step);
  @override
  Widget build(BuildContext context) {
    final at = step.index;
    return Column(children: [
      Bar(at / 2 * 100, height: 6),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final (i, t) in const ['Who you are', 'The code', 'Done'].indexed) Text(t, style: Ty.caption(c: i <= at ? color.brand : color.muted).copyWith(fontWeight: i == at ? FontWeight.w800 : FontWeight.w600)),
      ]),
    ]);
  }
}

/// Six boxes for the code; one hidden field behind them takes the typing, paste and the keyboard's SMS suggestion.
class _CodeBoxes extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChange;
  final bool error;
  const _CodeBoxes({required this.value, required this.onChange, this.error = false});
  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  final _focus = FocusNode();
  late final _ctl = TextEditingController(text: widget.value);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    // Come to the front with the keyboard up, so the SMS or email suggestion shows above it.
    Future<void>.delayed(const Duration(milliseconds: 450), () { if (mounted) _focus.requestFocus(); });
  }

  @override
  void didUpdateWidget(_CodeBoxes old) {
    super.didUpdateWidget(old);
    if (_ctl.text != widget.value) _ctl.text = widget.value;
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    try {
      final text = (await Clipboard.getData('text/plain'))?.text ?? '';
      final found = extractCode(text);
      if (found == null) {
        notify.info('No 6-digit code found', 'Copy the message or the code, then try again.');
        return;
      }
      widget.onChange(found);
      _focus.unfocus();
    } catch (_) {
      notify.err('Could not read the clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tap(
        scale: 1,
        label: 'Type or paste the 6-digit code',
        onTap: () => _focus.requestFocus(),
        onLongPress: _paste,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 6; i++)
            Builder(builder: (context) {
              final d = i < v.length ? v[i] : null;
              final active = _focus.hasFocus && i == (v.length < 5 ? v.length : 5);
              return Pop(
                key: ValueKey('$i-$d'),
                child: Container(
                  width: 46,
                  height: 58,
                  decoration: BoxDecoration(color: d != null ? color.tint : color.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.error ? color.danger : (active || d != null) ? color.brand : color.line, width: active ? 2 : 1)),
                  alignment: Alignment.center,
                  child: Text(d ?? '', style: Ty.custom(24, FontWeight.w800)),
                ),
              );
            }),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('Tap the code your keyboard suggests, or copy the message and paste it.', style: Ty.caption())),
        const SizedBox(width: 8),
        Tap(
          label: 'Paste the code',
          onTap: _paste,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: color.tint, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icn('clipboard-outline', size: 16, tint: color.brand), const SizedBox(width: 6), Text('Paste', style: Ty.custom(13, FontWeight.w800, c: color.brand))]),
          ),
        ),
      ]),
      SizedBox(
        height: 1,
        width: 1,
        child: Opacity(
          opacity: 0,
          child: TextField(
            controller: _ctl,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            showCursor: false,
            onChanged: (t) {
              final found = t.length > 6 ? extractCode(t) : null;
              widget.onChange(found ?? t.replaceAll(RegExp(r'\D'), '').substring(0, t.replaceAll(RegExp(r'\D'), '').length.clamp(0, 6)));
            },
          ),
        ),
      ),
    ]);
  }
}

/// Reset a forgotten password from the app: say who you are, type the code that was sent, choose a new password.
class Forgot extends StatefulWidget {
  final String addr, initialLogin;
  final String? schoolName;
  final VoidCallback onBack;
  final ValueChanged<String> onDone;
  const Forgot({super.key, required this.addr, this.schoolName, required this.initialLogin, required this.onBack, required this.onDone});
  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {
  _Step _step = _Step.who;
  late final _login = TextEditingController(text: widget.initialLogin);
  final _pw = TextEditingController(), _pw2 = TextEditingController();
  String _channel = 'email', _token = '', _dest = '', _code = '';
  List<String> _channels = ['whatsapp', 'sms', 'email'];
  Map<String, String> _errors = {};
  int _wait = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Which ways this school can send a code (WhatsApp and SMS are paid and may be off).
    setAddress(widget.addr);
    api('school').then<dynamic>((s) {
      if (!mounted) return null;
      final ch = s['channels'];
      final list = [if (ch?['whatsapp'] != false) 'whatsapp', if (ch?['sms'] != false) 'sms', 'email'];
      setState(() { _channels = list; if (!list.contains(_channel)) _channel = list.first; });
      return null;
    }).catchError((_) => null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _login.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
    });
  }

  void _fail(Object e, String fallback) {
    if (e is ApiError) {
      final flat = {for (final en in e.errors.entries) en.key: en.value.isEmpty ? '' : en.value.first};
      setState(() => _errors = flat.isNotEmpty ? flat : {'form': e.message});
    } else {
      setState(() => _errors = {'form': fallback});
    }
  }

  Future<void> _send() async {
    setState(() => _errors = {});
    try {
      setAddress(widget.addr);
      final r = await api('auth/forgot', method: 'POST', body: {'login': _login.text.trim(), 'channel': _channel});
      setState(() { _token = '${r['reset_token']}'; _dest = '${r['destination']}'; _wait = 30; _code = ''; });
      _tick();
      if (_step == _Step.who) {
        setState(() => _step = _Step.code);
      } else {
        notify.ok('A new code is on its way');
      }
    } catch (e) {
      _fail(e, 'Could not send the code. Check your connection.');
    }
  }

  Future<void> _change() async {
    setState(() => _errors = {});
    try {
      await api('auth/reset', method: 'POST', body: {'reset_token': _token, 'code': _code, 'password': _pw.text, 'password_confirmation': _pw2.text});
      setState(() => _step = _Step.done);
    } catch (e) {
      _fail(e, 'Could not change the password. Check your connection.');
    }
  }

  String? _err(String k) => _errors[k];

  Widget _card(List<Widget> kids) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: color.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < kids.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 16), child: kids[i])]),
      );

  Widget _heading(String t, String s) => Column(children: [
        Text(t, textAlign: TextAlign.center, style: Ty.display()),
        const SizedBox(height: 6),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Text(s, textAlign: TextAlign.center, style: Ty.body(c: color.muted))),
      ]);

  @override
  Widget build(BuildContext context) {
    final s = strength(_pw.text);
    final mismatch = _pw2.text.isNotEmpty && _pw.text != _pw2.text;
    final way = _channel == 'email' ? 'email' : _channel == 'sms' ? 'text message' : 'WhatsApp';
    String chLabel(String c) => c == 'email' ? 'Email' : c == 'sms' ? 'SMS' : 'WhatsApp';
    final body = switch (_step) {
      _Step.who => [
          const _Halo('lock-closed'),
          _heading('Forgot your password?', 'No problem${widget.schoolName != null ? ' at ${widget.schoolName}' : ''}. We will send a 6-digit code so you can choose a new one.'),
          _card([
            Field(icon: 'person-outline', label: 'Email, phone or admission number', controller: _login, autocorrect: false, error: _err('login'), onChanged: (_) => setState(() {})),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Send the code by', style: Ty.small(w: FontWeight.w600)),
              const SizedBox(height: 6),
              Chips<String>(value: _channel, onChange: (v) => setState(() => _channel = v), options: [for (final c in _channels) (value: c, label: chLabel(c))]),
              if (_err('channel') != null) Text(_err('channel')!, style: Ty.small(c: color.danger)),
            ]),
            if (_err('form') != null) Text(_err('form')!, style: Ty.small(c: color.danger)),
            AppButton('Send me a code', icon: 'paper-plane', disabled: _login.text.trim().isEmpty, onPressed: _send),
            AppButton('Back to sign in', kind: BtnKind.plain, icon: 'arrow-back', onPressed: widget.onBack),
          ]),
        ],
      _Step.code => [
          const _Halo('mail-unread'),
          _heading('Check your $way', 'We sent a 6-digit code to ${_dest.isEmpty ? 'you' : _dest}. It works for 15 minutes.'),
          _card([
            _CodeBoxes(value: _code, onChange: (v) => setState(() => _code = v), error: _err('code') != null || _err('reset_token') != null),
            if (_err('code') != null || _err('reset_token') != null) Text(_err('code') ?? _err('reset_token')!, style: Ty.small(c: color.danger)),
            Field(icon: 'lock-closed-outline', label: 'New password', controller: _pw, secure: true, autofill: const [AutofillHints.newPassword], error: _err('password'), onChanged: (_) => setState(() {})),
            if (_pw.text.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Bar(s.pct, height: 6, tint: s.label == 'Strong' ? color.brand : s.label == 'Good' ? const Color(0xFFD4A017) : color.danger),
                const SizedBox(height: 4),
                Text('${s.label}. Use at least 8 characters with letters and numbers.', style: Ty.caption()),
              ]),
            Field(icon: 'shield-checkmark-outline', label: 'Repeat the new password', controller: _pw2, secure: true, autofill: const [AutofillHints.newPassword], error: mismatch ? 'The two passwords are not the same.' : null, onChanged: (_) => setState(() {})),
            if (_err('form') != null) Text(_err('form')!, style: Ty.small(c: color.danger)),
            AppButton('Change my password', icon: 'checkmark-circle', disabled: _code.length != 6 || !s.ok || _pw.text != _pw2.text, onPressed: _change),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Tap(onTap: () => setState(() { _step = _Step.who; _code = ''; _errors = {}; }), child: Text('Use another account', style: Ty.custom(13, FontWeight.w700, c: color.muted))),
              if (_wait > 0) Muted('Send again in ${_wait}s') else Tap(onTap: _send, child: Text('Send a new code', style: Ty.custom(13, FontWeight.w800, c: color.brand))),
            ]),
          ]),
        ],
      _Step.done => [
          const _Halo('checkmark', done: true),
          _heading('Password changed', 'You have been signed out everywhere for safety. Sign in with your new password.'),
          AppButton('Sign in', icon: 'log-in-outline', onPressed: () => widget.onDone(_login.text.trim())),
        ],
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step == _Step.code) {
          setState(() { _step = _Step.who; _code = ''; _errors = {}; });
        } else {
          widget.onBack();
        }
      },
      child: Screen(center: true, bare: true, children: [
        _Progress(_step),
        for (final w in body) w,
      ]),
    );
  }
}
