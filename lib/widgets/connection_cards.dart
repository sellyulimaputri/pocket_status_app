import 'package:flutter/material.dart';

import '../services/bluetooth_service.dart';

class ConnectionCards extends StatelessWidget {
  final VoidCallback onDeviceTap;
  final VoidCallback onWifiTap;

  const ConnectionCards({
    super.key,
    required this.onDeviceTap,
    required this.onWifiTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = BleService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final device = service.connectedDevice;

        return Column(
          children: [
            _buildActionCard(
              icon: Icons.charging_station_outlined,
              title: "Perangkat Terhubung",
              subtitle: device == null
                  ? "Pairing Bluetooth & koneksi perangkat"
                  : "Terhubung ke ${service.deviceName(device)}",
              onTap: onDeviceTap,
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.wifi,
              title: "Wi-Fi",
              subtitle: "Konfigurasi Wi-Fi perangkat",
              onTap: onWifiTap,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}