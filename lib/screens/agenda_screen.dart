import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class AgendaScreen extends StatefulWidget {
  final String sessionToken;
  final Map<String, dynamic> userData;

  const AgendaScreen({
    super.key,
    required this.sessionToken,
    required this.userData,
  });

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  List<dynamic> birthdayList = [];
  List<dynamic> agendaList = [];
  bool _isLoading = true;
  bool _isFormExpanded = false;
  bool _isSubmitting = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final String apiBaseUrl = 'https://kitachat-production.up.railway.app';

  @override
  void initState() {
    super.initState();
    _fetchAgendaAndBirthdays();
  }

  // Mengambil data ulang tahun dan agenda dari REST API Railway
  Future<void> _fetchAgendaAndBirthdays() async {
    setState(() => _isLoading = true);
    try {
      final headers = {
        'x-user-id': widget.userData['id'].toString(),
        'x-session-token': widget.sessionToken,
      };

      // 1. Ambil Data Ulang Tahun Keluarga (Otomatis mencakup anggota yang baru mendaftar)
      final bdayResponse = await http.get(
        Uri.parse('$apiBaseUrl/api/family-birthdays'),
        headers: headers,
      );
      if (bdayResponse.statusCode == 200) {
        birthdayList = jsonDecode(bdayResponse.body);
      }

      // 2. Ambil Data Daftar Agenda Kegiatan
      final agendaResponse = await http.get(
        Uri.parse('$apiBaseUrl/api/agendas'),
        headers: headers,
      );
      if (agendaResponse.statusCode == 200) {
        agendaList = jsonDecode(agendaResponse.body);
      }
    } catch (e) {
      debugPrint('Error fetch agenda & birthdays: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Format tanggal ke format Indonesia (Contoh: 17 September)
  String _formatDateIndo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Tanggal belum diatur';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  // Format tanggal lengkap dengan tahun untuk daftar agenda
  String _formatFullDateIndo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // Buat Agenda Baru
  Future<void> _handleCreateAgenda() async {
    final title = _titleController.text.trim();
    final eventDate = _dateController.text.trim();
    final description = _descController.text.trim();

    if (title.isEmpty || eventDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan tanggal acara wajib diisi.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/agendas'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
        body: jsonEncode({
          'title': title,
          'event_date': eventDate,
          'description': description,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _titleController.clear();
        _dateController.clear();
        _descController.clear();
        setState(() {
          _isFormExpanded = false;
        });
        await _fetchAgendaAndBirthdays();
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Gagal menambahkan agenda.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error create agenda: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Hapus Agenda
  Future<void> _deleteAgenda(int agendaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Agenda'),
        content: const Text('Apakah Anda yakin ingin menghapus agenda ini?'),
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
        Uri.parse('$apiBaseUrl/api/agendas/$agendaId'),
        headers: {
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
      );

      if (response.statusCode == 200) {
        await _fetchAgendaAndBirthdays();
      }
    } catch (e) {
      debugPrint('Error delete agenda: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Menyesuaikan jumlah kolom grid kartu ulang tahun (Desktop: 4 kolom, Mobile: 2 kolom)
    final int crossAxisCount = screenWidth >= 900 ? 4 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda & Ulang Tahun'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFFE5DDD5),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF075E54)))
            : RefreshIndicator(
                onRefresh: _fetchAgendaAndBirthdays,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- KARTU KONTainer UTAMA ---
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. BAGIAN: DAFTAR ULANG TAHUN ANGGOTA
                                const Row(
                                  children: [
                                    Icon(Icons.cake, color: Color(0xFF075E54), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Daftar Ulang Tahun Anggota',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                birthdayList.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16.0),
                                        child: Center(
                                          child: Text(
                                            'Belum ada data anggota keluarga.',
                                            style: TextStyle(color: Colors.grey, fontSize: 13),
                                          ),
                                        ),
                                      )
                                    : GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 0.95,
                                        ),
                                        itemCount: birthdayList.length,
                                        itemBuilder: (context, index) {
                                          final member = birthdayList[index];
                                          final avatarUrl = member['profile_picture'] != null
                                              ? '$apiBaseUrl${member['profile_picture']}'
                                              : null;

                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8F9FA),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                CircleAvatar(
                                                  radius: 26,
                                                  backgroundColor: const Color(0xFF075E54),
                                                  backgroundImage: avatarUrl != null
                                                      ? CachedNetworkImageProvider(avatarUrl)
                                                      : null,
                                                  child: avatarUrl == null
                                                      ? const Icon(Icons.person, color: Colors.white, size: 26)
                                                      : null,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  member['name'] ?? 'Keluarga',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.cake, size: 12, color: Color(0xFFE74C3C)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatDateIndo(member['birth_date']),
                                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                const Divider(height: 32, thickness: 1),

                                // 2. BAGIAN: FORM TAMBAH AGENDA KELUARGA
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isFormExpanded = !_isFormExpanded;
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_month, color: Color(0xFF075E54), size: 22),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Tambah Agenda Keluarga',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _isFormExpanded ? 'Tutup formulir agenda' : 'Ketuk untuk membuat jadwal baru',
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        _isFormExpanded ? Icons.expand_less : Icons.chevron_right,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),

                                if (_isFormExpanded) ...[
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _titleController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nama acara atau kegiatan',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _dateController,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Pilih Tanggal Acara',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      prefixIcon: Icon(Icons.date_range, size: 20),
                                    ),
                                    onTap: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (pickedDate != null) {
                                        setState(() {
                                          _dateController.text = pickedDate.toIso8601String().split('T')[0];
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _descController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Keterangan atau lokasi (opsional)',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => setState(() => _isFormExpanded = false),
                                        child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF075E54),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: _isSubmitting ? null : _handleCreateAgenda,
                                        child: _isSubmitting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                              )
                                            : const Text('Simpan'),
                                      ),
                                    ],
                                  ),
                                ],

                                const Divider(height: 32, thickness: 1),

                                // 3. BAGIAN: DAFTAR KEGIATAN MENDATANG
                                const Row(
                                  children: [
                                    Icon(Icons.list_alt, color: Color(0xFF075E54), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Daftar Kegiatan Mendatang',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                agendaList.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12.0),
                                        child: Text(
                                          'Belum ada agenda kegiatan tercatat.',
                                          style: TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: agendaList.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final agenda = agendaList[index];
                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8F9FA),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        agenda['title'] ?? '',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF075E54).withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          _formatFullDateIndo(agenda['event_date']),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF075E54),
                                                          ),
                                                        ),
                                                      ),
                                                      if (agenda['description'] != null && agenda['description'].toString().isNotEmpty) ...[
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          agenda['description'],
                                                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                  tooltip: 'Hapus Agenda',
                                                  onPressed: () => _deleteAgenda(agenda['id']),
                                                ),
                                              ],
                                            ),
                                          );
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
      ),
    );
  }
}