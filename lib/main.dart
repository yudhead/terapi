import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// 1. PASTIKAN KAMU MENG-IMPORT KETIGA FILE INI
import 'main_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  runApp(const DismenoreCareApp());
}

class DismenoreCareApp extends StatelessWidget {
  const DismenoreCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DismenoreCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFC2185B), 
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MainNavigation(), // Ini akan memanggil class navigasi di bawah
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // 2. MASUKKAN WIDGET HALAMAN KE DALAM LIST INI
  // Urutannya harus sama persis dengan urutan ikon di bawah
  final List<Widget> _pages = [
    const MainScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Mengubah angka index saat ikon diklik
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 3. BODY INI YANG AKAN BERUBAH-UBAH SECARA OTOMATIS
      body: _pages[_selectedIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFFC2185B), // Warna saat diklik
        unselectedItemColor: Colors.grey, // Warna saat tidak diklik
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}