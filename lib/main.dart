import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() async {
  // ✅ Memastikan Flutter binding terinisialisasi dengan sempurna
  // untuk produksi Android, iOS, dan Web
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const KitatChatApp());
}

class KitatChatApp extends StatelessWidget {
  const KitatChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KitaChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF128C7E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,  // ✅ Material Design 3 untuk Flutter 3.24.x
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF128C7E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF111B21),
      ),
      themeMode: ThemeMode.system,  // Follow system theme preference
      home: const LoginScreen(),
    );
  }
}
