import 'package:flutter/material.dart';
import 'add_batch_screen.dart';
import 'scan_qr_screen.dart';
import 'update_batch_screen.dart';
import '../screens/admin_login_screen.dart';
import '../services/offline_service.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    OfflineService.startAutoSync();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final count = await OfflineService.getPendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _syncNow() async {
    final result = await OfflineService.syncAll();
    if (!mounted) return;

    if (result.synced > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result.synced} data berhasil disinkronkan!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    if (result.failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${result.failed} data gagal disinkronkan. Coba lagi nanti.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    _refreshPending();
  }

  void _showUpdateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Pilih Metode Update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Bagaimana Anda ingin menemukan batch?', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.qr_code_scanner,
              title: 'Scan QR Code',
              subtitle: 'Gunakan kamera untuk scan QR di bedeng',
              color: const Color(0xFF1565C0),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanQrScreen()));
              },
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.edit_note,
              title: 'Input Manual',
              subtitle: 'Ketik Batch ID secara manual',
              color: const Color(0xFF7B1FA2),
              onTap: () {
                Navigator.pop(ctx);
                _showManualInput(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInput(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: Color(0xFF7B1FA2)),
            SizedBox(width: 8),
            Text('Input Batch ID'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Contoh: ABC-2024-001',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.inventory_2),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final batchId = controller.text.trim();
              if (batchId.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UpdateBatchScreen(batchId: batchId),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('SIBIT Worker Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
            icon: const Icon(Icons.shield, color: Colors.white70, size: 18),
            label: const Text('Admin', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ===== SYNC BANNER =====
              if (_pendingCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_pendingCount data belum tersinkron',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                            ),
                            const Text(
                              'Akan otomatis terkirim saat ada sinyal',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _syncNow,
                        child: const Text('Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              const Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)),
              const SizedBox(height: 16),
              const Text('Selamat Datang, Pekerja', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Pilih aksi yang ingin Anda lakukan hari ini.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 48),
              _ActionCard(
                icon: Icons.add_circle,
                title: 'Tambah Batch Baru',
                subtitle: 'Input bibit yang baru saja disemai',
                color: const Color(0xFF2E7D32),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBatchScreen()));
                  _refreshPending();
                },
              ),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.update,
                title: 'Update Batch',
                subtitle: 'Scan QR atau input Batch ID manual',
                color: const Color(0xFF1565C0),
                onTap: () {
                  _showUpdateOptions(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
