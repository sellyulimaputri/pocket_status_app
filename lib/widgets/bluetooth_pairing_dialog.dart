import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/bluetooth_service.dart';

class BluetoothPairingDialog extends StatefulWidget {
  const BluetoothPairingDialog({super.key});

  /// Membuka dialog pairing dan mengembalikan perangkat yang dipilih.
  static Future<BluetoothDevice?> show(BuildContext context) {
    return showDialog<BluetoothDevice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BluetoothPairingDialog(),
    );
  }

  @override
  State<BluetoothPairingDialog> createState() => _BluetoothPairingDialogState();
}

class _BluetoothPairingDialogState extends State<BluetoothPairingDialog> {
  static const Color _accent = Color(0xFF2F80ED);

  final BleService _service = BleService.instance;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    // Hentikan scan supaya tidak boros daya setelah dialog ditutup.
    _service.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (!mounted) return;
    setState(() => _selectedId = null);
    await _service.startScan();
  }

  Future<void> _pair(ScanResult result) async {
    final device = await _service.pairDevice(result.device);
    if (!mounted) return;
    if (device != null) {
      Navigator.of(context).pop(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListenableBuilder(
          listenable: _service,
          builder: (context, _) {
            final results = _service.scanResults;
            ScanResult? selectedResult;
            for (final result in results) {
              if (result.device.remoteId.str == _selectedId) {
                selectedResult = result;
                break;
              }
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih perangkat Bluetooth yang ingin di-pair.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  if (!_service.isBluetoothOn && _service.errorMessage == null)
                    _buildBluetoothOffBanner(),
                  if (_service.errorMessage != null)
                    _buildErrorBanner(_service.errorMessage!),
                  if (_service.isBluetoothOn &&
                      _service.errorMessage == null &&
                      _service.isScanning)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LinearProgressIndicator(minHeight: 2),
                          const SizedBox(height: 6),
                          Text(
                            'Mencari perangkat di sekitar...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Flexible(child: _buildDeviceList(results)),
                  const SizedBox(height: 16),
                  _buildActions(selectedResult),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.bluetooth, color: _accent),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Pairing Bluetooth',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: _service.isBluetoothOn ? _startScan : null,
          tooltip: 'Cari ulang',
          icon: const Icon(Icons.refresh, size: 20),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildBluetoothOffBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Bluetooth belum aktif. Nyalakan Bluetooth untuk mulai memindai.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            TextButton(
              onPressed: _service.turnOnBluetooth,
              child: const Text('Nyalakan', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
            ),
          ),
          if (message.toLowerCase().contains('izin'))
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Pengaturan', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(List<ScanResult> results) {
    results = results.where(_service.isPocketStatusDevice).toList();
    if (!_service.isBluetoothOn) {
      return _buildEmptyState(
        icon: Icons.bluetooth_disabled,
        title: 'Bluetooth tidak aktif',
        subtitle: 'Nyalakan Bluetooth terlebih dahulu untuk mencari perangkat.',
      );
    }

    if (results.isEmpty) {
      if (_service.isScanning) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 12),
              Text(
                'Mencari perangkat Bluetooth...',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      }

      return _buildEmptyState(
        icon: Icons.bluetooth_searching,
        title: 'Tidak ada perangkat ditemukan',
        subtitle:
            'Pastikan perangkat IoT menyala, dalam jangkauan, dan sudah mengaktifkan Bluetooth.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildDeviceTile(results[index]),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(ScanResult result) {
    final id = result.device.remoteId.str;
    final isSelected = _selectedId == id;
    final isConnected = _service.connectedDevice == result.device;
    final name = _deviceName(result);

    return InkWell(
      onTap: () => setState(() => _selectedId = id),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF3FE) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? _accent : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        _signalIcon(result.rssi),
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${result.rssi} dBm  •  $id',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Terhubung',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (isSelected)
              const Icon(Icons.check_circle, color: _accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(ScanResult? selectedResult) {
    return Row(
      children: [
        TextButton(
          onPressed: _service.isConnecting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        const Spacer(),
        SizedBox(
          height: 42,
          child: ElevatedButton(
            onPressed: selectedResult == null || _service.isConnecting
                ? null
                : () => _pair(selectedResult),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: _service.isConnecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Pair',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _deviceName(ScanResult result) {
    final advName = result.advertisementData.advName.trim();
    if (advName.isNotEmpty) return advName;
    return _service.deviceName(result.device);
  }

  IconData _signalIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_cellular_alt;
    if (rssi >= -80) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }
}
