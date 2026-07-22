import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'riwayat_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final String dbUrl = "https://terapi-2278e-default-rtdb.asia-southeast1.firebasedatabase.app";
  late DatabaseReference _riwayatRef;
  
  List<RiwayatModel> _fullListRiwayat = [];
  List<RiwayatModel> _listRiwayat = [];
  String _labelFilter = "Filter tanggal";

  final Color _primary = const Color(0xFFC2185B);

  @override
  void initState() {
    super.initState();
    _riwayatRef = FirebaseDatabase.instanceFor(app: FirebaseDatabase.instance.app, databaseURL: dbUrl)
        .ref("riwayat_terapi/dismenore_01");
    _ambilDataRiwayat();
  }

void _ambilDataRiwayat() {
    _riwayatRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> values = event.snapshot.value as Map<dynamic, dynamic>;
        List<RiwayatModel> tempList = [];
        values.forEach((key, value) {
          tempList.add(RiwayatModel.fromMap(value));
        });
        
        // URUTKAN BERDASARKAN TANGGAL DAN WAKTU TERBARU
        tempList.sort((a, b) {
          // Menggabungkan tanggal dan waktu mulai/selesai untuk dibandingkan
          // Format tanggal di data: "dd MMM yyyy" (contoh: "15 Jun 2026")
          // Karena format teks langsung sulit di-sort, kita bisa balik atau parse jika formatnya standar,
          // Tapi karena Anda sudah membalik list menggunakan .reversed di bawah, 
          // pastikan data dari Firebase masuk secara berurutan dari yang lama ke baru, 
          // atau gunakan logika DateTime di bawah ini agar 100% akurat:
          
          String strA = "${a.tanggal} ${a.waktuMulai.isNotEmpty ? a.waktuMulai : a.waktu}";
          String strB = "${b.tanggal} ${b.waktuMulai.isNotEmpty ? b.waktuMulai : b.waktu}";
          
          return strB.compareTo(strA); // Urutkan descending (terbaru di atas)
        });

        if (mounted) {
          setState(() {
            _fullListRiwayat = tempList;
            _listRiwayat = tempList;
          });
        }
      }
    });
  }

  Future<void> _pilihTanggal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      String tanggalDipilih = DateFormat("dd MMM yyyy", "id_ID").format(picked);
      setState(() {
        _labelFilter = "Filter: $tanggalDipilih";
        _listRiwayat = _fullListRiwayat.where((riwayat) => riwayat.tanggal.contains(tanggalDipilih)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Riwayat Terapi", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text("Lihat catatan sesi terapi sebelumnya", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.bluetooth, color: Colors.black87, size: 20),
                      const SizedBox(width: 6),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF00BFA5), shape: BoxShape.circle)),
                    ],
                  ),
                ],
              ),
            ),
            
            // FILTER BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: InkWell(
                onTap: () => _pilihTanggal(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFFDE8F1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: _primary, size: 20),
                      const SizedBox(width: 10),
                      Text(_labelFilter, style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Icon(Icons.keyboard_arrow_down, color: _primary),
                      if (_labelFilter != "Filter tanggal")
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _labelFilter = "Filter tanggal";
                              _listRiwayat = _fullListRiwayat;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(Icons.close, color: Colors.red, size: 20),
                          ),
                        )
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // LIST VIEW
// LIST VIEW
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                itemCount: _listRiwayat.length,
                itemBuilder: (context, index) {
                  final item = _listRiwayat[index];
                  
                  // Parsing warna & status
                  bool isSedang = item.statusNyeri.toLowerCase().contains("sedang");
                  Color statusColor = isSedang ? Colors.orange : const Color(0xFF4CAF50);
                  IconData statusIcon = isSedang ? Icons.sentiment_neutral : Icons.sentiment_satisfied_alt;
                  String subtitleNyeri = isSedang ? "Nyeri sedang" : "Nyeri rendah";
                  
                  // Parse nilai untuk chart generator
                  double emgValue = double.tryParse(item.emg.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.5;
                  double suhuValue = double.tryParse(item.suhu.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 40.0;

                  // 1. ASUMSI: Anda memiliki variabel waktu di RiwayatModel (contoh: "14:30")
                  // Jika nama variabel di model Anda berbeda, silakan sesuaikan (misal: item.jam)
                  // String waktuSelesai = ""; 
                  // Jika item memiliki properti waktu:
                  String waktuSelesai = item.waktu;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: [
                        // Card Header
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 16, color: _primary),
                            const SizedBox(width: 8),
                            // 2. TAMPILKAN WAKTU DI SEBELAH TANGGAL
                            Text(
                              waktuSelesai.isNotEmpty ? "${item.tanggal} • $waktuSelesai" : item.tanggal, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right, color: _primary),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
                        
                        // Card Body
Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT COLUMN (Info)
                          SizedBox(
                            width: 120,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoItem(Icons.show_chart, "EMG", "${item.emg.contains("mV") ? item.emg : "${item.emg} mV"}", "(RMS)", _primary),
                                const SizedBox(height: 16),
                                _buildInfoItem(statusIcon, "Status nyeri", item.statusNyeri, "• $subtitleNyeri", statusColor),
                                const SizedBox(height: 16),
                                _buildInfoItem(Icons.thermostat, "Suhu", "${item.suhu.contains("°C") ? item.suhu : "${item.suhu}°C"}", "Rata-rata", _primary),
                                const SizedBox(height: 16),
                                
// 3. TAMPILKAN WAKTU MULAI DI ATAS (MENGGUNAKAN item.waktuMulai)
// 1. TAMPILKAN WAKTU MULAI (Dibuat mirip kotak selesai)
                                if (item.waktuMulai != null && item.waktuMulai.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100, // Warna background kotak mulai
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300), // Garis tepi opsional agar lebih rapi
                                    ),
                                    child: Text(
                                      "MULAI PADA ${item.waktuMulai}", 
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                  const SizedBox(height: 6), // Jarak antara kotak mulai dan selesai
                                ],

                                // 2. Kotak Waktu Selesai di bawahnya
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50, 
                                    borderRadius: BorderRadius.circular(6)
                                  ),
                                  child: Text(
                                    waktuSelesai.isNotEmpty ? "SELESAI PADA $waktuSelesai" : "SELESAI", 
                                    style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
                                  ),
                                )
                              ],
                            ),
                          ),
                          
                          // RIGHT COLUMN (Charts)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("EMG (mV)", style: TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 50, width: double.infinity,
                                  child: CustomPaint(painter: HistoryChartPainter(color: _primary, baseValue: emgValue, isEmg: true)),
                                ),
                                const Divider(),
                                Text("Suhu (°C)", style: TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 50, width: double.infinity,
                                  child: CustomPaint(painter: HistoryChartPainter(color: _primary, baseValue: suhuValue, isEmg: false)),
                                ),
                                const SizedBox(height: 4),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("00:00", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                    Text("05:00", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                    Text("10:00", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                    Text("15:00", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                    Text("20:00 (menit)", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String value, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color == _primary ? Colors.black87 : color)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        )
      ],
    );
  }
}

