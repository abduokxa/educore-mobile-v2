import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ui/ui.dart';

final RegExp _url = RegExp(r'''(https?://[^\s<]*[^\s<.,;:!?)\]}'"])''');

/// Copy something to the clipboard and say so.
Future<void> copyText(String value, String what) async {
  try {
    await Clipboard.setData(ClipboardData(text: value));
    notify.ok('$what copied');
  } catch (_) {
    notify.err('Could not copy');
  }
}

class _Chip extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _Chip(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => Tap(
        label: label,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.tint, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icn(icon, size: 16, tint: color.brand),
            const SizedBox(width: 6),
            Text(label, style: Ty.custom(13, FontWeight.w800, c: color.brand)),
          ]),
        ),
      );
}

Future<void> openLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    notify.err('Could not open the link');
  }
}

/// Message text where web addresses can be tapped, with buttons to open or copy each link and to copy a code.
class RichText2 extends StatelessWidget {
  final String text;
  final int? maxLines;
  final bool muted;
  const RichText2(this.text, {super.key, this.maxLines, this.muted = false});
  @override
  Widget build(BuildContext context) {
    final links = _url.allMatches(text).map((m) => m.group(0)!).toSet().take(3).toList();
    final code = RegExp('code', caseSensitive: false).hasMatch(text) ? RegExp(r'(?<!\d)(\d{6})(?!\d)').firstMatch(text)?.group(1) : null;
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _url.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      final u = m.group(0)!;
      spans.add(TextSpan(text: u, style: TextStyle(color: color.brand, decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () => openLink(u)));
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: spans), maxLines: maxLines, overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis, style: Ty.body(c: muted ? color.muted : color.ink)),
      if (maxLines == null && (links.isNotEmpty || code != null))
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            if (code != null) _Chip('copy-outline', 'Copy code $code', () => copyText(code, 'Code')),
            for (final l in links) ...[_Chip('open-outline', 'Open link', () => openLink(l)), _Chip('copy-outline', 'Copy link', () => copyText(l, 'Link'))],
          ]),
        ),
    ]);
  }
}
