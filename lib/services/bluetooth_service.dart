import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service untuk memindai, melakukan pairing, dan mengelola koneksi
/// perangkat Bluetooth Low Energy (BLE).
class BleService extends ChangeNotifier {
  BleService._();

  static final BleService instance = BleService._();

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _initStarted = false;

  // --- VARIABEL PENAMPUNG DATA ESP32 ---
  bool _isEspWifiConnected = false;
  String _espWifiSsid = "";
  String _espWifiIp = "";
  bool _hasEspStatus = false; // true setelah ESP membalas status minimal sekali
  List<Map<String, dynamic>> _scannedWifiList = [];
  bool _isEspScanningWifi = false;

  // Getters agar bisa dibaca oleh UI
  bool get isEspWifiConnected => _isEspWifiConnected;
  String get espWifiSsid => _espWifiSsid;
  String get espWifiIp => _espWifiIp;
  bool get hasEspStatus => _hasEspStatus;
  List<Map<String, dynamic>> get scannedWifiList => _scannedWifiList;
  bool get isEspScanningWifi => _isEspScanningWifi;

  // --- KONFIGURASI UUID ESP32 ---
  final String _serviceUuid = "7b5e0001-4f4f-4f4f-8b5a-000000000001";
  final String _cmdCharacteristicUuid = "7b5e0002-4f4f-4f4f-8b5a-000000000001";
  final String _dataCharacteristicUuid = "7b5e0003-4f4f-4f4f-8b5a-000000000001";

  BluetoothCharacteristic? _cmdCharacteristic;
  BluetoothCharacteristic? _dataCharacteristic;
  StreamSubscription<List<int>>? _dataSubscription;
  String _rxBuffer = ""; // penampung JSON yang datang terpotong-potong
  String? _errorMessage;

  BluetoothAdapterState get adapterState => _adapterState;
  bool get isBluetoothOn => _adapterState == BluetoothAdapterState.on;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;

  /// Bersihkan semua data ESP32 + listener (dipanggil saat BLE putus).
  void _resetEspState() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _cmdCharacteristic = null;
    _dataCharacteristic = null;
    _rxBuffer = "";

