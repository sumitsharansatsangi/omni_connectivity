import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omni_connectivity/omni_connectivity.dart';

import 'dart:io';

Future<bool> tcpProbe(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OmniConnectivity.init(
    options: [
      // InternetCheckOption.fromHostPort('1.1.1.1', 443),
      InternetCheckOption(
        customProbe: () => tcpProbe('1.1.1.1', 53),
      ), // you have to use only one of these too, we have  use this to just for showcase, but you will have option to use multiple options
    ],
    checkInterval: Duration(seconds: 8),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'unknown';
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _check();
    _sub = OmniConnectivity.onStatusChange.listen((s) {
      setState(() => _status = s.toString());
    });
  }

  Future<void> _check() async {
    final ok = await OmniConnectivity.hasInternetAccess();
    setState(() => _status = ok ? 'connected' : 'disconnected');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('OmniConnectivity example')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status: $_status'),
              ElevatedButton(onPressed: _check, child: const Text('Check now')),
            ],
          ),
        ),
      ),
    );
  }
}
