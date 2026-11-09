import 'package:flutter/material.dart';
import '../models/cuaca_model.dart';
import '../models/finance_model.dart';
import '../models/sholat_model.dart';
import '../models/sport_model.dart';

class TemplateCardWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget displayWidget;
  final bool isEnabled;
  final ValueChanged<bool>? onToggle;

  const TemplateCardWrapper({
    super.key,
    required this.title,
    required this.subtitle,
    required this.displayWidget,
    this.isEnabled = true,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Simulated OLED Device Display Frame
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: displayWidget,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                activeThumbColor: const Color(0xFF2F80ED),
                onChanged: onToggle,
              )
            ],
          )
        ],
      ),
    );
  }
}

// Template 1: Waktu & Tanggal Real dari Server Sholat / Cuaca
Widget buildTemplate1(CuacaModel? cuaca, SholatModel? sholat) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Icon(Icons.crop_square, color: Colors.transparent),
          Row(
            children: [
              Icon(Icons.battery_5_bar, color: Colors.white, size: 20),
              SizedBox(width: 4),
              Icon(Icons.wifi, color: Colors.white, size: 18),
            ],
          )
        ],
      ),
      Column(
        children: [
          // Jam server real dari API Sholat (fallback ke '--:--' jika kosong)
          Text(
            sholat?.jamServer ?? "--:--",
            style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, height: 1.0),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tanggal Masehi real dari API Sholat
              Text(
                sholat?.tanggalMasehi ?? "Loading...",
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              // Suhu real dari API Cuaca
              Text(
                "${cuaca?.suhu?.toInt() ?? '--'}°C",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          )
        ],
      )
    ],
  );
}

// Template 2: Dashboard Cuaca & Kualitas Udara (AQI) Real
Widget buildTemplate2(CuacaModel? cuaca) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            cuaca?.deskripsiCuaca ?? "Memuat cuaca...",
            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
          ),
          Text(
            "${cuaca?.suhu ?? '--'}°C",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Icon(Icons.air, color: Colors.white70, size: 20),
              const SizedBox(height: 4),
              Text("${cuaca?.kecepatanAngin ?? '--'} km/h", style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          Column(
            children: [
              const Icon(Icons.water_drop, color: Colors.blueAccent, size: 20),
              const SizedBox(height: 4),
              Text("${cuaca?.kelembapan ?? '--'}%", style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          Column(
            children: [
              const Icon(Icons.shield, color: Colors.orangeAccent, size: 20),
              const SizedBox(height: 4),
              Text("AQI: ${cuaca?.aqiIqair ?? '--'}", style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          "BMKG: ${cuaca?.lokasiBmkg ?? '-'} | IQAir: ${cuaca?.lokasiIqair ?? '-'}",
          style: const TextStyle(color: Colors.grey, fontSize: 9),
        ),
      )
    ],
  );
}

// Template 3: Financial & Crypto Ticker Real
Widget buildTemplate3(FinanceModel? finance) {
  final double btcVal = finance?.btcPersen ?? 0;
  final double ihsgVal = finance?.ihsgPersen ?? 0;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text("FINANCE & CRYPTO", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          Icon(Icons.trending_up, color: Colors.greenAccent, size: 18),
        ],
      ),
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("USD/IDR", style: TextStyle(color: Colors.white, fontSize: 13)),
              Text("Rp ${finance?.kursUsdIdr?.toInt() ?? '-'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("BTC/IDR", style: TextStyle(color: Colors.white, fontSize: 13)),
              Text(
                "${finance?.btcPersen ?? 0}%",
                style: TextStyle(
                  color: btcVal >= 0 ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      Text(
        "IHSG: ${finance?.ihsgHarga ?? '-'} (${ihsgVal >= 0 ? '+' : ''}${finance?.ihsgPersen ?? 0}%)",
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    ],
  );
}

// Template 4: Jadwal Sholat Terotomatisasi Real
Widget buildTemplate4(SholatModel? sholat) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("JADWAL SHOLAT", style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          Text(
            sholat?.nextSholat != null ? "Next: ${sholat?.nextSholat}" : "Sholat",
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
      Center(
        child: Column(
          children: [
            Text(
              sholat?.nextWaktu ?? "--:--",
              style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(
              sholat?.tanggalHijriah ?? "Waktu Menuju Sholat",
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text("S: ${sholat?.subuh ?? '-'}", style: const TextStyle(color: Colors.white, fontSize: 10)),
          Text("D: ${sholat?.dzuhur ?? '-'}", style: const TextStyle(color: Colors.white, fontSize: 10)),
          Text("A: ${sholat?.ashar ?? '-'}", style: const TextStyle(color: Colors.white, fontSize: 10)),
          Text("M: ${sholat?.maghrib ?? '-'}", style: const TextStyle(color: Colors.white, fontSize: 10)),
          Text("I: ${sholat?.isya ?? '-'}", style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      )
    ],
  );
}

// Template 5: Sports Standings / Football Real
Widget buildTemplate5(SportModel? sport) {
  final klasemenList = sport?.klasemenTop3 ?? [];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            sport?.namaLiga ?? "LIGA SEPAKBOLA",
            style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const Icon(Icons.sports_soccer, color: Colors.white, size: 16),
        ],
      ),
      Column(
        children: klasemenList.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Memuat klasemen...", style: TextStyle(color: Colors.white70, fontSize: 12)),
                )
              ]
            : List.generate(
                klasemenList.length > 3 ? 3 : klasemenList.length,
                (index) {
                  final team = klasemenList[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${team.posisi ?? (index + 1)}. ${team.klub ?? 'Team'}",
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          "${team.poin ?? 0} pts",
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      const Align(
        alignment: Alignment.centerRight,
        child: Text("Top 3 Klasemen", style: TextStyle(color: Colors.grey, fontSize: 10)),
      )
    ],
  );
}