import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // Pastikan file login_screen.dart sudah dibuat di folder lib/screens/[cite: 30]

void main() {
  // Memastikan binding widget terinisialisasi dengan sempurna untuk produksi Android & iOS
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KitatChatApp());
}

class KitatChatApp extends StatelessWidget {
  const KitatChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KitatChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF128C7E)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}