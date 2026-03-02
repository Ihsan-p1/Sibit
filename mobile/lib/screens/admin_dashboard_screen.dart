import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'worker_home_screen.dart';
import 'batch_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  List<dynamic> _batches = [];
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getBatches(),
        ApiService.getAnalytics(),
      ]);
      if (mounted) {
        setState(() {
          _batches = results[0] as List<dynamic>;
          _analytics = results[1] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyBatch(String batchId, String action) async {
    try {
      final result = await ApiService.verifyBatch(batchId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'Berhasil'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
        (route) => false,
      );
    }
  }

  void _openBatchDetail(String batchId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute<bool>(builder: (_) => BatchDetailScreen(batchId: batchId)),
    );
    if (result == true) _loadData(); // Refresh if batch was deleted
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                _buildRingkasanTab(),
                _buildSemuaBatchTab(),
                _buildVerifikasiTab(),
                _buildTerverifikasiTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: 'Ringkasan',
            activeIcon: Icon(Icons.dashboard, color: const Color(0xFF2E7D32)),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt),
            label: 'Semua Batch',
            activeIcon: Icon(Icons.list_alt, color: const Color(0xFF2E7D32)),
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('${_batches.where((b) => b['is_verified'] == false).length}'),
              isLabelVisible: _batches.any((b) => b['is_verified'] == false),
              child: const Icon(Icons.pending_actions),
            ),
            label: 'Verifikasi',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Terverifikasi',
          ),
        ],
      ),
    );
  }

  // ======================= TAB 1: RINGKASAN =======================
  Widget _buildRingkasanTab() {
    final data = _analytics;
    if (data == null) {
      return const Center(child: Text('Gagal memuat data analytics'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _summaryCard('Total Bibit', '${data['total_bibit'] ?? 0}', Icons.eco, Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Total Hidup', '${data['total_hidup'] ?? 0}', Icons.favorite, Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _summaryCard('Angka Kematian', '${data['total_mati'] ?? 0}', Icons.heart_broken, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Keberhasilan', '${data['tingkat_keberhasilan'] ?? 0}%', Icons.trending_up, Colors.teal)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _summaryCard('Total Batch', '${data['total_batch'] ?? 0}', Icons.inventory_2, Colors.indigo)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Terverifikasi', '${data['batch_verified'] ?? 0}', Icons.verified, Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          _summaryCard('Menunggu Verifikasi', '${data['batch_pending'] ?? 0}', Icons.hourglass_bottom, Colors.orange),
          const SizedBox(height: 20),

          // Per-batch survival bars
          const Text('Performa per Batch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...(data['batches'] as List<dynamic>? ?? []).map((b) {
            final rate = (b['survival_rate'] as num?)?.toDouble() ?? 0.0;
            final isHealthy = rate >= 85;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(b['batch_id']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${rate.toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isHealthy ? Colors.green : Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(isHealthy ? Colors.green : Colors.red),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${b['jumlah_hidup']} / ${b['jumlah_awal']} hidup  •  ${b['varietas'] ?? ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ======================= TAB 2: SEMUA BATCH =======================
  Widget _buildSemuaBatchTab() {
    if (_batches.isEmpty) {
      return _emptyState(Icons.inventory_2_outlined, 'Belum ada batch');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _batches.length,
        itemBuilder: (context, index) {
          final b = _batches[index];
          final awal = (b['jumlah_awal'] as num?)?.toInt() ?? 0;
          final hidup = (b['jumlah_hidup'] as num?)?.toInt() ?? 0;
          final survivalRate = awal > 0 ? (hidup / awal * 100) : 0.0;
          
          // 3-level health system
          final Color healthColor;
          final Color healthBg;
          final String healthLabel;
          if (survivalRate >= 85) {
            healthColor = const Color(0xFF2E7D32);
            healthBg = const Color(0xFFE8F5E9);
            healthLabel = '🟢 Sehat';
          } else if (survivalRate >= 60) {
            healthColor = const Color(0xFFF57C00);
            healthBg = const Color(0xFFFFF3E0);
            healthLabel = '🟡 Perlu Perhatian';
          } else {
            healthColor = const Color(0xFFE53935);
            healthBg = const Color(0xFFFFEBEE);
            healthLabel = '🔴 Kritis';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openBatchDetail(b['batch_id'] as String),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: healthColor, width: 4)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b['batch_id']?.toString() ?? '',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        _statusBadge(b['is_verified'] == true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: healthBg, borderRadius: BorderRadius.circular(12)),
                      child: Text(healthLabel,
                          style: TextStyle(fontSize: 11, color: healthColor, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    _detailRow('Varietas', b['varietas']?.toString() ?? '-'),
                    _detailRow('Lokasi', b['lokasi']?.toString() ?? '-'),
                    _detailRow('Pekerja', b['nama_pekerja']?.toString() ?? '-'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hidup: $hidup / $awal', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        Text('${survivalRate.toStringAsFixed(1)}%',
                            style: TextStyle(fontWeight: FontWeight.bold, color: healthColor)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: survivalRate / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(healthColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================= TAB 3: VERIFIKASI =======================
  Widget _buildVerifikasiTab() {
    final pending = _batches.where((b) => b['is_verified'] == false).toList();
    return _buildVerificationList(pending, showActions: true);
  }

  // ======================= TAB 4: TERVERIFIKASI =======================
  Widget _buildTerverifikasiTab() {
    final verified = _batches.where((b) => b['is_verified'] == true).toList();
    return _buildVerificationList(verified, showActions: false);
  }

  Widget _buildVerificationList(List<dynamic> batches, {required bool showActions}) {
    if (batches.isEmpty) {
      return _emptyState(
        showActions ? Icons.inbox : Icons.check_circle_outline,
        showActions ? 'Tidak ada data menunggu verifikasi' : 'Belum ada data terverifikasi',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: batches.length,
        itemBuilder: (context, index) {
          final b = batches[index];
          final awalNum = (b['jumlah_awal'] as num?)?.toInt() ?? 0;
          final hidupNum = (b['jumlah_hidup'] as num?)?.toInt() ?? 0;
          final survival = awalNum > 0
              ? (hidupNum / awalNum * 100).toStringAsFixed(1)
              : '0.0';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openBatchDetail(b['batch_id'] as String),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b['batch_id']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        _statusBadge(b['is_verified'] == true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _detailRow('Varietas', b['varietas']?.toString() ?? '-'),
                    _detailRow('Pekerja', b['nama_pekerja']?.toString() ?? '-'),
                    _detailRow('Hidup / Awal', '$hidupNum / $awalNum'),
                    _detailRow('Kesehatan', '$survival%'),
                    if (showActions) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _verifyBatch(b['batch_id'] as String, 'reject'),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Tolak'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _verifyBatch(b['batch_id'] as String, 'approve'),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Setujui'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================= HELPER WIDGETS =======================
  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6)],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isVerified ? '✅ Verified' : '⏳ Pending',
        style: TextStyle(
          fontSize: 11,
          color: isVerified ? Colors.green[700] : Colors.orange[700],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
