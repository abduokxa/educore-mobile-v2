import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'base.dart';
import 'overlays.dart';

enum BtnKind { primary, plain, danger, soft }

/// Shows dots and ignores a second tap while its work runs. If the handler returns a future, the dots follow it; a failure is shown to the person.
class AppButton extends StatefulWidget {
  final String label;
  final FutureOr<void> Function()? onPressed;
  final BtnKind kind;
  final bool disabled, busy;
  final String? icon;
  const AppButton(this.label, {super.key, required this.onPressed, this.kind = BtnKind.primary, this.disabled = false, this.busy = false, this.icon});
  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _own = false, _done = false;

  Future<void> _press() async {
    if (_own || widget.busy || _done) return;
    final r = widget.onPressed?.call();
    if (r is Future) {
      setState(() => _own = true);
      var ok = true;
      try {
        await r;
      } catch (e) {
        ok = false;
        if (mounted) notify.err('That did not work', e is ApiError ? e.message : 'Please try again.');
      }
      if (!mounted) return;
      setState(() {
        _own = false;
        _done = ok;
      });
      if (ok) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) setState(() => _done = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final working = widget.busy || _own;
    final (bg, fg) = switch (widget.kind) {
      BtnKind.primary => (color.brand, color.onBrand),
      BtnKind.danger => (color.danger, Colors.white),
      BtnKind.soft => (color.tint, color.brand),
      BtnKind.plain => (color.card, color.ink),
    };
    final off = widget.disabled || widget.onPressed == null;
    return Opacity(
      opacity: off ? 0.45 : 1,
      child: Tap(
        label: widget.label,
        onTap: off || working ? null : _press,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: widget.kind == BtnKind.plain ? Border.all(color: color.line) : null),
          alignment: Alignment.center,
          child: working
              ? Dots(tint: fg)
              : _done
                  ? Pop(child: Icn('checkmark-circle', size: 24, tint: fg))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (widget.icon != null) ...[Icn(widget.icon!, size: 19, tint: fg), const SizedBox(width: 8)],
                      Flexible(child: Text(widget.label, textAlign: TextAlign.center, style: Ty.custom(15.5, FontWeight.w700, c: fg))),
                    ]),
        ),
      ),
    );
  }
}

/// A labelled text field with its error underneath, sized for thumbs. The border lights up while you type.
class Field extends StatefulWidget {
  final String label;
  final String? hint, error, icon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool secure, multiline, autofocus, autocorrect;
  final int? maxLength, rows;
  final TextInputType? keyboardType;
  final TextInputAction? action;
  final Iterable<String>? autofill;
  final bool enabled;
  final TextAlign textAlign;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onSubmitted;
  const Field({
    super.key,
    this.label = '',
    this.hint,
    this.error,
    this.icon,
    this.controller,
    this.onChanged,
    this.secure = false,
    this.multiline = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.maxLength,
    this.rows,
    this.keyboardType,
    this.action,
    this.autofill,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.formatters,
    this.onSubmitted,
  });
  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  late bool _hide = widget.secure;
  final _focus = FocusNode();
  bool _has = false;
  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _has = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = widget.error;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.label.isNotEmpty) ...[Text(widget.label, style: Ty.small(w: FontWeight.w600)), const SizedBox(height: 6)],
      AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: color.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: err != null ? color.danger : _has ? color.brand : color.line, width: _has ? 2 : 1),
        ),
        child: Row(crossAxisAlignment: widget.multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
          if (widget.icon != null) Padding(padding: EdgeInsets.only(left: 14, top: widget.multiline ? 14 : 0), child: Icn(widget.icon!, size: 19, tint: _has ? color.brand : color.muted)),
          Expanded(
            child: TextField(
              focusNode: _focus,
              controller: widget.controller,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              obscureText: _hide,
              autofocus: widget.autofocus,
              autocorrect: widget.autocorrect && !widget.secure,
              enableSuggestions: !widget.secure,
              enabled: widget.enabled,
              textAlign: widget.textAlign,
              maxLength: widget.maxLength,
              inputFormatters: widget.formatters,
              keyboardType: widget.multiline ? TextInputType.multiline : widget.keyboardType,
              textInputAction: widget.action,
              autofillHints: widget.autofill,
              minLines: widget.multiline ? (widget.rows ?? 4) : 1,
              maxLines: widget.multiline ? (widget.rows != null ? widget.rows! + 2 : 8) : 1,
              style: Ty.custom(16, FontWeight.w500),
              cursorColor: color.brand,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: Ty.custom(16, FontWeight.w400, c: color.muted),
                counterText: '',
                border: InputBorder.none,
                isDense: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: widget.multiline ? 12 : 15),
              ),
            ),
          ),
          if (widget.secure)
            Tap(
              label: _hide ? 'Show password' : 'Hide password',
              onTap: () => setState(() => _hide = !_hide),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), child: Icn(_hide ? 'eye-outline' : 'eye-off-outline', size: 20, tint: color.muted)),
            ),
        ]),
      ),
      if (err != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(err, style: Ty.small(c: color.danger))),
    ]);
  }
}

/// Choices in a row that scrolls sideways when there are many: children, terms, filters.
class Chips<T> extends StatelessWidget {
  final List<({T value, String label})> options;
  final T value;
  final ValueChanged<T> onChange;
  const Chips({super.key, required this.options, required this.value, required this.onChange});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tap(
                label: o.label,
                onTap: () => onChange(o.value),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: o.value == value ? color.brand : color.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: o.value == value ? color.brand : color.line),
                  ),
                  alignment: Alignment.center,
                  child: Text(o.label, style: Ty.custom(14, FontWeight.w600, c: o.value == value ? color.onBrand : color.ink)),
                ),
              ),
            ),
        ]),
      );
}

/// Chips from a plain list of value/label pairs.
List<({String value, String label})> opts(Iterable<(String, String)> pairs) => [for (final p in pairs) (value: p.$1, label: p.$2)];

/// An on/off switch in the school's colour.
class Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChange;
  final String label;
  const Toggle({super.key, required this.value, required this.onChange, required this.label});
  @override
  Widget build(BuildContext context) => Tap(
        label: label,
        scale: 0.94,
        onTap: () => onChange(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: value ? color.brand : color.line, borderRadius: BorderRadius.circular(12)),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))]),
            child: value ? Icn('checkmark', size: 13, tint: color.brand) : null,
          ),
        ),
      );
}

/// A row with a switch: what it does, a line of explanation, and the switch. The whole row can be tapped.
class CheckRow extends StatelessWidget {
  final String label;
  final String? hint, icon;
  final bool value;
  final ValueChanged<bool> onChange;
  const CheckRow({super.key, required this.label, this.hint, this.icon, required this.value, required this.onChange});
  @override
  Widget build(BuildContext context) => Tap(
        scale: 0.99,
        onTap: () => onChange(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              if (icon != null) ...[IconBadge(icon!, size: 32, tint: value ? color.brand : color.muted, bg: value ? color.tint : color.bg), const SizedBox(width: 10)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: Ty.body(w: FontWeight.w600)),
                  if (hint != null) Text(hint!, style: Ty.small()),
                ]),
              ),
              const SizedBox(width: 10),
              Toggle(value: value, onChange: onChange, label: label),
            ]),
          ),
        ),
      );
}
