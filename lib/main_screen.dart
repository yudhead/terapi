import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final String dbUrl = "https://terapi-2278e-default-rtdb.asia-southeast1.firebasedatabase.app";
  late DatabaseReference _monitoringRef;
  late DatabaseReference _riwayatRef;
  late StreamSubscription _sensorSubscription;

  bool _isSesiAktif = false;
  int _detikBerjalan = 0;
  Timer? _timer;
  DateTime? _waktuMulaiTerapi;

  // Variabel data realtime
  double _suhuTerakhir = 0.0;
  double _emgRmsTerakhir = 0.0;
  int _intensitasTerakhir = 0;
  
  // List untuk menampung riwayat data EMG agar grafik bisa bergerak
  List<double> _emgHistory = []; 

  final Color _primaryColor = const Color(0xFFC2185B);
  final Color _lightPink = const Color(0xFFFDE8F1);

  @override
  void initState() {
    super.initState();
    _monitoringRef = FirebaseDatabase.instanceFor(app: FirebaseDatabase.instance.app, databaseURL: dbUrl)
        .ref("monitoring_terapi/dismenore_01");
    _riwayatRef = FirebaseDatabase.instanceFor(app: FirebaseDatabase.instance.app, databaseURL: dbUrl)
        .ref("riwayat_terapi/dismenore_01");

    // Mendengarkan perubahan data dari IoT secara realtime
    _sensorSubscription = _monitoringRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map data = event.snapshot.value as Map;
        
        if (mounted) {
          setState(() {
            _suhuTerakhir = (data['suhu'] ?? 0.0).toDouble();
            _emgRmsTerakhir = (data['emg_rms'] ?? 0.0).toDouble();
            _intensitasTerakhir = (data['intensitas_fuzzy'] ?? 0) as int;

            // Tambahkan data baru ke grafik
            _emgHistory.add(_emgRmsTerakhir);
            // Batasi agar grafik tidak terlalu panjang (maksimal 30 titik terakhir)
            if (_emgHistory.length > 30) {
              _emgHistory.removeAt(0); 
            }
          });
        }
      }
    });
  }

  void _mulaiSesi() {
    setState(() {
      _isSesiAktif = true;
      _waktuMulaiTerapi = DateTime.now();
      _emgHistory.clear(); // Bersihkan grafik saat sesi baru
    });
    _monitoringRef.child("status_aktif").set(true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() { _detikBerjalan++; });
    });
  }

  void _hentikanSesi() {
    _timer?.cancel();
    _monitoringRef.child("status_aktif").set(false);
    _simpanKeRiwayat();

    setState(() {
      _isSesiAktif = false;
      _detikBerjalan = 0;
    });
  }

  String _formatWaktu(int totalDetik) {
    int jam = totalDetik ~/ 3600;
    int menit = (totalDetik % 3600) ~/ 60;
    int detik = totalDetik % 60;
    return '${jam.toString().padLeft(2, '0')}:${menit.toString().padLeft(2, '0')}:${detik.toString().padLeft(2, '0')}';
  }

  void _simpanKeRiwayat() {
    if (_waktuMulaiTerapi == null) return;

    String tanggalTeks = DateFormat("dd MMM yyyy • HH:mm", "id_ID").format(_waktuMulaiTerapi!);
    String durasiTeks = _formatWaktu(_detikBerjalan);
    
    String statusNyeri = "Ringan";
    if (_intensitasTerakhir >= 70) {
      statusNyeri = "Berat";
    } else if (_intensitasTerakhir >= 30) {
      statusNyeri = "Sedang";
    }

    Map<String, dynamic> dataRiwayat = {
      "tanggal": tanggalTeks,
      "durasi": durasiTeks,
      "emg": _emgRmsTerakhir.toString(),
      "suhu": _suhuTerakhir.toString(),
      "statusNyeri": statusNyeri
    };

    _riwayatRef.push().set(dataRiwayat).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sesi disimpan ke Riwayat")));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sensorSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String statusNyeri = _intensitasTerakhir >= 70 ? "Berat" : (_intensitasTerakhir >= 30 ? "Sedang" : "Ringan");

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DismenoreCare", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(_isSesiAktif ? "Sesi berlangsung" : "Siap dimulai", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: _lightPink, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Durasi sesi", style: TextStyle(color: Color(0xFF882956), fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(_formatWaktu(_detikBerjalan), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Color(0xFF4A0024))),
                            ],
                          ),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Target", style: TextStyle(color: Color(0xFF882956), fontSize: 14)),
                              SizedBox(height: 4),
                              Text("20:00", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF4A0024))),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Aktivitas otot (EMG)", style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: _lightPink, borderRadius: BorderRadius.circular(10)),
                                child: Text(statusNyeri, style: const TextStyle(color: Color(0xFF882956), fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          
                          // GRAFIK DINAMIS REALTIME
                          SizedBox(
                            height: 60, width: double.infinity,
                            child: CustomPaint(
                              painter: RealtimeChartPainter(data: _emgHistory, color: _primaryColor, maxValue: 1.5),
                            ),
                          ),
                          
                          const SizedBox(height: 25),
                          Text("RMS: ${_emgRmsTerakhir.toStringAsFixed(2)} mV", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Suhu pemanas", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                const SizedBox(height: 8),
                                Text("$_suhuTerakhir°C", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(value: _suhuTerakhir / 60.0, minHeight: 8, backgroundColor: _lightPink, color: _primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Intensitas (fuzzy)", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                const SizedBox(height: 8),
                                Text("$_intensitasTerakhir%", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(value: _intensitasTerakhir / 100.0, minHeight: 8, backgroundColor: _lightPink, color: _primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0, top: 10.0),
              child: SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  onPressed: _isSesiAktif ? _hentikanSesi : _mulaiSesi,
                  child: Text(_isSesiAktif ? "Hentikan sesi" : "Mulai Sesi", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// LOGIKA PENGGAMBARAN GRAFIK DINAMIS DARI ARRAY
class RealtimeChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxValue;

  RealtimeChartPainter({required this.data, required this.color, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    double stepX = size.width / (30 - 1); // Mengasumsikan max 30 titik

    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double normalizedY = (data[i] / maxValue).clamp(0.0, 1.0);
      double y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Titik bulat di akhir grafik
    double lastNormY = (data.last / maxValue).clamp(0.0, 1.0);
    double lastY = size.height - (lastNormY * size.height);
    canvas.drawCircle(Offset((data.length - 1) * stepX, lastY), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Harus True agar animasi jalan
}