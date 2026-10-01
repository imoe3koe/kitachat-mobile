import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Diperlukan untuk kIsWeb dan debugPrint
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'; // WebRTC Asli
import '../services/socket_service.dart';
import 'login_screen.dart';
import 'pengaturan_screen.dart';

class HomeScreen extends StatefulWidget {
  final String sessionToken;
  final Map<String, dynamic> userData;

  const HomeScreen({
    super.key,
    required this.sessionToken,
    required this.userData,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SocketService _socketService = SocketService();
  List<dynamic> messageList = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Media & Recording Tools
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _isUploading = false;
  bool _isRecording = false;

  // State untuk Fitur Balas (Reply)
  Map<String, dynamic>? _replyingTo;

  // State & Variabel WebRTC Panggilan Keluarga
  bool _isInCall = false;
  String _callStatus = 'Memanggil...';
  String _callPeerName = '';
  String? _activeCallId;
  String? _targetUserId;
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Map<String, dynamic> incomingOfferData = {};

  // Konfigurasi STUN Server (Sesuai dengan versi web app.js)[cite: 8]
  final Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
    ],
    'iceCandidatePoolSize': 20,
  };

  final String apiBaseUrl = 'https://kitachat-production.up.railway.app';

  @override
  void initState() {
    super.initState();
    
    // 1. Hubungkan Socket.io secara aman
    _socketService.connectSocket(
      userId: widget.userData['id'].toString(),
      sessionToken: widget.sessionToken,
    );

    // 2. Tangkap Riwayat Chat
    _socketService.socket.off('chat_history');
    _socketService.socket.on('chat_history', (data) {
      if (mounted && data is List) {
        setState(() {
          messageList = List.from(data); 
        });
        _scrollToBottom();
        _markMessagesAsRead(); // Tandai dibaca saat riwayat dimuat
      }
    });

    // 3. Tangkap Pesan Baru Real-time
    _socketService.onReceiveMessage((data) {
      if (mounted) {
        setState(() {
          messageList.add(data); 
        });
        _scrollToBottom();
        _markMessagesAsRead(); // Tandai dibaca saat pesan baru masuk
      }
    });

    // 4. Tangkap Event Hapus Pesan
    _socketService.socket.off('message_deleted');
    _socketService.socket.on('message_deleted', (data) {
      if (mounted && data != null && data['id'] != null) {
        setState(() {
          final index = messageList.indexWhere((m) => m['id'] == data['id']);
          if (index != -1) {
            messageList[index]['is_deleted'] = true;
            messageList[index]['message'] = 'Pesan telah dihapus';
            messageList[index]['image_url'] = null;
            messageList[index]['audio_url'] = null;
            messageList[index]['pdf_url'] = null;
            messageList[index]['reply_text'] = null;
          }
        });
      }
    });

    // 5. Listener WebRTC Signaling Asli via Socket.io
    _setupWebRtcListeners();

    // 6. Tangkap Event Pembaruan Status Pesan Telah Dibaca (Real-time Read Receipt)
    _socketService.socket.off('messages_read');
    _socketService.socket.on('messages_read', (data) {
      if (mounted && data != null) {
        setState(() {
          // Perbarui status is_read pada daftar pesan lokal
          for (var msg in messageList) {
            if (msg['user_id']?.toString() == widget.userData['id'].toString()) {
              msg['is_read'] = true;
            }
          }
        });
      }
    });

    // Panggil pertama kali saat halaman dibuka
    _markMessagesAsRead();
  }

  // Fungsi untuk mengirim sinyal bahwa pesan di chat telah dibaca
  void _markMessagesAsRead() {
    try {
      _socketService.socket.emit('mark_messages_read', {
        'user_id': widget.userData['id'].toString(),
      });
    } catch (e) {
      debugPrint('Error mark messages as read: $e');
    }
  }

