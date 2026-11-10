import 'dart:async';
import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'services/bluetooth_service.dart'; // Import BLE Service yang baru kita perbaiki

import 'models/cuaca_model.dart';
import 'models/finance_model.dart';
import 'models/sholat_model.dart';
import 'models/sport_model.dart';

import 'widgets/header_widget.dart';
import 'widgets/connection_cards.dart';
import 'widgets/device_dialog.dart';
import 'widgets/wifi_dialog.dart';
import 'widgets/template_cards.dart';

void main() {
  runApp(const PocketStatusApp());
}

class PocketStatusApp extends StatelessWidget {
  const PocketStatusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pocket Status',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        fontFamily: 'Sans-Serif',
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  CuacaModel? cuacaData;
  FinanceModel? financeData;
  SholatModel? sholatData;
  SportModel? sportData;
  bool isLoading = true;

  // --- LOGIKA STATE & ROTASI TEMPLATE ---
  // Menyimpan status aktif/nonaktif setiap template
  Map<String, bool> activeTemplates = {
    'clock': true,
    'weather': false,
    'finance': false,
    'jadwal_sholat': false,
    'catface': false, // Ganti sport jadi catface agar sesuai C++ ESP32
  };

  Timer? _rotationTimer;
  int _currentRotationIndex = 0;

  @override
  void initState() {
    super.initState();
    loadAllData();
    _startRotationTimer(); // Mulai timer saat aplikasi dibuka
  }

  @override
  void dispose() {
    _rotationTimer?.cancel(); // Matikan timer jika aplikasi ditutup
    super.dispose();
  }

  Future<void> loadAllData() async {
    setState(() => isLoading = true);
    final results = await Future.wait([
      ApiService.fetchCuaca(),
      ApiService.fetchFinance(),
      ApiService.fetchSholat(),
      ApiService.fetchSport(),
    ]);

    setState(() {
      cuacaData = results[0] as CuacaModel?;
      financeData = results[1] as FinanceModel?;
      sholatData = results[2] as SholatModel?;
      sportData = results[3] as SportModel?;
      isLoading = false;
    });
  }

  // Menjalankan rotasi setiap 10 detik
  void _startRotationTimer() {
    _rotationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _rotateToNextTemplate();
    });
  }

  void _rotateToNextTemplate() {
    // Ambil daftar ID template yang posisinya "ON"
    final activeIds = activeTemplates.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (activeIds.isEmpty) {
      // Jika semua tombol dimatikan, paksa layar ESP32 jadi Idle Face (Kucing)
      BleService.instance.sendJsonCommand('{"action": "set_template", "id": "idle"}');
      return;
    }

    // Geser index ke template berikutnya
    _currentRotationIndex = (_currentRotationIndex + 1) % activeIds.length;
    String nextId = activeIds[_currentRotationIndex];

    // Tembak perintah ke ESP32
    BleService.instance.sendJsonCommand('{"action": "set_template", "id": "$nextId"}');
  }

  // Fungsi saat tombol switch digeser oleh user
  void _toggleTemplate(String id, bool value) {
    setState(() {
      activeTemplates[id] = value;
    });

    // Jika user menyalakan suatu layar, paksa ESP32 untuk langsung menampilkannya detik itu juga
    if (value) {
      BleService.instance.sendJsonCommand('{"action": "set_template", "id": "$id"}');
    }
  }
  // --------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadAllData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HeaderWidget(),
                const SizedBox(height: 24),

                ConnectionCards(
                  onDeviceTap: () => showDialog(
                    context: context,
                    builder: (_) => const DeviceDialog(),
                  ),
                  onWifiTap: () => showDialog(
                    context: context,
                    builder: (_) => const WifiDialog(),
                  ),
                ),
                const SizedBox(height: 28),

                Row(
                  children: const [
                    Icon(Icons.dashboard_customize_outlined, size: 20, color: Colors.black87),
                    SizedBox(width: 8),
                    Text("Konfigurasi Template", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),

                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  TemplateCardWrapper(
                    title: "Waktu",
                    subtitle: "Menampilkan waktu dan tanggal",
                    displayWidget: buildTemplate1(cuacaData, sholatData),
                    isEnabled: activeTemplates['clock']!,
                    onToggle: (val) => _toggleTemplate('clock', val),
                  ),
                  TemplateCardWrapper(
                    title: "Cuaca & Air Quality",
                    subtitle: "Suhu, Kelembaban, dan AQI real-time",
                    displayWidget: buildTemplate2(cuacaData),
                    isEnabled: activeTemplates['weather']!,
                    onToggle: (val) => _toggleTemplate('weather', val),
                  ),
                  TemplateCardWrapper(
                    title: "Pasar Finansial",
                    subtitle: "Kurs USD, Harga Emas, & Bitcoin",
                    displayWidget: buildTemplate3(financeData),
                    isEnabled: activeTemplates['finance']!,
                    onToggle: (val) => _toggleTemplate('finance', val),
                  ),
                  TemplateCardWrapper(
                    title: "Jadwal Sholat",
                    subtitle: "Countdown & Jadwal Sholat Otomatis",
                    displayWidget: buildTemplate4(sholatData),
                    isEnabled: activeTemplates['jadwal_sholat']!,
                    onToggle: (val) => _toggleTemplate('jadwal_sholat', val),
                  ),
                  // Menggunakan Widget Sport untuk mengaktifkan muka kucing di ESP32
                  TemplateCardWrapper(
                    title: "Mode Idle (Wajah Kucing)",
                    subtitle: "Animasi default saat santai",
                    displayWidget: buildTemplate5(sportData), 
                    isEnabled: activeTemplates['catface']!,
                    onToggle: (val) => _toggleTemplate('catface', val),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}