import 'package:test/test.dart';
import 'package:verion/verion.dart';

import 'utils.dart';

void main() {
  group('SubscribeContext teardown/cleanup contracts', () {
    late VerionScope scope;

    setUp(() {
      scope = VerionScope(label: "Teardown Test");
    });

    tearDown(() {
      scope.dispose();
    });

    group('Derive', () {
      test('teardown runs on re-evaluation', () async {
        final (src, setSrc) = createSource<int>(scope, 0);
        int teardownCallCount = 0;

        final derived = scope.derive((sub) {
          sub.onDispose(() {
            teardownCallCount++;
          });
          return sub(src) * 2;
        });

        // Initial evaluation happens immediately or on first read, depending on implementation.
        // Actually for derive it's on first read.
        expect(derived.value, 0);
        expect(teardownCallCount, 0);

        setSrc(1);
        await pump();
        expect(derived.value, 2);
        expect(teardownCallCount, 1);

        setSrc(2);
        await pump();
        expect(derived.value, 4);
        expect(teardownCallCount, 2);
      });

      test('teardown runs on dispose', () {
        final (src, _) = createSource<int>(scope, 0);
        int teardownCallCount = 0;

        final derived = scope.derive((sub) {
          sub.onDispose(() {
            teardownCallCount++;
          });
          return sub(src) * 2;
        });

        // Trigger first evaluation
        expect(derived.value, 0);
        expect(teardownCallCount, 0);

        derived.dispose();
        expect(teardownCallCount, 1);
      });

      test('only the latest teardown is run', () async {
        final (src, setSrc) = createSource<int>(scope, 0);
        int teardown1CallCount = 0;
        int teardown2CallCount = 0;

        final derived = scope.derive((sub) {
          final val = sub(src);
          if (val == 0) {
            sub.onDispose(() {
              teardown1CallCount++;
            });
          } else {
            sub.onDispose(() {
              teardown2CallCount++;
            });
          }
          return val;
        });

        expect(derived.value, 0);
        expect(teardown1CallCount, 0);
        expect(teardown2CallCount, 0);

        setSrc(1);
        await pump();
        expect(derived.value, 1);
        expect(teardown1CallCount, 1);
        expect(teardown2CallCount, 0);

        // Next update, the second teardown should be registered
        setSrc(2);
        await pump();
        expect(derived.value, 2);
        expect(teardown1CallCount, 1);
        expect(teardown2CallCount, 1);
      });
    });

    group('Trigger', () {
      test('teardown runs on re-evaluation', () async {
        final (src, setSrc) = createSource<int>(scope, 0);
        int teardownCallCount = 0;

        scope.trigger((sub) {
          sub.onDispose(() {
            teardownCallCount++;
          });
          sub(src);
        });

        // Trigger initializes immediately
        expect(teardownCallCount, 0);

        setSrc(1);
        await pump();
        expect(teardownCallCount, 1);

        setSrc(2);
        await pump();
        expect(teardownCallCount, 2);
      });

      test('teardown runs on dispose', () {
        final (src, _) = createSource<int>(scope, 0);
        int teardownCallCount = 0;

        final trigger = scope.trigger((sub) {
          sub.onDispose(() {
            teardownCallCount++;
          });
          sub(src);
        });

        expect(teardownCallCount, 0);

        trigger.dispose();
        expect(teardownCallCount, 1);
      });

      test('only the latest teardown is run', () async {
        final (src, setSrc) = createSource<int>(scope, 0);
        int teardown1CallCount = 0;
        int teardown2CallCount = 0;

        scope.trigger((sub) {
          final val = sub(src);
          if (val == 0) {
            sub.onDispose(() {
              teardown1CallCount++;
            });
          } else {
            sub.onDispose(() {
              teardown2CallCount++;
            });
          }
        });

        expect(teardown1CallCount, 0);
        expect(teardown2CallCount, 0);

        setSrc(1);
        await pump();
        expect(teardown1CallCount, 1);
        expect(teardown2CallCount, 0);

        setSrc(2);
        await pump();
        expect(teardown1CallCount, 1);
        expect(teardown2CallCount, 1);
      });
    });
  });
}
