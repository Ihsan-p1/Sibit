import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddBatchScreen extends StatefulWidget {
  const AddBatchScreen({super.key});

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _batchIdController = TextEditingController();
  final _varietasController = TextEditingController();
  final _jumlahController = TextEditingController();
  final _lokasiController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitBatch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.createBatch(
        batchId: _batchIdController.text,
        varietas: _varietasController.text,
        jumlahAwal: int.parse(_jumlahController.text),
        lokasi: _lokasiController.text,
        namaPekerja: _namaController.text,
      );
      if (mounted) {
        final isOffline = result['offline'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Batch berhasil didaftarkan!'),
            backgroundColor: isOffline ? Colors.orange : Colors.green,
            duration: Duration(seconds: isOffline ? 4 : 2),
          ),
        );
        _formKey.currentState!.reset();
        _namaController.clear();
        _batchIdController.clear();
        _varietasController.clear();
        _jumlahController.clear();
        _lokasiController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('Tambah Batch Baru'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField('Nama Pekerja', _namaController, Icons.person, 'Nama lengkap Anda'),
              _buildField('ID Batch', _batchIdController, Icons.tag, 'ABC-2024-001'),
              _buildField('Varietas Kelapa Sawit', _varietasController, Icons.eco, 'DxP Simalungun'),
              _buildField('Jumlah Awal (Pokok)', _jumlahController, Icons.numbers, '1000',
                  keyboardType: TextInputType.number),
              _buildField('Lokasi', _lokasiController, Icons.location_on, 'Bedeng A1'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data akan berstatus Menunggu Verifikasi sampai Admin menyetujuinya.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitBatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SIMPAN BATCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (v) => (v == null || v.isEmpty) ? '$label wajib diisi' : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2E7D32))),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _batchIdController.dispose();
    _varietasController.dispose();
    _jumlahController.dispose();
    _lokasiController.dispose();
    super.dispose();
  }
}
