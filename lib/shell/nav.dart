import 'package:flutter/foundation.dart';

/// Which tab of the bottom bar is showing. Screens open another one with [Nav.go]; the phone's back button steps back through the ones visited.
class Nav extends ChangeNotifier {
  Nav._();
  static final Nav I = Nav._();

  List<String> tabs = const [];
  String current = '';

  /// parent, teacher or student: the words some tabs show depend on it.
  String role = '';

  /// A screen opened from the side menu that is not a tab (Homework, Messages, Payslips...). It shows over the tabs until closed.
  String? page;

  /// The keys of the side-menu screens this person may open.
  List<String> pages = const [];

  /// Where the person has been, newest last: a tab, or a tab with a menu screen over it. Back steps through it.
  final List<(String, String?)> _history = [];

  /// While a test or exam is being taken, nothing else in the app can be opened: no tabs, no shortcuts, no notice taps.
  bool locked = false;

  void lock(bool on) {
    if (locked == on) return;
    locked = on;
    notifyListeners();
  }

  /// A notice a tap (or a link in an email) asked to open; the Notices screen takes it.
  String? openNotice;

  void setTabs(List<String> t, {String role = '', List<String> pages = const []}) {
    tabs = t;
    this.role = role;
    this.pages = pages;
    page = null;
    current = t.isEmpty ? '' : t.first;
    _history.clear();
    openNotice = null;
    notifyListeners();
  }

  void _remember() {
    final here = (current, page);
    if (_history.isEmpty || _history.last != here) _history.add(here);
    if (_history.length > 30) _history.removeAt(0);
  }

  /// Opens a tab. Anything opened over the tabs from the menu is put away.
  void go(String tab, {String? notice}) {
    if (locked || !tabs.contains(tab)) return;
    openNotice = notice;
    if (tab != current || page != null) {
      _remember();
      current = tab;
      page = null;
    }
    notifyListeners();
  }

  /// Opens a screen from the side menu over the tabs.
  void openPage(String key) {
    if (locked || !pages.contains(key) || page == key) return;
    _remember();
    page = key;
    notifyListeners();
  }

  /// Opens what a link or notice is about: a tab (like Fees), or a menu screen written "page:payslips".
  void goTo(String target, {String? notice}) {
    if (target.startsWith('page:')) {
      openPage(target.substring(5));
    } else {
      go(target, notice: notice);
    }
  }

  String? takeNotice() {
    final n = openNotice;
    openNotice = null;
    return n;
  }

  bool get canGoBack => _history.isNotEmpty;

  /// Steps back to where the person was just before, a menu screen included. Returns false when there is nowhere to go.
  bool back() {
    if (_history.isEmpty) return false;
    final (tab, was) = _history.removeLast();
    current = tab;
    page = was;
    notifyListeners();
    return true;
  }
}
