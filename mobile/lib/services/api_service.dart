import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'offline_service.dart';

class ApiService {
  // Change this to your server's IP when testing on a physical device
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator -> localhost
  static const storage = FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 15);

  // --- HELPER: HTTP with timeout + retry ---

  static Future<http.Response> _getWithRetry(String url) async {
    try {
      return await http.get(Uri.parse(url)).timeout(_timeout);
    } on TimeoutException {
      // One retry
      return await http.get(Uri.parse(url)).timeout(_timeout);
    }
  }

  static Future<http.Response> _postWithRetry(String url, Map<String, String> body) async {
    try {
      return await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(_timeout);
    } on TimeoutException {
      return await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(_timeout);
    }
  }

  // --- AUTH ---
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _postWithRetry('$baseUrl/api/login', {
      'username': username,
      'password': password,
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await storage.write(key: 'access_token', value: data['access_token']);
      await storage.write(key: 'role', value: data['role']);
      return data;
    } else {
      throw Exception('Login gagal. Periksa koneksi atau kredensial.');
    }
  }

  static Future<void> logout() async {
    await storage.deleteAll();
  }

  static Future<String?> getToken() async {
    return await storage.read(key: 'access_token');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // --- BATCHES ---
  static Future<List<dynamic>> getBatches() async {
    final response = await _getWithRetry('$baseUrl/api/batches');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    }
    throw Exception('Gagal memuat data batch');
  }

  static Future<Map<String, dynamic>> getBatchDetails(String batchId) async {
    final response = await _getWithRetry('$baseUrl/api/batches/$batchId');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    }
    throw Exception('Batch tidak ditemukan');
  }

  /// Create batch — falls back to offline queue if no connection.
  /// Returns a map with 'offline': true if saved locally.
  static Future<Map<String, dynamic>> createBatch({
    required String batchId,
    required String varietas,
    required int jumlahAwal,
    required String lokasi,
    required String namaPekerja,
  }) async {
    final data = {
      'batch_id': batchId,
      'varietas': varietas,
      'jumlah_awal': jumlahAwal,
      'lokasi': lokasi,
      'nama_pekerja': namaPekerja,
    };

    // Try online first
    try {
      final online = await OfflineService.isOnline();
      if (!online) throw Exception('Offline');

      final response = await _postWithRetry('$baseUrl/api/batches/create', {
        'batch_id': batchId,
        'varietas': varietas,
        'jumlah_awal': jumlahAwal.toString(),
        'lokasi': lokasi,
        'nama_pekerja': namaPekerja,
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Server error: ${response.body}');
    } catch (e) {
      // Offline fallback — save locally
      await OfflineService.savePending(
        type: 'create_batch',
        data: data,
      );
      return {
        'status': 'offline',
        'offline': true,
        'message': 'Tersimpan offline. Akan otomatis dikirim saat ada sinyal.',
      };
    }
  }

  /// Update batch — falls back to offline queue if no connection.
  static Future<Map<String, dynamic>> updateBatch({
    required String batchId,
    required int jumlahHidup,
    required String namaPekerja,
    String? catatan,
    String? photoPath,
  }) async {
    final data = {
      'batch_id': batchId,
      'jumlah_hidup': jumlahHidup,
      'nama_pekerja': namaPekerja,
      'catatan': catatan ?? '',
    };

    // Try online first
    try {
      final online = await OfflineService.isOnline();
      if (!online) throw Exception('Offline');

      final uri = Uri.parse('$baseUrl/api/batches/update/$batchId');
      final request = http.MultipartRequest('POST', uri);

      request.fields['jumlah_hidup'] = jumlahHidup.toString();
      request.fields['nama_pekerja'] = namaPekerja;
      request.fields['catatan'] = catatan ?? '';

      if (photoPath != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Server error: ${response.body}');
    } catch (e) {
      // Offline fallback — save locally
      await OfflineService.savePending(
        type: 'update_batch',
        data: data,
        photoPath: photoPath,
      );
      return {
        'status': 'offline',
        'offline': true,
        'message': 'Tersimpan offline. Akan otomatis dikirim saat ada sinyal.',
      };
    }
  }

  // --- ADMIN VERIFY ---
  static Future<Map<String, dynamic>> verifyBatch(String batchId, String action) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/api/batches/verify/$batchId?action=$action'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Gagal verifikasi: ${response.body}');
  }

  // --- ANALYTICS ---
  static Future<Map<String, dynamic>> getAnalytics() async {
    final response = await _getWithRetry('$baseUrl/api/analytics');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    }
    throw Exception('Gagal memuat analytics');
  }

  // --- DELETE BATCH ---
  static Future<Map<String, dynamic>> deleteBatch(String batchId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/batches/$batchId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Gagal menghapus batch: ${response.body}');
  }
}
