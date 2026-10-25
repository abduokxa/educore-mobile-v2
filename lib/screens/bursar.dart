import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/net.dart';
import '../features/docs.dart';
import '../shell/nav.dart';
import '../ui/ui.dart';

List _l(dynamic v) => (v as List?) ?? const [];
void _fail(Object e, String title) => notify.err(title, e is ApiError ? e.message : null);
String _tone(dynamic t) => const ['green', 'amber', 'red', 'blue', 'grey'].contains(t) ? '$t' : 'grey';

/// What the bursar sees first: money in today and this week, the term at a glance, and what needs a decision.
class BursarHome extends StatelessWidget {
  const BursarHome({super.key});
  @override
  Widget build(BuildContext context) => LoadView(
        path: 'bursar',
        builder: (context, d, reload) {
          final t = d['totals'] as Map;
          final today = d['today'] as Map, week = d['week'] as Map;
          final awaiting = _l(d['awaiting']);
          final overdue = d['overdue'] as Map;
          final pct = (t['billed'] as num) > 0 ? ((t['collected'] as num) / (t['billed'] as num) * 100).round() : 0;
          return Screen(onRefresh: reload, children: [
            HeroBlock(title: 'Today', sub: d['today_line'] as String?, icon: 'wallet-outline'),
            ShortcutGrid([
              ShortcutItem('Record payment', () => _recordPayment(context, reload)),
              ShortcutItem('Owing', () => Nav.I.go('Owing'), hint: '${t['owing_students']} students'),
              ShortcutItem('Payments', () => Nav.I.go('Payments')),
              ShortcutItem('Bills', () => Nav.I.go('Bills')),
            ]),
            StatRow([
              Stat(icon: 'cash-outline', label: 'Received today', value: naira(today['amount'] as num), hint: '${today['count']} payments'),
              Stat(icon: 'calendar-outline', label: 'This week', value: naira(week['amount'] as num), hint: '${week['count']} payments'),
            ]),
            ECard(title: d['term'] as String? ?? 'This term', icon: 'stats-chart-outline', children: [
              LR(left: const Muted('Billed'), right: Text(naira(t['billed'] as num), style: Ty.body(w: FontWeight.w700))),
              LR(left: const Muted('Collected'), right: Text(naira(t['collected'] as num), style: Ty.body(w: FontWeight.w700))),
              LR(left: const Muted('Still owed'), right: Text(naira(t['outstanding'] as num), style: Ty.body(w: FontWeight.w700, c: color.danger))),
              Bar(pct.toDouble(), height: 6),
              Muted('$pct% collected · ${t['owing_students']} students still owe'),
            ]),
            if (awaiting.isNotEmpty)
              ECard(title: 'Waiting for you to confirm', icon: 'time-outline', right: Pill('${awaiting.length}', toneName: 'amber'), children: [
                for (final p in awaiting)
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    LR(left: TwoLine('${p['student']}', '${p['class'] ?? ''} · ${p['reference'] ?? ''}'), right: Text(naira(p['amount'] as num), style: Ty.body(w: FontWeight.w700))),
                    const SizedBox(height: 8),
                    AppButton('Confirm: it is on the statement', kind: BtnKind.soft, icon: 'checkmark', onPressed: () async {
                      try {
                        final r = await api('payments/${p['id']}/confirm', method: 'POST');
                        notify.ok('${r['message']}');
                        await reload();
                      } catch (e) {
                        _fail(e, 'Could not confirm');
                      }
                    }),
                    const SizedBox(height: 6),
                  ]),
              ]),
            if ((overdue['count'] as num) > 0)
              ECard(title: 'Overdue by two weeks or more', icon: 'alert-circle-outline', right: Pill('${overdue['count']} bills', toneName: 'red'), children: [
                Text(naira(overdue['amount'] as num), style: Ty.custom(22, FontWeight.w800)),
                Muted('Last reminder: ${overdue['last_reminder'] ?? 'none yet'}'),
                AppButton('See who owes', kind: BtnKind.soft, icon: 'people-outline', onPressed: () => Nav.I.go('Owing')),
              ]),
            ECard(title: "Today's payments", icon: 'receipt-outline', right: Muted(naira(d['payments_total'] as num)), children: [
              if (_l(d['payments']).isEmpty) const Muted('Nothing received yet today.'),
              for (final p in _l(d['payments']))
                LR(left: TwoLine('${p['student']}', '${p['time']} · ${p['channel']}'), right: Text(naira(p['amount'] as num), style: Ty.body(w: FontWeight.w700))),
            ]),
            if (_l(d['unsent']).isNotEmpty) ECard(title: 'Bills not sent yet', icon: 'paper-plane-outline', right: Pill('${_l(d['unsent']).length}', toneName: 'blue'), children: [
              for (final b in _l(d['unsent'])) LR(left: TwoLine('${b['student']}', '${b['class'] ?? ''}'), right: Text(naira(b['total'] as num), style: Ty.body(w: FontWeight.w700))),
              const Muted('Send them from the Bills tab.'),
            ]),
          ]);
        },
      );
}

