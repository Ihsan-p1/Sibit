import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'update_batch_screen.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool _hasScanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _hasScanned = true);

    // The QR code contains the batch URL like: http://host/update-batch/BATCH_ID
    // We extract the batch_id from it
    final rawValue = barcode.rawValue!;
    String batchId = rawValue;

    // Try to extract batch_id from URL pattern
    final regex = RegExp(r'update-batch/([A-Za-z0-9_-]+)');
    final match = regex.firstMatch(rawValue);
    if (match != null) {
      batchId = match.group(1)!;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => UpdateBatchScreen(batchId: batchId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code Bedeng'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Arahkan kamera ke QR Code bedeng',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
