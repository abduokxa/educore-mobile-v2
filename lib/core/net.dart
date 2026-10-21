import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

/// Whether the phone can reach the server. Any request that fails for lack of signal marks it offline; while offline we check
/// the server every few seconds, and the moment it answers we are back online (and the alert goes away by itself).
class Net extends ChangeNotifier with WidgetsBindingObserver {
  Net._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final Net I = Net._();

  bool online = true;
  bool justBack = false;
  Timer? _probe;
  Timer? _clear;

  Future<bool> reachable() async {
    try {
      final res = await http.get(Uri.parse('${rootUrl()}/up'), headers: {'X-Client': 'mobile'}).timeout(const Duration(seconds: 5));
      return res.statusCode > 0;
    } catch (_) {
      return false;
    }
  }

  void goOffline() {
    if (!online) return;
    online = false;
    justBack = false;
    _clear?.cancel();
    notifyListeners();
    _probe ??= Timer.periodic(const Duration(seconds: 4), (_) async {
      if (await reachable()) goOnline();
    });
  }

  void goOnline() {
    _probe?.cancel();
    _probe = null;
    if (online) return;
    online = true;
    justBack = true;
    notifyListeners();
    _clear = Timer(const Duration(milliseconds: 2600), () {
      justBack = false;
      notifyListeners();
    });
  }

  void retry() => reachable().then((ok) {
        if (ok) goOnline();
      });

  /// The phone coming back to the front is a good moment to check again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !online) retry();
  }
}

/// A nudge for every open screen to load its data again: when a notice arrives while the app is open (a payment receipt, a new result)
/// and when the app comes back after being away for a while, so a balance or a list is never left showing old numbers.
class Refresh extends ChangeNotifier with WidgetsBindingObserver {
  Refresh._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final Refresh I = Refresh._();

  int tick = 0;
  DateTime? _left;
  static const _away = Duration(seconds: 30);

  void bump() {
    tick += 1;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _left ??= DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final gone = _left == null ? Duration.zero : DateTime.now().difference(_left!);
      _left = null;
      if (gone >= _away) bump();
    }
  }
}
