import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';
import 'package:flutter/foundation.dart';
import 'offline_service.dart';

class ApiService {
  // HTTPS ENFORCEMENT
  static const bool isProduction = kReleaseMode;
  static const String baseUrl = isProduction 
      ? 'https://10.0.2.2:8000' // Change to actual production domain later
      : 'http://10.0.2.2:8000'; // Local development

  static const storage = FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 15);

  // SSL Certificate Pinning configuration (Mocked for development)
  static const String _certFingerprint = "SHA-256-OF-YOUR-PROD-CERTIFICATE";

  static Future<void> checkSSLPinning(String url) async {
    if (!isProduction) return; // Disable pinning in dev
    try {
      final secureUrl = url.replaceFirst('http://', 'https://');
      await HttpCertificatePinning.check(
        serverURL: secureUrl,
        sha: SHA.SHA256,
        allowedSHAFingerprints: [_certFingerprint],
        timeout: 50,
      );
    } catch (e) {
      throw Exception('Peringatan: Koneksi tidak aman atau serangan Man-in-the-Middle terdeteksi!');
    }
  }

  // --- TOKEN REFRESH LOGIC ---
  static Future<bool> refreshToken() async {
    try {
      final rToken = await storage.read(key: 'refresh_token');
      if (rToken == null) return false;
      
      final response = await http.post(
          Uri.parse('$baseUrl/api/refresh-token'),
          body: {'refresh_token': rToken},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await storage.write(key: 'access_token', value: data['access_token']?.toString());
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- HELPER: HTTP with timeout, pinning, and refresh retry ---
  
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getToken();
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  static Future<http.Response> _getWithRetry(String url) async {
    await checkSSLPinning(url);
    var headers = await _getAuthHeaders();
    try {
      var response = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      if (response.statusCode == 401) {
        // Attempt token refresh
        final refreshed = await refreshToken();
        if (refreshed) {
           headers = await _getAuthHeaders();
           response = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
        }
      }
      return response;
    } on TimeoutException {
      return await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
    }
  }

  static Future<http.Response> _postWithRetry(String url, Map<String, String> body) async {
    await checkSSLPinning(url);
    var headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    
    try {
      var response = await http.post(Uri.parse(url), headers: headers, body: body).timeout(_timeout);
      if (response.statusCode == 401) {
        final refreshed = await refreshToken();
        if (refreshed) {
           headers = await _getAuthHeaders();
           headers['Content-Type'] = 'application/x-www-form-urlencoded';
           response = await http.post(Uri.parse(url), headers: headers, body: body).timeout(_timeout);
        }
      }
      return response;
    } on TimeoutException {
      return await http.post(Uri.parse(url), headers: headers, body: body).timeout(_timeout);
    }
  }

  // (Replaced by the logic block above)

  // --- AUTH ---
  // To handle 2FA we might add a totp_code option
  static Future<Map<String, dynamic>> login(String username, String password, {String? totpCode}) async {
    final bodyData = {
      'username': username,
      'password': password,
    };
    if (totpCode != null) bodyData['totp_code'] = totpCode;
    
    final response = await _postWithRetry('$baseUrl/api/login', bodyData);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await storage.write(key: 'access_token', value: data['access_token']?.toString());
      if (data.containsKey('refresh_token')) {
        await storage.write(key: 'refresh_token', value: data['refresh_token']?.toString());
      }
      await storage.write(key: 'role', value: data['role']?.toString());
      return data;
    } else if (response.statusCode == 403 && response.body.contains('TOTP_REQUIRED')) {
      throw Exception('TOTP_REQUIRED'); // Signals UI to prompt for 2FA code
    } else {
      throw Exception('Login gagal: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<void> logout() async {
    try {
      // Try to gracefully notify backend
      final rToken = await storage.read(key: 'refresh_token');
      if (rToken != null) {
        await _postWithRetry('$baseUrl/api/logout', {'refresh_token': rToken});
      }
    } catch (_) {}
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
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'] as List<dynamic>;
    }
    throw Exception('Gagal memuat data batch');
  }

  static Future<Map<String, dynamic>> getBatchDetails(String batchId) async {
    final response = await _getWithRetry('$baseUrl/api/batches/$batchId');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>;
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
        return jsonDecode(response.body) as Map<String, dynamic>;
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
      
      var headers = await _getAuthHeaders();
      request.headers.addAll(headers);
      request.fields['nama_pekerja'] = namaPekerja;
      request.fields['catatan'] = catatan ?? '';

      if (photoPath != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
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
    // This is handled by _postWithRetry essentially, but it's a PUT request.
    // So let's write a manual put using the same refresh logic format.
    await checkSSLPinning(baseUrl);
    var headers = await _getAuthHeaders();
    
    var response = await http.put(
      Uri.parse('$baseUrl/api/batches/verify/$batchId?action=$action'),
      headers: headers,
    ).timeout(_timeout);
    
    if (response.statusCode == 401 && await refreshToken()) {
      headers = await _getAuthHeaders();
      response = await http.put(
        Uri.parse('$baseUrl/api/batches/verify/$batchId?action=$action'),
        headers: headers,
      ).timeout(_timeout);
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Gagal verifikasi: ${response.body}');
  }

  // --- ANALYTICS ---
  static Future<Map<String, dynamic>> getAnalytics() async {
    final response = await _getWithRetry('$baseUrl/api/analytics');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Gagal memuat analytics');
  }

  // --- DELETE BATCH ---
  static Future<Map<String, dynamic>> deleteBatch(String batchId) async {
    await checkSSLPinning(baseUrl);
    var headers = await _getAuthHeaders();
    
    var response = await http.delete(
      Uri.parse('$baseUrl/api/batches/$batchId'),
      headers: headers,
    ).timeout(_timeout);
    
    if (response.statusCode == 401 && await refreshToken()) {
      headers = await _getAuthHeaders();
      response = await http.delete(
        Uri.parse('$baseUrl/api/batches/$batchId'),
        headers: headers,
      ).timeout(_timeout);
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Gagal menghapus batch: ${response.body}');
  }
}
