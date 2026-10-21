import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'net.dart';
import 'offline.dart';
import 'storage.dart';

/// The mobile app talks to the school's own address, so no school header is needed: the host picks the school.
class ApiError implements Exception {
  final int status;
  final String message;
  final Map<String, List<String>> errors;
  ApiError(this.status, this.message, [this.errors = const {}]);
  @override
  String toString() => message;
}

/// Every school lives at its own name under this address, e.g. greenfield.edu-core.ng.
const String rootDomain = String.fromEnvironment('ROOT_DOMAIN', defaultValue: 'edu-core.ng');

final RegExp _local = RegExp(r'^(localhost|127\.|10\.|192\.168\.)|\.localhost(:|$)');

/// "greenfield" becomes greenfield.edu-core.ng; a full address (a school's own domain, or a local test address) is kept as typed.
String normalizeAddress(String addr) {
  final a = addr.trim().toLowerCase().replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/+$'), '');
  return a.isNotEmpty && !RegExp(r'[.:]').hasMatch(a) ? '$a.$rootDomain' : a;
}

/// The address the phone talks to for the schools' sign-in list: the root address, not a school.
String rootUrl() => '${RegExp(r'^(localhost|127\.|10\.|192\.168\.)').hasMatch(rootDomain) ? 'http' : 'https'}://$rootDomain';

/// A school's address from the list, with the root address's port when testing locally.
String withRootPort(String host) {
  final port = RegExp(r':\d+$').firstMatch(rootDomain)?.group(0);
  return port != null && !RegExp(r':\d+$').hasMatch(host) ? host + port : host;
}

String _address = '';
String _token = '';
String _termId = '';

const _keyAddr = 'school_address';
const _keyToken = 'api_token';

String currentAddress() => _address;
bool get signedIn => _token.isNotEmpty;

/// The term the person chose to look at (empty means the current one). Sent with every request, so every screen follows it.
void setTermHeader(String? id) => _termId = id ?? '';

String baseUrl() => '${_local.hasMatch(_address) ? 'http' : 'https'}://$_address';

Future<bool> restore() async {
  _address = await Secure.get(_keyAddr) ?? '';
  _token = await Secure.get(_keyToken) ?? '';
  return _address.isNotEmpty && _token.isNotEmpty;
}

Future<void> saveSession(String addr, String token) async {
  _address = normalizeAddress(addr);
  _token = token;
  dropMemory();
  // Never show the last person's screens to the next one.
  unawaited(Store.removeAll([_snapKey(), _sessionKey()]));
  await Secure.set(_keyAddr, _address);
  await Secure.set(_keyToken, token);
}

Future<void> clearSession() async {
  _token = '';
  dropMemory();
  unawaited(Store.removeAll([_snapKey(), _sessionKey()]));
  await Secure.delete(_keyToken);
}

void setAddress(String addr) => _address = normalizeAddress(addr);

/// A request that never answers is worse than one that fails: after this long we give up and try again, so a screen never sits blank for ever.
const _timeout = Duration(seconds: 15);

Map<String, String> authHeaders() => {'X-Client': 'mobile', if (_token.isNotEmpty) 'Authorization': 'Bearer $_token', if (_termId.isNotEmpty) 'X-Term': _termId};

String _queryString(Map<String, String?>? q) =>
    (q ?? {}).entries.where((e) => e.value != null && e.value != '').map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value!)}').join('&');

/// The full address of an API path (for downloads).
String fileUrl(String path, [Map<String, String?>? query]) {
  final qs = _queryString(query);
  return '${baseUrl()}/api/$path${qs.isEmpty ? '' : '?$qs'}';
}

Future<http.Response> _send(String path, String method, dynamic body, String qs) {
  final uri = Uri.parse('${baseUrl()}/api/$path${qs.isEmpty ? '' : '?$qs'}');
  final headers = {'Accept': 'application/json', 'Content-Type': 'application/json', ...authHeaders()};
  final enc = body == null ? null : jsonEncode(body);
  final req = switch (method) {
    'POST' => http.post(uri, headers: headers, body: enc),
    'PUT' => http.put(uri, headers: headers, body: enc),
    'PATCH' => http.patch(uri, headers: headers, body: enc),
    'DELETE' => http.delete(uri, headers: headers, body: enc),
    _ => http.get(uri, headers: headers),
  };
  return req.timeout(_timeout);
}

