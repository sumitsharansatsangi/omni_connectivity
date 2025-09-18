// lib/src/impl_web.dart
//
// Web implementation using package:web + dart:js_interop.
// Avoids dart:js_util and dart:html; uses typed interop only.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'api.dart';

/// Perform a HEAD fetch using the browser's fetch API via package:web.
/// Uses AbortController and enforces timeout by aborting the fetch.
Future<bool> _fetchProbe(
  String url, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    // Create AbortController (JS-side)
    final controller = web.AbortController();
    final signal = controller.signal;

    // Build strongly-typed RequestInit (uses JSString via .toJS)
    final init = web.RequestInit(method: 'HEAD', signal: signal);

    // Call window.fetch. Pass JSString only to JS API.
    final jsUrl = url.toJS;
    final jsPromise = web.window.fetch(jsUrl, init);

    // Convert JSPromise<Response> -> Dart Future<Response>
    final response = await jsPromise.toDart.timeout(
      timeout,
      onTimeout: () {
        // abort the fetch if timed out
        try {
          controller.abort();
        } catch (_) {}
        throw TimeoutException('fetch timeout');
      },
    );

    // response.status is a Dart int via package:web typed bindings
    final status = response.status;
    return status >= 200 && status < 400;
  } catch (_) {
    return false;
  }
}

class OmniConnectivityImpl {
  static const Duration _defaultInterval = Duration(seconds: 10);

  // Keep Dart Uri here (do not mix with JS types)
  List<InternetCheckOption> _options = [
    InternetCheckOption(uri: Uri.parse('https://example.com/')),
  ];

  Duration _checkInterval = _defaultInterval;
  bool enableStrictCheck = false;
  InternetStatus? _lastStatus;
  Timer? _timerHandle;
  final StreamController<InternetStatus> _statusController =
      StreamController<InternetStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> init({
    List<InternetCheckOption>? options,
    Duration? checkInterval,
    bool? strict,
  }) async {
    if (options != null && options.isNotEmpty) _options = List.from(options);
    if (checkInterval != null) _checkInterval = checkInterval;
    if (strict != null) enableStrictCheck = strict;

    _statusController.onListen = _maybeEmitStatusUpdate;
    _statusController.onCancel = () {
      if (!_statusController.hasListener) {
        _connectivitySubscription?.cancel();
        _connectivitySubscription = null;
        _timerHandle?.cancel();
        _timerHandle = null;
        _lastStatus = null;
      }
    };
  }

  Future<bool> hasInternetAccess() async {
    final status = await checkOnce();
    return status == InternetStatus.connected;
  }

  Future<InternetStatus> checkOnce() async {
    if (_options.isEmpty) return InternetStatus.disconnected;
    final completer = Completer<InternetStatus>();
    int remaining = _options.length;
    int successCount = 0;

    for (final opt in _options) {
      // If the option provides a Dart-side customProbe, use that.
      // Otherwise, use the web fetch probe which accepts a Dart String and
      // only converts it to JS when calling fetch.
      final probe = opt.customProbe ??
          (() => _fetchProbe(opt.uri!.toString(), timeout: opt.timeout));
      unawaited(
        probe()
            .then((ok) {
              if (ok) successCount += 1;
            })
            .catchError((_) {})
            .whenComplete(() {
              remaining -= 1;
              if (completer.isCompleted) return;
              if (!enableStrictCheck && successCount > 0) {
                completer.complete(InternetStatus.connected);
              } else if (enableStrictCheck && remaining == 0) {
                completer.complete(
                  successCount == _options.length
                      ? InternetStatus.connected
                      : InternetStatus.disconnected,
                );
              } else if (!enableStrictCheck && remaining == 0) {
                completer.complete(
                  successCount > 0
                      ? InternetStatus.connected
                      : InternetStatus.disconnected,
                );
              }
            }),
      );
    }

    return completer.future;
  }

  Stream<InternetStatus> get onStatusChange {
    _startListeningToConnectivityChanges();
    return _statusController.stream;
  }

  void setIntervalAndResetTimer(Duration d) {
    _checkInterval = d;
    _timerHandle?.cancel();
    _timerHandle = Timer(_checkInterval, _maybeEmitStatusUpdate);
  }

  InternetStatus? get lastTryResults => _lastStatus;

  Future<void> _maybeEmitStatusUpdate() async {
    _startListeningToConnectivityChanges();
    _timerHandle?.cancel();

    final current = await checkOnce();
    if (!_statusController.hasListener) return;
    if (_lastStatus != current) _statusController.add(current);

    _timerHandle = Timer(_checkInterval, _maybeEmitStatusUpdate);
    _lastStatus = current;
  }

  void _startListeningToConnectivityChanges() {
    if (_connectivitySubscription != null) return;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      _,
    ) {
      if (_statusController.hasListener) _maybeEmitStatusUpdate();
    }, onError: (_) {});
  }
}

// Public instance consumed by api.dart via conditional import.
final OmniConnectivityImpl platformImpl = OmniConnectivityImpl();
