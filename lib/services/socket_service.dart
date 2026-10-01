import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late io.Socket socket;
  bool isConnected = false;

  void connectSocket({required String userId, required String sessionToken}) {
    debugPrint('Mencoba menghubungkan WebSocket untuk User ID: $userId');

    socket = io.io(
      'https://kitachat-production.up.railway.app',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection() // Mengaktifkan penyambungan ulang otomatis
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setAuth({
            'userId': userId,
            'sessionToken': sessionToken, 
          })
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      isConnected = true;
      debugPrint('🟢 Berhasil terhubung ke WebSocket Server KitatChat!');
    });

    socket.onConnectError((data) {
      debugPrint('⚠️ Connect Error WebSocket: $data');
    });

    socket.on('error', (data) {
      debugPrint('⚠️ Error WebSocket: $data');
    });

    socket.onDisconnect((_) {
      isConnected = false;
      debugPrint('🔴 Koneksi WebSocket terputus.');
    });

    socket.on('chat_history', (data) {
      debugPrint('📥 Riwayat chat diterima: $data');
    });
  }

  void onChatHistory(Function(dynamic) callback) {
    socket.off('chat_history');
    socket.on('chat_history', (data) {
      callback(data);
    });
  }

  void sendMessage({required String message, required String userId, String? imageUrl}) {
    if (isConnected) {
      final Map<String, dynamic> payload = {
        'user_id': userId,
        'message': message,
        'image_url': imageUrl,
      };
      
      debugPrint('📤 Mengirim pesan ke server: $payload');
      socket.emit('send_message', payload);
    } else {
      debugPrint('⚠️ Gagal mengirim: Klien WebSocket sedang tidak terhubung.');
    }
  }

  void onReceiveMessage(Function(dynamic) callback) {
    socket.off('receive_message');
    socket.on('receive_message', (data) {
      callback(data);
    });
  }

  void disconnect() {
    if (isConnected) {
      socket.disconnect();
      socket.destroy();
      isConnected = false;
    }
  }
}