import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../core/api.dart';
import '../ui/ui.dart';


/// Tell the person how the payment ended.
Future<void> _report(BuildContext context, Map<String, dynamic>? st) {
  if (st?['state'] == 'successful') {
    final receipt = st?['receipt'];
    return alertBox(context, 'Payment received', '${naira(st?['amount'] as num?)} paid for ${st?['child']}.${receipt != null ? ' Receipt $receipt.' : ''} The balance is now ${naira(st?['balance'] as num?)}.');
  }
  if (st?['state'] == 'failed') {
    return alertBox(context, 'Payment not completed', 'The payment did not go through, and nothing was taken from you. You can try again.');
  }
  return alertBox(context, 'Waiting for confirmation', 'We have not heard back from the payment company yet. If you paid, your balance updates as soon as it is confirmed. Pull down on the Fees screen to check again.');
}

/// Paying a child's bill: add optional other payments, then pay everything this term, only the milestones you choose
/// (one, several or all), or every term of the year together, as far as the school allows.
Future<void> showPaySheet(BuildContext context, String invoice, Future<void> Function() onChanged) {
  final root = Navigator.of(context, rootNavigator: true).context;
  return showAppSheet<void>(context, title: 'Payment', tall: true, builder: (_) => _PayBody(invoice: invoice, onChanged: onChanged, root: root));
}

enum _Mode { full, pick, year }

class _PayBody extends StatefulWidget {
  final String invoice;
  final Future<void> Function() onChanged;
  final BuildContext root;
  const _PayBody({required this.invoice, required this.onChanged, required this.root});
  @override
  State<_PayBody> createState() => _PayBodyState();
}

