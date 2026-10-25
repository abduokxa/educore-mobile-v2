import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/api.dart';
import 'core/background.dart';
import 'core/docstore.dart';
import 'core/prefetch.dart';
import 'core/entitle.dart';
import 'core/words.dart';
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
import 'screens/bursar.dart';
import 'screens/exams.dart';
import 'screens/extras.dart';
import 'screens/learning.dart';
import 'screens/inbox.dart';
import 'screens/login.dart';
import 'screens/parent.dart';
import 'screens/search.dart';
import 'screens/student.dart';
import 'screens/teacher.dart';
import 'shell/drawer.dart';
import 'shell/nav.dart';
import 'shell/status.dart';
import 'shell/tabbar.dart';
import 'shell/unread.dart';
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
      const Shortcut('Profile', 'Account'),
    ];

List<MoreItem> _teacherMore(Session s) => _menu(s, [
      ('students', MoreItem('search', 'Search', 'Find a student or a screen', (_) => Search(shortcuts: _teacherShortcuts(s)))),
      ('chat', MoreItem('chat', 'Messages', 'Talk to parents', (_) => const TeacherChat())),
      ('chat', MoreItem('meetings', 'Parent meetings', 'Offer times, see who booked', (_) => const TeacherMeetings())),
      ('students', MoreItem('help', 'Help', 'How things work', (_) => const HelpDocs())),
      ('homework', MoreItem('homework', 'Homework', 'Homework you set', (_) => const TeacherHomework())),
      ('lms.enabled', MoreItem('learn', w('{Learning}'), w('Your {courses} and {assignments} to mark'), (_) => const TeacherLearn())),
      ('cbt.manual_grading', MoreItem('mark-exams', w('Mark {exams}'), 'Written answers waiting for your marks', (_) => const TeacherMarking())),
      ('exams', MoreItem('class-results', 'Class results', 'Your class once the results are open', (_) => const TeacherClassResults())),
      ('leave', MoreItem('leave', 'Leave', 'Ask for leave and see decisions', (_) => const TeacherLeave())),
      ('payroll', MoreItem('payslips', 'Payslips', 'Your pay history', (_) => const TeacherPayslips())),
      ('school_calendar', MoreItem('calendar', 'School calendar', 'Term dates and events', (_) => const CalendarScreen())),
    ]);

List<MoreItem> _studentMore(Session s) => _menu(s, [
      ('homework', MoreItem('homework', 'Homework', 'What is due and when', (_) => const StudentHomework())),
      ('lms.enabled', MoreItem('learn', w('{Learn}'), w('{Courses}, {lessons} and {assignments}'), (_) => const StudentLearn())),
      ('online_tests', MoreItem('tests', w('{Tests} and {exams}'), w('Take a {test} or see your answers'), (_) => const StudentTests())),
      ('school_calendar', MoreItem('calendar', 'School calendar', 'Term dates and events', (_) => const CalendarScreen())),
    ]);

List<MoreItem> _bursarMore(Session s) => _menu(s, [
      ('fees', MoreItem('help', 'Help', 'How things work', (_) => const HelpDocs())),
      ('leave', MoreItem('leave', 'Leave', 'Ask for leave and see decisions', (_) => const TeacherLeave())),
      ('payroll', MoreItem('payslips', 'Payslips', 'Your pay history', (_) => const TeacherPayslips())),
      ('school_calendar', MoreItem('calendar', 'School calendar', 'Term dates and events', (_) => const CalendarScreen())),
    ]);

List<MoreItem> _moreFor(Session s, String ws) => ws == 'parent' ? _parentMore(s) : ws == 'teacher' ? _teacherMore(s) : ws == 'bursar' ? _bursarMore(s) : _studentMore(s);

class EducoreApp extends StatefulWidget {
  const EducoreApp({super.key});
  @override
  State<EducoreApp> createState() => _EducoreAppState();
}