    _hasEspStatus = false;
    _isEspWifiConnected = false;
    _espWifiSsid = "";
    _espWifiIp = "";
    _scannedWifiList = [];
    _isEspScanningWifi = false;
  }

  /// Inisialisasi plugin dilakukan saat pertama kali dibutuhkan supaya
  /// aplikasi tetap aman berjalan di platform yang tidak mendukung BLE
  /// (misalnya saat widget test).
  Future<bool> _initIfNeeded() async {
    if (_initStarted) return true;

    try {
      if (!await FlutterBluePlus.isSupported) return false;
    } catch (e) {
      debugPrint('Bluetooth tidak tersedia: $e');
      return false;
    }

    try {
      FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        if (state != BluetoothAdapterState.on) {
          _scanResults = [];
        }
        notifyListeners();
      });

      FlutterBluePlus.isScanning.listen((scanning) {
        _isScanning = scanning;
        notifyListeners();
      });

      FlutterBluePlus.scanResults.listen((results) {
        _scanResults = List<ScanResult>.from(results)
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        notifyListeners();
      });

      FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
        if (_connectedDevice != null && event.device == _connectedDevice) {
          if (event.connectionState == BluetoothConnectionState.disconnected) {
            _connectedDevice = null;
            _resetEspState();
            notifyListeners();
          }
        }
      });

      _initStarted = true;
      return true;
    } catch (e) {
      debugPrint('Gagal inisialisasi Bluetooth: $e');
      return false;
    }
  }

  Future<BluetoothAdapterState> _currentAdapterState() async {
    if (_adapterState != BluetoothAdapterState.unknown) {
      return _adapterState;
    }

    try {
      return await FlutterBluePlus.adapterState
          .firstWhere((state) => state != BluetoothAdapterState.unknown)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return _adapterState;
    }
  }

  /// Nama perangkat yang aman untuk ditampilkan.
  String deviceName(BluetoothDevice device) {
    final platformName = device.platformName.trim();
    if (platformName.isNotEmpty) return platformName;

    final advName = device.advName.trim();
    if (advName.isNotEmpty) return advName;

    return 'Perangkat tanpa nama';
  }

  /// Minta izin Bluetooth lalu mulai memindai perangkat di sekitar.
  Future<void> startScan() async {
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await _initIfNeeded()) {
        _errorMessage =
            'Bluetooth tidak tersedia di platform ini atau perangkat tidak mendukung BLE.';
        notifyListeners();
        return;
      }

      if (!await _ensurePermissions()) {
        _errorMessage =
            'Izin Bluetooth ditolak. Aktifkan izin Bluetooth di pengaturan aplikasi.';
        notifyListeners();
        return;
      }

      _adapterState = await _currentAdapterState();
      if (_adapterState == BluetoothAdapterState.unauthorized) {
        _errorMessage =
            'Izin Bluetooth ditolak. Aktifkan izin Bluetooth di pengaturan aplikasi.';
        notifyListeners();
        return;
      }

      if (_adapterState == BluetoothAdapterState.unavailable) {
        _errorMessage =
            'Bluetooth tidak tersedia di perangkat ini atau perangkat tidak mendukung BLE.';
        notifyListeners();
        return;
      }

      if (!isBluetoothOn) {
        // Banner "Bluetooth mati" yang akan ditampilkan oleh dialog.
        notifyListeners();
        return;
      }

      _scanResults = [];
      notifyListeners();

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 8),
      );
    } catch (e) {
      _errorMessage = 'Gagal memindai perangkat: ${_friendlyError(e)}';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Abaikan jika scan memang sudah berhenti.
    }
  }

  /// Membuka dialog sistem untuk menyalakan Bluetooth (Android).
  Future<void> turnOnBluetooth() async {
    _errorMessage = null;
    notifyListeners();

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await FlutterBluePlus.turnOn();
      } else {
        _errorMessage = 'Nyalakan Bluetooth secara manual dari pengaturan.';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal menyalakan Bluetooth: ${_friendlyError(e)}';
      notifyListeners();
    }
  }

  /// Connect ke perangkat lalu memicu proses pairing/bonding (Android).
  Future<BluetoothDevice?> pairDevice(BluetoothDevice device) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FlutterBluePlus.stopScan();

      final previousDevice = _connectedDevice;
      if (previousDevice != null && previousDevice != device) {
        try {
          await previousDevice.disconnect();
        } catch (_) {
          // Abaikan kegagalan disconnect perangkat sebelumnya.
        }
        _resetEspState();
      }

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 25),
        // MTU besar supaya JSON daftar Wi-Fi dari ESP tidak terpotong.
        mtu: 512,
      );

      // Android: munculkan dialog pairing sistem (PIN/konfirmasi).
      // iOS tidak membutuhkan bonding manual.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await device.createBond(timeout: 60);
        } catch (e) {
          debugPrint('Bluetooth bonding dilewati: $e');
        }
      }

      _connectedDevice = device;

      // --- CARI SERVICE & SETUP NOTIFY ---
      try {
        final services = await device.discoverServices();
        for (final service in services) {
          if (service.uuid.toString().toLowerCase() !=
              _serviceUuid.toLowerCase()) {
            continue;
          }

          for (final char in service.characteristics) {
            final cUuid = char.uuid.toString().toLowerCase();

            if (cUuid == _cmdCharacteristicUuid.toLowerCase()) {
              _cmdCharacteristic = char;
            } else if (cUuid == _dataCharacteristicUuid.toLowerCase()) {
              _dataCharacteristic = char;

              // Batalkan listener lama supaya balasan tidak diproses dobel.
              await _dataSubscription?.cancel();
              _rxBuffer = "";

              // Pasang listener dulu, baru aktifkan notify.
              _dataSubscription = char.onValueReceived.listen(_onDataReceived);
              await char.setNotifyValue(true);
            }
          }
        }

        if (_cmdCharacteristic == null || _dataCharacteristic == null) {
          debugPrint('Characteristic ESP32 tidak ditemukan. Cek UUID.');
        }
      } catch (e) {
        debugPrint("Gagal setup characteristics: $e");
      }
      // ------------------------------------

      return device;
    } catch (e) {
      _errorMessage =
          'Gagal pairing dengan ${deviceName(device)}: ${_friendlyError(e)}';
      return null;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Memproses data notify dari ESP32. JSON bisa datang terpotong-potong,
  /// jadi potongan digabung dulu sampai bisa di-decode.
  void _onDataReceived(List<int> value) {
    if (value.isEmpty) return;

    final chunk = utf8.decode(value, allowMalformed: true);

    // Pesan baru selalu diawali '{' -> buang sisa buffer yang rusak.
    if (chunk.trimLeft().startsWith('{')) {
      _rxBuffer = chunk;
    } else {
      _rxBuffer += chunk;
    }

    if (_rxBuffer.length > 8192) {
      _rxBuffer = "";
      return;
    }

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(_rxBuffer);
      if (decoded is! Map<String, dynamic>) return;
      data = decoded;
    } catch (_) {
      // Belum lengkap, tunggu potongan berikutnya.
      return;
    }

    debugPrint("Balasan ESP32: $_rxBuffer");
    _rxBuffer = "";

    final event = data['event'];

    if (event == 'status') {
      // Contoh: {"event":"status","status":"connected","ssid":"Biznet","ip":"192.168.1.12"}
      _isEspWifiConnected = data['status'] == 'connected';
      _espWifiSsid = (data['ssid'] ?? "").toString();
      _espWifiIp = (data['ip'] ?? "").toString();
      _hasEspStatus = true;
      notifyListeners();
    } else if (event == 'scan_start') {
      _isEspScanningWifi = true;
      notifyListeners();
    } else if (event == 'scan_result') {
      // Contoh: {"event":"scan_result","networks":[{"ssid":"Kosan","rssi":-50,"secure":true}]}
      final networks = data['networks'];
      if (networks is List) {
        _scannedWifiList = networks
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      _isEspScanningWifi = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device == null) return;

    try {
      await device.disconnect();
    } catch (_) {
      // Tetap reset state lokal meskipun perangkat sudah tidak terjangkau.
    }

    _connectedDevice = null;
    _resetEspState();
    notifyListeners();
  }

  Future<bool> _ensurePermissions() async {
    if (kIsWeb) return true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final scanGranted =
          statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectGranted =
          statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locationGranted =
          statuses[Permission.locationWhenInUse]?.isGranted ?? false;

      // Android 12+: butuh izin Scan + Connect.
      // Android 11 ke bawah: butuh izin lokasi.
      return (scanGranted && connectGranted) || locationGranted;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('android-only')) {
      return 'Fitur ini hanya tersedia di Android.';
    }
    return text.replaceFirst('FlutterBluePlusException: ', '');
  }

  /// Fungsi untuk mengirim perintah JSON ke ESP32
  Future<bool> sendJsonCommand(String jsonString) async {
    if (_cmdCharacteristic == null) {
      _errorMessage = "Koneksi ke perangkat belum sempurna.";
      notifyListeners();
      return false;
    }

    try {
      // Ubah teks JSON menjadi byte (UTF-8) sebelum dikirim
      final bytes = utf8.encode(jsonString);
      // Kirim ke Characteristic 0002 (Write)
      await _cmdCharacteristic!.write(bytes, withoutResponse: false);
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengirim perintah: ${_friendlyError(e)}';
      notifyListeners();
      return false;
    }
  }

  /// Meminta ESP32 mengirimkan status koneksinya saat ini
  Future<void> checkEspStatus() async {
    await sendJsonCommand('{"action": "get_status"}');
  }

  /// Menyuruh ESP32 memindai jaringan Wi-Fi di sekitar
  Future<void> scanEspWifi() async {
    _isEspScanningWifi = true;
    _scannedWifiList = []; // Bersihkan daftar lama
    notifyListeners();

    final ok = await sendJsonCommand('{"action": "scan_wifi"}');
    if (!ok) {
      _isEspScanningWifi = false;
      notifyListeners();
    }
  }

  /// Mengirim kredensial Wi-Fi baru ke ESP32
  Future<void> connectEspToWifi(String ssid, String password) async {
    // jsonEncode otomatis meng-escape karakter spesial (", \, dll).
    final payload = jsonEncode({
      "action": "set_wifi",
      "ssid": ssid,
      "pass": password,
    });
    await sendJsonCommand(payload);
  }
}