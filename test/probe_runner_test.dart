import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_connectivity/src/api.dart';
import 'package:omni_connectivity/src/probe_runner.dart';

void main() {
  InternetCheckOption option(String id) =>
      InternetCheckOption(uri: Uri.parse('test://$id'));

  test('returns disconnected when no options are provided', () async {
    final status = await runProbeChecks(
      options: const [],
      strict: false,
      resolveProbe: (_) async => true,
    );

    expect(status, InternetStatus.disconnected);
  });

  test('non-strict mode returns connected when any probe succeeds', () async {
    final options = [option('a'), option('b'), option('c')];
    final results = <String, bool>{'a': false, 'b': true, 'c': false};

    final status = await runProbeChecks(
      options: options,
      strict: false,
      resolveProbe: (opt) async => results[opt.uri!.host]!,
    );

    expect(status, InternetStatus.connected);
  });

  test('strict mode returns connected only when all probes succeed', () async {
    final options = [option('a'), option('b')];

    final status = await runProbeChecks(
      options: options,
      strict: true,
      resolveProbe: (_) async => true,
    );

    expect(status, InternetStatus.connected);
  });

  test('strict mode returns disconnected when any probe fails', () async {
    final options = [option('a'), option('b')];

    final status = await runProbeChecks(
      options: options,
      strict: true,
      resolveProbe: (opt) async => opt.uri!.host == 'a',
    );

    expect(status, InternetStatus.disconnected);
  });

  test('treats probe errors as failures', () async {
    final options = [option('a'), option('b')];

    final status = await runProbeChecks(
      options: options,
      strict: false,
      resolveProbe: (opt) async {
        if (opt.uri!.host == 'a') {
          throw Exception('probe failed');
        }
        return true;
      },
    );

    expect(status, InternetStatus.connected);
  });

  test('non-strict mode completes when first success is observed', () async {
    final pending = Completer<bool>();
    final options = [option('slow'), option('fast')];

    final statusFuture = runProbeChecks(
      options: options,
      strict: false,
      resolveProbe: (opt) async {
        if (opt.uri!.host == 'slow') {
          return pending.future;
        }
        return true;
      },
    );

    final status =
        await statusFuture.timeout(const Duration(milliseconds: 200));
    expect(status, InternetStatus.connected);
    expect(pending.isCompleted, isFalse);
  });
}
