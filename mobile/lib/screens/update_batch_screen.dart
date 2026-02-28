import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class UpdateBatchScreen extends StatefulWidget {
  final String batchId;
  const UpdateBatchScreen({super.key, required this.batchId});

  @override
  State<UpdateBatchScreen> createState() => _UpdateBatchScreenState();
}

class _UpdateBatchScreenState extends State<UpdateBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _jumlahController = TextEditingController();
  final _catatanController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _batchData;
  XFile? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    _loadBatchDetails();
  }

  Future<void> _loadBatchDetails() async {
    try {
      final data = await ApiService.getBatchDetails(widget.batchId);
      if (mounted) {
        setState(() {
          _batchData = data['batch'];
          _jumlahController.text = _batchData?['jumlah_hidup']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch tidak ditemukan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Pilih Sumber Foto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.photo_library, color: Colors.blue),
              ),
              title: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Pilih foto dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.camera_alt, color: Colors.green),
              ),
              title: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Ambil foto baru'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source, imageQuality: 60, maxWidth: 800);
      if (image != null && mounted) {
        setState(() => _selectedPhoto = image);
      }
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.updateBatch(
        batchId: widget.batchId,
        jumlahHidup: int.parse(_jumlahController.text),
        namaPekerja: _namaController.text,
        catatan: _catatanController.text,
        photoPath: _selectedPhoto?.path,
      );
      if (mounted) {
        final isOffline = result['offline'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Update berhasil!'),
            backgroundColor: isOffline ? Colors.orange : Colors.green,
            duration: Duration(seconds: isOffline ? 4 : 2),
          ),
        );
        Navigator.pop(context);
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
        title: Text('Update: ${widget.batchId}'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _batchData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Batch Info Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_batchData!['batch_id'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _infoRow('Varietas', _batchData!['varietas']?.toString() ?? '-'),
                          _infoRow('Jumlah Awal', _batchData!['jumlah_awal']?.toString() ?? '-'),
                          _infoRow('Jumlah Hidup', _batchData!['jumlah_hidup']?.toString() ?? '-'),
                          _infoRow('Terverifikasi', _batchData!['is_verified'] == true ? '✅ Ya' : '⏳ Pending'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Form Update Harian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _namaController,
                          validator: (v) => (v == null || v.isEmpty) ? 'Nama wajib diisi' : null,
                          decoration: _inputDecoration('Nama Pekerja', Icons.person),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _jumlahController,
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || v.isEmpty) ? 'Jumlah wajib diisi' : null,
                          decoration: _inputDecoration('Jumlah Hidup Saat Ini', Icons.numbers),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _catatanController,
                          maxLines: 3,
                          decoration: _inputDecoration('Catatan (Opsional)', Icons.notes),
                        ),
                        const SizedBox(height: 16),

                        // Photo Upload Section
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              if (_selectedPhoto != null) ...[
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: Stack(
                                    children: [
                                      Image.file(
                                        File(_selectedPhoto!.path),
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        top: 8, right: 8,
                                        child: GestureDetector(
                                          onTap: () => setState(() => _selectedPhoto = null),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
                              InkWell(
                                onTap: _pickPhoto,
                                borderRadius: _selectedPhoto == null
                                    ? BorderRadius.circular(12)
                                    : const BorderRadius.vertical(bottom: Radius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _selectedPhoto == null ? Icons.add_a_photo : Icons.swap_horiz,
                                        color: const Color(0xFF1565C0),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedPhoto == null ? 'Tambah Foto Progres' : 'Ganti Foto',
                                        style: const TextStyle(
                                          color: Color(0xFF1565C0),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Foto opsional untuk dokumentasi progres bibit',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),

                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('KIRIM UPDATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0))),
    );
  }

  Widget _infoRow(String label, String value) {
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

  @override
  void dispose() {
    _namaController.dispose();
    _jumlahController.dispose();
    _catatanController.dispose();
    super.dispose();
  }
}
