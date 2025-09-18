// lib/src/impl_io.dart

import 'dart:async';
import 'dart:io' show Socket;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'api.dart'; // to reuse public types (InternetCheckOption, InternetStatus)

// Public implementation class
class OmniConnectivityImpl {
  static const Duration _defaultInterval = Duration(seconds: 10);

  List<InternetCheckOption> _options = [
    InternetCheckOption.fromHostPort('1.1.1.1', 443),
    InternetCheckOption.fromHostPort('8.8.8.8', 53),
  ];

  Duration _checkInterval = _defaultInterval;
  bool enableStrictCheck = false;
  InternetStatus? _lastStatus;
  Timer? _timerHandle;
  final StreamController<InternetStatus> _statusController =
      StreamController<InternetStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Public API expected by api.dart
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
      final probe = opt.customProbe;
      if (probe == null) {
        remaining -= 1;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(
            successCount > 0
                ? InternetStatus.connected
                : InternetStatus.disconnected,
          );
        }
        continue;
      }

      unawaited(
        probe().then((ok) {
          if (ok) successCount += 1;
        }).catchError((_) {
          // ignore
        }).whenComplete(() {
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

  /// Public helper for InternetCheckOption.fromHostPort factory.
  Future<bool> tcpProbe(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

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

// Public top-level instance referenced by api.dart via conditional import
final OmniConnectivityImpl platformImpl = OmniConnectivityImpl();
