import 'package:flutter/material.dart';

/// The colours of a look. The same names and values as the web app and the earlier phone app.
class Palette {
  final Color brand, bg, card, line, ink, muted, danger, tint, onBrand;
  const Palette(this.brand, this.bg, this.card, this.line, this.ink, this.muted, this.danger, this.tint, this.onBrand);
}

Color _h(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));
Palette _p(String brand, String bg, String card, String line, String ink, String muted, String danger, String tint, String onBrand) =>
    Palette(_h(brand), _h(bg), _h(card), _h(line), _h(ink), _h(muted), _h(danger), _h(tint), _h(onBrand));

/// The looks the platform owner or a school can give the app.
final Map<String, Palette> themes = {
  'v2': _p('#0b4a3b', '#f7f7f8', '#ffffff', '#e4e4e8', '#18181b', '#5b5b66', '#dc2626', '#e7f1ee', '#ffffff'),
  'educore': _p('#0b4a3b', '#f8fafc', '#ffffff', '#e2e8f0', '#0f172a', '#475569', '#dc2626', '#e7f1ee', '#ffffff'),
  'evergreen': _p('#0b4a3b', '#f8fafc', '#ffffff', '#e2e8f0', '#0f172a', '#475569', '#dc2626', '#e7f1ee', '#ffffff'),
  'paper': _p('#14212b', '#ffffff', '#ffffff', '#d9e0e4', '#14212b', '#55646f', '#b3261e', '#eef2f4', '#ffffff'),
  'midnight': _p('#10b981', '#0b1a24', '#122a38', '#23455a', '#e6f0f4', '#a9bfca', '#ff8a80', '#183444', '#04180f'),
  'sunrise': _p('#0b4a3b', '#f2fbf6', '#ffffff', '#d9eee2', '#16322b', '#4b6a5f', '#d63b2f', '#d1fae5', '#ffffff'),
  'ledger': _p('#0b4a3b', '#ffffff', '#ffffff', '#cdd5d9', '#101820', '#55616d', '#b3261e', '#eef2f3', '#ffffff'),
  'slate': _p('#2563eb', '#eef1f5', '#ffffff', '#dbe1e8', '#0f172a', '#5b6678', '#b3261e', '#e0e9ff', '#ffffff'),
  'rail': _p('#0f766e', '#faf9f6', '#ffffff', '#e8e5dc', '#1c2b2a', '#66706f', '#b3261e', '#d9f0ec', '#ffffff'),
  'daily': _p('#9b1c2e', '#fbf8f1', '#fffdf8', '#d8cfbf', '#1a1614', '#6b625a', '#b3261e', '#f3e3e0', '#ffffff'),
  'dock': _p('#7c3aed', '#e9edf2', '#ffffff', '#e3e6ef', '#1e1b4b', '#5c5a80', '#b3261e', '#ece4ff', '#ffffff'),
  'righthand': _p('#0e7490', '#f6f7fb', '#ffffff', '#e0e6ee', '#0f2a35', '#51666f', '#b3261e', '#d8eff4', '#ffffff'),
  'panes': _p('#16a34a', '#f3f4f6', '#ffffff', '#e2e5ea', '#111827', '#5b6472', '#b3261e', '#dcf5e4', '#ffffff'),
  'launcher': _p('#6d28d9', '#f5f3ff', '#ffffff', '#e5defc', '#1e1b3a', '#5f5b7c', '#b3261e', '#ede9fe', '#ffffff'),
  'bento': _p('#14532d', '#ecebe6', '#fbfaf7', '#e1dfd7', '#13201a', '#5a625c', '#b3261e', '#d8e8d0', '#ffffff'),
  'bentonight': _p('#22d3ee', '#0b0f14', '#141b24', '#223041', '#e6edf3', '#8b98a5', '#f87171', '#10323b', '#04202a'),
  'ledgerplus': _p('#1d4ed8', '#f7f7f5', '#ffffff', '#d9d9d4', '#1a1a1a', '#6b6b66', '#b3261e', '#e8eefc', '#ffffff'),
  'board': _p('#ea580c', '#f4f5f7', '#ffffff', '#e3e6ea', '#1f2937', '#5e6673', '#b3261e', '#ffedd5', '#ffffff'),
  'sunny': _p('#f97316', '#fff7ed', '#ffffff', '#fde4cc', '#3b2412', '#7c5a3c', '#b3261e', '#ffedd5', '#ffffff'),
  'brutal': _p('#111111', '#fffbe6', '#ffffff', '#111111', '#111111', '#444444', '#b3261e', '#ffe14d', '#ffffff'),
  'glass': _p('#f0abfc', '#1e1b4b', '#2b2766', '#4a4585', '#ffffff', '#c7c3f0', '#fca5a5', '#3a3480', '#2e1065'),
  'swiss': _p('#e11d1d', '#ffffff', '#ffffff', '#111111', '#111111', '#555555', '#b3261e', '#f3f3f3', '#ffffff'),
  'terminal': _p('#4ade80', '#0a0e0a', '#0f150f', '#1c2a1c', '#c7f9cc', '#5ea36a', '#f87171', '#12301a', '#04130a'),
  'notebook': _p('#1e3a8a', '#f4ecd8', '#fffaf0', '#d6c9a8', '#2b2418', '#6f6451', '#b3261e', '#e6e1c8', '#ffffff'),
  'hero': _p('#fbbf24', '#0f172a', '#17213a', '#25324f', '#f1f5f9', '#94a3b8', '#f87171', '#1e2b4a', '#1c1300'),
  'blocks': _p('#111827', '#ffffff', '#ffffff', '#e5e7eb', '#111827', '#5b6472', '#b3261e', '#f3f4f6', '#ffffff'),
  'enterprise': _p('#0a58ca', '#f1f3f5', '#ffffff', '#d5dbe1', '#16202a', '#56616d', '#b3261e', '#e7f0ff', '#ffffff'),
};

