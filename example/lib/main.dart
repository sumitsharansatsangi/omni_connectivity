import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omni_connectivity/omni_connectivity.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OmniConnectivity.init(
    options: [
      InternetCheckOption.fromHostPort('1.1.1.1', 443),
      InternetCheckOption.fromHostPort('8.8.8.8', 53),
    ],
    checkInterval: const Duration(seconds: 8),
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
  List<InternetTransport> _transports = OmniConnectivity.lastKnownTransports;
  StreamSubscription<InternetStatus>? _statusSub;
  StreamSubscription<List<InternetTransport>>? _transportSub;

  @override
  void initState() {
    super.initState();
    _check();
    _statusSub = OmniConnectivity.onStatusChange.listen((status) {
      setState(() => _status = status.name);
    });
    _transportSub = OmniConnectivity.onTransportChange.listen((transports) {
      setState(() => _transports = transports);
    });
  }

  Future<void> _check() async {
    final ok = await OmniConnectivity.hasInternetAccess();
    setState(() {
      _status = ok ? 'connected' : 'disconnected';
      _transports = OmniConnectivity.lastKnownTransports;
    });
  }

  String get _transportText {
    if (_transports.isEmpty) {
      return 'unknown';
    }
    return _transports.map((transport) => transport.name).join(', ');
  }

  IconData _iconForTransport(InternetTransport transport) {
    switch (transport) {
      case InternetTransport.none:
        return Icons.portable_wifi_off;
      case InternetTransport.wifi:
        return Icons.wifi;
      case InternetTransport.mobile:
        return Icons.network_cell;
      case InternetTransport.ethernet:
        return Icons.settings_ethernet;
      case InternetTransport.bluetooth:
        return Icons.bluetooth;
      case InternetTransport.vpn:
        return Icons.vpn_lock;
      case InternetTransport.satellite:
        return Icons.satellite_alt;
      case InternetTransport.other:
        return Icons.device_hub;
    }
  }

  String _labelForTransport(InternetTransport transport) {
    switch (transport) {
      case InternetTransport.none:
        return 'None';
      case InternetTransport.wifi:
        return 'Wi-Fi';
      case InternetTransport.mobile:
        return 'Mobile';
      case InternetTransport.ethernet:
        return 'Ethernet';
      case InternetTransport.bluetooth:
        return 'Bluetooth';
      case InternetTransport.vpn:
        return 'VPN';
      case InternetTransport.satellite:
        return 'Satellite';
      case InternetTransport.other:
        return 'Other';
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _transportSub?.cancel();
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
              const SizedBox(height: 8),
              Text('Transport: $_transportText'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _transports
                    .map(
                      (transport) => Chip(
                        avatar: Icon(_iconForTransport(transport), size: 18),
                        label: Text(_labelForTransport(transport)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _check, child: const Text('Check now')),
            ],
          ),
        ),
      ),
    );
  }
}
