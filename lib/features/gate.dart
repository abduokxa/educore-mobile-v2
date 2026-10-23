import 'package:flutter/material.dart';
import '../core/entitle.dart';
import '../ui/ui.dart';

/// What a person sees when their school's plan does not include a feature. Nothing to buy here: the School Admin changes the plan.
class LockedView extends StatelessWidget {
  final String title, feature;
  const LockedView({super.key, required this.title, required this.feature});
  @override
  Widget build(BuildContext context) => Screen(children: [
        PageTitle(title),
        Empty(icon: 'lock-closed-outline', title: 'Not part of your school\'s plan', body: Ent.I.reason(feature) ?? 'This feature is not switched on for your school yet. Ask your School Admin about adding it.'),
      ]);
}

/// A note at the top of a screen when the subscription has ended and the feature can only be looked at.
class ReadOnlyNote extends StatelessWidget {
  final String feature;
  const ReadOnlyNote(this.feature, {super.key});
  @override
  Widget build(BuildContext context) {
    if (!Ent.I.readonly(feature)) return const SizedBox.shrink();
    final t = tone('amber');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icn('eye-outline', size: 18, tint: t.fg),
        const SizedBox(width: 10),
        Expanded(child: Text(Ent.I.reason(feature) ?? 'This is view-only right now. Everything is kept.', style: Ty.small(c: t.fg, w: FontWeight.w600))),
      ]),
    );
  }
}
