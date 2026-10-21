import 'package:flutter/material.dart';
import '../core/net.dart';
import '../ui/ui.dart';

/// The strip that drops in from the top when the phone cannot reach the server, keeps checking, turns green with
/// "Back online" the moment it can, and slides away by itself.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Net.I,
        builder: (context, _) {
          final show = !Net.I.online || Net.I.justBack;
          final good = Net.I.online && Net.I.justBack;
          final t = tone(good ? 'green' : 'amber');
          return Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              ignoring: !show,
              child: AnimatedSlide(
                offset: show ? Offset.zero : const Offset(0, -1.5),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Padding(
                    padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 8),
                    child: Center(
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 440),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                          decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.fg.withValues(alpha: 0.4)), boxShadow: const [BoxShadow(color: Color(0x260F172A), blurRadius: 16, offset: Offset(0, 6))]),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icn(good ? 'checkmark-circle' : 'cloud-offline', size: 22, tint: t.fg),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text(good ? 'Back online' : 'You are offline', style: Ty.h3(size: 14.5, c: t.fg)),
                                if (!good) Text('Showing what is saved on this phone. Reconnecting…', style: Ty.caption()),
                              ]),
                            ),
                            if (!good) ...[
                              const SizedBox(width: 10),
                              Spinner(size: 16),
                              const SizedBox(width: 8),
                              Tap(
                                label: 'Try again now',
                                onTap: Net.I.retry,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  constraints: const BoxConstraints(minHeight: 32),
                                  decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(16)),
                                  alignment: Alignment.center,
                                  child: Text('Retry', style: Ty.custom(12.5, FontWeight.w800, c: t.fg)),
                                ),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
