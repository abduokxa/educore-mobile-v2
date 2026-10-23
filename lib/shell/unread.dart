import 'package:flutter/foundation.dart';
import '../core/api.dart';

/// How many notices have not been read yet, for the badge on the bell at the top.
class Unread extends ChangeNotifier {
  Unread._();
  static final Unread I = Unread._();

  int count = 0;

  Future<void> load() async {
    try {
      final d = await api('inbox');
      final n = ((d['unread'] as num?) ?? 0).toInt();
      if (n != count) {
        count = n;
        notifyListeners();
      }
    } catch (_) {
      // The badge just stays as it was.
    }
  }

  void clear() {
    if (count == 0) return;
    count = 0;
    notifyListeners();
  }
}
