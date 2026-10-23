import 'package:educore/core/api.dart';
import 'package:educore/core/term.dart';
import 'package:educore/core/theme.dart';
import 'package:educore/core/words.dart';
import 'package:educore/features/version.dart';
import 'package:educore/screens/forgot.dart';
import 'package:educore/screens/inbox.dart';
import 'package:educore/shell/nav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('money', () {
    test('writes kobo as naira with thousands separators', () {
      expect(naira(1250000), '₦12,500');
      expect(naira(1250050), '₦12,500.50');
      expect(naira(0), '₦0');
      expect(naira(null), '₦0');
      expect(naira(-250000), '-₦2,500');
    });
  });

  group('school address', () {
    test('a short name gets the root domain, a full address is kept', () {
      expect(normalizeAddress('Greenfield'), 'greenfield.$rootDomain');
      expect(normalizeAddress('https://school.example.com/'), 'school.example.com');
      expect(normalizeAddress('greenfield.localhost:8000'), 'greenfield.localhost:8000');
    });

    test('a local test address is reached over http, others over https', () {
      setAddress('greenfield.localhost:8000');
      expect(baseUrl(), 'http://greenfield.localhost:8000');
      setAddress('greenfield.edu-core.ng');
      expect(baseUrl(), 'https://greenfield.edu-core.ng');
    });
  });

  group('app versions', () {
    test('compares numbers part by part, missing parts count as zero', () {
      expect(compareVersions('1.2.0', '1.10.0'), -1);
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('2.0.0', '1.9.9'), 1);
    });

    test('a build below the minimum must update; below the latest is only offered', () {
      final rules = VersionRules('1.1.0', '1.3.0', 'https://store');
      expect(updateState(rules, '1.0.0'), UpdateState.required);
      expect(updateState(rules, '1.2.0'), UpdateState.available);
      expect(updateState(rules, '1.3.0'), UpdateState.current);
      expect(updateState(null, '0.0.1'), UpdateState.current);
    });
  });

  group('password reset', () {
    test('finds a six digit code in a pasted message', () {
      expect(extractCode('Your Educore code is 482 913. It expires soon.'), '482913');
      expect(extractCode('482-913'), '482913');
      expect(extractCode('code: 123456'), '123456');
      expect(extractCode('no digits here'), isNull);
      expect(extractCode('12345678'), isNull);
    });

    test('rates a password', () {
      expect(strength('').ok, isFalse);
      expect(strength('abc').ok, isFalse);
      expect(strength('abcdefg1').ok, isTrue);
      expect(strength('a-very-long-passphrase-1').label, 'Strong');
    });
  });

  group('navigation', () {
    test('goes to a tab, remembers where it came from and steps back', () {
      Nav.I.setTabs(['Home', 'Fees', 'Results']);
      expect(Nav.I.current, 'Home');
      Nav.I.go('Fees');
      Nav.I.go('Results');
      expect(Nav.I.back(), isTrue);
      expect(Nav.I.current, 'Fees');
      expect(Nav.I.back(), isTrue);
      expect(Nav.I.current, 'Home');
      expect(Nav.I.back(), isFalse);
    });

    test('ignores a tab this role does not have, and hands a notice over once', () {
      Nav.I.setTabs(['Home', 'Notices']);
      Nav.I.go('Register');
      expect(Nav.I.current, 'Home');
      Nav.I.go('Notices', notice: 'abc');
      expect(Nav.I.takeNotice(), 'abc');
      expect(Nav.I.takeNotice(), isNull);
    });

    test('maps the page a notice is about to the screen that shows it', () {
      expect(targetFor('/parent/fees'), 'Fees');
      expect(targetFor('/teacher/attendance'), 'Register');
      expect(targetFor('/student/learn/assignment'), 'Learn');
      expect(targetFor('/teacher/payslips'), 'page:payslips');
      expect(targetFor('/parent/messages?thread=3'), 'page:chat');
      expect(targetFor('/something/else'), 'Notices');
    });

    test('Back goes to the screen before, a menu screen included, and a tab closes the screen over it', () {
      final nav = Nav.I..setTabs(['Home', 'Fees', 'Notices', 'Account'], role: 'parent', pages: ['help', 'chat']);
      nav.openPage('help');
      nav.go('Fees');
      expect(nav.page, isNull);
      nav.go('Home');
      nav.openPage('chat');
      expect(nav.page, 'chat');
      // Home, then Chat over it: back to Home, then Fees, then the Help that was open, then Home.
      expect(nav.back(), isTrue);
      expect(nav.page, isNull);
      expect(nav.current, 'Home');
      expect(nav.back(), isTrue);
      expect(nav.current, 'Fees');
      expect(nav.back(), isTrue);
      expect(nav.page, 'help');
      expect(nav.back(), isTrue);
      expect(nav.page, isNull);
      expect(nav.back(), isFalse);
    });

    test('a link opens its menu screen directly, and is ignored if this person has no such screen', () {
      final nav = Nav.I..setTabs(['My day', 'Notices', 'Account'], role: 'teacher', pages: ['payslips']);
      nav.goTo('page:payslips');
      expect(nav.page, 'payslips');
      nav.goTo('page:nothing');
      expect(nav.page, 'payslips');
      nav.lock(true);
      nav.goTo('Notices');
      expect(nav.current, 'My day');
      nav.lock(false);
    });
  });

  group('look', () {
    test('a school colour replaces the brand and picks readable text on it', () {
      applyTheme('educore', '#ffd400', false);
      expect(color.brand.toARGB32(), 0xFFFFD400);
      expect(lum(color.onBrand) < 0.3, isTrue);
      applyTheme('educore', '#0b4a3b', false);
      expect(color.onBrand.toARGB32(), 0xFFFFFFFF);
    });

    test('dark mode uses the dark surfaces and lightens a dark brand', () {
      applyTheme('educore', '#0b4a3b', true);
      expect(isDark(), isTrue);
      expect(lum(color.brand) > 0.3, isTrue);
    });
  });

  group('terms', () {
    test('has nothing to show before the school answers', () {
      Terms.I.reset();
      expect(Terms.I.shown, isNull);
    });
  });

  group('words for learning and exams', () {
    test('tokens are filled with the school\'s words, capital and plural included', () {
      Words.set({'school': {'words': {'course': ['learning area', 'learning areas'], 'lesson': ['activity', 'activities'], 'test': ['quiz', 'quizzes']}}});
      expect(w('New {course}'), 'New learning area');
      expect(w('{Courses} and {lessons}'), 'Learning areas and activities');
      expect(w('Leave the {test}?'), 'Leave the quiz?');
      expect(w('{unknown} stays'), '{unknown} stays');
      Words.set(null);
      expect(w('{course}'), 'e-class');
    });
  });

  group('a test being taken', () {
    test('locks the tabs until it is over', () {
      Nav.I.setTabs(['Today', 'Results', 'More']);
      Nav.I.lock(true);
      Nav.I.go('Results');
      expect(Nav.I.current, 'Today');
      Nav.I.lock(false);
      Nav.I.go('Results');
      expect(Nav.I.current, 'Results');
    });
  });
}
