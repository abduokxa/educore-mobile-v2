import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'base.dart';

String _pad(int n) => n.toString().padLeft(2, '0');

/// The API takes and gives dates as dd/mm/yyyy.
DateTime? parseDate(String v) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(v.trim());
  if (m == null) return null;
  final d = DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  return d.month == int.parse(m[2]!) ? d : null;
}

String formatDate(DateTime d) => '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

/// "08/10/2026" from the date picker becomes the 2026-10-08 the server reads.
String isoDate(String v) {
  final d = parseDate(v);
  return d == null ? v : '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
}

/// A field that opens the phone's calendar.
class DateField extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChange;
  final String? min;
  const DateField({super.key, required this.label, required this.value, required this.onChange, this.min});

  @override
  Widget build(BuildContext context) {
    final current = parseDate(value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Ty.small(w: FontWeight.w600)),
      const SizedBox(height: 6),
      Tap(
        label: label,
        scale: 0.99,
        onTap: () async {
          final first = parseDate(min ?? '') ?? DateTime(2000);
          final now = DateTime.now();
          final start = current ?? (now.isBefore(first) ? first : now);
          final picked = await showDatePicker(
            context: context,
            initialDate: start.isBefore(first) ? first : start,
            firstDate: first,
            lastDate: DateTime(2100),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: color.brand, brightness: isDark() ? Brightness.dark : Brightness.light).copyWith(primary: color.brand, onPrimary: color.onBrand)),
              child: child!,
            ),
          );
          if (picked != null) onChange(formatDate(picked));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.line)),
          child: Row(children: [
            Icn('calendar-outline', size: 19, tint: color.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(value.isEmpty ? 'Choose a date' : value, style: Ty.custom(16, FontWeight.w500, c: value.isEmpty ? color.muted : color.ink))),
            Icn('chevron-down', size: 18, tint: color.muted),
          ]),
        ),
      ),
    ]);
  }
}
