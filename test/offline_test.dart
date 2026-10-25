import 'dart:convert';
import 'dart:io';
import 'package:educore/core/api.dart';
import 'package:educore/core/docstore.dart';
import 'package:educore/core/offline.dart';
import 'package:educore/core/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Store.forget();
    FlutterSecureStorage.setMockInitialValues({});
    Vault.forget();
    setAddress('greenfield.edu-core.ng');
    dropMemory();
    tmp = await Directory.systemTemp.createTemp('educore-offline');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => tmp.path);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
    Offline.I.setEnabled(false, '');
  });

  test('what the phone keeps is sealed: the saved value is not readable, and reads back the same', () async {
    await Store.set('snap', jsonEncode({'child': 'Amina Bello', 'owes': 5250000}));
    final raw = (await SharedPreferences.getInstance()).getString('snap')!;
    expect(raw.startsWith('enc1:'), isTrue);
    expect(raw.contains('Amina'), isFalse);
    expect(jsonDecode((await Store.get('snap'))!)['child'], 'Amina Bello');
  });

  test('a value saved before sealing existed is still read, and a sealed value that cannot be opened reads as nothing', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('old', 'plain text');
    await prefs.setString('bad', 'enc1:AAAA');
    expect(await Store.get('old'), 'plain text');
    expect(await Store.get('bad'), isNull);
  });

  test('two different payments saved offline are both kept; the same payment saved again replaces itself', () async {
    final off = Offline.I..setEnabled(true, 'greenfield.edu-core.ng');
    await saveSession('greenfield.edu-core.ng', 'tok');
    await http.runWithClient(() async {
      Map body(String key, String amount) => {'client_key': key, 'invoice': 'INV1', 'amount': amount, 'method': 'cash', 'paid_on': '25/10/2026', 'received_from': 'x'};
      final a = await api('payments', method: 'POST', body: body('k1', '20000'), label: '₦20,000 from Mr Okoro for Amina');
      expect(a['queued'], true);
      await api('payments', method: 'POST', body: body('k2', '5000'), label: '₦5,000 from Mrs Bello for Musa');
      await api('payments', method: 'POST', body: body('k1', '20000'), label: '₦20,000 from Mr Okoro for Amina');
      final waiting = await off.waiting('payments');
      expect(waiting.length, 2);
      final okoro = waiting.firstWhere((q) => q.label!.contains('Okoro'));
      await off.discard(okoro.id);
      expect((await off.waiting('payments')).single.body['client_key'], 'k2');
    }, () => MockClient((req) async => throw http.ClientException('no signal')));
  });

  test('saved payments are sent with their key when the signal is back; the school refusing one is reported by name and does not block the rest', () async {
    final off = Offline.I..setEnabled(true, 'greenfield.edu-core.ng');
    await saveSession('greenfield.edu-core.ng', 'tok');
    await http.runWithClient(() async {
      await api('payments', method: 'POST', body: {'client_key': 'k1', 'invoice': 'A', 'amount': '100'}, label: '₦100 from X for Ada');
      await api('payments', method: 'POST', body: {'client_key': 'k2', 'invoice': 'B', 'amount': '900'}, label: '₦900 from Y for Bola');
      await api('payments', method: 'POST', body: {'client_key': 'k3', 'invoice': 'C', 'amount': '50'}, label: '₦50 from Z for Chi');
    }, () => MockClient((req) async => throw http.ClientException('no signal')));
    final seen = <Map>[];
    await http.runWithClient(() async {
      expect(await syncOutbox(), 2);
      expect(await off.pending(), 0);
    }, () => MockClient((req) async {
          final b = jsonDecode(req.body) as Map;
          seen.add(b);
          return b['client_key'] == 'k2'
              ? http.Response(jsonEncode({'message': 'The amount must be no more than the balance of ₦500.'}), 422, headers: {'content-type': 'application/json'})
              : http.Response(jsonEncode({'id': 'p'}), 201, headers: {'content-type': 'application/json'});
        }));
    expect(seen.map((b) => b['client_key']), ['k1', 'k2', 'k3']);
    final notes = await off.takeNotes();
    expect(notes.single, allOf(contains('₦900 from Y for Bola'), contains('no more than the balance')));
  });

  test('a document is kept sealed, opens again with no signal, and is gone when the person signs out', () async {
    Offline.I.setEnabled(true, 'greenfield.edu-core.ng');
    final pdf = utf8.encode('%PDF-1.4 receipt RCP-2610-0024 for Amina Bello');
    await DocStore.save('parent/receipts/abc', const {}, pdf, 'receipt-RCP-2610-0024');
    final onDisk = Directory('${tmp.path}/saved-docs').listSync().whereType<File>().single.readAsBytesSync();
    expect(utf8.decode(onDisk, allowMalformed: true).contains('Amina'), isFalse);
    final opened = await DocStore.find('parent/receipts/abc', const {}, 'receipt-RCP-2610-0024');
    expect(opened, isNotNull);
    expect(utf8.decode(opened!.readAsBytesSync()), contains('RCP-2610-0024'));
    expect((await DocStore.summary()).count, 1);
    expect(await DocStore.find('parent/receipts/other', const {}, 'x'), isNull);
    await DocStore.clear();
    expect((await DocStore.summary()).count, 0);
    expect(await DocStore.find('parent/receipts/abc', const {}, 'x'), isNull);
  });

  test('documents are only kept for a school that has the offline feature on, and the oldest go first when there are too many', () async {
    await DocStore.save('a', const {}, [1, 2, 3], 'a');
    expect((await DocStore.summary()).count, 0);
    Offline.I.setEnabled(true, 'greenfield.edu-core.ng');
    for (var i = 0; i < 225; i++) {
      await DocStore.save('doc/$i', const {}, [i % 250], 'd$i');
    }
    expect((await DocStore.summary()).count, 220);
    expect(await DocStore.has('doc/0', const {}), isFalse);
    expect(await DocStore.has('doc/224', const {}), isTrue);
  });

  test('signing out removes the saved screens and anything not yet sent', () async {
    final off = Offline.I..setEnabled(true, 'greenfield.edu-core.ng');
    await saveSession('greenfield.edu-core.ng', 'tok');
    await http.runWithClient(() async => api('parent/fees'), () => MockClient((req) async => http.Response(jsonEncode({'totals': {'balance': 100}}), 200, headers: {'content-type': 'application/json'})));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await http.runWithClient(() async => api('payments', method: 'POST', body: {'client_key': 'k', 'invoice': 'I'}), () => MockClient((req) async => throw http.ClientException('no signal')));
    expect(await off.pending(), 1);
    await off.wipe();
    expect(await off.pending(), 0);
    expect(await off.cacheGet('parent/fees', ''), isNull);
  });
}
