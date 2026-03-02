import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BatchDetailScreen extends StatefulWidget {
  final String batchId;

  const BatchDetailScreen({super.key, required this.batchId});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  Map<String, dynamic>? _batch;
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getBatchDetails(widget.batchId);
      if (mounted) {
        setState(() {
          _batch = data['batch'] is Map<String, dynamic>
              ? data['batch'] as Map<String, dynamic>
              : {'batch_id': widget.batchId};
          _logs = (data['logs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Batch'),
        content: Text('Yakin ingin menghapus batch ${widget.batchId}? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteBatch(widget.batchId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch berhasil dihapus'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batchId),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteBatch,
            tooltip: 'Hapus Batch',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _batch == null
              ? const Center(child: Text('Batch tidak ditemukan'))
              : RefreshIndicator(
                  onRefresh: _loadDetails,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      _buildStatsCard(),
                      const SizedBox(height: 16),
                      _buildAuditLogCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    final b = _batch!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                const Text('Informasi Umum',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            _infoRow('Batch ID', b['batch_id']?.toString() ?? '-'),
            _infoRow('Varietas', b['varietas']?.toString() ?? '-'),
            _infoRow('Lokasi', b['lokasi']?.toString() ?? '-'),
            _infoRow('Pekerja', b['nama_pekerja']?.toString() ?? '-'),
            _infoRow('Tanggal Semai', b['tanggal_semai']?.toString().substring(0, 10) ?? '-'),
            _infoRow('Status', b['is_verified'] == true ? '✅ Terverifikasi' : '⏳ Menunggu'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final b = _batch!;
    final awal = (b['jumlah_awal'] as num?)?.toInt() ?? 0;
    final hidup = (b['jumlah_hidup'] as num?)?.toInt() ?? 0;
    final mati = awal - hidup;
    final survivalRate = awal > 0 ? (hidup / awal * 100) : 0.0;
    final isHealthy = survivalRate >= 85;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                const Text('Statistik Bibit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _statBox('Awal', '$awal', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _statBox('Hidup', '$hidup', Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _statBox('Mati', '$mati', Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tingkat Keberhasilan', style: TextStyle(fontSize: 13, color: Colors.grey)),
                Text('${survivalRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isHealthy ? Colors.green : Colors.red,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: survivalRate / 100,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(isHealthy ? Colors.green : Colors.red),
              ),
            ),
            if (!isHealthy)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red, size: 16),
                      SizedBox(width: 4),
                      Text('⚠️ Mortalitas Tinggi', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                const Text('Riwayat Update',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Belum ada riwayat perubahan', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ..._logs.map((log) => _buildLogItem(log as Map<String, dynamic>)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: const Color(0xFF2E7D32), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(log['aksi']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          if (log['nilai_lama'] != null && log['nilai_baru'] != null)
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  const TextSpan(text: 'Jumlah Hidup: '),
                  TextSpan(
                    text: '${log['nilai_lama']}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' → '),
                  TextSpan(
                    text: '${log['nilai_baru']}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          if (log['keterangan'] != null && log['keterangan'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('"${log['keterangan']}"',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
            ),
          const SizedBox(height: 4),
          Text(log['tanggal']?.toString().substring(0, 16) ?? '',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
