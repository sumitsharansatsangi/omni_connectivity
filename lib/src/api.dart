// lib/src/api.dart
import 'dart:async';

// Conditional import selects the correct implementation file.
// Each implementation file must expose a top-level `platformImpl`.
import 'impl_io.dart' if (dart.library.html) 'impl_web.dart';

/// Public status enum
enum InternetStatus { connected, disconnected }

/// Public probe option (simple & light)
class InternetCheckOption {
  final Uri? uri;
  final Duration timeout;
  final Future<bool> Function()? customProbe;

  const InternetCheckOption({
    this.uri,
    this.timeout = const Duration(seconds: 3),
    this.customProbe,
  });

  factory InternetCheckOption.fromHostPort(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  }) {
    return InternetCheckOption(
      uri: Uri.parse('tcp://$host:$port'),
      timeout: timeout,
      // Use the public `platformImpl` (exported by impl_io.dart / impl_web.dart).
      customProbe: () => platformImpl.tcpProbe(host, port, timeout: timeout),
    );
  }

  @override
  String toString() => 'InternetCheckOption(uri: $uri, timeout: $timeout)';
}

/// Static, developer-friendly API (init + helpers)
class OmniConnectivity {
  OmniConnectivity._();

  /// Initialize package (optional). Call at app startup to provide custom options.
  static Future<void> init({
    List<InternetCheckOption>? options,
    Duration? checkInterval,
    bool? strict,
  }) =>
      platformImpl.init(
        options: options,
        checkInterval: checkInterval,
        strict: strict,
      );

  static Future<bool> hasInternetAccess() => platformImpl.hasInternetAccess();

  static Future<InternetStatus> checkOnce() => platformImpl.checkOnce();

  static Stream<InternetStatus> get onStatusChange =>
      platformImpl.onStatusChange;

  static void setIntervalAndResetTimer(Duration d) =>
      platformImpl.setIntervalAndResetTimer(d);

  static InternetStatus? get lastTryResults => platformImpl.lastTryResults;
}
