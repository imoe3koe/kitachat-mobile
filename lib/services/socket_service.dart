import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Service untuk mengelola WebSocket connection ke KitaChat server
/// Menggunakan Singleton pattern untuk memastikan hanya 1 instance
class SocketService {
  static final SocketService _instance = SocketService._internal();
  
  factory SocketService() {
    return _instance;
  }
  
  SocketService._internal();

  late io.Socket socket;
  bool isConnected = false;
  bool _disposed = false;  // ✅ Track disposal state

  /// Hubungkan ke WebSocket server dengan authentication
  void connectSocket({
    required String userId,
    required String sessionToken,
  }) {
    if (_disposed) {
      debugPrint('⚠️ SocketService telah di-dispose, tidak bisa connect lagi');
      return;
    }

    debugPrint('🔌 Mencoba menghubungkan WebSocket untuk User ID: $userId');

    // ✅ Konfigurasi dengan error handling yang baik
    socket = io.io(
      'https://kitachat-production.up.railway.app',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])  // WebSocket dengan fallback polling
          .disableAutoConnect()  // Manual connection control
          .enableReconnection()  // Auto-reconnect jika terputus
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)  // Delay 2 detik antar retry
          .setReconnectionDelayMax(5000)  // Max delay 5 detik
          .setAuth({
            'userId': userId,
            'sessionToken': sessionToken,
          })
          .build(),
    );

    // Koneksi
    socket.connect();

    // Event: Berhasil terhubung
    socket.onConnect((_) {
      isConnected = true;
      debugPrint('✅ [Socket] Berhasil terhubung ke WebSocket Server!');
    });

    // Event: Error saat connecting
    socket.onConnectError((data) {
      isConnected = false;
      debugPrint('❌ [Socket] Connect Error: $data');
    });

    // Event: General error
    socket.on('error', (data) {
      debugPrint('⚠️ [Socket] Error Event: $data');
    });

    // Event: Disconnect
    socket.onDisconnect((_) {
      isConnected = false;
      debugPrint('🔴 [Socket] Koneksi WebSocket terputus.');
    });

    // Event: Chat history received (untuk debugging)
    socket.on('chat_history', (data) {
      debugPrint('📥 [Socket] Riwayat chat diterima: ${data.length} pesan');
    });
  }

  /// Listener untuk menerima riwayat chat
  void onChatHistory(Function(dynamic) callback) {
    socket.off('chat_history');
    socket.on('chat_history', (data) {
      callback(data);
    });
  }

  /// Kirim pesan ke server
  void sendMessage({
    required String message,
    required String userId,
    String? imageUrl,
  }) {
    if (isConnected) {
      final Map<String, dynamic> payload = {
        'user_id': userId,
        'message': message,
        'image_url': imageUrl,
      };
      debugPrint('📤 [Socket] Mengirim pesan: ${message.substring(0, (message.length > 50 ? 50 : message.length))}...');
      socket.emit('send_message', payload);
    } else {
      debugPrint('⚠️ [Socket] Gagal mengirim: WebSocket sedang tidak terhubung.');
    }
  }

  /// Listener untuk menerima pesan baru real-time
  void onReceiveMessage(Function(dynamic) callback) {
    socket.off('receive_message');
    socket.on('receive_message', (data) {
      callback(data);
    });
  }

  /// Disconnect dan cleanup resources
  void disconnect() {
    if (!_disposed) {
      try {
        if (isConnected) {
          socket.disconnect();
        }
        socket.dispose();  // ✅ Explicit cleanup
        isConnected = false;
        _disposed = true;
        debugPrint('🔌 [Socket] WebSocket disconnected dan di-cleanup');
      } catch (e) {
        debugPrint('⚠️ [Socket] Error during disconnect: $e');
      }
    }
  }
}
