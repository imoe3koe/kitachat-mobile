import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/socket_service.dart';

class KeluargaScreen extends StatefulWidget {
  final String sessionToken;
  final Map<String, dynamic> userData;

  const KeluargaScreen({
    super.key,
    required this.sessionToken,
    required this.userData,
  });

  @override
  State<KeluargaScreen> createState() => _KeluargaScreenState();
}

class _KeluargaScreenState extends State<KeluargaScreen> {
  final SocketService _socketService = SocketService();
  List<dynamic> familyMembers = [];
  bool _isLoading = true;
  bool _isUpdatingLocation = false;
  
  final String apiBaseUrl = 'https://kitachat-production.up.railway.app';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchFamilyMembers();
    _updateMyCurrentLocation();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _socketService.socket.off('update_family_members');
    _socketService.socket.off('family_location_updated');
    super.dispose();
  }

  void _setupSocketListeners() {
    _socketService.socket.off('update_family_members');
    _socketService.socket.on('update_family_members', (data) {
      if (mounted) {
        _fetchFamilyMembers();
      }
    });

    _socketService.socket.off('family_location_updated');
    _socketService.socket.on('family_location_updated', (data) {
      if (mounted && data != null) {
        setState(() {
          final index = familyMembers.indexWhere((u) => u['id'].toString() == data['userId'].toString());
          if (index != -1) {
            familyMembers[index]['latitude'] = data['latitude'];
            familyMembers[index]['longitude'] = data['longitude'];
          }
        });
      }
    });
  }

  Future<void> _fetchFamilyMembers() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/users'),
        headers: {
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            familyMembers = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetch family members: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Sinkronisasi koordinat GPS perangkat ke backend dengan aman & anti-stuck
  Future<void> _updateMyCurrentLocation() async {
    setState(() => _isUpdatingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isUpdatingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isUpdatingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isUpdatingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _currentPosition = position;

      // Kirim koordinat ke backend via HTTP POST
      await http.post(
        Uri.parse('$apiBaseUrl/api/update-location'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      // Emit via socket agar anggota keluarga lain langsung menerima pembaruan
      _socketService.socket.emit('update_location', {
        'user_id': widget.userData['id'].toString(),
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      await _fetchFamilyMembers();
    } catch (e) {
      debugPrint('Error update location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mendapatkan lokasi GPS. Pastikan izin lokasi diizinkan di browser.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  void _openFamilyLocationModal() {
    _updateMyCurrentLocation();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.map, color: Color(0xFF075E54)),
                SizedBox(width: 8),
                Text('Lokasi & Darurat Keluarga', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pantau posisi terkini anggota keluarga atau gunakan tombol SOS jika terjadi keadaan darurat.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF075E54),
                        side: const BorderSide(color: Color(0xFF075E54)),
                      ),
                      icon: _isUpdatingLocation 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      label: Text(_isUpdatingLocation ? 'Mengambil GPS...' : 'Kirim Ulang Lokasi GPS Saya'),
                      onPressed: () async {
                        await _updateMyCurrentLocation();
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 8),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('KIRIM SINYAL SOS DARURAT', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _triggerSOSAlert(context),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // 🟢 Diperbaiki: Menghapus .toList() yang tidak perlu pada spread operator
                    ...familyMembers.map((user) {
                      final hasLocation = user['latitude'] != null && 
                                          user['longitude'] != null && 
                                          user['latitude'].toString().isNotEmpty && 
                                          user['longitude'].toString().isNotEmpty;
                      
                      final avatarUrl = user['photo_url'] != null ? '$apiBaseUrl${user['photo_url']}' : null;
                      final coordText = hasLocation 
                          ? '${_formatCoord(user['latitude'])}, ${_formatCoord(user['longitude'])}' 
                          : 'Koordinat belum tersedia (Belum aktifkan GPS)';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF075E54),
                              backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                              child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(coordText, style: TextStyle(fontSize: 11, color: hasLocation ? Colors.black87 : Colors.red[300])),
                                  if (hasLocation) ...[
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () async {
                                        final url = Uri.parse('https://maps.google.com/?q=${user['latitude']},${user['longitude']}');
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      child: Row(
                                        children: const [
                                          Icon(Icons.location_on, size: 14, color: Color(0xFF075E54)),
                                          SizedBox(width: 4),
                                          Text('Buka di Google Maps', style: TextStyle(fontSize: 12, color: Color(0xFF075E54), fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatCoord(dynamic val) {
    if (val == null) return '';
    try {
      return double.parse(val.toString()).toStringAsFixed(5);
    } catch (_) {
      return val.toString();
    }
  }

  Future<void> _triggerSOSAlert(BuildContext dialogContext) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi SOS'),
        content: const Text('PERHATIAN: Kirim sinyal darurat SOS ke seluruh anggota keluarga sekarang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kirim', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    String mapsLink = '';
    if (_currentPosition != null) {
      mapsLink = ' \nLokasi Saya: https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    }

    final sosMessage = '🚨 DARURAT (SOS)! Saya membutuhkan bantuan segera!$mapsLink';

    try {
      var requestBody = {'message': sosMessage};
      await http.post(
        Uri.parse('$apiBaseUrl/api/send-message'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
        body: jsonEncode(requestBody),
      );

      // Gunakan dialogContext.mounted untuk parameter BuildContext dialog
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext);

      // Gunakan mounted milik State untuk context utama
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinyal SOS berhasil dikirim ke obrolan keluarga!')),
      );
    } catch (e) {
      debugPrint('Error send SOS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Menyesuaikan jumlah kolom grid kartu anggota keluarga (Desktop: 4 kolom, Mobile: 2 kolom)
    final int crossAxisCount = screenWidth >= 900 ? 4 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Anggota Keluarga'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFFE5DDD5),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF075E54)))
            : RefreshIndicator(
                onRefresh: _fetchFamilyMembers,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF075E54),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Pantau Lokasi & Area Darurat Keluarga', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _openFamilyLocationModal,
                          ),
                          const SizedBox(height: 16),
                          familyMembers.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text('Belum ada anggota keluarga.', style: TextStyle(color: Colors.grey)),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.9,
                                  ),
                                  itemCount: familyMembers.length,
                                  itemBuilder: (context, index) {
                                    final user = familyMembers[index];
                                    final isOnline = user['is_online'] == true || user['is_online'] == 1;
                                    final statusColor = isOnline ? Colors.green : Colors.grey;
                                    final statusText = isOnline ? 'Online' : 'Offline';
                                    final avatarUrl = user['photo_url'] != null ? '$apiBaseUrl${user['photo_url']}' : null;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Stack(
                                            children: [
                                              CircleAvatar(
                                                radius: 28,
                                                backgroundColor: const Color(0xFF075E54),
                                                backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                                                child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 28) : null,
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            user['name'] ?? 'Pengguna',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user['phone'] ?? '',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}