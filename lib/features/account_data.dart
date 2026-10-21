import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../ui/ui.dart';

/// Ask for a copy of your data, or for it to be deleted, from inside the app. Parents file the request with the school; everyone else is taken to the page that reaches the platform.
class DataCard extends StatefulWidget {
  final String? workspace;
  final bool requests;
  const DataCard({super.key, required this.workspace, required this.requests});
  @override
  State<DataCard> createState() => _DataCardState();
}

class _DataCardState extends State<DataCard> {
  String? _ask;
  bool _busy = false;
  bool get _direct => widget.workspace == 'parent' && widget.requests;

  Future<void> _send(String kind) async {
    setState(() => _busy = true);
    try {
      await api('parent/data-requests', method: 'POST', body: {'kind': kind});
      notify.ok('Request received', 'The school will reply within 30 days.');
      if (mounted) setState(() => _ask = null);
    } catch (e) {
      notify.err('Could not send', e is ApiError ? e.message : null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ECard(title: 'Your data', icon: 'shield-checkmark-outline', children: [
        Muted(_direct ? 'Ask the school for a copy of the information it keeps about you and your children, or to delete it.' : 'To have your information deleted, ask your school office, or use the page below.'),
        if (_ask == null)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_direct) AppButton('Ask for a copy of my data', kind: BtnKind.soft, icon: 'download-outline', onPressed: () => setState(() => _ask = 'export')),
            if (_direct) const SizedBox(height: 8),
            AppButton('Delete my account and data', kind: BtnKind.plain, icon: 'trash-outline', onPressed: () {
              if (_direct) {
                setState(() => _ask = 'deletion');
              } else {
                launchUrl(Uri.parse('${rootUrl()}/data-deletion'), mode: LaunchMode.externalApplication);
              }
            }),
          ])
        else
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              _ask == 'deletion' ? 'Delete everything the school holds about you and your children? The school will check it is you and reply within 30 days.' : 'Send a request for a copy of your data? The school will reply within 30 days.',
              style: Ty.body(c: _ask == 'deletion' ? color.danger : color.ink, w: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            AppButton(_ask == 'deletion' ? 'Yes, send the deletion request' : 'Yes, send the request', kind: _ask == 'deletion' ? BtnKind.danger : BtnKind.primary, busy: _busy, onPressed: () => _send(_ask!)),
            const SizedBox(height: 8),
            AppButton('Cancel', kind: BtnKind.plain, onPressed: () => setState(() => _ask = null)),
          ]),
      ]);
}
