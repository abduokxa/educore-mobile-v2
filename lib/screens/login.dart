import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/storage.dart';
import '../ui/ui.dart';
import 'forgot.dart';

const _last = 'last_school';

class School {
  final String id, name, host;
  final String? place, color;
  final bool logo;
  School(this.id, this.name, this.host, this.place, this.color, this.logo);
  factory School.fromJson(Map<String, dynamic> j) => School('${j['id']}', '${j['name']}', '${j['host']}', j['place'] as String?, j['color'] as String?, j['logo'] == true);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'host': host, 'place': place, 'color': color, 'logo': logo};

  String? get logoUrl => logo ? '${RegExp(r'^(localhost|127\.|10\.|192\.168\.)|\.localhost(:|$)').hasMatch(host) ? 'http' : 'https'}://${withRootPort(host)}/api/school/logo' : null;
}

/// The list of schools in a sheet: search, scroll, tap one.
class _SchoolSheet extends StatefulWidget {
  final String? selected;
  final ValueChanged<School> onPick;
  const _SchoolSheet({required this.selected, required this.onPick});
  @override
  State<_SchoolSheet> createState() => _SchoolSheetState();
}

class _SchoolSheetState extends State<_SchoolSheet> {
  final _q = TextEditingController();
  List<School>? _rows;
  bool _failed = false, _more = false;
  int _page = 1, _lastPage = 1, _run = 0;
  Timer? _t;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load('', 1);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200 && !_more && _page < _lastPage) {
        setState(() => _more = true);
        _load(_q.text.trim(), _page + 1);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(String term, int p) async {
    final id = ++_run;
    try {
      final res = await http.get(Uri.parse('${rootUrl()}/api/directory/schools?q=${Uri.encodeQueryComponent(term)}&page=$p'), headers: {'Accept': 'application/json', 'X-Client': 'mobile'}).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('directory');
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (id != _run || !mounted) return;
      final data = (j['data'] as List).map((e) => School.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _rows = p > 1 ? [...?_rows, ...data] : data;
        _page = (j['meta']['page'] as num).toInt();
        _lastPage = (j['meta']['last_page'] as num).toInt();
        _failed = false;
        _more = false;
      });
    } catch (_) {
      if (id == _run && mounted) setState(() { _failed = true; _more = false; });
    }
  }

  void _search(String v) {
    _t?.cancel();
    _t = Timer(Duration(milliseconds: v.isEmpty ? 0 : 250), () {
      setState(() => _rows = null);
      _load(v.trim(), 1);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Container(
          decoration: BoxDecoration(color: color.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.line)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Icn('search', size: 18, tint: color.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _q,
                onChanged: _search,
                autocorrect: false,
                style: Ty.custom(16, FontWeight.w500),
                decoration: InputDecoration(hintText: 'Search by school name', hintStyle: Ty.custom(16, FontWeight.w400, c: color.muted), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ),
            if (_q.text.isNotEmpty) Tap(label: 'Clear search', onTap: () { _q.clear(); _search(''); }, child: Icn('close-circle', size: 18, tint: color.muted)),
          ]),
        ),
      ),
      if (_rows == null && !_failed)
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: Column(children: [for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 14), child: Row(children: [Skeleton(w: 46, h: 46, r: 15), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(h: 14, w: 160), SizedBox(height: 8), Skeleton(h: 11, w: 90)]))]))]))
      else if (_failed)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icn('cloud-offline-outline', size: 34, tint: color.muted),
            const SizedBox(height: 10),
            Text('Could not load the schools', textAlign: TextAlign.center, style: Ty.h3()),
            const Muted('Check your connection and try again.'),
            const SizedBox(height: 10),
            AppButton('Try again', kind: BtnKind.soft, icon: 'refresh', onPressed: () { setState(() { _rows = null; _failed = false; }); _load(_q.text.trim(), 1); }),
          ]),
        )
      else if (_rows != null && _rows!.isEmpty)
        Padding(padding: const EdgeInsets.all(28), child: Column(children: [Icn('school-outline', size: 34, tint: color.muted), const SizedBox(height: 8), Text('No school found', style: Ty.h3()), const SizedBox(height: 4), const Muted('Check the spelling, or ask your school for its name on Educore.')]))
      else
        Flexible(
          child: ListView.builder(
            controller: _scroll,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: (_rows?.length ?? 0) + (_more ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= _rows!.length) return const Padding(padding: EdgeInsets.all(12), child: Center(child: Spinner()));
              final s = _rows![i];
              final on = s.host == widget.selected;
              return Tap(
                scale: 0.985,
                label: s.name,
                onTap: () => widget.onPick(s),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: on ? color.tint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    SchoolLogo(uri: s.logoUrl, name: s.name, tint: s.color, size: 46),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.h3(size: 15.5)), if (s.place != null) Text(s.place!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.small())])),
                    Icn(on ? 'checkmark-circle' : 'chevron-forward', size: on ? 22 : 18, tint: on ? color.brand : color.muted),
                  ]),
                ),
              );
            },
          ),
        ),
    ]);
  }
}

