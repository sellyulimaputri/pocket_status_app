import 'package:flutter/material.dart';

import '../services/bluetooth_service.dart';

/// Dialog untuk mengatur Wi-Fi ESP32 lewat BLE:
/// 1. Melihat status internet ESP (connected / disconnected + SSID + IP)
/// 2. Melihat daftar Wi-Fi hasil scan ESP
/// 3. Mengirim SSID + password ke ESP supaya ESP tersambung ke Wi-Fi
class WifiDialog extends StatefulWidget {
  const WifiDialog({super.key});

  @override
  State<WifiDialog> createState() => _WifiDialogState();
}

class _WifiDialogState extends State<WifiDialog> {
  final BleService _ble = BleService.instance;

  bool _statusTimedOut = false;
  bool _scanTimedOut = false;
  int _scanToken = 0;

  String? _connectingSsid; // != null berarti sedang proses menyambungkan
  String? _resultMessage;
  bool _resultSuccess = false;

  bool get _isBleReady => _ble.connectedDevice != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted || !_isBleReady) return;
    _fetchWifiStatus();
    // Beri jeda supaya dua perintah BLE tidak saling tabrakan.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _scanWifiNetworks();
  }

  // ---------------------------------------------------------------------------
  // LOGIC BLE
  // ---------------------------------------------------------------------------

  /// Minta status ke ESP. Jawabannya masuk lewat BleService (notify).
  Future<void> _fetchWifiStatus() async {
    if (!_isBleReady) return;
    setState(() => _statusTimedOut = false);

    await _ble.checkEspStatus();
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;
    if (!_ble.hasEspStatus) setState(() => _statusTimedOut = true);
  }

  /// Minta ESP memindai Wi-Fi sekitar.
  Future<void> _scanWifiNetworks() async {
    if (!_isBleReady) return;
    final token = ++_scanToken;
    setState(() => _scanTimedOut = false);

    await _ble.scanEspWifi();

    // Pengaman: kalau ESP tidak membalas, jangan loading selamanya.
    await Future.delayed(const Duration(seconds: 20));
    if (!mounted || token != _scanToken) return;
    if (_ble.isEspScanningWifi) setState(() => _scanTimedOut = true);
  }

  Future<void> _onNetworkTap(Map<String, dynamic> network) async {
    if (_connectingSsid != null) return;

    final ssid = network['ssid'].toString();
    final isSecure = network['secure'] != false; // default dianggap berpassword

    String password = '';
    if (isSecure) {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => _PasswordDialog(ssid: ssid),
      );
      if (result == null) return; // dibatalkan
      password = result;
    }

    if (!mounted) return;
    await _connectToWifi(ssid, password);
  }

  Future<void> _connectToWifi(String ssid, String password) async {
    setState(() {
      _connectingSsid = ssid;
      _resultMessage = null;
    });

    await _ble.connectEspToWifi(ssid, password);

    // Cek status ESP tiap beberapa detik sampai tersambung ke SSID tujuan
    // (maksimal ±20 detik).
    var success = false;
    final deadline = DateTime.now().add(const Duration(seconds: 20));

    while (mounted && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      await _ble.checkEspStatus();
      await Future.delayed(const Duration(milliseconds: 800));

      if (_ble.isEspWifiConnected && _ble.espWifiSsid == ssid) {
        success = true;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _connectingSsid = null;
      _resultSuccess = success;
      _resultMessage = success
          ? 'ESP berhasil terhubung ke "$ssid".'
          : 'ESP gagal terhubung ke "$ssid". Cek password lalu coba lagi.';
    });
  }

  /// Hapus duplikat SSID, buang SSID kosong, urutkan dari sinyal terkuat.
  List<Map<String, dynamic>> _cleanNetworks(List<Map<String, dynamic>> raw) {
    num rssiOf(Map<String, dynamic> n) => (n['rssi'] is num) ? n['rssi'] as num : -100;

    final sorted = [...raw]..sort((a, b) => rssiOf(b).compareTo(rssiOf(a)));
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final n in sorted) {
      final ssid = (n['ssid'] ?? '').toString();
      if (ssid.isEmpty || !seen.add(ssid)) continue;
      result.add(n);
    }
    return result;
  }

  IconData _signalIcon(dynamic rssi) {
    final value = rssi is num ? rssi : -100;
    if (value >= -60) return Icons.wifi;
    if (value >= -75) return Icons.wifi_2_bar;
    return Icons.wifi_1_bar;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder mendengarkan BleService (ChangeNotifier), jadi UI
    // otomatis update setiap ESP mengirim status / hasil scan.
    return AnimatedBuilder(
      animation: _ble,
      builder: (context, _) {
        final isConnecting = _connectingSsid != null;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isConnecting),
                const SizedBox(height: 16),
                _buildStatusCard(),
                if (isConnecting) ...[
                  const SizedBox(height: 12),
                  _buildConnectingBanner(),
                ] else if (_resultMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildResultBanner(),
                ],
                const SizedBox(height: 20),
                _buildNetworkSection(isConnecting),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isConnecting ? null : () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F80ED),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isConnecting) {
    return Row(
      children: [
        const Icon(Icons.wifi, color: Colors.grey),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Konfigurasi Wi-Fi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        IconButton(
          tooltip: 'Refresh status',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: (!_isBleReady || isConnecting) ? null : _fetchWifiStatus,
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    Widget child;

    if (!_isBleReady) {
      child = const Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bluetooth belum terhubung ke ESP. Pairing dulu di menu perangkat.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      );
    } else if (!_ble.hasEspStatus) {
      child = Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _statusTimedOut
              ? const Text(
                  'ESP tidak membalas status. Tekan refresh untuk coba lagi.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                )
              : const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      );
    } else {
      final connected = _ble.isEspWifiConnected;
      final ssid = _ble.espWifiSsid.isEmpty ? '-' : _ble.espWifiSsid;
      final ip = _ble.espWifiIp.isEmpty ? '-' : _ble.espWifiIp;

      child = Column(
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.wifi : Icons.wifi_off,
                color: connected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Status Internet ESP',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    connected ? '• Connected' : '• Disconnected',
                    style: TextStyle(
                      color: connected ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('SSID', connected ? ssid : '-', bold: true),
          const SizedBox(height: 4),
          _infoRow('IP Address', connected ? ip : '-'),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectingBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Menyambungkan ESP ke "$_connectingSsid"...',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    final color = _resultSuccess ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _resultSuccess ? Icons.check_circle : Icons.error_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _resultMessage!,
              style: TextStyle(fontSize: 12, color: color.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSection(bool isConnecting) {
    final scanning = _ble.isEspScanningWifi && !_scanTimedOut;
    final networks = _cleanNetworks(_ble.scannedWifiList);

    Widget body;
    if (!_isBleReady) {
      body = _centerHint('Hubungkan Bluetooth ke ESP terlebih dahulu.');
    } else if (scanning) {
      body = _centerHint('ESP sedang mencari jaringan Wi-Fi...');
    } else if (_scanTimedOut && networks.isEmpty) {
      body = _centerHint('ESP tidak membalas hasil scan. Coba Scan Ulang.');
    } else if (networks.isEmpty) {
      body = _centerHint('Tidak ada Wi-Fi ditemukan.');
    } else {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: networks.length,
          itemBuilder: (context, index) {
            final network = networks[index];
            final ssid = network['ssid'].toString();
            final isSecure = network['secure'] != false;
            final isCurrent = _ble.isEspWifiConnected && _ble.espWifiSsid == ssid;

            return ListTile(
              dense: true,
              enabled: !isConnecting,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_signalIcon(network['rssi']), color: Colors.black87),
              title: Text(
                ssid,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: isCurrent
                  ? const Text('Terhubung',
                      style: TextStyle(fontSize: 11, color: Colors.green))
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSecure)
                    const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: () => _onNetworkTap(network),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Koneksi Tersedia',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed:
                  (!_isBleReady || scanning || isConnecting) ? null : _scanWifiNetworks,
              child: scanning
                  ? const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Scan Ulang', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        body,
      ],
    );
  }

  Widget _centerHint(String text) {
    return SizedBox(
      height: 80,
      width: double.infinity,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}

/// Dialog input password. Dibuat sebagai widget sendiri supaya
/// TextEditingController di-dispose dengan aman.
class _PasswordDialog extends StatefulWidget {
  final String ssid;

  const _PasswordDialog({required this.ssid});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Connect to ${widget.ssid}', style: const TextStyle(fontSize: 16)),
      content: TextField(
        controller: _controller,
        obscureText: _obscure,
        autofocus: true,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Masukkan Password',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F80ED),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _submit,
          child: const Text('Connect', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}