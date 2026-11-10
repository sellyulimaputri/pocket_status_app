import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_status_1/models/wifi_scan_model.dart';

void main() {
  test('parses a single wifi result and keeps optional fields defensive', () {
    final event = decodeWifiBleEvent(
      utf8.encode(
        jsonEncode({
          'event': 'wifi_result',
          'scan_id': 4,
          'index': 0,
          'total': 1,
          'ssid': '',
          'rssi': -72,
          'channel': 11,
          'security': 'WPA2',
          'future_field': true,
        }),
      ),
    );

    expect(event, isNotNull);
    final network = WifiNetwork.fromJson(event!);
    expect(network.displaySsid, 'Hidden network');
    expect(network.rssi, -72);
    expect(network.channel, 11);
    expect(network.security, 'WPA2');
  });

  test('rejects malformed or non-object notification payloads', () {
    expect(decodeWifiBleEvent(utf8.encode('{bad json')), isNull);
    expect(decodeWifiBleEvent(utf8.encode('[]')), isNull);
  });

  test('status accepts optional and extra fields', () {
    final status = BleDeviceStatus.fromJson({
      'event': 'wifi_status',
      'state': 'wifi_connected',
      'configured': true,
      'connecting': false,
      'connected': true,
      'ssid': 'Pocket WiFi',
      'scan_id': 7,
      'extra': 'ignored',
    });

    expect(status.state, 'wifi_connected');
    expect(status.wifiConnected, isTrue);
    expect(status.wifiConfigured, isTrue);
    expect(status.wifiConnecting, isFalse);
    expect(status.ssid, 'Pocket WiFi');
    expect(status.scanId, 7);
  });
}
