import 'package:flutter/material.dart';
import 'services/api_service.dart';
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
        useMaterial3: true,
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

  @override
  void initState() {
    super.initState();
    loadAllData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadAllData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Widget Terpisah
                const HeaderWidget(),
                const SizedBox(height: 24),

                // 2. Connection Cards Terpisah (Perangkat & Wi-Fi)
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

                // Konfigurasi Template Header
                Row(
                  children: const [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 20,
                      color: Colors.black87,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Konfigurasi Template",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                  // 5 Template Display Cards (Data Real API)
                  TemplateCardWrapper(
                    title: "Waktu",
                    subtitle: "Menampilkan waktu dan tanggal",
                    displayWidget: buildTemplate1(cuacaData, sholatData),
                  ),
                  TemplateCardWrapper(
                    title: "Cuaca & Air Quality",
                    subtitle: "Suhu, Kelembaban, dan AQI real-time",
                    displayWidget: buildTemplate2(cuacaData),
                  ),
                  TemplateCardWrapper(
                    title: "Pasar Finansial",
                    subtitle: "Kurs USD, Harga Emas, & Bitcoin",
                    displayWidget: buildTemplate3(financeData),
                  ),
                  TemplateCardWrapper(
                    title: "Jadwal Sholat",
                    subtitle: "Countdown & Jadwal Sholat Otomatis",
                    displayWidget: buildTemplate4(sholatData),
                  ),
                  TemplateCardWrapper(
                    title: "Sepak Bola",
                    subtitle: "Klasemen 3 Besar Liga Pilihan",
                    displayWidget: buildTemplate5(sportData),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
