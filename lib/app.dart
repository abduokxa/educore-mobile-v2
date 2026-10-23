import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/api.dart';
import 'core/entitle.dart';
import 'core/net.dart';
import 'core/offline.dart';
import 'core/storage.dart';
import 'core/term.dart';
import 'core/theme.dart';
import 'features/lock.dart';
import 'features/push.dart';
import 'features/termsheet.dart';
import 'features/version.dart';
import 'screens/account.dart';
import 'screens/exams.dart';
import 'screens/extras.dart';
import 'screens/learning.dart';
import 'screens/inbox.dart';
import 'screens/login.dart';
import 'screens/parent.dart';
import 'screens/search.dart';
import 'screens/student.dart';
import 'screens/teacher.dart';
import 'shell/nav.dart';
import 'shell/status.dart';
import 'shell/tabbar.dart';
import 'ui/ui.dart';

const _modeKey = 'educore_mode';

typedef Session = Map<String, dynamic>;

/// Features the platform owner switched off for this school are hidden.
bool _on(Session s, String k) => (s['modules'] as Map?)?[k] != false;

/// The "More" menu: only the features this school has switched on.
bool _feature(Session s, String k) => ((s['school'] as Map?)?['modules'] as Map?)?[k] == true;
List<MoreItem> _menu(Session s, List<(String, MoreItem)> items) => [for (final (module, item) in items) if (_feature(s, module)) item];

List<MoreItem> _parentMore(Session s) => _menu(s, [
      ('chat', MoreItem('chat', 'Messages', "Talk to your child's teacher", (_) => const ParentChat())),
      ('chat', MoreItem('meetings', 'Meet a teacher', 'Book a time to talk in person', (_) => const ParentMeetings())),
      ('parent_portal', MoreItem('help', 'Help', 'How things work', (_) => const HelpDocs())),
      ('parent_portal', MoreItem('notice-settings', 'Notice settings', 'How the school reaches you, and what was sent', (_) => const ParentNotices())),
      ('homework', MoreItem('homework', 'Homework', 'What is due and when', (_) => const ParentHomework())),
      ('school_calendar', MoreItem('calendar', 'School calendar', 'Term dates, holidays and events', (_) => const CalendarScreen())),
      ('transport', MoreItem('transport', 'School bus', 'Route, stop and pick-up time', (_) => const ParentTransport())),
      ('boarding', MoreItem('boarding', 'Boarding', 'Hostel, room and exeats', (_) => const ParentBoarding())),
    ]);

List<Shortcut> _teacherShortcuts(Session s) => [
      const Shortcut('My day', 'My day'),
      if (_on(s, 'attendance')) const Shortcut('Mark the register', 'Register'),
      if (_on(s, 'exams')) const Shortcut('Enter scores', 'Scores'),
      const Shortcut('Notices', 'Notices'),
      const Shortcut('More', 'More'),
    ];

List<MoreItem> _teacherMore(Session s) => _menu(s, [
      ('students', MoreItem('search', 'Search', 'Find a student or a screen', (_) => Search(shortcuts: _teacherShortcuts(s)))),
      ('chat', MoreItem('chat', 'Messages', 'Talk to parents', (_) => const TeacherChat())),
      ('chat', MoreItem('meetings', 'Parent meetings', 'Offer times, see who booked', (_) => const TeacherMeetings())),
      ('students', MoreItem('help', 'Help', 'How things work', (_) => const HelpDocs())),
      ('homework', MoreItem('homework', 'Homework', 'Homework you set', (_) => const TeacherHomework())),
      ('lms.enabled', MoreItem('learn', 'Learning', 'Your courses and assignments to mark', (_) => const TeacherLearn())),
      ('cbt.manual_grading', MoreItem('mark-exams', 'Mark exams', 'Written answers waiting for your marks', (_) => const TeacherMarking())),
      ('exams', MoreItem('class-results', 'Class results', 'Your class once the results are open', (_) => const TeacherClassResults())),
      ('leave', MoreItem('leave', 'Leave', 'Ask for leave and see decisions', (_) => const TeacherLeave())),
      ('payroll', MoreItem('payslips', 'Payslips', 'Your pay history', (_) => const TeacherPayslips())),
      ('school_calendar', MoreItem('calendar', 'School calendar', 'Term dates and events', (_) => const CalendarScreen())),
    ]);

