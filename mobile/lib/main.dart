import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'screens/worker_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool jailbroken = false;
  try {
    jailbroken = await FlutterJailbreakDetection.jailbroken;
  } on PlatformException {
    jailbroken = true; // Assume unsafe if check fails
  }

  runApp(SibitApp(isJailbroken: jailbroken));
}

class SibitApp extends StatelessWidget {
  final bool isJailbroken;
  
  const SibitApp({super.key, required this.isJailbroken});

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
      home: isJailbroken ? _buildErrorScreen() : const WorkerHomeScreen(),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.security_rounded, size: 80, color: Colors.red),
              SizedBox(height: 24),
              Text(
                'Akses Ditolak',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Perangkat Anda terdeteksi telah dimodifikasi (Root/Jailbreak). Demi keamanan, aplikasi SIBIT tidak dapat dijalankan di perangkat ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
