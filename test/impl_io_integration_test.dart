import 'package:flutter_test/flutter_test.dart';
import 'package:omni_connectivity/src/api.dart';
import 'package:omni_connectivity/src/impl_io.dart';

void main() {
  group('OmniConnectivityImpl (IO)', () {
    late OmniConnectivityImpl impl;

    setUp(() {
      impl = OmniConnectivityImpl();
    });

    test('init stores custom options', () async {
      final opts = [
        InternetCheckOption(customProbe: () async => true),
        InternetCheckOption(customProbe: () async => false),
      ];

      await impl.init(options: opts);

      // Access private _options via reflection or test by behavior
      final status = await impl.checkOnce();
      // If it uses our options, first one succeeds -> connected
      expect(status, InternetStatus.connected);
    });

    test('checkOnce returns connected when a custom probe succeeds', () async {
      final options = [
        InternetCheckOption(customProbe: () async => false),
        InternetCheckOption(customProbe: () async => true),
      ];

      await impl.init(options: options);
      final status = await impl.checkOnce();

      expect(status, InternetStatus.connected);
    });

    test('checkOnce returns disconnected when all probes fail', () async {
      final options = [
        InternetCheckOption(customProbe: () async => false),
        InternetCheckOption(customProbe: () async => false),
      ];

      await impl.init(options: options);
      final status = await impl.checkOnce();

      expect(status, InternetStatus.disconnected);
    });

    test('strict mode requires all probes to succeed', () async {
      final options = [
        InternetCheckOption(customProbe: () async => true),
        InternetCheckOption(customProbe: () async => false),
      ];

      await impl.init(options: options, strict: true);
      final status = await impl.checkOnce();

      expect(status, InternetStatus.disconnected);
    });

    test('strict mode succeeds when all probes succeed', () async {
      final options = [
        InternetCheckOption(customProbe: () async => true),
        InternetCheckOption(customProbe: () async => true),
      ];

      await impl.init(options: options, strict: true);
      final status = await impl.checkOnce();

      expect(status, InternetStatus.connected);
    });

    test('hasInternetAccess returns true when connected', () async {
      await impl.init(
        options: [InternetCheckOption(customProbe: () async => true)],
      );

      final result = await impl.hasInternetAccess();
      expect(result, isTrue);
    });

    test('hasInternetAccess returns false when disconnected', () async {
      await impl.init(
        options: [InternetCheckOption(customProbe: () async => false)],
      );

      final result = await impl.hasInternetAccess();
      expect(result, isFalse);
    });

    test('probe exceptions are treated as failures', () async {
      final options = [
        InternetCheckOption(
          customProbe: () async => throw Exception('probe error'),
        ),
        InternetCheckOption(customProbe: () async => true),
      ];

      await impl.init(options: options);
      final status = await impl.checkOnce();

      expect(status, InternetStatus.connected);
    });

    test('checkOnce completes in non-strict mode after first success',
        () async {
      final callCounts = <String, int>{'a': 0, 'b': 0};
      final options = [
        InternetCheckOption(
          customProbe: () async {
            callCounts['a'] = callCounts['a']! + 1;
            return false;
          },
        ),
        InternetCheckOption(
          customProbe: () async {
            callCounts['b'] = callCounts['b']! + 1;
            return true;
          },
        ),
      ];

      await impl.init(options: options, strict: false);
      final status = await impl.checkOnce();

      expect(status, InternetStatus.connected);
      // Both may be called due to racing, but non-strict should not wait
      // for all to complete
      expect(callCounts['b']!, greaterThanOrEqualTo(1));
    });
  });
}
