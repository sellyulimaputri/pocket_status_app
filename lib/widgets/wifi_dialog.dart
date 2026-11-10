import 'package:flutter/material.dart';

import '../models/wifi_scan_model.dart';
import '../services/bluetooth_service.dart';
import '../services/wifi_scanner_service.dart';

class WifiDialog extends StatefulWidget {
  const WifiDialog({super.key});

  @override
  State<WifiDialog> createState() => _WifiDialogState();
}

class _WifiDialogState extends State<WifiDialog> {
  static const _accent = Color(0xFF2F80ED);
  final _scanner = WifiScannerService();
  String? _selectedSsid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scanner.connectToCurrentDevice();
    });
  }

  @override
  void dispose() {
    _scanner.disposeScanner();
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListenableBuilder(
        listenable: _scanner,
        builder: (context, _) {
          final state = _scanner.state;
          final isConnected = BleService.instance.connectedDevice != null;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .86,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isConnected),
                  const SizedBox(height: 12),
                  _buildDeviceBanner(isConnected, state),
                  const SizedBox(height: 14),
                  if (state.errorMessage != null)
                    _buildError(state.errorMessage!),
                  _buildScanStatus(state),
                  const SizedBox(height: 10),
                  Expanded(child: _buildNetworkList(state)),
                  const SizedBox(height: 12),
                  _buildActions(state, isConnected),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isConnected) {
    return Row(
      children: [
        const Icon(Icons.wifi_find, color: _accent),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Wi-Fi Scanner',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          size: 18,
          color: isConnected ? Colors.green : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildDeviceBanner(bool isConnected, WifiScanState state) {
    final device = BleService.instance.connectedDevice;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? Colors.green.shade700 : Colors.orange.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConnected
                  ? 'Terhubung ke ${BleService.instance.deviceName(device!)}'
                  : 'Hubungkan PocketStatus untuk memindai Wi-Fi.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (state.deviceStatus?.wifiConnected == true)
            const Tooltip(
              message: 'ESP32 terhubung ke Wi-Fi',
              child: Icon(Icons.cloud_done, size: 18, color: Colors.green),
            ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStatus(WifiScanState state) {
    final label = switch (state.phase) {
      WifiScanPhase.idle => 'Siap memindai jaringan di sekitar perangkat.',
      WifiScanPhase.scanning => 'Memindai jaringan Wi-Fi...',
      WifiScanPhase.completed => '${state.networks.length} jaringan ditemukan.',
      WifiScanPhase.error => 'Pemindaian berhenti karena error.',
    };
    return Row(
      children: [
        if (state.phase == WifiScanPhase.scanning)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkList(WifiScanState state) {
    if (state.networks.isEmpty && state.phase != WifiScanPhase.scanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_find, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'Belum ada jaringan ditemukan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Tekan Scan Wi-Fi untuk meminta daftar dari PocketStatus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.networks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildNetworkTile(state.networks[index]),
    );
  }

  Widget _buildNetworkTile(WifiNetwork network) {
    final selected = _selectedSsid == network.ssid;
    return InkWell(
      onTap: () => setState(() => _selectedSsid = network.ssid),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEBF3FE) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _wifiIcon(network.rssi),
              color: selected ? _accent : Colors.grey.shade700,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    network.displaySsid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${network.rssi} dBm  •  Channel ${network.channel}  •  ${network.security}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: _accent, size: 19),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(WifiScanState state, bool isConnected) {
    final scanning = state.phase == WifiScanPhase.scanning;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: !isConnected || scanning ? null : _scanner.scanWifi,
            icon: Icon(scanning ? Icons.hourglass_top : Icons.refresh),
            label: Text(scanning ? 'Scanning...' : 'Scan Wi-Fi'),
            style: FilledButton.styleFrom(backgroundColor: _accent),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isConnected ? _scanner.requestStatus : null,
          tooltip: 'Minta status perangkat',
          icon: const Icon(Icons.sync),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: 'Tutup',
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  IconData _wifiIcon(int rssi) {
    if (rssi >= -55) return Icons.network_wifi;
    if (rssi >= -70) return Icons.network_wifi_3_bar;
    return Icons.network_wifi_1_bar;
  }
}