/// Reading data is safe to repeat, so a dropped connection, a timeout or a busy server (502, 503, 504, 429) is tried once more after a short pause. Writes are sent once.
Future<http.Response> _sendWithRetry(String path, String method, dynamic body, String qs) async {
  final reads = method == 'GET';
  final tries = reads ? 2 : 1;
  for (var i = 1;; i++) {
    try {
      final res = await _send(path, method, body, qs);
      if (reads && i < tries && const [429, 502, 503, 504].contains(res.statusCode)) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        continue;
      }
      return res;
    } catch (e) {
      if (i >= tries) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }
}

class _Mem {
  final int at;
  final dynamic data;
  _Mem(this.at, this.data);
}

/// What this phone has already loaded in this session, so going back to a screen shows it at once while fresh data is fetched behind it.
final Map<String, _Mem> _memory = {};

/// The same read asked for twice at once (a screen and the warm-up) is sent once.
final Map<String, Future<dynamic>> _flying = {};
String _memKey(String path, String qs) => '$_address|$_termId|$path?$qs';

/// The copy of a screen's data already on the phone, if any.
dynamic peek(String path, [Map<String, String?>? query]) => _memory[_memKey(path, _queryString(query))]?.data;

void dropMemory() {
  _memory.clear();
  _flying.clear();
  _snapTimer?.cancel();
  _snapTimer = null;
}

/// How old the copy on the phone is, or null when there is none.
Duration? peekAge(String path, [Map<String, String?>? query]) {
  final m = _memory[_memKey(path, _queryString(query))];
  return m == null ? null : DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(m.at));
}

/// A copy loaded less than this long ago is shown as it is, without asking the school again.
const freshFor = Duration(seconds: 20);

/// The screens loaded last time are kept on the phone, so the app opens on them at once and refreshes them behind the scenes,
/// instead of showing a blank screen until the network answers. It is removed when the person signs out.
String _snapKey() => 'snap:$_address';
const _snapMax = 400000, _snapMaxOne = 120000;
Timer? _snapTimer;
void _scheduleSnapshot() {
  if (_snapTimer != null || _token.isEmpty) return;
  _snapTimer = Timer(const Duration(milliseconds: 1500), () async {
    _snapTimer = null;
    if (_token.isEmpty) return; // signed out in the meantime: nothing is kept
    try {
      final mine = _memory.entries.where((e) => e.key.startsWith('$_address|')).toList()..sort((a, b) => b.value.at.compareTo(a.value.at));
      final out = <String, dynamic>{};
      var size = 0;
      for (final e in mine) {
        final one = {'at': e.value.at, 'data': e.value.data};
        final n = jsonEncode(one).length;
        if (n > _snapMaxOne) continue;
        if (size + n > _snapMax) break;
        size += n;
        out[e.key] = one;
      }
      await Store.set(_snapKey(), jsonEncode(out));
    } catch (_) {/* storage full or not available: the app just starts the slower way */}
  });
}

/// The signed-in person's session (name, role, school settings) is kept too, so a cold start does not wait for the network to draw the first screen.
String _sessionKey() => 'session:$_address';
void rememberSession(dynamic s) {
  if (_token.isNotEmpty) unawaited(Store.set(_sessionKey(), jsonEncode(s)));
}

