import 'package:flutter/material.dart';
import 'screens/worker_home_screen.dart';

void main() {
  runApp(const SibitApp());
}

class SibitApp extends StatelessWidget {
  const SibitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIBIT - Sistem Tracking Batch Bibit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const WorkerHomeScreen(),
    );
  }
}