class Login extends StatefulWidget {
  final void Function(Map<String, dynamic> session) onSession;
  final void Function(String? hex)? onBrand;
  const Login({super.key, required this.onSession, this.onBrand});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  School? _school;
  bool _manual = false, _remember = true, _google = false, _forgot = false;
  final _typed = TextEditingController(), _login = TextEditingController(), _password = TextEditingController(), _code = TextEditingController();
  String? _challenge, _error;
  Timer? _googleTimer;

  String get _addr => _manual ? normalizeAddress(_typed.text) : _school != null ? withRootPort(_school!.host) : '';

  @override
  void initState() {
    super.initState();
    // The school last signed in to is already chosen next time.
    Secure.get(_last).then((v) {
      if (v == null || !mounted) return;
      try {
        setState(() => _school = School.fromJson(jsonDecode(v) as Map<String, dynamic>));
        widget.onBrand?.call(_school?.color);
        _checkGoogle();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _googleTimer?.cancel();
    _typed.dispose();
    _login.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Ask the school whether Google sign-in is switched on, once a school is chosen.
  void _checkGoogle() {
    _googleTimer?.cancel();
    final addr = _addr;
    if (addr.isEmpty) {
      setState(() => _google = false);
      return;
    }
    _googleTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        setAddress(addr);
        final r = await api('auth/options');
        if (mounted) setState(() => _google = r['google'] == true);
      } catch (_) {
        if (mounted) setState(() => _google = false);
      }
    });
  }

  Future<void> _finish(Map<String, dynamic> r) async {
    await saveSession(_addr, '${r['token']}');
    if (_school != null && !_manual) Secure.set(_last, jsonEncode(_school!.toJson()));
    widget.onSession(Map<String, dynamic>.from(r['session'] as Map));
  }

  void _fail(Object e) => setState(() => _error = e is ApiError ? (e.errors['login']?.first ?? e.errors['code']?.first ?? e.message) : 'Could not sign in. Check your connection.');

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      setAddress(_addr);
      final r = await api('auth/login', method: 'POST', body: {'login': _login.text, 'password': _password.text, 'remember': _remember});
      if (r['two_factor'] == true) {
        setState(() => _challenge = '${r['challenge']}');
        return;
      }
      await _finish(Map<String, dynamic>.from(r as Map));
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _submitCode() async {
    setState(() => _error = null);
    try {
      await _finish(Map<String, dynamic>.from(await api('auth/login/2fa', method: 'POST', body: {'challenge': _challenge, 'code': _code.text}) as Map));
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _withGoogle() async {
    setState(() => _error = null);
    try {
      setAddress(_addr);
      final url = await FlutterWebAuth2.authenticate(url: '${baseUrl()}/auth/google?app=1', callbackUrlScheme: 'educore');
      final m = RegExp(r'[?&]code=([^&]+)').firstMatch(url);
      if (m == null) {
        setState(() => _error = 'Google sign-in did not finish. Please try again.');
        return;
      }
      await _finish(Map<String, dynamic>.from(await api('auth/google', method: 'POST', body: {'code': Uri.decodeComponent(m.group(1)!)}) as Map));
    } on PlatformException {
      // closed by the person
    } catch (e) {
      _fail(e);
    }
  }

  void _pickSchool() {
    showAppSheet<void>(context, title: 'Choose your school', tall: true, builder: (ctx) => _SchoolSheet(
      selected: _school?.host,
      onPick: (s) {
        Navigator.pop(ctx);
        setState(() { _school = s; _error = null; });
        widget.onBrand?.call(s.color);
        _checkGoogle();
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_forgot) {
      return Forgot(addr: _addr, schoolName: _manual ? null : _school?.name, initialLogin: _login.text, onBack: () => setState(() => _forgot = false), onDone: (l) => setState(() { _login.text = l; _password.clear(); _error = null; _forgot = false; }));
    }
    final school = _manual ? null : _school;
    return PopScope(
      canPop: _challenge == null && !_manual,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_challenge != null) {
          setState(() { _challenge = null; _code.clear(); _error = null; });
        } else if (_manual) {
          setState(() => _manual = false);
        }
      },
      child: Screen(center: true, bare: true, children: [
        Column(children: [
          const SizedBox(height: 12),
          Pop(
            key: ValueKey(school?.id ?? 'app'),
            child: school != null
                ? SchoolLogo(uri: school.logoUrl, name: school.name, tint: school.color, size: 76)
                : Container(width: 76, height: 76, decoration: BoxDecoration(color: color.brand, borderRadius: BorderRadius.circular(24)), child: Icn('school', size: 38, tint: color.onBrand)),
          ),
          const SizedBox(height: 14),
          Text(_challenge != null ? 'Two-step check' : school != null ? school.name : 'Welcome back', textAlign: TextAlign.center, style: Ty.display()),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(_challenge != null ? 'Type the 6-digit code from your authenticator app.' : school != null ? 'Sign in with the details your school gave you.' : 'Choose your school, then sign in with the details it gave you.', textAlign: TextAlign.center, style: Ty.body(c: color.muted)),
          ),
        ]),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: color.line), boxShadow: const [BoxShadow(color: Color(0x120F172A), blurRadius: 24, offset: Offset(0, 8))]),
          child: _challenge != null ? _codeStep() : _signInStep(school),
        ),
        Center(child: Text('Powered by Educore', style: Ty.small())),
      ]),
    );
  }

  Widget _codeStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field(icon: 'keypad-outline', label: '6-digit code or recovery code', controller: _code, keyboardType: TextInputType.number, autofill: const [AutofillHints.oneTimeCode], autofocus: true, error: _error, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        AppButton('Continue', disabled: _code.text.length < 6, onPressed: _submitCode),
        const SizedBox(height: 14),
        AppButton('Back', kind: BtnKind.plain, onPressed: () => setState(() { _challenge = null; _code.clear(); _error = null; })),
      ]);

  Widget _signInStep(School? school) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_manual)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Field(icon: 'globe-outline', label: 'School address', controller: _typed, hint: 'greenfield.edu-core.ng', autocorrect: false, keyboardType: TextInputType.url, onChanged: (_) { setState(() {}); _checkGoogle(); }),
            const SizedBox(height: 8),
            Tap(onTap: () { setState(() => _manual = false); _checkGoogle(); }, child: Text('Choose from the list instead', style: Ty.custom(13, FontWeight.w700, c: color.brand))),
          ])
        else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('School', style: Ty.small(w: FontWeight.w600)),
            const SizedBox(height: 6),
            Tap(
              label: school != null ? 'School: ${school.name}. Tap to change.' : 'Choose your school',
              onTap: _pickSchool,
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: school != null ? color.tint : color.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: school != null ? color.brand : color.line, width: 1.5)),
                child: Row(children: [
                  school != null ? SchoolLogo(uri: school.logoUrl, name: school.name, tint: school.color, size: 44) : IconBadge('school-outline', size: 44),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(school?.name ?? 'Select your school', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.h3(c: school != null ? color.ink : color.muted)), if (school?.place != null) Text(school!.place!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.small())])),
                  Icn('chevron-down', size: 20, tint: color.muted),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Tap(onTap: () => setState(() => _manual = true), child: Text('School not listed? Type its address', style: Ty.small(w: FontWeight.w600))),
          ]),
        const SizedBox(height: 16),
        Field(icon: 'person-outline', label: 'Email, phone or admission number', controller: _login, autocorrect: false, autofill: const [AutofillHints.username], onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        Field(icon: 'lock-closed-outline', label: 'Password', controller: _password, secure: true, autofill: const [AutofillHints.password], error: _error, onChanged: (_) => setState(() {}), onSubmitted: (_) => _addr.isNotEmpty && _login.text.isNotEmpty && _password.text.isNotEmpty ? _submit() : null),
        const SizedBox(height: 16),
        CheckRow(label: 'Keep me signed in for 30 days', value: _remember, onChange: (v) => setState(() => _remember = v)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Opacity(
            opacity: _addr.isEmpty ? 0.5 : 1,
            child: Tap(label: 'Forgot your password?', onTap: _addr.isEmpty ? null : () => setState(() { _error = null; _forgot = true; }), child: Text('Forgot your password?', style: Ty.custom(13, FontWeight.w800, c: color.brand))),
          ),
        ),
        const SizedBox(height: 16),
        AppButton('Sign in', icon: 'log-in-outline', disabled: _addr.isEmpty || _login.text.isEmpty || _password.text.isEmpty, onPressed: _submit),
        if (_google) ...[const SizedBox(height: 16), AppButton('Continue with Google', kind: BtnKind.plain, icon: 'logo-google', onPressed: _withGoogle)],
      ]);
}