List<MoreItem> _studentMore(Session s) => _menu(s, [
      ('homework', MoreItem('homework', 'Homework', 'What is due and when', (_) => const StudentHomework())),
      ('lms.enabled', MoreItem('learn', 'Learn', 'Courses, lessons and assignments', (_) => const StudentLearn())),
      ('online_tests', MoreItem('tests', 'Tests and exams', 'Take a test or see your answers', (_) => const StudentTests())),
      ('school_calendar', MoreItem('calendar', 'School calendar', 'Term dates and events', (_) => const CalendarScreen())),
    ]);

class EducoreApp extends StatefulWidget {
  const EducoreApp({super.key});
  @override
  State<EducoreApp> createState() => _EducoreAppState();
}

class _EducoreAppState extends State<EducoreApp> {
  bool _ready = false;
  Session? _session;
  Mode _mode = Mode.system;
  String? _previewBrand, _wsSeen;
  final _lock = AppLock();
  final _update = UpdateWatcher();
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    _lock.start();
    _lock.addListener(_rebuild);
    _update.start();
    _update.addListener(_rebuild);
    PushService.init(onOpen: _openHref);
    Net.I; // start watching the connection
    Refresh.I;
    _boot();
  }

  @override
  void dispose() {
    _lock.dispose();
    _update.dispose();
    _links?.cancel();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    final m = await Secure.get(_modeKey);
    _mode = m == 'light' ? Mode.light : m == 'dark' ? Mode.dark : Mode.system;
    if (await restore()) {
      // Everything saved on the phone is read first (it takes a moment), so the app can open on the last screens at once.
      await Future.wait([Offline.I.loadFlag(), Terms.I.prime(), loadSnapshot()]);
      final saved = await recallSession();
      if (saved is Map) {
        _setSession(Map<String, dynamic>.from(saved));
        if (mounted) setState(() => _ready = true);
      }
      // The school's answer replaces the saved copy a moment later. If the sign-in has ended, the person is sent back to sign in.
      try {
        _setSession(Map<String, dynamic>.from(await api('auth/me') as Map));
      } catch (e) {
        if (!(e is ApiError && e.status == 0)) {
          await clearSession();
          _setSession(null);
        }
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  String? get _ws => (_session?['active_role'] as Map?)?['workspace'] as String?;

  void _setSession(Session? s) {
    if (!mounted) return;
    Ent.I.set(s);
    setState(() => _session = s);
    _lock.setSignedIn(s != null);
    if (s != null) {
      rememberSession(s);
      final off = _feature(s, 'offline_mobile');
      Offline.I.setEnabled(off, currentAddress());
      if (off) syncOutbox();
    }
    _onWorkspace();
  }

  /// Once someone is in a workspace: tabs, terms, background loads, and links that open a screen.
  void _onWorkspace() {
    final ws = _ws;
    final key = _session == null ? null : ws;
    if (key == _wsSeen) return;
    _wsSeen = key;
    final s = _session;
    if (s == null || ws == null || !const ['parent', 'teacher', 'student'].contains(ws)) {
      Terms.I.reset();
      Nav.I.setTabs(const []);
      _links?.cancel();
      return;
    }
    Nav.I.setTabs(switch (ws) {
      'parent' => ['Home', if (_on(s, 'fees')) 'Fees', if (_on(s, 'exams')) 'Results', if (_on(s, 'attendance')) 'Attendance', 'Notices', if (_parentMore(s).isNotEmpty) 'More', 'Account'],
      'teacher' => ['My day', if (_on(s, 'attendance')) 'Register', if (_on(s, 'exams')) 'Scores', 'Notices', if (_teacherMore(s).isNotEmpty) 'More', 'Account'],
      _ => ['Today', if (_on(s, 'exams')) 'Results', 'Notices', if (_studentMore(s).isNotEmpty) 'More', 'Account'],
    });
    Terms.I.load();
    // The main screens of the role are loaded in the background as soon as the person is in, so the tabs open at once.
    warm(switch (ws) {
      'parent' => ['parent/home', 'parent/fees', 'parent/results', 'parent/attendance', 'inbox', 'parent/notices'],
      'teacher' => ['teacher/home', 'teacher/register', 'teacher/scores', 'inbox'],
      _ => ['student/home', 'student/results', 'inbox', 'student/notices'],
    });
    // Setting up notifications can wait until the first screen is showing.
    Future<void>.delayed(const Duration(seconds: 3), PushService.register);
    _listenForLinks();
  }

  /// Opens the screen a notice or a link is about (like /parent/fees or /parent/notices?id=x). Waits for the app to be signed in and ready.
  void _openHref(String? href, [int tries = 12]) {
    if (_session == null || Nav.I.tabs.isEmpty) {
      if (tries > 0) Future<void>.delayed(const Duration(milliseconds: 500), () => _openHref(href, tries - 1));
      return;
    }
    final notice = href == null ? null : RegExp(r'/notices\?id=([A-Za-z0-9_-]+)').firstMatch(href);
    if (notice != null) {
      Nav.I.go('Notices', notice: notice.group(1));
    } else {
      Nav.I.go(href == null ? 'Notices' : tabFor(href));
    }
  }

  /// Links from emails arrive as https://school.edu-core.ng/parent/fees; only the portal pages are handed to the app.
  void _listenForLinks() {
    _links?.cancel();
    final links = AppLinks();
    void open(Uri u) {
      final m = RegExp(r'^https?://[^/]+(/(?:parent|student|teacher)(?:/[A-Za-z0-9_\-/]*)?(?:\?[^#]*)?)').firstMatch(u.toString());
      if (m != null) _openHref(m.group(1));
    }

    links.getInitialLink().then((u) => u == null ? null : open(u)).catchError((_) => null);
    _links = links.uriLinkStream.listen(open, onError: (_) {});
  }

  Future<void> _signOut() async {
    await clearSession();
    _lock.unlock();
    _setSession(null);
  }

  void _pickMode(Mode m) {
    setState(() => _mode = m);
    m == Mode.system ? Secure.delete(_modeKey) : Secure.set(_modeKey, m.name);
  }

  @override
  Widget build(BuildContext context) {
    final system = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final dark = _mode == Mode.dark || (_mode == Mode.system && system == Brightness.dark);
    final school = _session?['school'] as Map?;
    final schoolBrand = (school?['brand_color'] as String?) ?? _previewBrand;
    applyTheme((school?['ui'] as Map?)?['app'] as String?, schoolBrand, dark);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: color.bg,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));
    final look = (school?['ui'] as Map?)?['app'] ?? 'educore';
    return MaterialApp(
      key: ValueKey('$look-$dark'),
      title: 'Educore',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      navigatorKey: navigatorKey,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: _themeData(dark),
      darkTheme: _themeData(dark),
      home: _home(),
    );
  }

  ThemeData _themeData(bool dark) => ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: color.bg,
        canvasColor: color.card,
        colorScheme: ColorScheme.fromSeed(seedColor: color.brand, brightness: dark ? Brightness.dark : Brightness.light).copyWith(primary: color.brand, onPrimary: color.onBrand, surface: color.card, onSurface: color.ink, error: color.danger),
        dividerColor: color.line,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      );

  Widget _home() {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Pop(child: Container(width: 72, height: 72, decoration: BoxDecoration(color: color.brand, borderRadius: BorderRadius.circular(24)), child: Icn('school', size: 36, tint: color.onBrand))),
            const SizedBox(height: 18),
            const Spinner(size: 22),
          ]),
        ),
      );
    }
    if (_update.state == UpdateState.required) return Scaffold(body: UpdateRequired(url: _update.url));
    final s = _session;
    final ws = _ws;
    final school = s?['school'] as Map?;
    final chrome = ChromeData(
      school: school?['name'] as String?,
      logo: school?['has_logo'] == true ? '${baseUrl()}/api/school/logo' : null,
      brandColor: (school?['brand_color'] as String?) ?? _previewBrand,
      name: (s?['user'] as Map?)?['name'] as String?,
      onAccount: () => Nav.I.go('Account'),
      term: s != null && ws != null && const ['parent', 'teacher', 'student'].contains(ws) ? const TermChip() : null,
      banner: s != null && ws != null ? const TermBanner() : null,
    );
    Widget body;
    if (s == null) {
      body = Login(onSession: _setSession, onBrand: (hex) => setState(() => _previewBrand = hex));
    } else if (ws == null) {
      body = RolePicker(session: s, onPick: _setSession);
    } else if (const ['parent', 'teacher', 'student'].contains(ws)) {
      body = _RoleShell(
        key: ValueKey(ws),
        session: s,
        ws: ws,
        mode: _mode,
        onMode: _pickMode,
        onSignOut: _signOut,
      );
    } else {
      body = Screen(bare: true, children: [
        const SizedBox(height: 40),
        const H1('Use the web app'),
        const Muted('Your role works on the school website. This app is for parents, teachers and students.'),
        AppButton('Sign out', kind: BtnKind.plain, icon: 'log-out-outline', onPressed: _signOut),
      ]);
    }
    return Chrome(
      data: chrome,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          Positioned.fill(child: body),
          if (_update.state == UpdateState.available)
            Positioned(left: 12, right: 12, bottom: 96, child: UpdateNotice(url: _update.url)),
          const ConnectivityBanner(),
          if (s != null && _lock.locked) Positioned.fill(child: LockScreen(onUnlock: _lock.unlock, onSignOut: _signOut, school: school?['name'] as String?)),
        ]),
      ),
    );
  }
}

