import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart'; // Menggunakan file_picker yang lebih stabil untuk Web & Mobile
import 'package:cached_network_image/cached_network_image.dart';


class AlbumScreen extends StatefulWidget {
  final String sessionToken;
  final Map<String, dynamic> userData;

  const AlbumScreen({
    super.key,
    required this.sessionToken,
    required this.userData,
  });

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<dynamic> albumList = [];
  bool _isLoading = false;
  bool _isUploading = false;
  
  PlatformFile? _selectedFile; // Menggunakan PlatformFile agar aman untuk Web & Mobile
  final TextEditingController _captionController = TextEditingController();

  final String apiBaseUrl = 'https://kitachat-production.up.railway.app';

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/albums'),
        headers: {
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            albumList = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetch album: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Pemilihan file gambar menggunakan FilePicker yang handal di Flutter Web
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        withData: true, // Wajib bernilai true agar bytes terbaca di Web
      );

      if (result == null || result.files.single.bytes == null) return;

      setState(() {
        _selectedFile = result.files.single;
      });
    } catch (e) {
      debugPrint('Error pilih file gambar: $e');
    }
  }

  
    // Proses upload foto mendukung Web (bytes) dan Mobile (bytes/path)
  Future<void> _uploadPhoto() async {
    if (_selectedFile == null) return;
    setState(() => _isUploading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/api/albums'),
      );
      request.headers['x-user-id'] = widget.userData['id'].toString();
      request.headers['x-session-token'] = widget.sessionToken;
      request.fields['caption'] = _captionController.text.trim();

      // Normalisasi nama file agar ekstensinya berhuruf kecil
      String originalName = _selectedFile!.name;
      String sanitizedName = originalName.toLowerCase();

      // Ekstrak tipe ekstensi file secara dinamis untuk menentukan header konten
      String extension = sanitizedName.split('.').last;
      String mimeSubtype = 'jpeg'; // Default cadangan
      if (extension == 'png') mimeSubtype = 'png';
      if (extension == 'gif') mimeSubtype = 'gif';
      if (extension == 'webp') mimeSubtype = 'webp';

      if (_selectedFile!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image', // 🟢 DIKEMBALIKAN KE 'image': Sesuai ekspektasi backend /api/albums
            _selectedFile!.bytes!, 
            filename: sanitizedName,
            contentType: http.MediaType('image', mimeSubtype),
          ),
        );
      } else if (_selectedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image', // 🟢 DIKEMBALIKAN KE 'image'
            _selectedFile!.path!,
            filename: sanitizedName,
            contentType: http.MediaType('image', mimeSubtype),
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _captionController.clear();
        setState(() {
          _selectedFile = null;
        });
        await _fetchAlbums();
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Gagal mengunggah foto.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error upload foto: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }


  Future<void> _deletePhoto(int photoId) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Foto'),
        content: const Text('Apakah Anda yakin ingin menghapus foto ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/api/albums/$photoId'),
        headers: {
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
      );

      if (response.statusCode == 200) {
        await _fetchAlbums();
      }
    } catch (e) {
      debugPrint('Error hapus foto: $e');
    }
  }

  void _showZoomDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(imageUrl),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.userData['id']?.toString();
    final screenWidth = MediaQuery.of(context).size.width;

    // Penyesuaian jumlah kolom responsif modern (Desktop: 4-5 kolom, Ponsel: 2 kolom)
    int crossAxisCount = 2;
    if (screenWidth >= 1200) {
      crossAxisCount = 5;
    } else if (screenWidth >= 900) {
      crossAxisCount = 4;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Album Kenangan Keluarga'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFFE5DDD5),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  // Kartu Pemicu Unggah Momen Keluarga (Modern Container)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
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
                      children: [
                        InkWell(
                          onTap: _pickImage,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF075E54).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Color(0xFF075E54), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Unggah Momen Keluarga',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedFile != null
                                          ? 'Terpilih: ${_selectedFile!.name}'
                                          : 'Ketuk untuk pilih dari galeri atau kamera',
                                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                        if (_selectedFile != null) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: _captionController,
                            decoration: const InputDecoration(
                              hintText: 'Keterangan foto (opsional)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _selectedFile = null),
                                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF075E54),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _isUploading ? null : _uploadPhoto,
                                child: _isUploading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Kirim Foto'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Grid Kontainer Foto Album Keluarga Bergaya Kartu Modern
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF075E54))),
                    )
                  else if (albumList.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('Belum ada foto di album.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85, // Memberikan ruang proporsional untuk teks caption di bawah
                      ),
                      itemCount: albumList.length,
                      itemBuilder: (context, index) {
                        final item = albumList[index];
                        final imageUrl = '$apiBaseUrl${item['image_url']}';
                        final isOwner = item['user_id']?.toString() == currentUserId;
                        final caption = item['caption']?.toString() ?? '';
                        final uploaderName = item['uploader_name']?.toString() ?? 'Keluarga';

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showZoomDialog(imageUrl),
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                                          errorWidget: (context, url, error) => const Icon(Icons.error),
                                        ),
                                      ),
                                      if (isOwner)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: PopupMenuButton<String>(
                                            icon: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.more_vert, color: Colors.white, size: 14),
                                            ),
                                            onSelected: (value) {
                                              if (value == 'delete') {
                                                _deletePhoto(item['id']);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 13)),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      uploaderName,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (caption.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        caption,
                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
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
    );
  }
}