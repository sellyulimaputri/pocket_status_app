import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/bluetooth_service.dart';
import 'bluetooth_pairing_dialog.dart';

class DeviceDialog extends StatelessWidget {
  const DeviceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BleService.instance;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final device = service.connectedDevice;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.charging_station_outlined,
                        color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      "Perangkat Terhubung",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _openPairing(context),
                      tooltip: "Cari perangkat",
                      icon: const Icon(Icons.add, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDeviceStatus(context, service, device),
                const SizedBox(height: 16),
                if (device == null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openPairing(context),
                      icon: const Icon(Icons.bluetooth_searching, size: 18),
                      label: const Text("Cari & Pair Perangkat"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2F80ED),
                        side: const BorderSide(color: Color(0xFF2F80ED)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: service.disconnect,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Disconnect",
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openPairing(context),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Ganti Perangkat",
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F80ED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeviceStatus(
    BuildContext context,
    BleService service,
    BluetoothDevice? device,
  ) {
    final isConnected = device != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: isConnected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device != null
                      ? service.deviceName(device)
                      : "Belum ada perangkat",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isConnected ? "• Connected" : "• Disconnected",
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                if (device != null)
                  Text(
                    "ID: ${device.remoteId.str}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (device != null)
            const Icon(Icons.link, color: Colors.green, size: 18),
        ],
      ),
    );
  }

  Future<void> _openPairing(BuildContext context) async {
    final paired = await BluetoothPairingDialog.show(context);
    if (!context.mounted || paired == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Berhasil terhubung ke ${BleService.instance.deviceName(paired)}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
