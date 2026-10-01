import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitachat_mobile/screens/login_screen.dart'; // Sesuaikan nama paket Anda

void main() {
  testWidgets('Navigasi awal test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}