class _PayBodyState extends State<_PayBody> {
  dynamic _d;
  String? _error;
  _Mode? _mode;
  final List<int> _picked = [];
  final List<String> _extras = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await api('parent/pay', query: {'invoice': widget.invoice});
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? e.message : 'Could not load the payment options.');
    }
  }

  Future<void> _addExtras() async {
    setState(() => _busy = true);
    try {
      await api('parent/extras', method: 'POST', body: {'invoice': _d['invoice']['id'], 'items': _extras});
      _extras.clear();
      _picked.clear();
      await _load();
      await widget.onChanged();
    } catch (e) {
      if (mounted) await alertBox(context, 'Could not add that', e is ApiError ? e.message : null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takeOff(String item) async {
    setState(() => _busy = true);
    try {
      await api('parent/extras', method: 'DELETE', body: {'invoice': _d['invoice']['id'], 'item': item});
      _picked.clear();
      await _load();
      await widget.onChanged();
    } catch (e) {
      if (mounted) await alertBox(context, 'Could not take that off', e is ApiError ? e.message : null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(_Mode choice) async {
    setState(() => _busy = true);
    try {
      final body = choice == _Mode.year ? {'plan': 'year'} : choice == _Mode.pick ? {'plan': 'schedules', 'schedules': _picked} : {'plan': 'full'};
      final r = await api('parent/pay', method: 'POST', body: {'invoice': _d['invoice']['id'], 'method': 'card', 'app': true, ...body});
      // The payment page opens on the web. When it finishes it sends the person back here (educore://payment), and the browser closes by itself.
      try {
        await FlutterWebAuth2.authenticate(url: '${r['checkout_url']}', callbackUrlScheme: 'educore');
      } on PlatformException {/* the person closed the page: we still ask the school how it went */}
      // The link back only says the page finished. What really happened is asked of the school, which asks the payment company.
      Map<String, dynamic>? st;
      if (r['reference'] != null) {
        try {
          st = Map<String, dynamic>.from(await api('parent/pay/status', query: {'reference': '${r['reference']}'}) as Map);
        } catch (_) {}
      }
      await widget.onChanged();
      if (mounted) Navigator.pop(context);
      if (widget.root.mounted) await _report(widget.root, st);
    } catch (e) {
      if (mounted) await alertBox(context, 'Could not start the payment', e is ApiError ? e.message : null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return Padding(padding: const EdgeInsets.all(24), child: Center(child: _error != null ? Muted(_error!) : const Spinner(size: 22)));
    }
    final open = (d['schedules'] as List).where((s) => (s['balance'] as num) > 0).toList();
    final yearOnly = d['period'] == 'year';
    final choice = _mode ?? (yearOnly ? _Mode.year : _Mode.full);
    final online = d['online'] == true;
    final year = d['year'];
    final amount = choice == _Mode.year
        ? ((year?['total'] as num?) ?? 0)
        : choice == _Mode.pick
            ? open.where((s) => _picked.contains(s['key'])).fold<num>(0, (n, s) => n + (s['balance'] as num))
            : d['invoice']['balance'] as num;
    final canPay = online && amount > 0 && (choice != _Mode.pick || _picked.isNotEmpty) && (choice != _Mode.year || year != null);
    final first = d['student']['first_name'];
    final optional = d['optional'] as List;
    final modes = <({_Mode value, String label})>[
      if (!yearOnly) (value: _Mode.full, label: 'This term'),
      if (!yearOnly && d['milestones'] == true && open.isNotEmpty) (value: _Mode.pick, label: 'Choose'),
      if (d['period'] != 'term' && year != null) (value: _Mode.year, label: 'Whole year'),
    ];
    return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
      Text('Pay for $first', style: Ty.h3(size: 18)),
      const SizedBox(height: 14),
      if (!online) const Padding(padding: EdgeInsets.only(bottom: 14), child: Muted('Online payment is not available. Please pay at the school bursary.')),
      if (optional.isNotEmpty) ...[
        Text('Other payments', style: Ty.h3()),
        const SizedBox(height: 4),
        Muted("Optional. Choose the ones you want and they are added to $first's bill."),
        const SizedBox(height: 6),
        for (final o in optional)
          o['added'] == true
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text('${o['name']} · ${naira(o['amount'] as num)}', style: Ty.body(w: FontWeight.w600))),
                    const Pill('On the bill', toneName: 'green'),
                    const SizedBox(width: 6),
                    SizedBox(width: 110, child: AppButton('Take off', kind: BtnKind.plain, disabled: _busy, onPressed: () => _takeOff('${o['id']}'))),
                  ]),
                )
              : CheckRow(
                  label: '${o['name']} · ${naira(o['amount'] as num)}',
                  hint: o['note'] as String?,
                  value: _extras.contains(o['id']),
                  onChange: (v) => setState(() => v ? _extras.add('${o['id']}') : _extras.remove(o['id'])),
                ),
        if (_extras.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: AppButton('Add ${_extras.length == 1 ? 'this' : 'these ${_extras.length}'} to the bill', icon: 'add-circle-outline', kind: BtnKind.soft, busy: _busy, onPressed: _addExtras)),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Rule()),
      ],
      Text('What do you want to pay?', style: Ty.h3()),
      const SizedBox(height: 8),
      if (modes.length > 1) Chips<_Mode>(value: choice, onChange: (m) => setState(() => _mode = m), options: modes),
      const SizedBox(height: 8),
      if (choice == _Mode.full) Muted('Everything owing this term: ${naira(d['invoice']['balance'] as num)}.'),
      if (choice == _Mode.pick) ...[
        const Muted('Pay one payment, several, or all of them.'),
        for (final s in open)
          CheckRow(
            label: '${s['name']} · ${naira(s['balance'] as num)}',
            hint: 'Due ${s['due']}${(s['paid'] as num) > 0 ? ' · ${naira(s['paid'] as num)} paid' : ''} · ${s['status']}',
            value: _picked.contains(s['key']),
            onChange: (v) => setState(() => v ? _picked.add(s['key'] as int) : _picked.remove(s['key'])),
          ),
      ],
      if (choice == _Mode.year && year != null) Muted('${(year['bills'] as List).map((b) => '${b['term']} ${naira(b['balance'] as num)}').join(' · ')}. One payment, and a receipt for each term.'),
      if (yearOnly && year == null) const Muted('There is nothing left to pay on this bill.'),
      const SizedBox(height: 16),
      AppButton(amount > 0 ? 'Pay ${naira(amount)}' : 'Pay', icon: 'card-outline', disabled: !canPay, busy: _busy, onPressed: () => _pay(choice)),
      const SizedBox(height: 10),
      Text('You will go to a secure payment page.', textAlign: TextAlign.center, style: Ty.small()),
    ]);
  }
}
