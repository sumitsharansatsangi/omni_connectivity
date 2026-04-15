// lib/src/api.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

// Conditional import selects the correct implementation file.
// Each implementation file must expose a top-level `platformImpl`.
import 'impl_io.dart' if (dart.library.html) 'impl_web.dart';

/// Public status enum
enum InternetStatus { connected, disconnected }

/// Public transport info derived from connectivity_plus results.
enum InternetTransport {
  none,
  wifi,
  mobile,
  ethernet,
  bluetooth,
  vpn,
  satellite,
  other,
}

List<InternetTransport> mapConnectivityResultsToTransports(
  List<ConnectivityResult> results,
) {
  final transports = <InternetTransport>{};

  for (final result in results) {
    switch (result) {
      case ConnectivityResult.none:
        transports.add(InternetTransport.none);
      case ConnectivityResult.wifi:
        transports.add(InternetTransport.wifi);
      case ConnectivityResult.mobile:
        transports.add(InternetTransport.mobile);
      case ConnectivityResult.ethernet:
        transports.add(InternetTransport.ethernet);
      case ConnectivityResult.bluetooth:
        transports.add(InternetTransport.bluetooth);
      case ConnectivityResult.vpn:
        transports.add(InternetTransport.vpn);
      case ConnectivityResult.satellite:
        transports.add(InternetTransport.satellite);
      case ConnectivityResult.other:
        transports.add(InternetTransport.other);
    }
  }

  if (transports.isEmpty) {
    return const [InternetTransport.none];
  }

  if (transports.length > 1 && transports.contains(InternetTransport.none)) {
    transports.remove(InternetTransport.none);
  }

  final sorted = transports.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return sorted;
}

bool areSameTransports(
  List<InternetTransport> a,
  List<InternetTransport> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

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

  static Stream<List<InternetTransport>> get onTransportChange =>
      platformImpl.onTransportChange;

  static void setIntervalAndResetTimer(Duration d) =>
      platformImpl.setIntervalAndResetTimer(d);

  static InternetStatus? get lastTryResults => platformImpl.lastTryResults;

  static List<InternetTransport> get lastKnownTransports =>
      platformImpl.lastKnownTransports;
}
