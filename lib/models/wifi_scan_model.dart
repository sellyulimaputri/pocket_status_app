import 'dart:convert';

enum WifiScanPhase { idle, scanning, completed, error }

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.channel,
    required this.security,
    required this.index,
    required this.total,
  });

  final String ssid;
  final int rssi;
  final int channel;
  final String security;
  final int index;
  final int total;

  String get displaySsid => ssid.trim().isEmpty ? 'Hidden network' : ssid;

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: _stringValue(json['ssid']),
      rssi: _intValue(json['rssi']),
      channel: _intValue(json['channel']),
      security: _stringValue(json['security'], fallback: 'Unknown'),
      index: _intValue(json['index']),
      total: _intValue(json['total']),
    );
  }
}

class BleDeviceStatus {
  const BleDeviceStatus({
    required this.state,
    required this.wifiConnected,
    required this.scanId,
    this.wifiConfigured,
    this.wifiConnecting,
    this.ssid,
  });

  final String state;
  final bool? wifiConnected;
  final int? scanId;
  final bool? wifiConfigured;
  final bool? wifiConnecting;
  final String? ssid;

  factory BleDeviceStatus.fromJson(Map<String, dynamic> json) {
    return BleDeviceStatus(
      state: _stringValue(json['state'], fallback: 'unknown'),
      wifiConnected: _nullableBool(json['wifi_connected'] ?? json['connected']),
      scanId: _nullableIntValue(json['scan_id']),
      wifiConfigured: _nullableBool(
        json['wifi_configured'] ?? json['configured'],
      ),
      wifiConnecting: _nullableBool(
        json['wifi_connecting'] ?? json['connecting'],
      ),
      ssid: _nullableString(json['wifi_ssid'] ?? json['ssid']),
    );
  }
}

class WifiScanState {
  const WifiScanState({
    this.phase = WifiScanPhase.idle,
    this.networks = const [],
    this.scanId,
    this.errorMessage,
    this.deviceStatus,
    this.expectedTotal,
  });

  final WifiScanPhase phase;
  final List<WifiNetwork> networks;
  final int? scanId;
  final String? errorMessage;
  final BleDeviceStatus? deviceStatus;
  final int? expectedTotal;

  WifiScanState copyWith({
    WifiScanPhase? phase,
    List<WifiNetwork>? networks,
    int? scanId,
    String? errorMessage,
    bool clearError = false,
    BleDeviceStatus? deviceStatus,
    int? expectedTotal,
  }) {
    return WifiScanState(
      phase: phase ?? this.phase,
      networks: networks ?? this.networks,
      scanId: scanId ?? this.scanId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      expectedTotal: expectedTotal ?? this.expectedTotal,
    );
  }
}

Map<String, dynamic>? decodeWifiBleEvent(List<int> value) {
  try {
    final decoded = jsonDecode(utf8.decode(value, allowMalformed: false));
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  } on JsonUnsupportedObjectError {
    return null;
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

int _intValue(Object? value) {
  return value is int ? value : int.tryParse('$value') ?? 0;
}

int? _nullableIntValue(Object? value) {
  if (value is int) return value;
  return value == null ? null : int.tryParse('$value');
}

bool? _nullableBool(Object? value) {
  return value is bool ? value : null;
}

String? _nullableString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}
