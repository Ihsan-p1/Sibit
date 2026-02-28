import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'api_service.dart';

/// Manages offline queue — saves operations locally when offline,
/// syncs them to the server when connectivity returns.
class OfflineService {
  static Database? _db;
  static StreamSubscription? _connectivitySub;
  static bool _syncing = false;

  // --- DATABASE SETUP ---

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'sibit_offline.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            data TEXT NOT NULL,
            photo_local_path TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  // --- CONNECTIVITY LISTENER ---

  /// Start listening for connectivity changes. Call once at app startup.
  static void startAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      // results is List<ConnectivityResult>
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        syncAll(); // auto-sync when connection comes back
      }
    });
  }

  static void stopAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // --- CHECK CONNECTIVITY ---

  static Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // --- SAVE PENDING OPERATION ---

  static Future<void> savePending({
    required String type, // 'create_batch' or 'update_batch'
    required Map<String, dynamic> data,
    String? photoPath,
  }) async {
    final db = await database;

    // If there's a photo, copy it to app's local directory
    // (so it persists even if original is deleted from gallery)
    String? localPhotoPath;
    if (photoPath != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'pending_photos'));
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(photoPath)}';
      final destPath = p.join(photosDir.path, fileName);
      await File(photoPath).copy(destPath);
      localPhotoPath = destPath;
    }

    await db.insert('pending_operations', {
      'type': type,
      'data': jsonEncode(data),
      'photo_local_path': localPhotoPath,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // --- GET PENDING COUNT ---

  static Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_operations');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // --- GET PENDING OPERATIONS (for display) ---

  static Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query('pending_operations', orderBy: 'created_at ASC');
  }

  // --- SYNC ALL PENDING ---

  static Future<SyncResult> syncAll() async {
    if (_syncing) return SyncResult(synced: 0, failed: 0, remaining: 0);
    _syncing = true;

    int synced = 0;
    int failed = 0;

    try {
      final db = await database;
      final pending = await db.query('pending_operations', orderBy: 'id ASC');

      for (final op in pending) {
        try {
          final type = op['type'] as String;
          final data = jsonDecode(op['data'] as String) as Map<String, dynamic>;
          final photoPath = op['photo_local_path'] as String?;

          if (type == 'create_batch') {
            await ApiService.createBatch(
              batchId: data['batch_id'],
              varietas: data['varietas'],
              jumlahAwal: data['jumlah_awal'],
              lokasi: data['lokasi'],
              namaPekerja: data['nama_pekerja'],
            );
          } else if (type == 'update_batch') {
            await ApiService.updateBatch(
              batchId: data['batch_id'],
              jumlahHidup: data['jumlah_hidup'],
              namaPekerja: data['nama_pekerja'],
              catatan: data['catatan'],
              photoPath: photoPath,
            );
          }

          // Success — remove from queue
          await db.delete('pending_operations', where: 'id = ?', whereArgs: [op['id']]);

          // Clean up local photo copy
          if (photoPath != null) {
            final photoFile = File(photoPath);
            if (await photoFile.exists()) await photoFile.delete();
          }

          synced++;
        } catch (e) {
          // This specific operation failed — skip and try the next one
          failed++;
        }
      }
    } finally {
      _syncing = false;
    }

    final remaining = await getPendingCount();
    return SyncResult(synced: synced, failed: failed, remaining: remaining);
  }

  // --- CLEANUP ---

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('pending_operations');
    // Clean up stored photos
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'pending_photos'));
    if (await photosDir.exists()) await photosDir.delete(recursive: true);
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final int remaining;
  SyncResult({required this.synced, required this.failed, required this.remaining});
}
