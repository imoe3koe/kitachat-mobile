import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Tab State ('login' atau 'register')
  String _currentTab = 'login';

  // Controller Login
  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Controller Register
  final TextEditingController _regNameController = TextEditingController();
  final TextEditingController _regPhoneController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  final TextEditingController _regBirthdateController = TextEditingController();
  final TextEditingController _regInviteCodeController = TextEditingController();

  // Tipe Pendaftaran ('create' untuk buat keluarga baru, 'join' untuk gabung)
  String _registerType = 'create';

  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  final String apiBaseUrl = 'https://kitachat-production.up.railway.app';

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _regBirthdateController.dispose();
    _regInviteCodeController.dispose();
    super.dispose();
  }

  // --- PROSES LOGIN ---
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    final phone = _loginPhoneController.text.trim();
    final password = _loginPasswordController.text;

    if (phone.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Nomor telepon dan password wajib diisi.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final sessionToken = data['session_token'];
        final userData = data['user'];

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(
              sessionToken: sessionToken,
              userData: userData,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'Terjadi kesalahan saat login.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi Anda.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PROSES REGISTRASI / DAFTAR BARU ---
  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    final name = _regNameController.text.trim();
    final phone = _regPhoneController.text.trim();
    final password = _regPasswordController.text;
    final birthdate = _regBirthdateController.text.trim();
    final inviteCode = _regInviteCodeController.text.trim().toUpperCase();

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Nama, nomor telepon, dan password wajib diisi.';
      });
      return;
    }

    if (_registerType == 'join' && inviteCode.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kode undangan keluarga wajib diisi jika ingin bergabung.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': password,
          'birthdate': birthdate,
          'register_type': _registerType,
          'invite_code': inviteCode,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _successMessage = data['message'] ?? 'Registrasi berhasil. Silakan masuk.';
          _currentTab = 'login'; // Pindah otomatis ke tab login
        });
        _regNameController.clear();
        _regPhoneController.clear();
        _regPasswordController.clear();
        _regBirthdateController.clear();
        _regInviteCodeController.clear();
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'Registrasi gagal.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Tidak dapat terhubung ke server saat mendaftar.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF128C7E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Logo & Judul
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A884),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00A884).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.comment, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kitachat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111B21),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hub Keluarga Tercinta',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF667781)),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Tab Pilihan (Masuk vs Daftar)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _currentTab = 'login';
                                _errorMessage = '';
                                _successMessage = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currentTab == 'login' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _currentTab == 'login'
                                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                      : [],
                                ),
                                child: Text(
                                  'Masuk',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _currentTab == 'login' ? const Color(0xFF00A884) : const Color(0xFF667781),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _currentTab = 'register';
                                _errorMessage = '';
                                _successMessage = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currentTab == 'register' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _currentTab == 'register'
                                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                      : [],
                                ),
                                child: Text(
                                  'Daftar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _currentTab == 'register' ? const Color(0xFF00A884) : const Color(0xFF667781),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pesan Sukses / Error
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_successMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Text(
                          _successMessage,
                          style: const TextStyle(color: Color(0xFF27AE60), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // KONDISIONAL TAMPILAN: FORM LOGIN ATAU FORM REGISTER
                    if (_currentTab == 'login') ...[
                      // --- FORM LOGIN ---
                      TextField(
                        controller: _loginPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Nomor Telepon',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _loginPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Masuk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      // --- FORM REGISTER (Buat / Gabung Keluarga) ---
                      Row(
                        children: [
                          Expanded(
                            child: 
                            // ignore: deprecated_member_use
                            RadioListTile<String>(
                              title: const Text('Buat Keluarga', style: TextStyle(fontSize: 12)),
                              value: 'create',
                              groupValue: _registerType,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: const Color(0xFF00A884),
                              onChanged: (val) {
                                if (val != null) setState(() => _registerType = val);
                              },
                            ),
                          ),
                          Expanded(
                            child: 
                            // ignore: deprecated_member_use
                            RadioListTile<String>(
                              title: const Text('Gabung Keluarga', style: TextStyle(fontSize: 12)),
                              value: 'join',
                              groupValue: _registerType,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: const Color(0xFF00A884),
                              onChanged: (val) {
                                if (val != null) setState(() => _registerType = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_registerType == 'join') ...[
                        TextField(
                          controller: _regInviteCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Kode Undangan Keluarga (Cth: KITA-XXXX)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.vpn_key),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: _regNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _regPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Nomor Telepon',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _regPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password (min. 8 karakter)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _regBirthdateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Lahir',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                          isDense: true,
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime(1990),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            if (!mounted) return;
                            _regBirthdateController.text = picked.toIso8601String().split('T')[0];
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A884),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Daftar Sekarang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],

                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      '© 2026 Kitachat • Developed by imoe3koe',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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