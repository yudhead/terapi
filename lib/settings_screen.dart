import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Pastikan plugin ini ada di pubspec.yaml

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _statusKoneksi = "Mengecek...";
  String _namaPerangkat = "-";
  String _macAddress = "-";
  bool _isConnected = false;
  final Color _primary = const Color(0xFFC2185B);

  @override
  void initState() {
    super.initState();
    _cekStatusBluetooth();
  }

  // Logika dinamis untuk mengecek perangkat yang terhubung
  Future<void> _cekStatusBluetooth() async {
    bool isEnabled = await FlutterBluePlus.isSupported;
    if (!isEnabled) {
      setState(() => _statusKoneksi = "Tidak didukung");
      return;
    }

    // Mengambil daftar perangkat yang sudah terhubung (bonded)
    List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
    
    // Mencari perangkat dengan nama target "DysmenoCare"[cite: 3]
    var targetDevice = connectedDevices.firstWhere(
      (d) => d.platformName.contains("DysmenoCare"), 
      orElse: () => BluetoothDevice(remoteId: const DeviceIdentifier("00:00:00:00:00:00"))
    );

    if (targetDevice.remoteId.str != "00:00:00:00:00:00") {
      setState(() {
        _isConnected = true;
        _statusKoneksi = "Terhubung";
        _namaPerangkat = targetDevice.platformName;
        _macAddress = targetDevice.remoteId.str;
      });
    } else {
      setState(() {
        _isConnected = false;
        _statusKoneksi = "Terputus";
        _namaPerangkat = "-";
        _macAddress = "-";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text("Pengaturan", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Atur preferensi terapi Anda", style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              Text("Koneksi Bluetooth", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
              const SizedBox(height: 16),

              // Main Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Item Device Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFDE8F1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.bluetooth, color: _primary),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_namaPerangkat, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(_isConnected ? "Perangkat terhubung" : "Tidak ada perangkat", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const Spacer(),
                          if (_isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                              child: const Text("Terhubung", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // Info Rows
                    _buildInfoRow(Icons.settings_input_component, "Status koneksi", _statusKoneksi, isStatus: true),
                    _buildInfoRow(Icons.smartphone, "Nama perangkat", _namaPerangkat),
                    _buildInfoRow(Icons.bluetooth_searching, "Alamat Bluetooth", _macAddress),
                    
                    const SizedBox(height: 16),
                    
                    // Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: BorderSide(color: _primary.withOpacity(0.2)),
                            backgroundColor: const Color(0xFFFDE8F1),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_isConnected ? "Putuskan koneksi" : "Hubungkan koneksi"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isStatus ? Colors.green : Colors.black87)),
        ],
      ),
    );
  }
}