class SholatModel {
  final String? tanggalMasehi;
  final String? tanggalHijriah;
  final String? subuh;
  final String? dzuhur;
  final String? ashar;
  final String? maghrib;
  final String? isya;
  final String? imsak;
  final String? jamServer;
  final String? nextSholat;
  final String? nextWaktu;

  SholatModel({
    this.tanggalMasehi,
    this.tanggalHijriah,
    this.subuh,
    this.dzuhur,
    this.ashar,
    this.maghrib,
    this.isya,
    this.imsak,
    this.jamServer,
    this.nextSholat,
    this.nextWaktu,
  });

  factory SholatModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return SholatModel(
      tanggalMasehi: data['tanggal_masehi'],
      tanggalHijriah: data['tanggal_hijriah'],
      subuh: data['subuh'],
      dzuhur: data['dzuhur'],
      ashar: data['ashar'],
      maghrib: data['maghrib'],
      isya: data['isya'],
      imsak: data['imsak'],
      jamServer: data['jam_server'],
      nextSholat: data['next_sholat'],
      nextWaktu: data['next_waktu'],
    );
  }
}