Future<dynamic> recallSession() async {
  try {
    final raw = await Store.get(_sessionKey());
    return raw == null ? null : jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

Future<void> loadSnapshot() async {
  try {
    final raw = await Store.get(_snapKey());
    if (raw == null) return;
    (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      _memory.putIfAbsent(k, () => _Mem(m['at'] as int, m['data']));
    });
  } catch (_) {/* nothing saved, or unreadable */}
}

/// Load the main screens of a role in the background, three at a time, so the tabs open instantly. Failures are ignored; the screen will ask again itself.
Future<void> warm(List<String> paths) async {
  final todo = paths.where((p) => (peekAge(p) ?? const Duration(days: 1)) > freshFor).toList();
  for (var i = 0; i < todo.length; i += 3) {
    await Future.wait(todo.skip(i).take(3).map((p) => api(p).then<dynamic>((v) => v).catchError((_) => null)));
  }
}

/// The last time a screen showed a saved copy instead of fresh data (null when the last load was live).
int? lastStaleAt;

Future<dynamic> api(String path, {String method = 'GET', Map<String, String?>? query, dynamic body}) {
  final qs = _queryString(query);
  if (method != 'GET') return _request(path, method, body, qs);
  final key = _memKey(path, qs);
  final running = _flying[key];
  if (running != null) return running;
  // The callback must not return the removed future: whenComplete would wait for it, which is this very request.
  final p = _request(path, method, body, qs).whenComplete(() {
    _flying.remove(key);
  });
  _flying[key] = p;
  return p;
}

dynamic _decode(http.Response res) {
  if (res.bodyBytes.isEmpty) return null;
  return jsonDecode(utf8.decode(res.bodyBytes));
}

Future<dynamic> _request(String path, String method, dynamic body, String qs) async {
  http.Response res;
  try {
    res = await _sendWithRetry(path, method, body, qs);
    Net.I.goOnline();
  } catch (_) {
    Net.I.goOffline();
    // No signal. With the offline feature on: show the saved copy, or keep the write for later.
    final off = Offline.I;
    if (method == 'GET' && off.enabled) {
      final saved = await off.cacheGet(path, qs.isEmpty ? '' : '?$qs');
      if (saved != null) {
        lastStaleAt = saved.at;
        return saved.data;
      }
    }
    if (off.canQueue(path, method)) {
      await off.enqueue(path, method, body);
      return {'ok': true, 'queued': true, 'message': 'Saved on this phone. It will be sent when you are back online.'};
    }
    throw ApiError(0, 'You seem to be offline. Check your connection and try again.');
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    dynamic data;
    try {
      data = _decode(res);
    } catch (_) {/* not JSON */}
    final errs = <String, List<String>>{};
    if (data is Map && data['errors'] is Map) {
      (data['errors'] as Map).forEach((k, v) => errs['$k'] = v is List ? v.map((e) => '$e').toList() : ['$v']);
    }
    throw ApiError(res.statusCode, data is Map && data['message'] is String ? data['message'] as String : 'That did not work. Please try again.', errs);
  }
  final out = res.statusCode == 204 ? null : _decode(res);
  if (method == 'GET') {
    lastStaleAt = null;
    _memory[_memKey(path, qs)] = _Mem(DateTime.now().millisecondsSinceEpoch, out);
    _scheduleSnapshot();
    unawaited(Offline.I.cachePut(path, qs.isEmpty ? '' : '?$qs', out));
    unawaited(syncOutbox());
  } else {
    // Something was changed, so what was loaded before may be out of date.
    _memory.clear();
    _scheduleSnapshot();
  }
  return out;
}

/// Send what was saved while offline. Called when a request succeeds, so it runs as soon as there is signal.
Future<int> syncOutbox() {
  return Offline.I.flush((q) async {
    try {
      final res = await _send(q.path, q.method, q.body, '');
      if (res.statusCode >= 200 && res.statusCode < 300) return Sent();
      var msg = 'The school did not accept it.';
      try {
        final d = _decode(res);
        if (d is Map && d['message'] is String) msg = d['message'] as String;
      } catch (_) {}
      if (res.statusCode >= 500 || res.statusCode == 429) return StillOffline();
      final when = DateTime.fromMillisecondsSinceEpoch(q.at);
      return Refused('${q.path.replaceFirst('teacher/', '')} saved offline on ${when.day}/${when.month}/${when.year} was not accepted: $msg');
    } catch (_) {
      return StillOffline();
    }
  });
}

/// Money is kept in kobo. "₦12,500" or "₦12,500.50".
String naira(num? kobo) {
  final k = (kobo ?? 0).round();
  final whole = k ~/ 100;
  final rem = (k % 100).abs();
  final digits = whole.abs().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${whole < 0 ? '-' : ''}₦$grouped${rem != 0 ? '.${rem.toString().padLeft(2, '0')}' : ''}';
}
