import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/wifi_scan_model.dart';
import 'bluetooth_service.dart';

class WifiScannerService extends ChangeNotifier {
  static final Guid serviceUuid = Guid('7b5e0001-4f4f-4f4f-8b5a-000000000001');
  static final Guid commandUuid = Guid('7b5e0002-4f4f-4f4f-8b5a-000000000001');
  static final Guid dataUuid = Guid('7b5e0003-4f4f-4f4f-8b5a-000000000001');
  static final Guid statusUuid = Guid('7b5e0004-4f4f-4f4f-8b5a-000000000001');

  final BleService _bleService;
  WifiScanState _state = const WifiScanState();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _command;
  BluetoothCharacteristic? _data;
  BluetoothCharacteristic? _status;
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<List<int>>? _statusSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _scanTimeout;
  Timer? _configurationTimeout;
  final Set<String> _receivedResultKeys = <String>{};
  bool _scanCommandInFlight = false;
  bool _configurationInFlight = false;
  bool _disposed = false;

  WifiScannerService({BleService? bleService})
    : _bleService = bleService ?? BleService.instance;

  WifiScanState get state => _state;
  bool get isReady => _command != null && _data != null && _status != null;
  bool get isConfiguring => _configurationInFlight;

  Future<void> connectToCurrentDevice() async {
    final device = _bleService.connectedDevice;
    if (device == null) {
      _setError(
        'Hubungkan PocketStatus melalui menu perangkat terlebih dahulu.',
      );
      return;
    }
    if (_device == device && isReady) return;

    await _cancelSubscriptions();
    _device = device;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final mtu = await device.requestMtu(247);
          debugPrint('[BLE] MTU requested 247 / negotiated $mtu');
        } catch (error) {
          debugPrint('[BLE] MTU request failed: $error');
        }
      }

      final services = await device.discoverServices();
      final service = _findService(services, serviceUuid);
      if (service == null) {
        throw StateError('Service PocketStatus tidak ditemukan.');
      }

      _command = _findCharacteristic(service, commandUuid);
      _data = _findCharacteristic(service, dataUuid);
      _status = _findCharacteristic(service, statusUuid);
      if (_command == null || _data == null || _status == null) {
        throw StateError(
          'Characteristic Command, Data, atau Status tidak lengkap.',
        );
      }
      if (!_command!.properties.write &&
          !_command!.properties.writeWithoutResponse) {
        throw StateError('Characteristic Command tidak mendukung WRITE.');
      }
      if (!_data!.properties.notify) {
        throw StateError('Characteristic Data tidak mendukung NOTIFY.');
      }
      if (!_status!.properties.notify && !_status!.properties.read) {
        throw StateError('Characteristic Status tidak mendukung READ/NOTIFY.');
      }

      debugPrint('[BLE] Service ditemukan: ${service.uuid}');
      debugPrint('[BLE] Command ditemukan: ${_command!.uuid}');
      debugPrint('[BLE] Data ditemukan: ${_data!.uuid}');
      debugPrint('[BLE] Status ditemukan: ${_status!.uuid}');

      _dataSubscription = _data!.onValueReceived.listen(_handleData);
      await _data!.setNotifyValue(true);
      debugPrint('[BLE] Data notifications enabled');

      if (_status!.properties.notify) {
        _statusSubscription = _status!.onValueReceived.listen(_handleStatus);
        await _status!.setNotifyValue(true);
        debugPrint('[BLE] Status notifications enabled');
      }

      _connectionSubscription = device.connectionState.listen((
        connectionState,
      ) {
        if (connectionState == BluetoothConnectionState.disconnected) {
          _handleDisconnected();
        }
      });
      try {
        _handleStatus(await _status!.read());
      } catch (error) {
        debugPrint('[BLE] Status read gagal: $error');
      }
      _clearError();
    } catch (error) {
      debugPrint('[BLE] Gagal menyiapkan Wi-Fi scanner: $error');
      await _cancelSubscriptions();
      _command = null;
      _data = null;
      _status = null;
      _setError(_friendlyError(error));
    }
  }

  Future<void> scanWifi() async {
    if (_scanCommandInFlight || _state.phase == WifiScanPhase.scanning) return;
    if (!isReady) await connectToCurrentDevice();
    final command = _command;
    if (command == null) return;

    try {
      _state = _state.copyWith(phase: WifiScanPhase.scanning, clearError: true);
      _scanCommandInFlight = true;
      _scanTimeout?.cancel();
      _scanTimeout = Timer(const Duration(seconds: 45), () {
        if (_state.phase == WifiScanPhase.scanning) {
          _setError('Pemindaian Wi-Fi melewati batas waktu.');
        }
      });
      _notify();
      final withoutResponse = !command.properties.write;
      debugPrint('[BLE TX] SCAN_WIFI');
      await command.write(
        'SCAN_WIFI'.codeUnits,
        withoutResponse: withoutResponse,
      );
    } catch (error) {
      _scanTimeout?.cancel();
      _setError('Gagal mengirim SCAN_WIFI: ${_friendlyError(error)}');
    } finally {
      _scanCommandInFlight = false;
    }
  }

  Future<void> requestStatus() => _sendCommand('GET_STATUS');

  Future<void> requestWifiConfig() => _sendCommand('GET_WIFI_CONFIG');

  Future<void> clearWifiConfiguration() => _sendCommand('CLEAR_WIFI');

  Future<void> configureWifi({
    required String ssid,
    required String password,
  }) async {
    final trimmedSsid = ssid.trim();
    if (trimmedSsid.isEmpty) {
      _setError('Pilih jaringan Wi-Fi terlebih dahulu.');
      return;
    }
    if (_configurationInFlight) return;
    if (!isReady) await connectToCurrentDevice();
    final command = _command;
    if (command == null) return;

    _configurationInFlight = true;
    _configurationTimeout?.cancel();
    _configurationTimeout = Timer(const Duration(seconds: 30), () {
      if (_configurationInFlight) {
        _configurationInFlight = false;
        _setError('Perangkat tidak merespons konfigurasi Wi-Fi.');
      }
    });
    _notify();

    try {
      final payload = jsonEncode({
        'command': 'SET_WIFI',
        'ssid': trimmedSsid,
        'password': password,
      });
      debugPrint('[BLE TX] SET_WIFI for selected SSID');
      await command.write(
        utf8.encode(payload),
        withoutResponse: !command.properties.write,
      );
    } catch (error) {
      _configurationTimeout?.cancel();
      _configurationInFlight = false;
      _setError('Gagal menyimpan konfigurasi Wi-Fi: ${_friendlyError(error)}');
    }
  }

  Future<void> _sendCommand(String commandText) async {
    final command = _command;
    if (command == null) {
      _setError('Koneksi BLE belum siap.');
      return;
    }
    try {
      debugPrint('[BLE TX] $commandText');
      await command.write(
        commandText.codeUnits,
        withoutResponse: !command.properties.write,
      );
    } catch (error) {
      _setError('Gagal mengirim $commandText: ${_friendlyError(error)}');
    }
  }

  void _handleData(List<int> value) => _handlePayload(value, 'Data');

  void _handleStatus(List<int> value) => _handlePayload(value, 'Status');

  void _handlePayload(List<int> value, String source) {
    final event = decodeWifiBleEvent(value);
    if (event == null) {
      debugPrint('[BLE RX] JSON tidak valid dari $source');
      return;
    }

    final eventName = event['event'];
    if (eventName is! String) return;
    debugPrint('[BLE RX] $eventName');

    switch (eventName) {
      case 'scan_start':
        _scanTimeout?.cancel();
        _receivedResultKeys.clear();
        _state = WifiScanState(
          phase: WifiScanPhase.scanning,
          scanId: _nullableInt(event['scan_id']),
          expectedTotal: _nullableInt(event['total']),
        );
        _notify();
        break;
      case 'wifi_result':
        final eventScanId = _nullableInt(event['scan_id']);
        if (eventScanId == null ||
            (_state.scanId != null && eventScanId != _state.scanId) ||
            _state.phase != WifiScanPhase.scanning) {
          return;
        }
        final network = WifiNetwork.fromJson(event);
        final resultKey = _resultKey(eventScanId, network);
        if (!_receivedResultKeys.add(resultKey)) return;
        debugPrint('[BLE RX] wifi_result: ${network.displaySsid}');
        final networks = [..._state.networks, network];
        _state = _state.copyWith(
          phase: WifiScanPhase.scanning,
          networks: networks,
          scanId: eventScanId,
          expectedTotal: _nullableInt(event['total']),
          clearError: true,
        );
        _notify();
        break;
      case 'scan_complete':
        final eventScanId = _nullableInt(event['scan_id']);
        if (eventScanId == null ||
            (_state.scanId != null && eventScanId != _state.scanId)) {
          return;
        }
        debugPrint('[BLE RX] scan_complete');
        _scanTimeout?.cancel();
        _state = _state.copyWith(
          phase: WifiScanPhase.completed,
          scanId: eventScanId,
          expectedTotal: _nullableInt(event['total']),
        );
        _notify();
        break;
      case 'error':
        final code = event['code'] is String ? event['code'] as String : null;
        final message = event['message'] is String
            ? event['message'] as String
            : _errorMessageForCode(code);
        debugPrint('[BLE RX] error: ${code ?? 'unavailable'} - $message');
        _scanTimeout?.cancel();
        if (code == 'wifi_config_save_failed' ||
            code == 'invalid_wifi_config') {
          _configurationTimeout?.cancel();
          _configurationInFlight = false;
        }
        _setError(
          code == 'mtu_too_small'
              ? 'Payload Wi-Fi terlalu besar untuk MTU BLE perangkat '
                    '(${event['required'] ?? '?'} byte dibutuhkan, '
                    'tersedia ${event['available'] ?? '?'} byte).'
              : message,
        );
        break;
      case 'status':
      case 'wifi_status':
      case 'wifi_config':
      case 'wifi_config_saved':
      case 'wifi_config_cleared':
        if (eventName != 'status') {
          _configurationTimeout?.cancel();
          _configurationInFlight = false;
        }
        final status = BleDeviceStatus.fromJson(event);
        var phase = _state.phase;
        if (status.state == 'scanning' && phase == WifiScanPhase.idle) {
          phase = WifiScanPhase.scanning;
        }
        _state = _state.copyWith(deviceStatus: status, phase: phase);
        _notify();
        break;
    }
  }

  void _handleDisconnected() {
    _scanTimeout?.cancel();
    _configurationTimeout?.cancel();
    _configurationInFlight = false;
    _command = null;
    _data = null;
    _status = null;
    _receivedResultKeys.clear();
    _state = WifiScanState(
      phase: WifiScanPhase.error,
      errorMessage: 'PocketStatus terputus dari Bluetooth.',
    );
    _notify();
  }

  Future<void> disposeScanner() async {
    _scanTimeout?.cancel();
    _configurationTimeout?.cancel();
    await _cancelSubscriptions();
    _command = null;
    _data = null;
    _status = null;
  }

  Future<void> _cancelSubscriptions() async {
    await _dataSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _dataSubscription = null;
    _statusSubscription = null;
    _connectionSubscription = null;
  }

  BluetoothService? _findService(List<BluetoothService> services, Guid uuid) {
    for (final service in services) {
      if (service.uuid == uuid) return service;
    }
    return null;
  }

  BluetoothCharacteristic? _findCharacteristic(
    BluetoothService service,
    Guid uuid,
  ) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == uuid) return characteristic;
    }
    return null;
  }

  int? _nullableInt(Object? value) {
    if (value is int) return value;
    return value == null ? null : int.tryParse('$value');
  }

  void _setError(String message) {
    _scanTimeout?.cancel();
    _state = _state.copyWith(phase: WifiScanPhase.error, errorMessage: message);
    _notify();
  }

  String _resultKey(int scanId, WifiNetwork network) {
    return '$scanId|${network.ssid}|${network.rssi}|${network.channel}|'
        '${network.security}';
  }

  String _errorMessageForCode(String? code) {
    return switch (code) {
      'busy' => 'PocketStatus sedang menjalankan proses lain.',
      'scan_start_failed' => 'PocketStatus gagal memulai scan Wi-Fi.',
      'scan_failed' => 'PocketStatus gagal menyelesaikan scan Wi-Fi.',
      'unknown_command' => 'Perintah BLE belum didukung firmware.',
      'invalid_wifi_config' =>
        'SSID atau format konfigurasi Wi-Fi tidak valid.',
      'wifi_config_save_failed' =>
        'Konfigurasi Wi-Fi gagal disimpan perangkat.',
      null => 'Firmware mengembalikan error umum (kode tidak tersedia).',
      _ => 'Firmware mengembalikan error: $code',
    };
  }

  void _clearError() {
    _state = _state.copyWith(clearError: true);
    _notify();
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('FlutterBluePlusException: ', '');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanTimeout?.cancel();
    _configurationTimeout?.cancel();
    unawaited(_cancelSubscriptions());
    super.dispose();
  }
}