/// The dark version of any look: deep blue-grey surfaces and a lighter form of the brand colour.
final Palette _dark = _p('#34c28f', '#0b1a24', '#122a38', '#23455a', '#e6f0f4', '#a9bfca', '#ff8a80', '#183444', '#04180f');

/// The palette every screen reads. It is replaced in place when the look, the school's colour or dark mode changes.
Palette color = themes['educore']!;

double lum(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
bool isDark() => lum(color.bg) < lum(color.ink);

Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Which home layout each look uses: cards, a grid of big shortcuts, a settings-style list, or colourful tiles.
enum HomeLayout { cards, grid, list, tiles }

const Map<String, HomeLayout> _family = {
  'daily': HomeLayout.list, 'dock': HomeLayout.grid, 'panes': HomeLayout.list, 'launcher': HomeLayout.grid, 'bento': HomeLayout.tiles,
  'bentonight': HomeLayout.tiles, 'ledgerplus': HomeLayout.list, 'sunny': HomeLayout.tiles, 'brutal': HomeLayout.grid, 'glass': HomeLayout.tiles,
  'v2': HomeLayout.list, 'swiss': HomeLayout.list, 'terminal': HomeLayout.list, 'notebook': HomeLayout.list, 'hero': HomeLayout.grid,
  'blocks': HomeLayout.tiles, 'enterprise': HomeLayout.list, 'paper': HomeLayout.list, 'sunrise': HomeLayout.tiles, 'ledger': HomeLayout.list,
};
HomeLayout homeLayout = HomeLayout.cards;

final RegExp _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

/// Applies a look, light or dark, and then the school's own colour on top of it: the brand, its soft tint and the text that sits on it.
void applyTheme(String? key, String? brand, bool dark) {
  homeLayout = _family[key ?? ''] ?? HomeLayout.cards;
  color = dark ? _dark : (themes[key ?? 'educore'] ?? themes['educore']!);
  if (brand == null || !_hex.hasMatch(brand)) return;
  final base = _h(brand);
  final onDark = lum(color.bg) < lum(color.ink);
  final b = onDark ? mix(base, Colors.white, lum(base) < 0.35 ? 0.5 : 0.2) : base;
  color = Palette(b, color.bg, color.card, color.line, color.ink, color.muted, color.danger, mix(b, color.card, onDark ? 0.78 : 0.9),
      lum(b) > 0.6 ? const Color(0xFF10151C) : Colors.white);
}

/// Soft status colours that read on both light and dark looks: a tinted background and a readable text colour.
({Color bg, Color fg}) tone(String? name) {
  final dark = isDark();
  final fg = <String, List<Color>>{
    'green': [const Color(0xFF15803D), const Color(0xFF4ADE80)],
    'blue': [const Color(0xFF1D4ED8), const Color(0xFF7AA8FF)],
    'amber': [const Color(0xFFB45309), const Color(0xFFFBBF24)],
    'red': [const Color(0xFFB91C1C), const Color(0xFFFF8A80)],
  };
  final c = (fg[name] ?? [color.muted, color.muted])[dark ? 1 : 0];
  return (fg: c, bg: c.withValues(alpha: dark ? 0.17 : 0.10));
}

/// The sizes of text used across the app.
class Ty {
  static TextStyle _s(double size, FontWeight w, {double? height, double? ls, Color? c}) =>
      TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, height: height == null ? null : height / size, letterSpacing: ls, color: c ?? color.ink);
  static TextStyle display({Color? c}) => _s(30, FontWeight.w800, height: 36, ls: -0.6, c: c);
  static TextStyle h1({Color? c}) => _s(26, FontWeight.w800, height: 32, ls: -0.4, c: c);
  static TextStyle h2({Color? c}) => _s(20, FontWeight.w700, height: 26, ls: -0.2, c: c);
  static TextStyle h3({Color? c, double size = 16}) => _s(size, FontWeight.w700, height: 22, c: c);
  static TextStyle body({Color? c, FontWeight w = FontWeight.w400}) => _s(15, w, height: 22, c: c);
  static TextStyle small({Color? c, FontWeight w = FontWeight.w500}) => _s(13, w, height: 18, c: c ?? color.muted);
  static TextStyle caption({Color? c}) => _s(12, FontWeight.w600, height: 16, c: c ?? color.muted);
  static TextStyle custom(double size, FontWeight w, {Color? c, double? ls}) => _s(size, w, ls: ls, c: c);
}

/// Spacing and corner sizes shared by every screen.
const double kRadius = 18;

/// Phones use the full width; tablets and large phones in landscape get a centred column so lines stay readable.
class Layout {
  final double width;
  Layout(this.width);
  bool get tablet => width >= 700;
  double get gutter => tablet ? 28 : (width < 360 ? 14 : 18);
  double get maxWidth => tablet ? 760 : 560;
  static Layout of(BuildContext context) => Layout(MediaQuery.sizeOf(context).width);
}
