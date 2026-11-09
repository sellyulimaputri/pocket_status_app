class KlasemenItem {
  final int? posisi;
  final String? klub;
  final int? main;
  final int? poin;

  KlasemenItem({this.posisi, this.klub, this.main, this.poin});

  factory KlasemenItem.fromJson(Map<String, dynamic> json) {
    return KlasemenItem(
      posisi: json['posisi'],
      klub: json['klub'],
      main: json['main'],
      poin: json['poin'],
    );
  }
}

class SportModel {
  final String? namaLiga;
  final List<KlasemenItem>? klasemenTop3;

  SportModel({this.namaLiga, this.klasemenTop3});

  factory SportModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    var list = data['klasemen_top3'] as List?;
    List<KlasemenItem>? parsedKlasemen = list?.map((i) => KlasemenItem.fromJson(i)).toList();

    return SportModel(
      namaLiga: data['nama_liga'],
      klasemenTop3: parsedKlasemen,
    );
  }
}