import 'package:flutter/material.dart';
import '../core/docstore.dart';
import '../core/net.dart';
import '../core/offline.dart';
import '../core/prefetch.dart';
import '../ui/ui.dart';

/// On the Profile screen: what the phone has saved for use with no signal, how fresh it is, and a button to refresh it now.
class OfflineCard extends StatefulWidget {
  final String? workspace;
  const OfflineCard({super.key, this.workspace});
  @override
  State<OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends State<OfflineCard> {
  DateTime? _last;
  ({int count, int bytes, DateTime? last})? _docs;
  int _waiting = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Offline.I.addListener(_read);
    Prefetch.last.addListener(_read);
    _read();
  }

  @override
  void dispose() {
    Offline.I.removeListener(_read);
    Prefetch.last.removeListener(_read);
    super.dispose();
  }

  Future<void> _read() async {
    final l = await Prefetch.lastRun();
    final d = await DocStore.summary();
    final w = await Offline.I.pending();
    if (mounted) {
      setState(() {
        _last = l;
        _docs = d;
        _waiting = w;
      });
    }
  }

  Future<void> _now() async {
    final ws = widget.workspace;
    if (ws == null) return;
    setState(() => _busy = true);
    try {
      await Prefetch.run(role: ws, force: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _read();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Offline.I.enabled) return const SizedBox.shrink();
    final docs = _docs;
    final mb = docs == null ? 0.0 : docs.bytes / (1024 * 1024);
    return ECard(title: 'Available offline', icon: 'cloud-download-outline', children: [
      Muted(_last == null
          ? 'Your screens${Offline.I.docs ? ' and documents' : ''} are being saved on this phone in the background, so they open with no signal.'
          : 'Saved ${ago(_last!)}.${Offline.I.docs ? ' Receipts, bills and report cards open with no signal.' : ''}${Offline.I.background ? ' This refreshes by itself whenever there is a connection, even if the app is closed.' : ' It refreshes whenever you open the app with a connection.'}'),
      if (docs != null && docs.count > 0) Muted('${docs.count} documents · ${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB, kept private on this phone.'),
      if (_waiting > 0) Muted('$_waiting saved on this phone, waiting to be sent. ${Offline.I.background ? 'They are sent as soon as there is a connection, even if the app is closed.' : 'They are sent when you open the app with a connection.'}'),
      if (widget.workspace != null) AppButton('Update now', kind: BtnKind.soft, icon: 'refresh', busy: _busy, disabled: !Net.I.online, onPressed: _now),
    ]);
  }
}
