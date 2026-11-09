class FinanceModel {
  final double? ihsgHarga;
  final double? ihsgPersen;
  final double? emasDuniaIdr;
  final double? kursUsdIdr;
  final double? btcIdr;
  final double? btcPersen;
  final double? ethIdr;
  final double? ethPersen;

  FinanceModel({
    this.ihsgHarga,
    this.ihsgPersen,
    this.emasDuniaIdr,
    this.kursUsdIdr,
    this.btcIdr,
    this.btcPersen,
    this.ethIdr,
    this.ethPersen,
  });

  factory FinanceModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    
    // Helper untuk konversi aman dari String atau angka ke double
    double? parseToDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return FinanceModel(
      ihsgHarga: parseToDouble(data['ihsg_harga']),
      ihsgPersen: parseToDouble(data['ihsg_persen']),
      emasDuniaIdr: parseToDouble(data['emas_dunia_idr']),
      kursUsdIdr: parseToDouble(data['kurs_usd_idr']),
      btcIdr: parseToDouble(data['btc_idr']),
      btcPersen: parseToDouble(data['btc_persen']),
      ethIdr: parseToDouble(data['eth_idr']),
      ethPersen: parseToDouble(data['eth_persen']),
    );
  }
}