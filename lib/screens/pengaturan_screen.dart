import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class PengaturanScreen extends StatefulWidget {
  final String sessionToken;
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>>? onUserUpdated;

  const PengaturanScreen({
    super.key,
    required this.sessionToken,
    required this.userData,
    required this.onLogout,
    this.onUserUpdated,
  });

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  late Map<String, dynamic> currentUserData;
  final String apiBaseUrl = 'https://kitachat-production.up.railway.app';
  final ImagePicker _picker = ImagePicker();
  
  int _photoVersion = 0;

  @override
  void initState() {
    super.initState();
    currentUserData = Map.from(widget.userData);
  }

  Map<String, String> get _headers => {
        'x-user-id': currentUserData['id'].toString(),
        'x-session-token': widget.sessionToken,
      };

  Future<void> _handleUpdatePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/api/update-photo'));
      request.headers.addAll(_headers);

      final bytes = await image.readAsBytes();
      final mimeType = image.mimeType ?? 'image/jpeg';
      final mimeSplit = mimeType.split('/');

      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name.isNotEmpty ? image.name : 'profile.jpg',
        contentType: mimeSplit.length == 2 
            ? MediaType(mimeSplit[0], mimeSplit[1]) 
            : MediaType('image', 'jpeg'),
      );
      
      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (!mounted) return;
      final data = jsonDecode(response.body);
      final messenger = ScaffoldMessenger.of(context);

      if (response.statusCode == 200) {
        setState(() {
          if (data['user'] != null) {
            currentUserData = data['user'];
            _photoVersion++;
            
            if (widget.onUserUpdated != null) {
              widget.onUserUpdated!(currentUserData);
            }
          }
        });
        messenger.showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Foto profil berhasil diperbarui.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Gagal memperbarui foto profil.')),
        );
      }
    } catch (e) {
      debugPrint('Error update photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan jaringan saat mengunggah foto.')),
      );
    }
  }

  void _openEditProfileModal() {
    final nameController = TextEditingController(text: currentUserData['name'] ?? '');
    final bdayController = TextEditingController(text: currentUserData['birthdate'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.person_outline, color: Color(0xFF075E54)),
            SizedBox(width: 8),
            Text('Edit Profil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bdayController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Tanggal Lahir',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today, size: 20),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: dialogContext,
                  initialDate: DateTime.tryParse(bdayController.text) ?? DateTime(1990),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  bdayController.text = picked.toIso8601String().split('T')[0];
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _submitUpdateProfile(nameController.text.trim(), bdayController.text.trim());
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUpdateProfile(String name, String birthdate) async {
    if (name.isEmpty) return;
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/update-profile'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'birthdate': birthdate}),
      );
      if (!mounted) return;
      final data = jsonDecode(response.body);
      final messenger = ScaffoldMessenger.of(context);

      if (response.statusCode == 200) {
        setState(() {
          if (data['user'] != null) {
            currentUserData = data['user'];
            if (widget.onUserUpdated != null) {
              widget.onUserUpdated!(currentUserData);
            }
          }
        });
        messenger.showSnackBar(SnackBar(content: Text(data['message'] ?? 'Profil berhasil diperbarui.')));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(data['error'] ?? 'Gagal memperbarui profil.')));
      }
    } catch (e) {
      debugPrint('Error profile update: $e');
    }
  }

  void _openEmailModal() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Email Pemulihan'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Alamat email aktif', border: OutlineInputBorder()),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                final response = await http.put(
                  Uri.parse('$apiBaseUrl/api/update-email'),
                  headers: {..._headers, 'Content-Type': 'application/json'},
                  body: jsonEncode({'email': email}),
                );
                if (!mounted) return;
                final data = jsonDecode(response.body);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message'] ?? 'Email berhasil disimpan.')),
                );
              } catch (e) {
                debugPrint('Error email update: $e');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _openPasswordModal() {
    final oldPwController = TextEditingController();
    final newPwController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ganti Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password lama', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password baru (min. 8 karakter)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
            onPressed: () async {
              final oldPw = oldPwController.text;
              final newPw = newPwController.text;
              if (oldPw.isEmpty || newPw.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password lama wajib diisi dan password baru minimal 8 karakter.')),
                );
                return;
              }
              Navigator.pop(dialogContext);
              try {
                final response = await http.put(
                  Uri.parse('$apiBaseUrl/api/update-password'),
                  headers: {..._headers, 'Content-Type': 'application/json'},
                  body: jsonEncode({'old_password': oldPw, 'new_password': newPw}),
                );
                if (!mounted) return;
                final data = jsonDecode(response.body);
                final messenger = ScaffoldMessenger.of(context);

                if (response.statusCode == 200) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(data['message'] ?? 'Password berhasil diubah.')),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text(data['error'] ?? 'Gagal mengganti password.')),
                  );
                }
              } catch (e) {
                debugPrint('Error password update: $e');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleClearMyMessages() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pesan Saya'),
        content: const Text('Yakin ingin menghapus semua riwayat obrolan Anda?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/api/messages'),
        headers: _headers,
      );
      if (!mounted) return;
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Riwayat obrolan berhasil dihapus.')),
      );
    } catch (e) {
      debugPrint('Error clear chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawPhotoUrl = currentUserData['photo_url'];
    final baseAvatarUrl = rawPhotoUrl != null
        ? (rawPhotoUrl.startsWith('http')
            ? rawPhotoUrl
            : '$apiBaseUrl$rawPhotoUrl')
        : null;

    final avatarUrl = baseAvatarUrl != null ? '$baseAvatarUrl?v=$_photoVersion' : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFFE5DDD5),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFF075E54),
                          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                          child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUserData['name'] ?? 'Nama Pengguna',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    currentUserData['phone'] ?? 'Nomor Telepon',
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
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
                      children: [
                        _buildSettingItem(
                          icon: Icons.person_outline,
                          title: 'Ubah Informasi Profil',
                          subtitle: 'Perbarui nama dan tanggal lahir',
                          onTap: _openEditProfileModal,
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        _buildSettingItem(
                          icon: Icons.image_outlined,
                          title: 'Ganti Foto Profil',
                          subtitle: 'Perbarui foto akun',
                          onTap: _handleUpdatePhoto,
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        _buildSettingItem(
                          icon: Icons.delete_outline,
                          title: 'Hapus Pesan Saya',
                          subtitle: 'Hapus pesan yang Anda kirim',
                          isDanger: true,
                          onTap: _handleClearMyMessages,
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        _buildSettingItem(
                          icon: Icons.email_outlined,
                          title: 'Email Pemulihan',
                          subtitle: 'Tambah email untuk reset password',
                          onTap: _openEmailModal,
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        _buildSettingItem(
                          icon: Icons.lock_outline,
                          title: 'Ganti Password',
                          subtitle: 'Perbarui kata sandi akun',
                          onTap: _openPasswordModal,
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        _buildSettingItem(
                          icon: Icons.system_update_outlined,
                          title: 'Cek Pembaruan',
                          subtitle: 'Periksa versi aplikasi terbaru',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Aplikasi sudah menggunakan versi terbaru.')),
                            );
                          },
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        _buildSettingItem(
                          icon: Icons.logout,
                          title: 'Keluar Aplikasi',
                          subtitle: 'Akhiri sesi akun',
                          isDanger: true,
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Keluar Aplikasi'),
                                content: const Text('Apakah Anda yakin ingin keluar dari sesi ini?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Keluar', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              widget.onLogout();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    const color = Colors.black87;
    final iconColor = isDanger ? Colors.red : const Color(0xFF075E54);

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDanger ? Colors.red : color),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}