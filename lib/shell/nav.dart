import 'package:flutter/foundation.dart';

/// Which tab of the bottom bar is showing. Screens open another one with [Nav.go]; the phone's back button steps back through the ones visited.
class Nav extends ChangeNotifier {
  Nav._();
  static final Nav I = Nav._();

  List<String> tabs = const [];
  String current = '';
  final List<String> _history = [];

  /// A notice a tap (or a link in an email) asked to open; the Notices screen takes it.
  String? openNotice;

  void setTabs(List<String> t) {
    tabs = t;
    current = t.isEmpty ? '' : t.first;
    _history.clear();
    openNotice = null;
    notifyListeners();
  }

  void go(String tab, {String? notice}) {
    if (!tabs.contains(tab)) return;
    openNotice = notice;
    if (tab != current) {
      _history.add(current);
      current = tab;
    }
    notifyListeners();
  }

  String? takeNotice() {
    final n = openNotice;
    openNotice = null;
    return n;
  }

  bool get canGoBack => _history.isNotEmpty;

  /// Steps back to the tab visited before. Returns false when there is nowhere to go.
  bool back() {
    if (_history.isEmpty) return false;
    current = _history.removeLast();
    notifyListeners();
    return true;
  }
}