/// The signed-in app for one role: the screens as tabs under an animated bottom bar, kept alive once opened.
class _RoleShell extends StatefulWidget {
  final Session session;
  final String ws;
  final Mode mode;
  final ValueChanged<Mode> onMode;
  final Future<void> Function() onSignOut;
  const _RoleShell({super.key, required this.session, required this.ws, required this.mode, required this.onMode, required this.onSignOut});
  @override
  State<_RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<_RoleShell> {
  final Set<String> _visited = {};

  Widget _screen(String tab) {
    final s = widget.session;
    final school = s['school'] as Map?;
    switch (tab) {
      case 'Home': return const ParentHome();
      case 'Fees': return const ParentFees();
      case 'Results': return widget.ws == 'student' ? const StudentResults() : const ParentResults();
      case 'Attendance': return const ParentAttendance();
      case 'Notices': return Inbox(notices: widget.ws == 'parent' ? 'parent/notices' : widget.ws == 'student' ? 'student/notices' : null);
      case 'My day': return const TeacherHome();
      case 'Register': return const TeacherRegister();
      case 'Scores': return const TeacherScores();
      case 'Today': return const StudentHome();
      case 'More': return More(items: widget.ws == 'parent' ? _parentMore(s) : widget.ws == 'teacher' ? _teacherMore(s) : _studentMore(s));
      case 'Account':
        return AccountScreen(name: '${(s['user'] as Map)['name']}', school: school?['name'] as String?, workspace: widget.ws, requests: _on(s, 'data_requests'), mode: widget.mode, onMode: widget.onMode, onSignOut: widget.onSignOut);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Nav.I,
        builder: (context, _) {
          final nav = Nav.I;
          if (nav.current.isNotEmpty) _visited.add(nav.current);
          final index = nav.tabs.indexOf(nav.current);
          return PopScope(
            canPop: nav.tabs.isEmpty || index <= 0 && !nav.canGoBack,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) nav.back();
            },
            child: Column(children: [
              // The tab bar below already keeps clear of the system buttons, so the screens do not add that space again.
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: IndexedStack(
                    index: index < 0 ? 0 : index,
                    children: [for (final t in nav.tabs) _visited.contains(t) ? KeyedSubtree(key: ValueKey(t), child: _screen(t)) : const SizedBox.shrink()],
                  ),
                ),
              ),
              const AppTabBar(),
            ]),
          );
        },
      );
}
