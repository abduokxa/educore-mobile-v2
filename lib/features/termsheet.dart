import 'package:flutter/material.dart';
import '../core/term.dart';
import '../ui/ui.dart';

/// "2026/2027" becomes "26/27", so the chip stays small.
String shortSession(String s) => s.replaceFirstMapped(RegExp(r'(\d{2})(\d{2})/(\d{2})(\d{2})'), (m) => '${m[2]}/${m[4]}');

/// The chip at the top of every screen: which term the app is showing. Tap it to choose another.
class TermChip extends StatelessWidget {
  const TermChip({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Terms.I,
        builder: (context, _) {
          final t = Terms.I.shown;
          if (t == null) return const SizedBox.shrink();
          final past = t.past ? tone('amber') : null;
          final fg = past?.fg ?? color.brand;
          return Tap(
            label: 'Showing ${t.row.label}. Tap to change the term.',
            onTap: () => showAppSheet(context, title: 'Session and term', tall: true, builder: (_) => const TermSheet()),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: past?.bg ?? color.tint, borderRadius: BorderRadius.circular(17)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icn('calendar-outline', size: 15, tint: fg),
                const SizedBox(width: 5),
                Text('${t.row.name.replaceAll(' Term', '')} · ${shortSession(t.session)}', style: Ty.custom(12.5, FontWeight.w700, c: fg)),
                const SizedBox(width: 5),
                Icn('chevron-down', size: 13, tint: fg),
              ]),
            ),
          );
        },
      );
}

/// Shown on every screen while looking at a term that is not the current one, with a one-tap way back.
class TermBanner extends StatelessWidget {
  const TermBanner({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Terms.I,
        builder: (context, _) {
          final t = Terms.I.shown;
          if (t == null || !t.past) return const SizedBox.shrink();
          final w = tone('amber');
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(color: w.bg, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icn('time-outline', size: 18, tint: w.fg),
              const SizedBox(width: 10),
              Expanded(child: Text('Showing ${t.row.label}', style: Ty.custom(13, FontWeight.w700, c: w.fg))),
              Tap(
                label: 'Go back to the current term',
                onTap: () => Terms.I.choose(null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(minHeight: 34),
                  decoration: BoxDecoration(color: w.fg, borderRadius: BorderRadius.circular(17)),
                  alignment: Alignment.center,
                  child: Text('Current term', style: Ty.custom(12.5, FontWeight.w800, c: Colors.white)),
                ),
              ),
            ]),
          );
        },
      );
}

/// Sessions and their terms. Choose one once and the whole app follows it.
class TermSheet extends StatelessWidget {
  const TermSheet({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Terms.I,
        builder: (context, _) {
          final shown = Terms.I.shown;
          return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            if (shown?.past == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AppButton('Back to the current term', icon: 'arrow-undo-outline', onPressed: () {
                  Terms.I.choose(null);
                  Navigator.pop(context);
                }),
              ),
            for (final s in Terms.I.sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                    child: Row(children: [Text(s.name, style: Ty.h3()), const SizedBox(width: 8), if (s.isCurrent) const Pill('Current session', toneName: 'green')]),
                  ),
                  for (final t in s.terms)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Tap(
                        scale: 0.985,
                        label: '${t.label}, ${t.status}',
                        onTap: () {
                          Terms.I.choose(t.isCurrent ? null : t.id);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: shown?.row.id == t.id ? color.tint : color.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: shown?.row.id == t.id ? color.brand : color.line, width: 1.5),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t.name, style: Ty.h3(size: 15.5)),
                                if (t.starts != null) Muted('${t.starts} to ${t.ends}'),
                              ]),
                            ),
                            Pill(t.status, toneName: t.isCurrent ? 'green' : t.status == 'Finished' ? 'grey' : 'blue'),
                            if (shown?.row.id == t.id) ...[const SizedBox(width: 8), Icn('checkmark-circle', size: 22, tint: color.brand)],
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
          ]);
        },
      );
}