/// A list that loads a page at a time from a paginated endpoint, with tabs and an optional search.
class _Paged extends StatefulWidget {
  final String path, title;
  final String? sub, searchHint;
  final List<({String value, String label})> tabs;
  final Widget Function(BuildContext, Map row, Future<void> Function() reload) row;
  final List<Widget> top;
  final String empty;
  const _Paged({required this.path, required this.title, this.sub, this.searchHint, this.tabs = const [], required this.row, this.top = const [], required this.empty});
  @override
  State<_Paged> createState() => _PagedState();
}

class _PagedState extends State<_Paged> {
  final _rows = <Map>[];
  final _q = TextEditingController();
  String _tab = 'all';
  int _page = 1, _last = 1;
  Map _counts = const {};
  bool _busy = true;
  String? _error;
  int _token = 0, _tick = Refresh.I.tick;

  @override
  void initState() {
    super.initState();
    Refresh.I.addListener(_onRefresh);
    _load(reset: true);
  }

  @override
  void dispose() {
    Refresh.I.removeListener(_onRefresh);
    _q.dispose();
    super.dispose();
  }

  /// A payment saved from anywhere, or the app coming back after a while, loads the list again.
  void _onRefresh() {
    if (Refresh.I.tick != _tick) {
      _tick = Refresh.I.tick;
      _load(reset: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    final mine = ++_token;
    if (reset) _page = 1;
    setState(() {
      _busy = true;
      _error = null;
      if (reset) _rows.clear();
    });
    try {
      final d = await api(widget.path, query: {'page': '$_page', 'per_page': '15', if (widget.tabs.isNotEmpty) 'tab': _tab, if (_q.text.trim().isNotEmpty) 'q': _q.text.trim()}) as Map;
      if (!mounted || mine != _token) return;
      setState(() {
        _rows.addAll([for (final r in _l(d['data'])) Map.from(r as Map)]);
        _last = ((d['meta'] as Map)['last_page'] as num).toInt();
        _counts = (d['counts'] as Map?) ?? const {};
        _busy = false;
      });
    } catch (e) {
      if (!mounted || mine != _token) return;
      setState(() {
        _busy = false;
        _error = e is ApiError ? e.message : 'Something went wrong.';
      });
    }
  }

  Future<void> _reload() => _load(reset: true);

  @override
  Widget build(BuildContext context) => Screen(onRefresh: _reload, children: [
        PageTitle(widget.title, sub: widget.sub),
        ...widget.top,
        if (widget.searchHint != null) Field(label: '', hint: widget.searchHint, icon: 'search-outline', controller: _q, action: TextInputAction.search, onSubmitted: (_) => _load(reset: true)),
        if (widget.tabs.isNotEmpty)
          Chips<String>(
            value: _tab,
            onChange: (v) {
              _tab = v;
              _load(reset: true);
            },
            options: [for (final t in widget.tabs) (value: t.value, label: _counts[t.value] != null ? '${t.label} · ${_counts[t.value]}' : t.label)],
          ),
        if (_error != null) Empty(icon: 'cloud-offline-outline', title: 'Could not load this', body: _error, action: AppButton('Try again', kind: BtnKind.soft, icon: 'refresh', onPressed: _reload)),
        if (_error == null && _rows.isEmpty && !_busy) Empty(icon: 'file-tray-outline', title: widget.empty),
        if (_rows.isNotEmpty) ListGroup([for (final r in _rows) widget.row(context, r, _reload)]),
        if (_busy) const Center(child: Padding(padding: EdgeInsets.all(14), child: Spinner(size: 22))),
        if (!_busy && _error == null && _page < _last)
          AppButton('Show more', kind: BtnKind.soft, icon: 'chevron-down', onPressed: () {
            _page++;
            return _load();
          }),
      ]);
}

/// Who still owes this term, worst first, with a reminder one tap away.
class BursarOwing extends StatelessWidget {
  const BursarOwing({super.key});
  @override
  Widget build(BuildContext context) => _Paged(
        path: 'defaulters',
        title: 'Who owes',
        sub: 'Students with a balance this term. Tap one to remind the family or record a payment.',
        tabs: const [(value: 'all', label: 'All'), (value: 'overdue', label: 'Overdue'), (value: 'part', label: 'Part paid'), (value: 'unpaid', label: 'Not paid')],
        empty: 'Nobody owes anything here',
        row: (context, r, reload) => ListRow(
          icon: 'person-outline',
          title: '${r['student']}',
          sub: '${r['class'] ?? ''} · ${r['days'] != null ? '${r['days']} days late' : 'due ${r['due']}'}',
          right: Text(naira(r['balance'] as num), style: Ty.body(w: FontWeight.w800, c: r['days'] != null ? color.danger : color.ink)),
          onPress: () => showAppSheet<void>(context, title: '${r['student']}', builder: (_) => _OwingActions(row: r, onDone: reload)),
        ),
      );
}

class _OwingActions extends StatelessWidget {
  final Map row;
  final Future<void> Function() onDone;
  const _OwingActions({required this.row, required this.onDone});
  @override
  Widget build(BuildContext context) {
    final phone = '${row['phone'] ?? ''}'.replaceAll(RegExp(r'[^0-9+]'), '');
    return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 16), children: [
      LR(left: const Muted('Owes'), right: Text(naira(row['balance'] as num), style: Ty.custom(20, FontWeight.w800, c: color.danger))),
      LR(left: const Muted('Class'), right: Text('${row['class'] ?? ''}', style: Ty.body())),
      LR(left: const Muted('Family'), right: Text('${row['guardian'] ?? 'No guardian on record'}', style: Ty.body())),
      LR(left: const Muted('Last reminder'), right: Text('${row['last']}', style: Ty.body())),
      const SizedBox(height: 12),
      AppButton('Send a reminder', icon: 'notifications-outline', onPressed: () async {
        try {
          final r = await api('invoices/${row['id']}/remind', method: 'POST');
          notify.ok('${r['message']}');
          if (context.mounted) Navigator.pop(context);
          await onDone();
        } catch (e) {
          _fail(e, 'Reminder not sent');
        }
      }),
      const SizedBox(height: 8),
      AppButton('Record a payment', kind: BtnKind.soft, icon: 'cash-outline', onPressed: () {
        Navigator.pop(context);
        _recordPayment(context, onDone, invoice: '${row['id']}', student: '${row['student']}', balance: row['balance'] as num, guardian: row['guardian'] as String?);
      }),
      if (phone.isNotEmpty) ...[
        const SizedBox(height: 8),
        AppButton('Call ${row['guardian'] ?? 'the family'}', kind: BtnKind.plain, icon: 'call-outline', onPressed: () => launchUrl(Uri.parse('tel:$phone'))),
      ],
    ]);
  }
}

