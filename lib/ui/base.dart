import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../core/theme.dart';
import 'ion.dart';

bool reduceMotion(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;

/// An Ionicons icon by name, in the current look's ink unless told otherwise.
class Icn extends StatelessWidget {
  final String name;
  final double size;
  final Color? tint;
  const Icn(this.name, {super.key, this.size = 20, this.tint});
  @override
  Widget build(BuildContext context) => Icon(ion(name), size: size, color: tint ?? color.ink);
}

/// Anything tappable: it sinks a little while pressed.
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? label;
  const Tap({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97, this.label});
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      label: widget.label,
      // With a label the control reads as that label once, not again for the text drawn inside it.
      excludeSemantics: widget.label != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(scale: _down && !reduceMotion(context) ? widget.scale : 1, duration: const Duration(milliseconds: 90), child: widget.child),
      ),
    );
  }
}

/// A round, tinted background behind an icon.
class IconBadge extends StatelessWidget {
  final String name;
  final double size;
  final Color? tint, bg;
  const IconBadge(this.name, {super.key, this.size = 40, this.tint, this.bg});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg ?? color.tint, borderRadius: BorderRadius.circular(size / 2.6)),
        alignment: Alignment.center,
        child: Icn(name, size: size * 0.5, tint: tint ?? color.brand),
      );
}

String initialsOf(String name, {bool honorifics = true}) {
  var n = name;
  if (honorifics) n = n.replaceFirst(RegExp(r'^(mr|mrs|ms|miss|dr|prof)\.?\s+', caseSensitive: false), '');
  final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
  final s = parts.map((p) => p[0].toUpperCase()).join();
  return s.isEmpty ? '?' : s;
}

/// Initials in a coloured circle.
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final bool solid;
  const Avatar(this.name, {super.key, this.size = 40, this.solid = false});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: solid ? color.brand : color.tint),
        alignment: Alignment.center,
        child: Text(initialsOf(name), style: Ty.custom(size * 0.38, FontWeight.w700, c: solid ? color.onBrand : color.brand)),
      );
}

/// The school's logo when it has one, or its initials on its own colour.
class SchoolLogo extends StatefulWidget {
  final String? uri;
  final String name;
  final String? tint;
  final double size;
  const SchoolLogo({super.key, this.uri, required this.name, this.tint, this.size = 40});
  @override
  State<SchoolLogo> createState() => _SchoolLogoState();
}

class _SchoolLogoState extends State<SchoolLogo> {
  bool _failed = false;
  @override
  void didUpdateWidget(SchoolLogo old) {
    super.didUpdateWidget(old);
    if (old.uri != widget.uri) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.size / 3);
    if (widget.uri != null && !_failed) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: Colors.white, borderRadius: r, border: Border.all(color: color.line)),
        child: ClipRRect(
          borderRadius: r,
          child: Image.network(widget.uri!, fit: BoxFit.contain, semanticLabel: '${widget.name} logo', errorBuilder: (_, e, s) {
            scheduleMicrotask(() {
              if (mounted) setState(() => _failed = true);
            });
            return const SizedBox();
          }),
        ),
      );
    }
    final t = widget.tint;
    final bg = t != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(t) ? Color(int.parse('FF${t.substring(1)}', radix: 16)) : color.brand;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: bg, borderRadius: r),
      alignment: Alignment.center,
      child: Text(initialsOf(widget.name, honorifics: false), style: Ty.custom(widget.size * 0.36, FontWeight.w800, c: Colors.white)),
    );
  }
}

/// A small status pill with a dot.
class Pill extends StatelessWidget {
  final String text;
  final String toneName;
  const Pill(this.text, {super.key, this.toneName = 'grey'});
  @override
  Widget build(BuildContext context) {
    final t = tone(toneName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: t.fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: Ty.custom(12.5, FontWeight.w700, c: t.fg))),
      ]),
    );
  }
}

/// A thin progress bar that grows to its value.
class Bar extends StatelessWidget {
  final double pct;
  final double height;
  final Color? tint;
  const Bar(this.pct, {super.key, this.height = 8, this.tint});
  @override
  Widget build(BuildContext context) {
    final v = (pct.isNaN ? 0 : pct.clamp(0, 100)) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: color.line,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v.toDouble()),
          duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, x, _) => FractionallySizedBox(widthFactor: x, child: Container(color: tint ?? color.brand)),
        ),
      ),
    );
  }
}

/// A grey block that breathes while something loads.
class Skeleton extends StatefulWidget {
  final double? w;
  final double h;
  final double r;
  const Skeleton({super.key, this.w, required this.h, this.r = 10});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: widget.w,
          height: widget.h,
          decoration: BoxDecoration(color: Color.lerp(color.line, color.tint, _c.value * 0.7), borderRadius: BorderRadius.circular(widget.r)),
        ),
      );
}

/// Three dots that pulse: used inside a button that is working.
class Dots extends StatefulWidget {
  final Color tint;
  final double size;
  const Dots({super.key, required this.tint, this.size = 7});
  @override
  State<Dots> createState() => _DotsState();
}

class _DotsState extends State<Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size / 3),
              child: Opacity(
                opacity: 0.35 + 0.65 * ((_c.value * 3 - i).abs() < 1 ? 1 - (_c.value * 3 - i).abs() : 0),
                child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: widget.tint, shape: BoxShape.circle)),
              ),
            ),
        ]),
      );
}

class Spinner extends StatelessWidget {
  final double size;
  const Spinner({super.key, this.size = 20});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CircularProgressIndicator(strokeWidth: 2.4, color: color.brand));
}

/// A number that counts up to its value.
class CountUp extends StatelessWidget {
  final double to;
  final String Function(double) render;
  final TextStyle style;
  const CountUp({super.key, required this.to, required this.render, required this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: to),
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text(render(v), style: style),
      );
}

/// Content that rises into place when it first appears.
class Reveal extends StatefulWidget {
  final int index;
  final Widget child;
  const Reveal({super.key, this.index = 0, required this.child});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  Timer? _t;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
    } else {
      _t = Timer(Duration(milliseconds: (widget.index.clamp(0, 8)) * 45), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(opacity: a, child: AnimatedBuilder(animation: a, builder: (_, c) => Transform.translate(offset: Offset(0, 14 * (1 - a.value)), child: c), child: widget.child));
  }
}

/// A little spring when something appears.
class Pop extends StatelessWidget {
  final Widget child;
  const Pop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion(context) ? 1 : 0.6, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.elasticOut,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: child,
      );
}

/// The icon used by a few small spots in the shell.
const IconData kChevron = Ionicons.chevronForward;
