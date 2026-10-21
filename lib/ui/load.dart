import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/net.dart';
import '../core/term.dart';
import 'base.dart';
import 'controls.dart';
import 'layout.dart';
import '../core/theme.dart';

typedef LoadBuilder = Widget Function(BuildContext context, dynamic data, Future<void> Function() reload);

/// Loads a screen's data. What the phone already has for this screen is shown at once and fresh data is fetched behind it;
/// a copy loaded a few seconds ago is not asked for again. It loads again by itself when the term changes, the signal comes back,
/// a notice arrives, or the app returns after a while away.
class LoadView extends StatefulWidget {
  final String path;
  final Map<String, String?>? query;
  final LoadBuilder builder;
  final Widget Function(BuildContext context, String error, Future<void> Function() retry)? onError;
  const LoadView({super.key, required this.path, this.query, required this.builder, this.onError});
  @override
  State<LoadView> createState() => _LoadViewState();
}

class _LoadViewState extends State<LoadView> {
  dynamic _data;
  String? _error;
  int _latest = 0;
  int _tick = Refresh.I.tick;

  @override
  void initState() {
    super.initState();
    _data = peek(widget.path, widget.query);
    Terms.I.addListener(_onTerm);
    Net.I.addListener(_onNet);
    Refresh.I.addListener(_onRefresh);
    _start();
  }

  @override
  void didUpdateWidget(LoadView old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || '${old.query}' != '${widget.query}') {
      _data = peek(widget.path, widget.query);
      _error = null;
      _start();
    }
  }

  @override
  void dispose() {
    Terms.I.removeListener(_onTerm);
    Net.I.removeListener(_onNet);
    Refresh.I.removeListener(_onRefresh);
    super.dispose();
  }

  void _start() {
    final have = peek(widget.path, widget.query);
    final age = peekAge(widget.path, widget.query);
    // A copy loaded a few seconds ago (by the warm-up, or on the last visit) is not asked for again.
    if (have == null || age == null || age > freshFor) _load();
  }

  void _onTerm() {
    _data = peek(widget.path, widget.query);
    _load();
  }

  void _onNet() {
    if (Net.I.online && (_error != null || lastStaleAt != null)) _load();
  }

  void _onRefresh() {
    if (Refresh.I.tick != _tick) {
      _tick = Refresh.I.tick;
      _load();
    }
  }

  Future<void> _load() async {
    final mine = ++_latest;
    try {
      final d = await api(widget.path, query: widget.query);
      if (!mounted || mine != _latest) return; // a newer request for another term or child is already on its way
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (!mounted || mine != _latest) return;
      setState(() => _error = e is ApiError ? e.message : 'Something went wrong.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      if (_error != null && widget.onError != null) return widget.onError!(context, _error!, _load);
      return Loading(error: _error, retry: _load);
    }
    return widget.builder(context, _data, _load);
  }
}

/// The placeholder while a screen loads (a few shimmering blocks in the shape of cards), or the error with a way to try again.
class Loading extends StatelessWidget {
  final String? error;
  final Future<void> Function() retry;
  const Loading({super.key, this.error, required this.retry});
  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Screen(children: [
        Empty(icon: 'cloud-offline-outline', title: 'Could not load this', body: error, action: AppButton('Try again', kind: BtnKind.soft, icon: 'refresh', onPressed: retry)),
      ]);
    }
    return Screen(children: [
      const Skeleton(h: 30, w: 180, r: 8),
      for (var i = 0; i < 3; i++)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: color.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: color.line)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(h: 16, w: 140), SizedBox(height: 12), Skeleton(h: 12), SizedBox(height: 8), Skeleton(h: 12, w: 200)]),
        ),
    ]);
  }
}
