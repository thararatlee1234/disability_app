import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th', null);
  runApp(const DisabilityApp());
}

class DisabilityApp extends StatelessWidget {
  const DisabilityApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'รายชื่อผู้ทุพพลภาพ',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'),
      ],
      locale: const Locale('th', 'TH'),
      home: const LoginScreen(),
    );
  }
}
