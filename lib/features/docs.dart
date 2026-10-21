import 'package:flutter/material.dart';
import '../ui/ui.dart';
import 'files.dart';
import 'pdf_view.dart';

/// Two ways to get a document the school made: look at it now, or save and share it. The files are the same PDFs as on the website.
class DocActions extends StatefulWidget {
  final String path, name;
  final Map<String, String?> query;
  final String? label;
  final String view, save;
  const DocActions({super.key, required this.path, this.query = const {}, required this.name, this.label, this.view = 'View', this.save = 'Download'});
  @override
  State<DocActions> createState() => _DocActionsState();
}

class _DocActionsState extends State<DocActions> {
  String? _busy;

  Future<void> _run(String kind) async {
    setState(() => _busy = kind);
    try {
      await (kind == 'view' ? (String p, Map<String, String?> q, String n) => previewDocument(p, q, n, title: widget.label ?? n) : saveDocument)(widget.path, widget.query, widget.name);
    } catch (e) {
      notify.err('Could not open the file', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icn('document-text-outline', size: 16, tint: color.muted),
              const SizedBox(width: 6),
              Flexible(child: Text(widget.label!, style: Ty.small(w: FontWeight.w600))),
            ]),
          ),
        Row(children: [
          Expanded(child: AppButton(widget.view, icon: 'eye-outline', busy: _busy == 'view', disabled: _busy == 'save', onPressed: () => _run('view'))),
          const SizedBox(width: 10),
          Expanded(child: AppButton(widget.save, icon: 'download-outline', kind: BtnKind.soft, busy: _busy == 'save', disabled: _busy == 'view', onPressed: () => _run('save'))),
        ]),
      ]);
}
