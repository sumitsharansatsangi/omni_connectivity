import 'dart:async';

import 'api.dart';

typedef ProbeResolver = Future<bool> Function(InternetCheckOption option);

Future<InternetStatus> runProbeChecks({
  required List<InternetCheckOption> options,
  required bool strict,
  required ProbeResolver resolveProbe,
}) async {
  if (options.isEmpty) {
    return InternetStatus.disconnected;
  }

  final completer = Completer<InternetStatus>();
  var remaining = options.length;
  var successCount = 0;

  for (final option in options) {
    unawaited(
      resolveProbe(option)
          .then((ok) {
            if (ok) {
              successCount += 1;
            }
          })
          .catchError((_) {})
          .whenComplete(() {
            remaining -= 1;
            if (completer.isCompleted) {
              return;
            }

            if (!strict && successCount > 0) {
              completer.complete(InternetStatus.connected);
              return;
            }

            if (remaining == 0) {
              final isConnected =
                  strict ? successCount == options.length : successCount > 0;
              completer.complete(
                isConnected
                    ? InternetStatus.connected
                    : InternetStatus.disconnected,
              );
            }
          }),
    );
  }

  return completer.future;
}
