import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import '../ui/ui.dart';
import 'files.dart';

/// Shows a school document (report card, bill, receipt, payslip) inside the app, so it can be read at once.
/// The bar underneath saves or shares it.
Future<void> previewDocument(String path, Map<String, String?> query, String name, {String? title}) async {
  final nav = navigatorKey.currentState;
  if (nav == null || kIsWeb) return viewDocument(path, query, name);
  unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => PdfPreview(path: path, query: query, name: name, title: title ?? name))));
}

class PdfPreview extends StatefulWidget {
  final String path, name, title;
  final Map<String, String?> query;
  const PdfPreview({super.key, required this.path, required this.query, required this.name, required this.title});
  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  late Future<File> _file;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _file = fetchDocument(widget.path, widget.query, widget.name);
  }

  void _retry() => setState(() => _file = fetchDocument(widget.path, widget.query, widget.name));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await saveDocument(widget.path, widget.query, widget.name);
    } catch (e) {
      notify.err('Could not save the file', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: color.bg,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
              child: Row(children: [
                Tap(label: 'Close', onTap: () => Navigator.of(context).maybePop(), child: Padding(padding: const EdgeInsets.all(10), child: Icn('arrow-back', size: 24, tint: color.ink))),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ty.h3())),
              ]),
            ),
            Expanded(
              child: FutureBuilder<File>(
                future: _file,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icn('document-text-outline', size: 40, tint: color.muted),
                          const SizedBox(height: 12),
                          Text(snap.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center, style: Ty.body(c: color.muted)),
                          const SizedBox(height: 16),
                          AppButton('Try again', icon: 'refresh', kind: BtnKind.soft, onPressed: _retry),
                        ]),
                      ),
                    );
                  }
                  if (!snap.hasData) return const Center(child: Spinner(size: 28));
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: color.line)),
                    clipBehavior: Clip.antiAlias,
                    child: PdfViewer.file(snap.data!.path, params: PdfViewerParams(backgroundColor: color.line)),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: AppButton('Download or share', icon: 'download-outline', busy: _saving, onPressed: _save),
            ),
          ]),
        ),
      );
}
