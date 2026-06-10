import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() => runApp(const DisabilityApp());

class DisabilityApp extends StatelessWidget {
  const DisabilityApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'รายชื่อผู้ทุพพลภาพ',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const LoginScreen(),
    );
  }
}
