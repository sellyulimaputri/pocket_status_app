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
  String? _errorMessage;

  BluetoothAdapterState get adapterState => _adapterState;
  bool get isBluetoothOn => _adapterState == BluetoothAdapterState.on;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;

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
      }

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 25),
        mtu: null,
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

  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device == null) return;

    try {
      await device.disconnect();
    } catch (_) {
      // Tetap reset state lokal meskipun perangkat sudah tidak terjangkau.
    }

    _connectedDevice = null;
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
}