/// Payments received, newest first. A receipt opens as a PDF; a transfer waiting on the bank statement can be confirmed here.
class BursarPayments extends StatelessWidget {
  const BursarPayments({super.key});
  @override
  Widget build(BuildContext context) => _Paged(
        path: 'payments',
        title: 'Payments',
        sub: 'Everything received this term, with its receipt.',
        empty: 'No payments yet',
        top: [Builder(builder: (context) => AppButton('Record a payment', icon: 'add-circle-outline', onPressed: () => _recordPayment(context, () async => Refresh.I.bump())))],
        row: (context, r, reload) => ListRow(
          icon: r['needs_confirm'] == true ? 'time-outline' : 'receipt-outline',
          title: '${r['student']}',
          sub: '${r['date']} ${r['time'] ?? ''} · ${r['channel']} · ${r['receipt']}',
          right: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(naira(r['amount'] as num), style: Ty.body(w: FontWeight.w800)),
            Pill('${r['status']}', toneName: _tone(r['tone'])),
          ]),
          onPress: () => showAppSheet<void>(context, title: '${r['student']}', builder: (_) => _PaymentSheet(row: r, onDone: reload)),
        ),
      );
}

class _PaymentSheet extends StatelessWidget {
  final Map row;
  final Future<void> Function() onDone;
  const _PaymentSheet({required this.row, required this.onDone});
  @override
  Widget build(BuildContext context) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 16), children: [
        LR(left: const Muted('Amount'), right: Text(naira(row['amount'] as num), style: Ty.custom(20, FontWeight.w800))),
        LR(left: const Muted('Bill'), right: Text('${row['invoice']}', style: Ty.body())),
        LR(left: const Muted('Method'), right: Text('${row['channel']}', style: Ty.body())),
        LR(left: const Muted('Reference'), right: Text('${row['reference']}', style: Ty.body())),
        LR(left: const Muted('Receipt'), right: Text('${row['receipt']}', style: Ty.body())),
        const SizedBox(height: 12),
        if (row['needs_confirm'] == true)
          AppButton('Confirm: it is on the statement', icon: 'checkmark', onPressed: () async {
            try {
              final r = await api('payments/${row['id']}/confirm', method: 'POST');
              notify.ok('${r['message']}');
              if (context.mounted) Navigator.pop(context);
              await onDone();
            } catch (e) {
              _fail(e, 'Could not confirm');
            }
          }),
        if (row['has_receipt'] == true) DocActions(path: 'payments/${row['id']}/receipt', name: 'receipt-${row['receipt']}', label: 'Receipt ${row['receipt']}'),
      ]);
}

