import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final String dbUrl = "https://terapi-2278e-default-rtdb.asia-southeast1.firebasedatabase.app";
  late DatabaseReference _riwayatRef;

  BluetoothConnection? _connection;
  String _buffer = "";

  bool _isSesiAktif = false;
  int _detikBerjalan = 0;
  Timer? _timer;
  DateTime? _waktuMulaiTerapi;
  
  // Variabel untuk Target Waktu Timer (Default 20 menit)
  int _targetMenit = 1; 

  double _suhuTerakhir = 0.0;
  double _emgRmsTerakhir = 0.0;
  String _statusNyeriIoT = "Tidak Nyeri";
  
  List<double> _emgHistory = []; 

  final Color _primaryColor = const Color(0xFFC2185B);
  final Color _lightPink = const Color(0xFFFDE8F1);

  @override
  void initState() {
    super.initState();
    _riwayatRef = FirebaseDatabase.instanceFor(app: FirebaseDatabase.instance.app, databaseURL: dbUrl)
        .ref("riwayat_terapi/dismenore_01");
  }

  void _onDataReceived(Uint8List data) {
    _buffer += ascii.decode(data);
    if (_buffer.contains('\n')) {
      List<String> lines = _buffer.split('\n');
      for (int i = 0; i < lines.length - 1; i++) {
        _processLine(lines[i]);
      }
      _buffer = lines.last;
    }
  }

  void _processLine(String line) {
    try {
      if (line.contains("Suhu:") && line.contains("EMG:")) {
        List<String> parts = line.split('|');
        if (parts.length >= 3) {
          String suhuStr = parts[0].replaceAll(RegExp(r'[^0-9.]'), '');
          String emgStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
          String statusStr = parts[2].replaceAll("Status:", "").trim();

          if (mounted) {
            setState(() {
              _suhuTerakhir = double.tryParse(suhuStr) ?? 0.0;
              _emgRmsTerakhir = double.tryParse(emgStr) ?? 0.0;
              _statusNyeriIoT = statusStr;

              _emgHistory.add(_emgRmsTerakhir);
              if (_emgHistory.length > 30) {
                _emgHistory.removeAt(0); 
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error parsing data: $e");
    }
  }

  void _mulaiSesi() async {
    // 1. MINTA IZIN BLUETOOTH SECARA PAKSA KE HP (WAJIB UNTUK ANDROID 12+)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    // Jika user menolak izin, hentikan proses
    if (statuses[Permission.bluetoothConnect]!.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Izin Bluetooth ditolak! Tidak bisa menyambung.")));
      return;
    }

    // Membungkus SELURUH proses koneksi untuk mencegah Silent Error
    try {
      // 2. Cek daftar perangkat yang sudah di-pairing
      List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? target;
      
      for(var d in bonded) {
        if(d.name != null && d.name!.contains("ESP32_Heater_Fuzzy")) {
          target = d; 
          break;
        }
      }

      if(target == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alat belum dipasangkan! Cek pengaturan Bluetooth.")));
         return;
      }

      setState(() {
        _isSesiAktif = true;
        _waktuMulaiTerapi = DateTime.now();
        _emgHistory.clear(); 
        _buffer = "";
      });

      // 3. Proses Koneksi
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menghubungkan ke IoT...")));
      
      _connection = await BluetoothConnection.toAddress(target.address);
      
      // Kirim perintah START ke ESP32
      _connection!.output.add(Uint8List.fromList(utf8.encode("START\n")));
      await _connection!.output.allSent;
      
      BluetoothConnection activeConnection = _connection!;
      
      activeConnection.input!.listen(_onDataReceived).onDone(() {
         // Pastikan event onDone ini BUKAN dari sisa koneksi lama yang nyangkut
         if (_isSesiAktif && mounted && _connection == activeConnection) {
            _hentikanSesi(otomatis: false); 
         }
      });

      // 4. Jalankan Timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() { 
            _detikBerjalan++; 
          });
          
          // PINDAHKAN PENGECEKAN INI KE LUAR SETSTATE
          if (_detikBerjalan >= _targetMenit * 60) {
            _hentikanSesi(otomatis: true);
          }
        }
      });
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hapus pesan "menghubungkan"
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Terhubung. Terapi dimulai selama $_targetMenit menit.")));
      
    } catch (e) {
      // JIKA ADA ERROR SISTEM, PESANNYA AKAN MUNCUL DI SINI
      setState(() { _isSesiAktif = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Gagal: $e"), 
        duration: const Duration(seconds: 4), // Tampil lebih lama agar bisa dibaca
      ));
    }
  }

  void _hentikanSesi({bool otomatis = false}) async {
    // 1. CEGAH PEMANGGILAN GANDA (Gembok utama agar fungsi tidak berjalan 2x)
    if (!_isSesiAktif) return;

    // 2. LANGSUNG MATIKAN STATUS AKTIF
    // Ini memastikan timer atau bluetooth tidak bisa memanggil fungsi ini lagi
    setState(() {
      _isSesiAktif = false;
    });

    // 3. Amankan data sebelum terhapus
    int durasiFinal = _detikBerjalan; 
    DateTime? waktuMulaiFinal = _waktuMulaiTerapi; 
    
    // 4. Matikan timer
    _timer?.cancel();
    _timer = null;

    // 5. Putus koneksi IoT sesegera mungkin di latar belakang
    try {
      if (_connection != null && _connection!.isConnected) {
        _connection!.output.add(Uint8List.fromList(utf8.encode("STOP\n")));
        await _connection!.output.allSent;
      }
    } catch (e) {
      debugPrint("Gagal kirim perintah STOP: $e");
    } finally {
      _connection?.dispose(); 
      _connection = null;
    }

    // 6. SIMPAN DATA (Tunggu sampai benar-benar masuk ke Firebase)
    await _simpanKeRiwayat(durasiFinal: durasiFinal, waktuMulai: waktuMulaiFinal, otomatis: otomatis);

    // 7. Bersihkan angka di layar SETELAH data aman tersimpan
    if (mounted) {
      setState(() {
        _detikBerjalan = 0;
        _emgHistory.clear(); 
        _suhuTerakhir = 0.0;
        _emgRmsTerakhir = 0.0;
        _waktuMulaiTerapi = null;
      });
    }
  }

Future<void> _simpanKeRiwayat({required int durasiFinal, DateTime? waktuMulai, bool otomatis = false}) async {
    if (waktuMulai == null) return;

    // Karena di main.dart kamu sudah set 'id_ID', kita bisa menggunakannya dengan aman di sini
    String tanggalTeks = DateFormat("dd MMM yyyy", "id_ID").format(waktuMulai);
    String waktuMulaiTeks = DateFormat("HH:mm", "id_ID").format(waktuMulai);
    String waktuSelesaiTeks = DateFormat("HH:mm", "id_ID").format(DateTime.now()); 
    String durasiTeks = _formatWaktu(durasiFinal);
    
    Map<String, dynamic> dataRiwayat = {
      "tanggal": tanggalTeks,
      "waktuMulai": waktuMulaiTeks,     // <--- Simpan waktu mulai
      "waktuSelesai": waktuSelesaiTeks, 
      "durasi": durasiTeks,
      "emg": _emgRmsTerakhir.toString(),
      "suhu": _suhuTerakhir.toString(),
      "statusNyeri": _statusNyeriIoT
    };

    try {
      // KITA TAMBAHKAN TIMEOUT 7 DETIK AGAR TIDAK NYANGKUT SELAMANYA
      await _riwayatRef.push().set(dataRiwayat).timeout(const Duration(seconds: 7));
      
      if (mounted) {
        if (otomatis) {
          _tampilkanDialogSelesai();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sesi dihentikan dan disimpan ke Riwayat")));
        }
      }
    } on TimeoutException catch (_) {
      // JIKA 7 DETIK GAGAL, MUNCULKAN PESAN MERAH INI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal: Koneksi Firebase terputus/ditolak!"), backgroundColor: Colors.red)
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Sistem: $error"), backgroundColor: Colors.red));
      }
    }
  }

  String _formatWaktu(int totalDetik) {
    int jam = totalDetik ~/ 3600;
    int menit = (totalDetik % 3600) ~/ 60;
    int detik = totalDetik % 60;
    return '${jam.toString().padLeft(2, '0')}:${menit.toString().padLeft(2, '0')}:${detik.toString().padLeft(2, '0')}';
  }

  
  // Fungsi untuk menampilkan Pop-up saat timer habis
  void _tampilkanDialogSelesai() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text("Terapi Selesai"),
            ],
          ),
          content: Text("Waktu terapi $_targetMenit menit telah berakhir. Data sesi telah otomatis disimpan ke riwayat Anda."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Tutup", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double maxEmgData = _emgHistory.isEmpty ? 2.0 : _emgHistory.reduce(math.max);
    double dynamicChartMax = maxEmgData < 2.0 ? 2.0 : maxEmgData * 1.3; 

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
                      const Text("Terapi dismenore", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(_isSesiAktif ? "Sesi berlangsung" : "Siap dimulai", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.bluetooth, color: Colors.black87, size: 20),
                      const SizedBox(width: 6),
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: _isSesiAktif ? const Color(0xFF00BFA5) : Colors.grey, shape: BoxShape.circle)),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("Target", style: TextStyle(color: Color(0xFF882956), fontSize: 14)),
                              
                              // DROPDOWN UNTUK MEMILIH TIMER (Hanya bisa diubah saat sesi belum mulai)
                              DropdownButton<int>(
                                value: _targetMenit,
                                underline: const SizedBox(), // Menghilangkan garis bawah bawaan
                                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A0024)),
                                items: [1, 2, 3].map((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text("$value:00", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF4A0024))),
                                  );
                                }).toList(),
                                onChanged: _isSesiAktif ? null : (int? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _targetMenit = newValue;
                                    });
                                  }
                                },
                              )
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
                                child: Text(_statusNyeriIoT, style: const TextStyle(color: Color(0xFF882956), fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          
                          SizedBox(
                            height: 70, width: double.infinity,
                            child: CustomPaint(
                              painter: RealtimeChartPainter(data: _emgHistory, color: _primaryColor, maxValue: dynamicChartMax),
                            ),
                          ),
                          
                          const SizedBox(height: 15),
                          Text("RMS: ${_emgRmsTerakhir.toStringAsFixed(2)} mV", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // KOTAK SUHU PEMANAS (Sekarang full-width tanpa intensitas)
                    Container(
                      width: double.infinity,
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
                            child: LinearProgressIndicator(value: _suhuTerakhir / 55.0, minHeight: 8, backgroundColor: _lightPink, color: _primaryColor),
                          ),
                        ],
                      ),
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
                  onPressed: _isSesiAktif ? () => _hentikanSesi(otomatis: false) : _mulaiSesi,
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

// LOGIKA PENGGAMBARAN GRAFIK DINAMIS DENGAN FILL GRADIENT
class RealtimeChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxValue;

  RealtimeChartPainter({required this.data, required this.color, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.4), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    double stepX = size.width / (30 - 1); 

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
    
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paintLine);

    double lastNormY = (data.last / maxValue).clamp(0.0, 1.0);
    double lastY = size.height - (lastNormY * size.height);
    canvas.drawCircle(Offset((data.length - 1) * stepX, lastY), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; 
}