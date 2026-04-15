# omni_connectivity

[![pub version](https://img.shields.io/pub/v/omni_connectivity.svg)](https://pub.dev/packages/omni_connectivity)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Lightweight, platform-aware reachability checks for Flutter apps.

This package answers a practical question: can my app reach the endpoint(s) that matter to my business logic?

It supports:
- native socket probes (TCP) through `fromHostPort`
- browser `fetch` probes on web
- custom probe functions for protocol-specific checks (gRPC health, backend ping, MethodChannel/FFI handshake, etc.)
- exposing current transport type(s) like Wi-Fi, mobile, ethernet, VPN, or none

## Why this package

`connectivity_plus` tells you when network interfaces change.

`omni_connectivity` tells you whether your configured probe targets are actually reachable, and it gives you a single static API to check once or monitor changes over time.

## Features

- Simple static API: `OmniConnectivity.*`
- Multiple probe targets per check
- `strict` mode support:
  - `strict: false` (default): connected if any probe succeeds
  - `strict: true`: connected only if all probes succeed
- Change stream based on connectivity events + periodic probe checks
- Works across native and web with platform-appropriate behavior
- Transport visibility via `lastKnownTransports` and `onTransportChange`

## Installation

```yaml
dependencies:
  omni_connectivity: ^0.2.0
```

Then import:

```dart
import 'package:omni_connectivity/omni_connectivity.dart';
```

## Quick start

`OmniConnectivity.init()` is optional. Call it only when you want custom options, interval, or strict behavior.

```dart
import 'package:flutter/widgets.dart';
import 'package:omni_connectivity/omni_connectivity.dart';

Future<bool> myBackendHealthProbe() async {
  // Add your own app-specific check here.
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await OmniConnectivity.init(
    options: [
      // Native TCP probe.
      InternetCheckOption.fromHostPort('1.1.1.1', 443),
      // Custom app/service probe.
      InternetCheckOption(
        uri: Uri.parse('https://api.example.com/health'),
        customProbe: myBackendHealthProbe,
      ),
    ],
    checkInterval: const Duration(seconds: 8),
    strict: false,
  );

  final hasAccess = await OmniConnectivity.hasInternetAccess();
  print('has internet access: $hasAccess');

  OmniConnectivity.onStatusChange.listen((status) {
    print('status changed: $status');
  });

  OmniConnectivity.onTransportChange.listen((transports) {
    print('transport changed: $transports');
  });
}
```

## Public API

### `OmniConnectivity.init({ options, checkInterval, strict })`

Optional initialization. If not called, built-in defaults are used.

- `options`: `List<InternetCheckOption>`
- `checkInterval`: `Duration` between periodic checks
- `strict`: `bool`, default `false`

### `OmniConnectivity.hasInternetAccess() -> Future<bool>`

Returns `true` when probe evaluation resolves to connected.

### `OmniConnectivity.checkOnce() -> Future<InternetStatus>`

Runs the current probes once and returns:
- `InternetStatus.connected`
- `InternetStatus.disconnected`

### `OmniConnectivity.onStatusChange -> Stream<InternetStatus>`

Broadcast stream of connectivity status changes.

### `OmniConnectivity.onTransportChange -> Stream<List<InternetTransport>>`

Broadcast stream of transport type changes.

Example values include:
- `InternetTransport.wifi`
- `InternetTransport.mobile`
- `InternetTransport.ethernet`
- `InternetTransport.vpn`
- `InternetTransport.satellite`
- `InternetTransport.none`

### `OmniConnectivity.setIntervalAndResetTimer(Duration d)`

Updates polling interval and resets internal timer.

### `OmniConnectivity.lastTryResults -> InternetStatus?`

Returns last computed status, or `null` before first check.

### `OmniConnectivity.lastKnownTransports -> List<InternetTransport>`

Returns last known transport type list. Defaults to `[InternetTransport.none]` before first connectivity update.

## InternetCheckOption

```dart
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
  });
}
```

- Use `fromHostPort` for native TCP checks.
- Use `customProbe` for fully custom logic.
- On web, when `customProbe` is not provided, the implementation uses `fetch` against `uri`.

## Platform behavior

| Platform | Default probe behavior |
| --- | --- |
| Native (Android/iOS/macOS/Linux/Windows) | Uses configured probe callbacks. `fromHostPort` performs TCP socket checks. |
| Web | Uses `fetch` (`HEAD`) for options with `uri` when `customProbe` is not provided. |

## Web and CORS

- Browser probes are subject to CORS.
- Ensure probed endpoints allow your origin and support request methods used by health checks.
- Prefer probing endpoints you control for predictable behavior.

## Best practices

- Keep probe timeouts short (typically 1-3 seconds).
- Probe business-relevant endpoints, not just public DNS/IP targets.
- Use `strict: true` only when all endpoints must be reachable for your app to operate.
- Keep probe targets configurable for different environments.

## Development guide

### Prerequisites

- Flutter SDK `>=3.7.0`
- Dart SDK `>=3.2.0 <4.0.0`

### Local setup

```bash
flutter pub get
```

### Run tests

```bash
flutter test
```

### Run a single test file

```bash
flutter test test/probe_runner_test.dart
```

## Example app

An example Flutter app is available in the `example/` folder.

Run it with:

```bash
cd example
flutter pub get
flutter run
```

## Contributing

Contributions are welcome.

Please:
- open an issue for bugs or feature requests
- keep changes scoped and documented
- add or update tests when behavior changes

## License

MIT License. See [LICENSE](LICENSE).

## Author

[Sumit Kumar](https://github.com/sumitsharansatsangi)