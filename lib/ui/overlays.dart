import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'base.dart';

/// Shows messages on top of everything: a green tick for good news, a red mark for a problem.
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

class Notify {
  void _show(String title, String? detail, String icon, Color tint) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color.card,
      elevation: 6,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.line)),
      duration: const Duration(seconds: 4),
      content: Row(children: [
        Icn(icon, size: 22, tint: tint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: Ty.custom(14.5, FontWeight.w700)),
            if (detail != null && detail.isNotEmpty) Text(detail, style: Ty.small()),
          ]),
        ),
      ]),
    ));
  }

  void ok(String title, [String? detail]) => _show(title, detail, 'checkmark-circle', color.brand);
  void err(String title, [String? detail]) => _show(title, detail, 'close-circle', color.danger);
  void info(String title, [String? detail]) => _show(title, detail, 'alert-circle-outline', tone('amber').fg);
}

final Notify notify = Notify();

/// A sheet that slides up from the bottom. [tall] lets it use most of the screen.
Future<T?> showAppSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder, bool tall = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: color.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) {
      final kb = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: kb),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * (tall ? 0.92 : 0.75)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 44, height: 5, decoration: BoxDecoration(color: color.line, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(children: [
                Expanded(child: Text(title, style: Ty.h2())),
                Tap(onTap: () => Navigator.of(ctx).pop(), label: 'Close', child: Padding(padding: const EdgeInsets.all(8), child: Icn('close', size: 22, tint: color.muted))),
              ]),
            ),
            Flexible(child: builder(ctx)),
          ]),
        ),
      );
    },
  );
}

/// A yes/no question. Returns true when the person confirms.
Future<bool> confirm(BuildContext context, {required String title, String? message, String yes = 'Yes', String no = 'Keep', bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: color.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: Ty.h3(size: 18)),
      content: message == null || message.isEmpty ? null : Text(message, style: Ty.body(c: color.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(no, style: Ty.custom(15, FontWeight.w700, c: color.muted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes, style: Ty.custom(15, FontWeight.w800, c: destructive ? color.danger : color.brand))),
      ],
    ),
  );
  return r == true;
}

/// A message the person has to read before carrying on.
Future<void> alertBox(BuildContext context, String title, [String? message]) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: color.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: Ty.h3(size: 18)),
      content: message == null || message.isEmpty ? null : Text(message, style: Ty.body(c: color.muted)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: Ty.custom(15, FontWeight.w800, c: color.brand)))],
    ),
  );
}