class _EducoreAppState extends State<EducoreApp> {
  final ValueNotifier<int> _changed = ValueNotifier(0);
  final _scaffold = GlobalKey<ScaffoldState>();
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
    Net.I.addListener(_netChanged);
    Refresh.I.addListener(_saveForOffline);
    BackgroundSync.init();
    _boot();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _changed.value++;
  }

  /// The connection came back: what was saved on the phone is sent, and the offline copies are brought up to date, with no screen involved.
  void _netChanged() {
    if (!Net.I.online || _ws == null) return;
    unawaited(syncOutbox());
    _saveForOffline();
  }

  /// Quietly refresh what is kept for offline use. Skipped when it ran recently, so calling it often costs nothing.
  void _saveForOffline() {
    final ws = _ws;
    if (ws == null || !const ['parent', 'teacher', 'student', 'bursar'].contains(ws) || !Net.I.online) return;
    unawaited(Prefetch.run(role: ws));
  }

  @override
  void dispose() {
    Net.I.removeListener(_netChanged);
    Refresh.I.removeListener(_saveForOffline);
    _changed.dispose();
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
      Offline.I.setEnabled(off, currentAddress(), docs: _feature(s, 'offline_mobile.documents'), background: _feature(s, 'offline_mobile.background'), payments: _feature(s, 'offline_mobile.payments'));
      // The owner may have switched background sync off for this school since last time.
      if (!_feature(s, 'offline_mobile.background')) BackgroundSync.stop();
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
    if (s == null || ws == null || !const ['parent', 'teacher', 'student', 'bursar'].contains(ws)) {
      Terms.I.reset();
      Nav.I.setTabs(const []);
      _links?.cancel();
      return;
    }
    // Five at most in the bar, with Profile last. Notices have the bell at the top, and everything else is in the side menu.
    Nav.I.setTabs(switch (ws) {
      'parent' => ['Home', if (_on(s, 'fees')) 'Fees', if (_on(s, 'exams')) 'Results', if (_on(s, 'attendance')) 'Attendance', 'Notices', 'Account'],
      'teacher' => ['My day', if (_on(s, 'attendance')) 'Register', if (_on(s, 'exams')) 'Scores', if (_feature(s, 'lms.enabled')) 'Learn', 'Notices', 'Account'],
      'bursar' => [if (_feature(s, 'fees')) ...['Today', 'Owing', 'Payments', 'Bills'], 'Notices', 'Account'],
      _ => ['Today', if (_feature(s, 'lms.enabled')) 'Learn', if (_feature(s, 'online_tests')) 'Tests', if (_on(s, 'exams')) 'Results', 'Notices', 'Account'],
    }, role: ws, pages: [for (final i in _moreFor(s, ws)) i.key]);
    Unread.I.load();
    Terms.I.load();
    // The main screens of the role are loaded in the background as soon as the person is in, so the tabs open at once.
    warm(switch (ws) {
      'parent' => ['parent/home', 'parent/fees', 'parent/results', 'parent/attendance', 'inbox', 'parent/notices'],
      'teacher' => ['teacher/home', 'teacher/register', 'teacher/scores', 'inbox'],
      'bursar' => ['bursar', 'inbox'],
      _ => ['student/home', 'student/results', 'inbox', 'student/notices'],
    });
    // Setting up notifications can wait until the first screen is showing.
    Future<void>.delayed(const Duration(seconds: 3), PushService.register);
    // Offline copies are saved behind the screens, and the phone's own schedule keeps them fresh and sends saved work, app open or not.
    BackgroundSync.start();
    Future<void>.delayed(const Duration(seconds: 6), _saveForOffline);
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
      Nav.I.goTo(href == null ? 'Notices' : targetFor(href));
    }
  }

  /// Links from emails arrive as https://school.edu-core.ng/parent/fees; only the portal pages are handed to the app.
  void _listenForLinks() {
    _links?.cancel();
    final links = AppLinks();
    void open(Uri u) {
      final m = RegExp(r'^https?://[^/]+(/(?:parent|student|teacher|bursar)(?:/[A-Za-z0-9_\-/]*)?(?:\?[^#]*)?)').firstMatch(u.toString());
      if (m != null) _openHref(m.group(1));
    }

    links.getInitialLink().then((u) => u == null ? null : open(u)).catchError((_) => null);
    _links = links.uriLinkStream.listen(open, onError: (_) {});
  }

  Future<void> _signOut() async {
    await BackgroundSync.stop();
    // Nothing of this person's stays on the phone: saved screens, documents and anything not yet sent.
    await Offline.I.wipe();
    await DocStore.clear();
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
      // The first route keeps whatever it was built with, so it is told to rebuild whenever this state changes.
      home: ListenableBuilder(listenable: _changed, builder: (context, _) => _home()),
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
    final inRole = s != null && ws != null && const ['parent', 'teacher', 'student', 'bursar'].contains(ws);
    final chrome = ChromeData(
      school: school?['name'] as String?,
      logo: school?['has_logo'] == true ? '${baseUrl()}/api/school/logo' : null,
      brandColor: (school?['brand_color'] as String?) ?? _previewBrand,
      name: (s?['user'] as Map?)?['name'] as String?,
      menu: inRole ? MenuButton(onOpen: () => _scaffold.currentState?.openDrawer()) : null,
      bell: inRole ? const NoticeBell() : null,
      banner: s != null && ws != null ? const TermBanner() : null,
    );
    Widget body;
    if (s == null) {
      body = Login(onSession: _setSession, onBrand: (hex) => setState(() => _previewBrand = hex));
    } else if (ws == null) {
      body = RolePicker(session: s, onPick: _setSession);
    } else if (const ['parent', 'teacher', 'student', 'bursar'].contains(ws)) {
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
        const Muted('Your role works on the school website. This app is for parents, teachers, students and bursars.'),
        AppButton('Sign out', kind: BtnKind.plain, icon: 'log-out-outline', onPressed: _signOut),
      ]);
    }
    final role = switch (ws) { 'parent' => 'Parent', 'teacher' => 'Teacher', 'student' => 'Student', _ => '' };
    return Chrome(
      data: chrome,
      child: ListenableBuilder(listenable: Nav.I, builder: (context, _) => Scaffold(
        key: _scaffold,
        resizeToAvoidBottomInset: true,
        drawer: inRole
            ? AppDrawer(school: school?['name'] as String? ?? 'Educore', person: (s['user'] as Map?)?['name'] as String? ?? '', roleLabel: role, logo: chrome.logo, brand: chrome.brandColor, more: _moreFor(s, ws))
            : null,
        drawerEnableOpenDragGesture: inRole && !Nav.I.locked,
        body: Stack(children: [
          Positioned.fill(child: body),
          if (_update.state == UpdateState.available)
            Positioned(left: 12, right: 12, bottom: 96, child: UpdateNotice(url: _update.url)),
          const ConnectivityBanner(),
          if (s != null && _lock.locked) Positioned.fill(child: LockScreen(onUnlock: _lock.unlock, onSignOut: _signOut, school: school?['name'] as String?)),
        ]),
      )),
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
  String _lastTab = '';

  @override
  void initState() {
    super.initState();
    Nav.I.addListener(_tabChanged);
  }

  @override
  void dispose() {
    Nav.I.removeListener(_tabChanged);
    super.dispose();
  }

  /// The bell's count is read again each time a screen is left, and cleared on the notices themselves.
  void _tabChanged() {
    if (Nav.I.current == _lastTab) return;
    _lastTab = Nav.I.current;
    Nav.I.current == 'Notices' ? Unread.I.clear() : Unread.I.load();
  }

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
      case 'Today': return widget.ws == 'bursar' ? const BursarHome() : const StudentHome();
      case 'Owing': return const BursarOwing();
      case 'Payments': return const BursarPayments();
      case 'Bills': return const BursarBills();
      case 'Learn': return widget.ws == 'teacher' ? const TeacherLearn() : const StudentLearn();
      case 'Tests': return const StudentTests();
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
          final menu = _moreFor(widget.session, widget.ws);
          final page = nav.page == null ? null : menu.where((i) => i.key == nav.page).firstOrNull;
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
                  child: Stack(children: [
                    Positioned.fill(
                      child: IndexedStack(
                        index: index < 0 ? 0 : index,
                        children: [for (final t in nav.tabs) _visited.contains(t) ? KeyedSubtree(key: ValueKey(t), child: _screen(t)) : const SizedBox.shrink()],
                      ),
                    ),
                    // A screen from the side menu sits over the tabs until Back is pressed.
                    if (page != null)
                      Positioned.fill(
                        child: Container(
                          key: ValueKey('page-${page.key}'),
                          color: color.bg,
                          child: WithBack(onBack: nav.back, label: 'Back', child: Builder(builder: page.screen)),
                        ),
                      ),
                  ]),
                ),
              ),
              const AppTabBar(),
            ]),
          );
        },
      );
}
