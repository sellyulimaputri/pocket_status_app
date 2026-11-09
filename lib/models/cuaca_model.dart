class CuacaModel {
  final String? lokasiBmkg;
  final String? lokasiIqair;
  final double? suhu;
  final int? kelembapan;
  final int? kodeCuaca;
  final String? deskripsiCuaca;
  final double? kecepatanAngin;
  final String? arahAngin;
  final int? aqiIqair;

  CuacaModel({
    this.lokasiBmkg,
    this.lokasiIqair,
    this.suhu,
    this.kelembapan,
    this.kodeCuaca,
    this.deskripsiCuaca,
    this.kecepatanAngin,
    this.arahAngin,
    this.aqiIqair,
  });

  factory CuacaModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return CuacaModel(
      lokasiBmkg: data['lokasi_bmkg'],
      lokasiIqair: data['lokasi_iqair'],
      suhu: (data['suhu'] as num?)?.toDouble(),
      kelembapan: data['kelembapan'],
      kodeCuaca: data['kode_cuaca'],
      deskripsiCuaca: data['deskripsi_cuaca'],
      kecepatanAngin: (data['kecepatan_angin'] as num?)?.toDouble(),
      arahAngin: data['arah_angin'],
      aqiIqair: data['aqi_iqair'],
    );
  }
}