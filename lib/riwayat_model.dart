class RiwayatModel {
  final String tanggal;
  final String durasi;
  final String emg;
  final String statusNyeri;
  final String suhu;

  RiwayatModel({
    this.tanggal = "",
    this.durasi = "",
    this.emg = "",
    this.statusNyeri = "Ringan",
    this.suhu = "0.0°C",
  });

  // Fungsi untuk mengubah data dari Firebase (Map) menjadi Objek Dart
  factory RiwayatModel.fromMap(Map<dynamic, dynamic> map) {
    return RiwayatModel(
      tanggal: map['tanggal']?.toString() ?? "",
      durasi: map['durasi']?.toString() ?? "",
      emg: map['emg']?.toString() ?? "",
      statusNyeri: map['statusNyeri']?.toString() ?? "Ringan",
      suhu: map['suhu']?.toString() ?? "0.0°C",
    );
  }
}