  void _setupWebRtcListeners() {
    // Panggilan Masuk (Offer)
    _socketService.socket.off('incoming_call');
    _socketService.socket.on('incoming_call', (data) async {
      if (mounted && data != null) {
        setState(() {
          _isInCall = true;
          _callStatus = 'Panggilan Masuk...';
          _callPeerName = data['callerName'] ?? 'Keluarga';
          _activeCallId = data['callId']?.toString();
          _targetUserId = data['fromUserId']?.toString();
          incomingOfferData = data;
        });
        _showIncomingCallDialog(data);
      }
    });

    // Jawaban Panggilan (Answer)
    _socketService.socket.off('call_answered');
    _socketService.socket.on('call_answered', (data) async {
      if (mounted && data != null && _peerConnection != null) {
        try {
          final answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          await _peerConnection!.setRemoteDescription(answer);
          if (!mounted) return;
          setState(() {
            _callStatus = 'Terhubung';
          });
        } catch (e) {
          debugPrint('Gagal memproses remote description (answer): $e');
        }
      }
    });

    // Pertukaran ICE Candidate
    _socketService.socket.off('call_ice_candidate');
    _socketService.socket.on('call_ice_candidate', (data) async {
      if (mounted && data != null && _peerConnection != null) {
        try {
          final candidateData = data['candidate'];
          if (candidateData != null) {
            RTCIceCandidate candidate = RTCIceCandidate(
              candidateData['candidate'],
              candidateData['sdpMid'],
              candidateData['sdpMLineIndex'],
            );
            await _peerConnection!.addCandidate(candidate);
          }
        } catch (e) {
          debugPrint('Gagal menambahkan ICE Candidate: $e');
        }
      }
    });

    // Mengakhiri Panggilan
    _socketService.socket.off('end_call');
    _socketService.socket.on('end_call', (data) {
      if (mounted) {
        _cleanupCall(notify: false);
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Panggilan diakhiri.')),
        );
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _socketService.socket.off('chat_history');
    _socketService.socket.off('message_deleted');
    _socketService.socket.off('incoming_call');
    _socketService.socket.off('call_answered');
    _socketService.socket.off('call_ice_candidate');
    _socketService.socket.off('end_call');
    _socketService.socket.off('messages_read');
    _socketService.disconnect();
    _cleanupCall(notify: false);
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // --- LOGIKA WEBRTC PEER CONNECTION ---

  Future<RTCPeerConnection> _createPeerConnection() async {
    RTCPeerConnection pc = await createPeerConnection(_rtcConfig, {});

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (_targetUserId != null && _activeCallId != null) {
        _socketService.socket.emit('call_ice_candidate', {
          'toUserId': _targetUserId,
          'callId': _activeCallId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      }
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        debugPrint('Stream audio jarak jauh berhasil diterima.');
      }
    };

    return pc;
  }

  Future<void> _startCall(String targetUserId, String targetName) async {
    if (!mounted) return;
    setState(() {
      _isInCall = true;
      _callStatus = 'Memanggil $targetName...';
      _callPeerName = targetName;
      _targetUserId = targetUserId;
      _activeCallId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    });

    _showActiveCallDialog();

    try {
      final Map<String, dynamic> mediaConstraints = {'audio': true, 'video': false};
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      _peerConnection = await _createPeerConnection();
      
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _socketService.socket.emit('call_user', {
        'toUserId': targetUserId,
        'callId': _activeCallId,
        'callerName': widget.userData['name'],
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        }
      });
    } catch (e) {
      debugPrint('Error memulai WebRTC Call: $e');
      _cleanupCall(notify: true);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _acceptCall() async {
    try {
      if (!mounted) return;
      setState(() {
        _callStatus = 'Menghubungkan...';
      });

      final Map<String, dynamic> mediaConstraints = {'audio': true, 'video': false};
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      _peerConnection = await _createPeerConnection();

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      final offerData = incomingOfferData['offer'];
      RTCSessionDescription offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _socketService.socket.emit('call_answer', {
        'toUserId': _targetUserId,
        'callId': _activeCallId,
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        }
      });

      if (!mounted) return;
      setState(() {
        _callStatus = 'Terhubung';
      });
    } catch (e) {
      debugPrint('Error menerima panggilan WebRTC: $e');
      _cleanupCall(notify: true);
    }
  }

  void _cleanupCall({bool notify = true}) {
    if (notify && _targetUserId != null && _activeCallId != null) {
      _socketService.socket.emit('end_call', {'toUserId': _targetUserId});
    }

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    _peerConnection?.dispose();
    _peerConnection = null;

    if (!mounted) return;
    setState(() {
      _isInCall = false;
      _activeCallId = null;
      _targetUserId = null;
    });
  }

  // --- FITUR CHAT LAINNYA ---

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/send-message'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
        body: jsonEncode({
          'message': text,
          'reply_to_id': _replyingTo?['id'],
          'client_time': TimeOfDay.now().format(context),
        }),
      );

      if (response.statusCode == 201) {
        _messageController.clear();
        if (!mounted) return;
        setState(() {
          _replyingTo = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error kirim pesan: $e');
    }
  }

  Future<void> _pickAndSendImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (file == null) return;
    await _uploadFile(file, "image");
  }

  Future<void> _pickAndSendPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    await _uploadFile(result.files.single, "pdf");
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      return;
    }
    
    if (kIsWeb) {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: '',
      );
    } else {
      await _recorder.start(
        const RecordConfig(),
        path: '', 
      );
    }

