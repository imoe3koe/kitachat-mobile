import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/socket_service.dart'; // Import untuk cleanup socket
import 'package:cached_network_image/cached_network_image.dart'; // Ditambahkan untuk dukungan avatar foto profil dinamis

// Modul halaman pendukung keluarga
import 'album_screen.dart';
import 'agenda_screen.dart';
import 'keluarga_screen.dart';
import 'pengaturan_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final String sessionToken;
  final Map<String, dynamic> userData;

  const MainNavigationScreen({
    super.key,
    required this.sessionToken,
    required this.userData,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isDarkMode = false; // State untuk fitur ubah tema (Terang / Gelap)

  // 1. Jadikan userData sebagai state lokal agar reaktif saat diperbarui dari menu Pengaturan
  late Map<String, dynamic> _currentUserData;
  final String apiBaseUrl = 'https://kitachat-production.up.railway.app';

  @override
  void initState() {
    super.initState();
    _currentUserData = Map.from(widget.userData);
  }

  // Fungsi untuk menangkap pembaruan profil dari PengaturanScreen secara global
  void _handleUserUpdated(Map<String, dynamic> updatedData) {
    if (mounted) {
      setState(() {
        _currentUserData = Map.from(updatedData);
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() {
    // 1. Putuskan koneksi socket secara bersih agar tidak bocor di background
    SocketService().disconnect();

    // 2. Navigasi kembali ke halaman login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 2. Daftarkan halaman dengan _currentUserData terbaru agar sinkron di semua tab
    final List<Widget> pages = [
      HomeScreen(
        sessionToken: widget.sessionToken, 
        userData: _currentUserData,
      ),
      AlbumScreen(sessionToken: widget.sessionToken, userData: _currentUserData),
      AgendaScreen(sessionToken: widget.sessionToken, userData: _currentUserData),
      KeluargaScreen(sessionToken: widget.sessionToken, userData: _currentUserData),
      PengaturanScreen(
        sessionToken: widget.sessionToken,
        userData: _currentUserData,
        onLogout: _logout,
        onUserUpdated: _handleUserUpdated, // 🟢 Hubungkan callback update profil di sini
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    
    // Deteksi otomatis apakah diakses dari perangkat mobile / layar kecil (< 768px)
    final bool isMobile = screenWidth < 768;

    // Lebar sidebar dinamis berdasarkan ukuran layar desktop/web
    final double sidebarWidth = screenWidth > 1200 
        ? 300 
        : screenWidth > 900 
            ? 260 
            : 220;

    // Palet warna dinamis berdasarkan mode tema aktif
    final Color backgroundColor = _isDarkMode ? const Color(0xFF111B21) : Colors.white;
    final Color chatBackgroundColor = _isDarkMode ? const Color(0xFF0B141A) : const Color(0xFFE5DDD5);
    final Color textColor = _isDarkMode ? Colors.white : Colors.black87;
    final Color subtitleColor = _isDarkMode ? Colors.grey[400]! : Colors.grey;
    final Color borderColor = _isDarkMode ? const Color(0xFF222D34) : const Color(0xFFE5DDD5);

    // --- TAMPILAN MOBILE (Bottom Navigation Bar) ---
    if (isMobile) {
      return Theme(
        data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
        child: Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF075E54),
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Obrolan'),
              BottomNavigationBarItem(icon: Icon(Icons.photo_album), label: 'Album'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Agenda'),
              BottomNavigationBarItem(icon: Icon(Icons.family_restroom), label: 'Keluarga'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Pengaturan'),
            ],
          ),
        ),
      );
    }

    // Mengambil URL foto profil untuk Sidebar Web
    final rawPhotoUrl = _currentUserData['photo_url'];
    final avatarUrl = rawPhotoUrl != null
        ? (rawPhotoUrl.startsWith('http') ? rawPhotoUrl : '$apiBaseUrl$rawPhotoUrl')
        : null;

    // --- TAMPILAN DESKTOP / WEB (Sidebar Responsif Kiri) ---
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Kiri dengan Lebar Adaptif & Tema Dinamis
          Container(
            width: sidebarWidth,
            color: backgroundColor,
            child: Column(
              children: [
                // Header Profil & Tombol Aksi Atas
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF075E54),
                        radius: 20,
                        backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUserData['name'] ?? 'Pengguna',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentUserData['phone'] ?? '',
                              style: TextStyle(fontSize: 12, color: subtitleColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Tombol Ubah Tema (Berfungsi Aktif Toggle Terang/Gelap)
                      IconButton(
                        icon: Icon(
                          _isDarkMode ? Icons.light_mode : Icons.dark_mode, 
                          size: 20, 
                          color: _isDarkMode ? Colors.amber : Colors.grey,
                        ),
                        tooltip: _isDarkMode ? 'Ubah ke Tema Terang' : 'Ubah ke Tema Gelap',
                        onPressed: () {
                          setState(() {
                            _isDarkMode = !_isDarkMode;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_isDarkMode ? 'Mode Gelap diaktifkan' : 'Mode Terang diaktifkan'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      // Tombol Logout
                      IconButton(
                        icon: const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                        tooltip: 'Keluar',
                        onPressed: _logout,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Daftar Menu Navigasi Sidebar
                Expanded(
                  child: Material(
                    color: backgroundColor,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildNavItem(0, 'Obrolan', Icons.chat),
                        _buildNavItem(1, 'Album', Icons.photo_album),
                        _buildNavItem(2, 'Agenda', Icons.calendar_month),
                        _buildNavItem(3, 'Keluarga', Icons.family_restroom),
                        _buildNavItem(4, 'Pengaturan', Icons.settings),
                      ],
                    ),
                  ),
                ),

                // Footer Copyright Sesuai Permintaan
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '@2026 ktiachat . developed by imoe3koe',
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // --- KONTEN UTAMA DI KANAN (IndexedStack untuk Menjaga State Chat/Socket) ---
          Expanded(
            child: Theme(
              data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
              child: Container(
                color: chatBackgroundColor,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: pages,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    final itemTextColor = isSelected 
        ? const Color(0xFF075E54) 
        : (_isDarkMode ? Colors.white70 : Colors.black87);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF075E54).withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF075E54) : (_isDarkMode ? Colors.grey[400] : Colors.grey[700]),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: itemTextColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        onTap: () => _onItemTapped(index),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}