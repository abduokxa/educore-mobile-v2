import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../ui/ui.dart';

class VersionRules {
  final String min, latest, storeUrl;
  VersionRules(this.min, this.latest, this.storeUrl);
}

Future<String> appVersion() async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    return '0.0.0';
  }
}

/// -1 when a is older than b, 0 when equal, 1 when newer. Missing parts count as 0, so 1.2 equals 1.2.0.
int compareVersions(String a, String b) {
  final x = a.split('.').map((n) => int.tryParse(n) ?? 0).toList();
  final y = b.split('.').map((n) => int.tryParse(n) ?? 0).toList();
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d < 0 ? -1 : 1;
  }
  return 0;
}

/// Ask the platform whether this build is too old (must update) or simply not the newest (offer it). Silent when the platform cannot be reached.
Future<VersionRules?> fetchRules() async {
  try {
    final res = await http.get(Uri.parse('${rootUrl()}/api/app/version'), headers: {'Accept': 'application/json', 'X-Client': 'mobile'}).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return VersionRules('${j['min'] ?? ''}', '${j['latest'] ?? ''}', '${j['store_url'] ?? ''}');
  } catch (_) {
    return null;
  }
}

enum UpdateState { required, available, current }

UpdateState updateState(VersionRules? rules, String version) {
  if (rules == null) return UpdateState.current;
  if (rules.min.isNotEmpty && compareVersions(version, rules.min) < 0) return UpdateState.required;
  if (rules.latest.isNotEmpty && compareVersions(version, rules.latest) < 0) return UpdateState.available;
  return UpdateState.current;
}

/// Checks the version rules when the app opens and each time it comes back after a while.
class UpdateWatcher extends ChangeNotifier with WidgetsBindingObserver {
  UpdateState state = UpdateState.current;
  String url = '';
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    Future<void>.delayed(const Duration(milliseconds: 2500), check); // after the first screen has had the network to itself
  }

  Future<void> check() async {
    if (DateTime.now().difference(_last) < const Duration(minutes: 30)) return;
    _last = DateTime.now();
    final r = await fetchRules();
    if (r == null) return;
    state = updateState(r, await appVersion());
    url = r.storeUrl;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = state;
    if (s == AppLifecycleState.resumed) check();
  }
}

Future<void> _open(String url) async {
  if (url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Shown instead of the app when this version is too old to work.
class UpdateRequired extends StatelessWidget {
  final String url;
  const UpdateRequired({super.key, required this.url});
  @override
  Widget build(BuildContext context) => Container(
        color: color.bg,
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Pop(child: Container(width: 96, height: 96, decoration: BoxDecoration(color: color.tint, shape: BoxShape.circle), child: Icn('cloud-download-outline', size: 46, tint: color.brand))),
              const SizedBox(height: 18),
              Text('Please update Educore', textAlign: TextAlign.center, style: Ty.display()),
              const SizedBox(height: 10),
              Text('This version is too old to work with your school any more. It takes a minute, and your information is safe.', textAlign: TextAlign.center, style: Ty.body(c: color.muted)),
              const SizedBox(height: 18),
              AppButton('Update now', icon: 'arrow-up-circle-outline', onPressed: () => _open(url)),
            ]),
          ),
        ),
      );
}

/// A quiet line when a newer version exists. It can be dismissed until the app is opened again.
class UpdateNotice extends StatefulWidget {
  final String url;
  const UpdateNotice({super.key, required this.url});
  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> {
  bool _hide = false;
  @override
  Widget build(BuildContext context) {
    if (_hide) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(color: color.ink, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icn('cloud-download-outline', size: 20, tint: color.card),
        const SizedBox(width: 10),
        Expanded(child: Text('A new version of Educore is ready.', style: Ty.custom(13, FontWeight.w700, c: color.card))),
        Tap(label: 'Update', onTap: () => _open(widget.url), child: Text('Update', style: Ty.custom(13, FontWeight.w800, c: color.card).copyWith(decoration: TextDecoration.underline))),
        const SizedBox(width: 12),
        Tap(label: 'Dismiss', onTap: () => setState(() => _hide = true), child: Icn('close', size: 18, tint: color.card)),
      ]),
    );
  }
}