    if (!mounted) return;
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
    });
    if (path != null) {
      if (kIsWeb) {
        await _uploadPathOrBlob(path, "audio");
      } else {
        await _uploadFile(XFile(path), "audio");
      }
    }
  }

  Future<void> _uploadFile(dynamic fileInput, String type) async {
    if (!mounted) return;
    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/api/send-message'),
      );
      request.headers['x-user-id'] = widget.userData['id'].toString();
      request.headers['x-session-token'] = widget.sessionToken;
      request.fields['type'] = type;
      request.fields['client_time'] = TimeOfDay.now().format(context);
      
      if (_replyingTo != null) {
        request.fields['reply_to_id'] = _replyingTo!['id'].toString();
      }

      if (kIsWeb && fileInput is XFile) {
        var bytes = await fileInput.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('media', bytes, filename: fileInput.name),
        );
      } else if (fileInput is PlatformFile) {
        if (fileInput.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes('media', fileInput.bytes!, filename: fileInput.name),
          );
        } else if (fileInput.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath('media', fileInput.path!),
          );
        }
      } else if (fileInput is XFile) {
        request.files.add(
          await http.MultipartFile.fromPath('media', fileInput.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (!mounted) return;
        setState(() => _replyingTo = null);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error upload file: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _uploadPathOrBlob(String pathOrBlob, String type) async {
    if (!mounted) return;
    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/api/send-message'),
      );
      request.headers['x-user-id'] = widget.userData['id'].toString();
      request.headers['x-session-token'] = widget.sessionToken;
      request.fields['type'] = type;
      request.fields['client_time'] = TimeOfDay.now().format(context);
      
      if (_replyingTo != null) {
        request.fields['reply_to_id'] = _replyingTo!['id'].toString();
      }

      if (kIsWeb) {
        final uri = Uri.parse(pathOrBlob);
        final responseBlob = await http.get(uri);
        request.files.add(
          http.MultipartFile.fromBytes('media', responseBlob.bodyBytes, filename: 'voice_note.m4a'),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('media', pathOrBlob),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (!mounted) return;
        setState(() => _replyingTo = null);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error upload audio blob: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await http.delete(
        Uri.parse('$apiBaseUrl/api/messages/$messageId'),
        headers: {
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
      );
    } catch (e) {
      debugPrint('Error hapus pesan: $e');
    }
  }

  void _showImageDialog(String imageUrl) {
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

  void _updateUserData(Map<String, dynamic> updatedData) {
    if (mounted) {
      setState(() {
        widget.userData.clear();
        widget.userData.addAll(updatedData);
      });
    }
  }

  void _openPengaturan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PengaturanScreen(
          sessionToken: widget.sessionToken,
          userData: widget.userData,
          onLogout: _logout,
          onUserUpdated: (newData) {
            _updateUserData(newData);
          },
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.purple),
                title: const Text("Gambar"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text("Dokumen PDF"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendPdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageText(String text, bool isDeleted) {
    if (isDeleted) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
      );
    }
    return Linkify(
      text: text,
      onOpen: (link) async {
        await launchUrl(
          Uri.parse(link.url),
          mode: LaunchMode.externalApplication,
        );
      },
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black,
      ),
      linkStyle: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
    );
  }

  Future<void> _openCallMenu() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/users'),
        headers: {
          'x-user-id': widget.userData['id'].toString(),
          'x-session-token': widget.sessionToken,
        },
      );
      if (response.statusCode != 200) return;

      final List users = jsonDecode(response.body);
      final otherMembers = users.where((u) => u['id'].toString() != widget.userData['id'].toString()).toList();

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Keluarga untuk Ditelepon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: otherMembers.length,
                    itemBuilder: (context, index) {
                      final member = otherMembers[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(member['name']),
                        trailing: IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () {
                            Navigator.pop(context);
                            _startCall(member['id'].toString(), member['name']);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error call menu: $e');
    }
  }

  void _showActiveCallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_callStatus),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_in_talk, size: 60, color: Colors.green),
            const SizedBox(height: 10),
            Text(_callPeerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _cleanupCall(notify: true);
              Navigator.pop(context);
            },
            child: const Text('Tutup', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showIncomingCallDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Panggilan Masuk...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ring_volume, size: 60, color: Colors.blue),
            const SizedBox(height: 10),
            Text(data['callerName'] ?? 'Keluarga', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _socketService.socket.emit('end_call', {'toUserId': data['fromUserId']});
              Navigator.pop(context);
            },
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _acceptCall();
              _showActiveCallDialog();
            },
            child: const Text('Terima'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    _socketService.disconnect();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Solusi 1: Mereferensikan variabel _isInCall agar warning 'unused_field' hilang
    // ignore: unnecessary_statements
    _isInCall;

    final currentUserId = widget.userData['id']?.toString();
    final screenWidth = MediaQuery.of(context).size.width;

    // Menyesuaikan batas maksimal lebar gelembung pesan secara adaptif (Desktop vs Ponsel)
    final double maxBubbleWidth = screenWidth > 768 ? screenWidth * 0.55 : screenWidth * 0.82;

    return Scaffold(
      appBar: AppBar(
        title: Text('Kitachat — Keluarga (${widget.userData['family_code'] ?? '-'})'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        actions: [
          // 🟢 Solusi 2 (Opsional): Memanfaatkan _isInCall untuk indikator warna ikon call
          IconButton(
            icon: Icon(
              Icons.call, 
              color: _isInCall ? Colors.greenAccent : Colors.white,
            ), 
            onPressed: _openCallMenu,
            tooltip: _isInCall ? 'Panggilan Aktif' : 'Panggilan Suara',
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: _openPengaturan),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: const Color(0xFFE5DDD5),
          child: Column(
            children: [
              Expanded(
                child: messageList.isEmpty
                    ? const Center(child: Text('Belum ada pesan obrolan keluarga.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messageList.length,
                        itemBuilder: (context, index) {
                          final msg = messageList[index];
                          final isMe = msg['user_id']?.toString() == currentUserId;
                          final isDeleted = msg['is_deleted'] == true;
                          final imageUrl = msg['image_url'];
                          final audioUrl = msg['audio_url'];
                          final pdfUrl = msg['pdf_url'];

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: isDeleted ? null : () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) => SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.reply),
                                          title: const Text('Balas Pesan'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            setState(() => _replyingTo = msg);
                                          },
                                        ),
                                        if (isMe)
                                          ListTile(
                                            leading: const Icon(Icons.delete, color: Colors.red),
                                            title: const Text('Hapus Pesan', style: TextStyle(color: Colors.red)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _deleteMessage(msg['id']);
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                                      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 1,
                                        spreadRadius: 0.2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe && !isDeleted)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            msg['name'] ?? 'Keluarga',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
                                          ),
                                        ),
                                      
                                      if (msg['reply_text'] != null && !isDeleted)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            border: const Border(left: BorderSide(color: Color(0xFF075E54), width: 3)),
                                          ),
                                          child: Text(msg['reply_text'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                                        ),

                                      if (imageUrl != null && imageUrl.toString().isNotEmpty && !isDeleted) ...[
                                        GestureDetector(
                                          onTap: () => _showImageDialog('$apiBaseUrl$imageUrl'),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              constraints: const BoxConstraints(maxWidth: 240, maxHeight: 260),
                                              child: CachedNetworkImage(
                                                imageUrl: "$apiBaseUrl$imageUrl",
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                                errorWidget: (context, url, error) => const Icon(Icons.error),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],

                                      if (audioUrl != null && audioUrl.toString().isNotEmpty && !isDeleted) ...[
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.play_arrow, color: Color(0xFF075E54)),
                                              onPressed: () {
                                                _audioPlayer.play(UrlSource("$apiBaseUrl$audioUrl"));
                                              },
                                            ),
                                            const Text("Voice Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                      ],

                                      if (pdfUrl != null && pdfUrl.toString().isNotEmpty && !isDeleted) ...[
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                          title: const Text("Dokumen PDF", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          subtitle: Text(msg['pdf_name'] ?? "file.pdf", style: const TextStyle(fontSize: 11)),
                                        ),
                                        const SizedBox(height: 6),
                                      ],

                                      _buildMessageText(msg['message'] ?? '', isDeleted),

                                      const SizedBox(height: 2),
                                      
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              msg['time'] ?? '',
                                              style: const TextStyle(fontSize: 10, color: Colors.black45),
                                            ),
                                            if (isMe)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 3),
                                                child: Icon(
                                                  Icons.done_all,
                                                  size: 14,
                                                  // Berubah jadi biru jika is_read bernilai true atau 1
                                                  color: (msg['is_read'] == true || msg['is_read'] == 1) 
                                                      ? Colors.blue 
                                                      : Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              if (_isUploading)
                const LinearProgressIndicator(color: Color(0xFF075E54)),

              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[200],
                  child: Row(
                    children: [
                      const Icon(Icons.reply, size: 20, color: Color(0xFF075E54)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Membalas ke ${_replyingTo!['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF075E54))),
                            Text(_replyingTo!['message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyingTo = null)),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Color(0xFF075E54)),
                      onPressed: _showAttachmentMenu,
                      tooltip: 'Lampirkan Berkas',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: "Ketik pesan...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    if (_isRecording)
                      IconButton(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        onPressed: _stopRecording,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.mic, color: Color(0xFF075E54)),
                        onPressed: _startRecording,
                      ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF25D366)),
                      onPressed: _handleSendMessage,
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
}