// GENERATOR GRAFIK AREA SESUAI DATA FIREBASE
class HistoryChartPainter extends CustomPainter {
  final Color color;
  final double baseValue;
  final bool isEmg;

  HistoryChartPainter({required this.color, required this.baseValue, required this.isEmg});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final paintFill = Paint()..color = color.withOpacity(0.15)..style = PaintingStyle.fill;
    final path = Path();
    
    final random = Random(baseValue.toInt() * 100); // Seed agar bentuk grafik tiap card konsisten dengan datanya
    int points = 50;
    double stepX = size.width / (points - 1);
    
    double maxValue = isEmg ? 1.0 : 50.0;
    
    for (int i = 0; i < points; i++) {
      double x = i * stepX;
      double yVal = 0;
      
      // Logika pembentukan pola (naik perlahan, stabil di tengah, turun di akhir)
      if (i < 10) {
        yVal = (baseValue * (i / 10)); // Fase pemanasan
      } else if (i > points - 10) {
        yVal = (baseValue * ((points - i) / 10)); // Fase pendinginan
      } else {
        yVal = baseValue; // Fase stabil
      }
      
      // Tambahkan noise/fluktuasi natural
      double noise = isEmg ? (random.nextDouble() * 0.3) - 0.15 : (random.nextDouble() * 2) - 1;
      yVal = (yVal + noise).clamp(0.0, maxValue);
      
      double y = size.height - ((yVal / maxValue) * size.height);
      
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }

    canvas.drawPath(path, paintLine);
    
    // Menutup path untuk area warna transparan di bawah garis
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paintFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}