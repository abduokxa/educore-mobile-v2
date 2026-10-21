import 'dart:convert';
import 'package:educore/core/api.dart';
import 'package:educore/core/offline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<http.Request> sent;

  Future<T> withServer<T>(Future<T> Function() body, http.Response Function(http.Request) answer) {
    sent = [];
    return http.runWithClient(body, () => MockClient((req) async {
          sent.add(req);
          return answer(req);
        }));
  }

  http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    setAddress('greenfield.edu-core.ng');
    dropMemory();
  });

  test('a read comes back, carries the sign-in and the chosen term, and is kept for the next screen', () async {
    await withServer(() async {
      await saveSession('greenfield.edu-core.ng', 'tok123');
      setTermHeader('TERM9');
      final d = await api('parent/home');
      expect(d['greeting'], 'Hello');
      expect(peek('parent/home')['greeting'], 'Hello');
      expect(peekAge('parent/home')! < const Duration(seconds: 2), isTrue);
    }, (req) => json({'greeting': 'Hello'}));
    expect(sent.single.url.toString(), 'https://greenfield.edu-core.ng/api/parent/home');
    expect(sent.single.headers['Authorization'], 'Bearer tok123');
    expect(sent.single.headers['X-Term'], 'TERM9');
    expect(sent.single.headers['X-Client'], 'mobile');
    setTermHeader(null);
  });

  test('the same read asked twice at once is sent once, and a finished read is not stuck waiting on itself', () async {
    await withServer(() async {
      final both = await Future.wait([api('inbox'), api('inbox')]).timeout(const Duration(seconds: 5));
      expect(both[0]['unread'], 2);
      expect(both[1]['unread'], 2);
      // After it finished, asking again sends a new request.
      await api('inbox').timeout(const Duration(seconds: 5));
    }, (req) => json({'unread': 2}));
    expect(sent.length, 2);
  });

  test('a refusal carries the school\'s message and the fields it complained about', () async {
    await withServer(() async {
      try {
        await api('auth/login', method: 'POST', body: {'login': 'x'});
        fail('expected an ApiError');
      } on ApiError catch (e) {
        expect(e.status, 422);
        expect(e.message, 'Check the details');
        expect(e.errors['login'], ['Wrong login']);
      }
    }, (req) => json({'message': 'Check the details', 'errors': {'login': ['Wrong login']}}, 422));
  });

  test('a read that fails for lack of signal is tried once more, a write is not', () async {
    var calls = 0;
    await withServer(() async {
      expect((await api('terms'))['ok'], true);
    }, (req) => ++calls == 1 ? http.Response('busy', 503) : json({'ok': true}));
    expect(sent.length, 2);

    sent = [];
    await http.runWithClient(() async {
      await expectLater(api('devices', method: 'POST', body: {}), throwsA(isA<ApiError>()));
    }, () => MockClient((req) async {
          sent.add(req);
          return http.Response('busy', 503);
        }));
    expect(sent.length, 1);
  });

  test('with weak-network support on, a register saved offline waits in the outbox and is sent later', () async {
    final off = Offline.I;
    off.setEnabled(true, 'greenfield.edu-core.ng');
    await saveSession('greenfield.edu-core.ng', 'tok');
    // No signal at all: the request throws.
    await http.runWithClient(() async {
      final r = await api('teacher/register', method: 'POST', body: {'class': 'C1', 'date': '2026-10-21', 'marks': {'s1': 'present'}});
      expect(r['queued'], true);
      expect(await off.pending(), 1);
      // Saving the same register again replaces the first copy.
      await api('teacher/register', method: 'POST', body: {'class': 'C1', 'date': '2026-10-21', 'marks': {'s1': 'absent'}});
      expect(await off.pending(), 1);
    }, () => MockClient((req) async => throw http.ClientException('no signal')));
    // Back online: the outbox is sent.
    await withServer(() async {
      expect(await syncOutbox(), 1);
      expect(await off.pending(), 0);
    }, (req) => json({'ok': true}));
    expect(jsonDecode(sent.single.body)['marks']['s1'], 'absent');
    off.setEnabled(false, '');
  });

  test('a saved screen is read back when the phone has no signal', () async {
    final off = Offline.I;
    off.setEnabled(true, 'greenfield.edu-core.ng');
    await saveSession('greenfield.edu-core.ng', 'tok');
    await withServer(() async => api('parent/fees'), (req) => json({'totals': {'balance': 100}}));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    dropMemory();
    await http.runWithClient(() async {
      final d = await api('parent/fees');
      expect(d['totals']['balance'], 100);
      expect(lastStaleAt, isNotNull);
    }, () => MockClient((req) async => throw http.ClientException('no signal')));
    off.setEnabled(false, '');
  });
}