/// Every bill this term, searchable by student or bill number.
class BursarBills extends StatelessWidget {
  const BursarBills({super.key});
  @override
  Widget build(BuildContext context) => _Paged(
        path: 'invoices',
        title: 'Bills',
        sub: 'Every bill this term. Search by name or bill number.',
        searchHint: 'Search a student or bill',
        tabs: const [(value: 'all', label: 'All'), (value: 'paid', label: 'Paid'), (value: 'part', label: 'Part paid'), (value: 'unpaid', label: 'Not paid'), (value: 'overdue', label: 'Overdue')],
        empty: 'No bills here',
        row: (context, r, reload) => ListRow(
          icon: 'document-text-outline',
          title: '${r['student']}',
          sub: '${r['number']} · ${r['class'] ?? ''}',
          right: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(naira(r['billed'] as num), style: Ty.body(w: FontWeight.w800)),
            Pill('${r['status']}', toneName: _tone(r['tone'])),
          ]),
          onPress: () => showAppSheet<void>(context, title: '${r['student']}', tall: true, builder: (_) => _BillSheet(id: '${r['id']}', onDone: reload)),
        ),
      );
}

class _BillSheet extends StatelessWidget {
  final String id;
  final Future<void> Function() onDone;
  const _BillSheet({required this.id, required this.onDone});
  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: api('invoices/$id'),
        builder: (context, snap) {
          if (snap.hasError) return Padding(padding: const EdgeInsets.all(18), child: Muted(snap.error is ApiError ? (snap.error as ApiError).message : 'Could not load this bill.'));
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(30), child: Center(child: Spinner(size: 24)));
          final b = snap.data as Map;
          final owing = (b['balance'] as num) > 0;
          return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 16), children: [
            Row(children: [Expanded(child: Text('${b['number']} · ${b['term']}', style: Ty.small())), Pill('${b['status']}', toneName: _tone(b['tone']))]),
            const SizedBox(height: 8),
            for (final l in _l(b['lines'])) LR(left: Text('${l['item']}', style: Ty.body()), right: Text(naira(l['amount'] as num), style: Ty.body(w: FontWeight.w600))),
            const Rule(),
            LR(left: const Muted('Billed'), right: Text(naira(b['billed'] as num), style: Ty.body(w: FontWeight.w700))),
            LR(left: const Muted('Paid'), right: Text(naira(b['paid'] as num), style: Ty.body(w: FontWeight.w700))),
            LR(left: const Muted('Balance'), right: Text(naira(b['balance'] as num), style: Ty.body(w: FontWeight.w800, c: owing ? color.danger : color.ink))),
            if (_l(b['payments']).isNotEmpty) ...[
              const SizedBox(height: 10),
              const SectionTitle('Payments'),
              for (final p in _l(b['payments'])) LR(left: TwoLine('${p['date']}', '${p['channel']} · ${p['receipt']}'), right: Text(naira(p['amount'] as num), style: Ty.body(w: FontWeight.w700))),
            ],
            const SizedBox(height: 12),
            if (owing)
              AppButton('Record a payment', icon: 'cash-outline', onPressed: () {
                Navigator.pop(context);
                _recordPayment(context, onDone, invoice: id, student: '${b['student']}', balance: b['balance'] as num, guardian: b['guardian'] as String?);
              }),
            if (owing) ...[
              const SizedBox(height: 8),
              AppButton('Send a reminder', kind: BtnKind.soft, icon: 'notifications-outline', onPressed: () async {
                try {
                  final r = await api('invoices/$id/remind', method: 'POST');
                  notify.ok('${r['message']}');
                } catch (e) {
                  _fail(e, 'Reminder not sent');
                }
              }),
            ],
            DocActions(path: 'invoices/$id/pdf', name: 'bill-${b['number']}', label: 'Bill ${b['number']}'),
          ]);
        },
      );
}

