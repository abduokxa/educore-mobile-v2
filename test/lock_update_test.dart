import 'package:educore/features/lock.dart';
import 'package:educore/features/play_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('app lock delay', () {
    test('asks again only after the chosen time away', () {
      expect(shouldLock(const Duration(seconds: 30), const Duration(seconds: 60)), isFalse);
      expect(shouldLock(const Duration(seconds: 60), const Duration(seconds: 60)), isTrue);
      expect(shouldLock(const Duration(minutes: 4), const Duration(minutes: 5)), isFalse);
      expect(shouldLock(const Duration(minutes: 16), const Duration(minutes: 15)), isTrue);
    });

    test('"always" asks every time the app comes back', () {
      expect(shouldLock(Duration.zero, Duration.zero), isTrue);
    });

    test('the choices include the usual one minute', () {
      expect(lockDelays, contains(defaultAway.inSeconds));
    });
  });

  group('google play update', () {
    test('an ordinary update is not urgent, a high priority one is', () {
      expect(const PlayUpdate(available: true, flexible: true, priority: 2).urgent, isFalse);
      expect(const PlayUpdate(available: true, immediate: true, priority: 4).urgent, isTrue);
    });

    test('nothing is offered when Play has nothing', () {
      expect(PlayUpdate.none.available, isFalse);
    });
  });
}
