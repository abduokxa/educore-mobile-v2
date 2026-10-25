import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/docstore.dart';

/// The file names we save under: letters, numbers, dots and dashes only.
String safeName(String name) {
  final s = name.replaceAll(RegExp(r'[^\w.-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'document' : s;
}

String _refusal(List<int> body) {
  try {
    final m = jsonDecode(utf8.decode(body));
    if (m is Map && m['message'] is String) return m['message'] as String;
  } catch (_) {}
  return 'The school could not make that file.';
}

class _Refused implements Exception {
  final String message;
  _Refused(this.message);
  @override
  String toString() => message;
}

/// Receipts never change once made, so the saved copy is opened at once; everything else is fetched fresh when there is a connection.
bool _steady(String path) => RegExp(r'receipt').hasMatch(path);

/// Downloads a document (with the person's sign-in) and returns where it is on the phone. With no connection, or when the school cannot be reached,
/// the copy saved earlier is used. Every document fetched is kept for next time.
Future<File> fetchDocument(String path, Map<String, String?> query, String name, {String ext = 'pdf'}) async {
  if (ext == 'pdf' && _steady(path)) {
    final saved = await DocStore.find(path, query, name);
    if (saved != null) return saved;
  }
  try {
    final res = await http.get(Uri.parse(fileUrl(path, query)), headers: authHeaders()).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw _Refused(_refusal(res.bodyBytes));
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${safeName(name)}.$ext');
    await f.writeAsBytes(res.bodyBytes, flush: true);
    if (ext == 'pdf') await DocStore.save(path, query, res.bodyBytes, name);
    return f;
  } on _Refused catch (e) {
    throw Exception(e.message);
  } catch (e) {
    final saved = ext == 'pdf' ? await DocStore.find(path, query, name) : null;
    if (saved != null) return saved;
    throw Exception('You seem to be offline, and this document is not saved on the phone yet. Open it once with a connection.');
  }
}

/// Opens a PDF in the phone's own PDF viewer, or offers it to other apps when there is none.
Future<void> viewDocument(String path, Map<String, String?> query, String name) async {
  if (kIsWeb) {
    await launchUrl(Uri.parse(fileUrl(path, query)));
    return;
  }
  final f = await fetchDocument(path, query, name);
  final r = await OpenFilex.open(f.path, type: 'application/pdf');
  if (r.type != ResultType.done) {
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/pdf')], title: name));
  }
}

/// Saves or shares a PDF: Save to Files or Drive, WhatsApp, e-mail, print.
Future<void> saveDocument(String path, Map<String, String?> query, String name) async {
  final f = await fetchDocument(path, query, name);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/pdf')], title: name));
}