/// Opens the form for a payment taken at the bursary (cash, transfer, POS or cheque).
Future<void> _recordPayment(BuildContext context, Future<void> Function() onDone, {String? invoice, String? student, num? balance, String? guardian}) =>
    showAppSheet<void>(context, title: 'Record a payment', tall: true, builder: (_) => _RecordPayment(onDone: onDone, invoice: invoice, student: student, balance: balance, guardian: guardian));

class _RecordPayment extends StatefulWidget {
  final Future<void> Function() onDone;
  final String? invoice, student, guardian;
  final num? balance;
  const _RecordPayment({required this.onDone, this.invoice, this.student, this.balance, this.guardian});
  @override
  State<_RecordPayment> createState() => _RecordPaymentState();
}

class _RecordPaymentState extends State<_RecordPayment> {
  final _search = TextEditingController(), _amount = TextEditingController(), _ref = TextEditingController(), _from = TextEditingController();
  List _found = const [];
  String? _invoice, _student;
  num? _balance;
  String _method = 'cash', _date = formatDate(DateTime.now());
  bool _notify = true, _looking = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      _invoice = widget.invoice;
      _student = widget.student;
      _balance = widget.balance;
      _amount.text = _plain(widget.balance ?? 0);
      _from.text = widget.guardian ?? '';
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _amount.dispose();
    _ref.dispose();
    _from.dispose();
    super.dispose();
  }

  /// 125000 kobo is typed as 1250 (and 125050 as 1250.50).
  String _plain(num kobo) {
    final k = kobo.round();
    return k % 100 == 0 ? '${k ~/ 100}' : (k / 100).toStringAsFixed(2);
  }

  Future<void> _lookup(String q) async {
    final mine = ++_token;
    if (q.trim().length < 2) {
      setState(() => _found = const []);
      return;
    }
    setState(() => _looking = true);
    try {
      final r = await api('payments/lookup', query: {'q': q.trim()}) as List;
      if (!mounted || mine != _token) return;
      setState(() {
        _found = r;
        _looking = false;
      });
    } catch (_) {
      if (mounted && mine == _token) setState(() => _looking = false);
    }
  }

  bool get _needsRef => _method == 'bank_transfer' || _method == 'cheque';
  bool get _ready => _invoice != null && double.tryParse(_amount.text.replaceAll(',', '')) != null && double.parse(_amount.text.replaceAll(',', '')) > 0 && _from.text.trim().isNotEmpty && parseDate(_date) != null && (!_needsRef || _ref.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 16), children: [
        if (_invoice == null) ...[
          Field(label: 'Student', hint: 'Type a name or admission number', icon: 'search-outline', controller: _search, onChanged: _lookup, autofocus: true),
          const SizedBox(height: 8),
          if (_looking) const Center(child: Padding(padding: EdgeInsets.all(10), child: Spinner(size: 20))),
          if (_found.isNotEmpty)
            ListGroup([
              for (final s in _found)
                ListRow(
                  icon: 'person-outline',
                  title: '${s['name']}',
                  sub: s['invoice'] == null ? '${s['class'] ?? ''} · no bill yet' : '${s['class'] ?? ''} · owes ${naira(s['invoice']['balance'] as num)}',
                  onPress: s['invoice'] == null
                      ? null
                      : () => setState(() {
                            _invoice = '${s['invoice']['id']}';
                            _student = '${s['name']}';
                            _balance = s['invoice']['balance'] as num;
                            _amount.text = _plain(_balance!);
                            _from.text = '${s['guardian'] ?? ''}';
                          }),
                ),
            ]),
        ] else ...[
          ECard(title: _student ?? '', icon: 'person-outline', right: Muted('owes ${naira(_balance)}'), children: [
            if (widget.invoice == null) AppButton('Choose another student', kind: BtnKind.plain, icon: 'swap-horizontal-outline', onPressed: () => setState(() => _invoice = null)),
          ]),
          const SizedBox(height: 12),
          Field(label: 'Amount received (₦)', controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          Text('How was it paid?', style: Ty.small(w: FontWeight.w600)),
          const SizedBox(height: 6),
          Chips<String>(value: _method, onChange: (v) => setState(() => _method = v), options: const [(value: 'cash', label: 'Cash'), (value: 'bank_transfer', label: 'Bank transfer'), (value: 'pos', label: 'POS'), (value: 'cheque', label: 'Cheque')]),
          if (_needsRef) ...[
            const SizedBox(height: 12),
            Field(label: 'Teller, transfer or cheque reference', controller: _ref, maxLength: 60, onChanged: (_) => setState(() {})),
          ],
          const SizedBox(height: 12),
          Field(label: 'Received from', controller: _from, maxLength: 100, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          DateField(label: 'Date paid', value: _date, onChange: (v) => setState(() => _date = v)),
          const SizedBox(height: 12),
          CheckRow(value: _notify, onChange: (v) => setState(() => _notify = v), label: 'Send the receipt to the family', hint: 'By WhatsApp, SMS or email, as the family prefers'),
          const SizedBox(height: 14),
          AppButton('Save payment', icon: 'checkmark', disabled: !_ready, onPressed: () async {
            try {
              final r = await api('payments', method: 'POST', body: {
                'invoice': _invoice,
                'amount': _amount.text.replaceAll(',', ''),
                'method': _method,
                'paid_on': _date,
                'reference': _ref.text.trim().isEmpty ? null : _ref.text.trim(),
                'received_from': _from.text.trim(),
                'notify': _notify,
                'confirmed': true,
              });
              notify.ok('${r['message']}');
              if (context.mounted) Navigator.pop(context);
              await widget.onDone();
              Refresh.I.bump();
            } catch (e) {
              _fail(e, 'Payment not saved');
            }
          }),
        ],
      ]);
}
