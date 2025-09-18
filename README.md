# omni\_connectivity

[![pub version](https://img.shields.io/badge/pub-v0.1.0-blue.svg)](https://pub.dev/) <!-- Replace with your pub.dev link -->
[![build status](https://img.shields.io/badge/build-passing-brightgreen.svg)](#) <!-- Replace with CI badge -->
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) <!-- Replace with your license -->

**Lightweight, platform-aware reachability / probe checker for Flutter (native + web).**
Check whether your app can reach the network or a specific service (TCP, TLS, HTTP/GraphQL, Web fetch, or a custom native handshake like QUIC/Rust) with a tiny API and minimal dependencies.

---

## Table of contents

* [Why `omni_connectivity`](#why-omni_connectivity)
* [Features](#features)
* [Install](#install)
* [Quick start](#quick-start)
* [Public API](#public-api)
* [Probe examples (copy-paste)](#probe-examples-copy-paste)
* [Web considerations & CORS](#web-considerations--cors)
* [Best practices](#best-practices)
* [Troubleshooting](#troubleshooting)
* [Contributing](#contributing)
* [License](#license)

---

## Why `omni_connectivity`

Many apps need more than a simple "is there any network" boolean. They need to know whether a *specific* service or protocol is reachable (TCP/TLS endpoint, HTTP/GraphQL endpoint, gRPC service, WebSocket, or custom native handshake). `omni_connectivity` is a tiny package designed to:

* Be platform-aware (native vs web).
* Keep dependencies minimal (no `http` or `grpc` required).
* Let you plug custom probes (FFI/MethodChannel/native code) for protocol-specific checks.
* Provide an ergonomic, static API that’s easy for developers to call anywhere.

---

## Features

* Static API: `OmniConnectivity.*` — easy to call from app code.
* Platform implementations:

  * Native: `Socket` / `SecureSocket` (no `http` required).
  * Web: `fetch` via `package:web` + `dart:js_interop` (typed interop).
* Flexible: `InternetCheckOption.customProbe` accepts any `Future<bool>` probe.
* `strict` mode: require all probes to succeed (or default: first success = connected).
* `onStatusChange` stream triggered by `connectivity_plus` events (used only as triggers; actual status relies on probes).

---

## Install

Add to your plugin/app `pubspec.yaml`:

```yaml
dependencies:
  omni_connectivity: ^0.0.1
```

When packaging your plugin, add your `omni_connectivity` package and export `lib/omni_connectivity.dart`.

---

## Quick start

```dart
import 'package:flutter/widgets.dart';
import 'package:omni_connectivity/omni_connectivity.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await OmniConnectivity.init(
    options: [
      // native-friendly TCP probe (Cloudflare)
      InternetCheckOption.fromHostPort('1.1.1.1', 443),
      // custom probe (native/FFI/MethodChannel)
      InternetCheckOption(
        uri: Uri.parse('custom://custom-service'),
        customProbe: () => myCustomProbe(),
      ),
    ],
    checkInterval: Duration(seconds: 8),
    strict: false,
  );

  final ok = await OmniConnectivity.hasInternetAccess();
  print('Has internet access: $ok');

  OmniConnectivity.onStatusChange.listen((status) {
    print('Connectivity changed: $status');
  });
}
```

---

## Public API

### `OmniConnectivity.init({ options, checkInterval, strict })`

Initialize/override configuration. Optional; if not called, reasonable defaults are used.

* `options` — `List<InternetCheckOption>` (probes to run).
* `checkInterval` — `Duration` between periodic checks.
* `strict` — `bool` (default `false`).

### `OmniConnectivity.hasInternetAccess() -> Future<bool>`

Convenience one-liner returning `true` when at least one probe succeeded (or all succeeded if `strict`).

### `OmniConnectivity.checkOnce() -> Future<InternetStatus>`

Runs the configured probes once and returns `InternetStatus.connected` or `InternetStatus.disconnected`.

### `OmniConnectivity.onStatusChange -> Stream<InternetStatus>`

Subscribe to connectivity state changes.

### `OmniConnectivity.setIntervalAndResetTimer(Duration d)`

Change polling interval and reset the timer.

### `OmniConnectivity.lastTryResults -> InternetStatus?`

Last known status (or `null` if no checks have been run).

---

## `InternetCheckOption`

Represents one probe:

```dart
class InternetCheckOption {
  final Uri? uri;
  final Duration timeout;
  final Future<bool> Function()? customProbe;

  const InternetCheckOption({ this.uri, this.timeout = const Duration(seconds: 3), this.customProbe });

  factory InternetCheckOption.fromHostPort(String host, int port, { Duration timeout = const Duration(seconds: 3) }) => ...;
}
```

* `fromHostPort(host, port)` is a convenience factory for native TCP probes.
* `customProbe` accepts any async function returning `bool` — ideal for FFI/MethodChannel native handshakes (QUIC, Rust, bincode), gRPC health RPCs, or application-layer checks.

---

## Probe examples (copy-paste)

### TCP probe (native)

```dart
import 'dart:io';

Future<bool> tcpProbe(String host, int port, { Duration timeout = const Duration(seconds: 2) }) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
```

### TLS probe (native)

```dart
import 'dart:io';

Future<bool> tlsProbe(String host, int port, { Duration timeout = const Duration(seconds: 3) }) async {
  try {
    final socket = await SecureSocket.connect(host, port, timeout: timeout, onBadCertificate: (_) => true);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
```

### HTTP HEAD probe (native, no `http` package)

```dart
import 'dart:io';
import 'dart:convert';

Future<bool> httpHeadProbe(Uri uri, { Duration timeout = const Duration(seconds: 3) }) async {
  final client = HttpClient();
  try {
    client.connectionTimeout = timeout;
    final req = await client.openUrl('HEAD', uri);
    final resp = await req.close().timeout(timeout);
    return resp.statusCode >= 200 && resp.statusCode < 400;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
```

### Fetch HEAD probe (web; CORS required)

```dart
// implemented inside web impl using package:web + dart:js_interop
Future<bool> fetchHeadProbe(String url, { Duration timeout = const Duration(seconds: 3) });
```

### gRPC probe (when you already depend on grpc)

```dart
import 'package:grpc/grpc.dart';

Future<bool> grpcProbe(String host, int port, { Duration timeout = const Duration(seconds: 3) }) async {
  final channel = ClientChannel(host, port: port, options: const ChannelOptions(credentials: ChannelCredentials.insecure()));
  try {
    await channel.getConnection().isReady.timeout(timeout);
    await channel.shutdown();
    return true;
  } catch (_) {
    try { await channel.shutdown(); } catch (_) {}
    return false;
  }
}
```

### Other native handshakes (recommended: MethodChannel or FFI)

Implement a small probe in native code / Rust that performs the handshake and returns `bool`. Expose it via `MethodChannel` and call it as a `customProbe`.

Dart:

```dart
Future<bool> otherProbe() async {
  // define any function that returns bool
}
```

---

## Web considerations & CORS

* Browser probes use `fetch` and are subject to **CORS**. The server must allow cross-origin HEAD/GET requests for probes to succeed from web builds.
* `dart:io` sockets are unavailable on web — web builds must use `fetch` or a custom web-friendly probe.
* Prefer to probe endpoints you control (CORS-enabled) for reliable web behavior.

---

## Best practices

* Keep probe timeouts short (1–3s) to avoid blocking UI.
* Use TCP/TLS probes for fast reachability checks (native).
* Use `customProbe` for app-layer validation or protocol-specific handshakes.
* Use `strict = true` only when all endpoints are under your control.
* Allow consumers of your plugin to override default endpoints (don’t hardcode public IPs as single source of truth).

---

## Troubleshooting

* **Web probes fail with CORS errors** — ensure the endpoint returns `Access-Control-Allow-Origin: *` (or your origin) and allows HEAD/GET.
* **Probe flaky on some networks** — corporate or captive networks may block public DNS or certain IPs. Make endpoints configurable and prefer application-layer health endpoints you control.

---

## Contributing

Contributions welcome! 

Please open issues or PRs. Follow the existing style and add tests for new behaviors.

If you liked the package, then please give it a Like 👍🏼 and Star ⭐ on GitHub.

---

## License

Choose a license for your project. Example: **MIT**. Add a `LICENSE` file to the repository.

---

## A final note

`omni_connectivity` is meant to be a small, focused plugin: a developer-friendly, cross-platform probe abstraction. It keeps the core dependency-free for protocol-specific checks and lets apps plug in the exact probe they need (TCP, HTTP, gRPC, any binary protocol you made).

## 👨‍💻 Author

[![Sumit Kumar](https://github.com/sumitsharansatsangi.png?size=100)](https://github.com/sumitsharansatsangi)  
**[Sumit Kumar](https://github.com/sumitsharansatsangi)**  