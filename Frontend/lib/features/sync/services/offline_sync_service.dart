import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/utils/storage_helper.dart';
import '../../../core/api/services/workout_service.dart';
import '../../../core/api/services/tracking_service.dart';
import '../../../core/models/workout_models.dart';
import '../../../core/models/body_measurement.dart';
import '../domain/entities/pending_sync.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();

  factory OfflineSyncService() => _instance;

  OfflineSyncService._internal();

  late Box<PendingSync> _syncBox;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  Future<void> init() async {
    final suffix = StorageHelper.getUserStorageSuffix();
    if (!Hive.isAdapterRegistered(44)) {
      Hive.registerAdapter(PendingSyncAdapter());
    }
    _syncBox = await Hive.openBox<PendingSync>('pending_sync$suffix');

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        // İletişim sağlandığında senkronizasyonu başlat
        debugPrint('İnternet bağlantısı geldi, sync başlatılıyor...');
        _syncPendingItems();
      }
    });

    // Başlangıçta da kontrol et
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi)) {
      _syncPendingItems();
    }
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    if (_syncBox.isOpen) {
      await _syncBox.close();
    }
  }

  /// Yeni bir çevrimdışı işlem eklendiğinde kuyruğa kaydeder
  Future<void> addToQueue(PendingSync item) async {
    if (!_syncBox.isOpen) {
      final suffix = StorageHelper.getUserStorageSuffix();
      _syncBox = await Hive.openBox<PendingSync>('pending_sync$suffix');
    }
    await _syncBox.put(item.id, item);
    debugPrint('Sıraya eklendi (Çevrimdışı): ${item.toString()}');
  }

  Future<void> _syncPendingItems() async {
    if (_isSyncing) return;
    if (!_syncBox.isOpen) return;

    if (_syncBox.isEmpty) return;

    _isSyncing = true;
    final keys = _syncBox.keys.toList();

    for (var key in keys) {
      final item = _syncBox.get(key);
      if (item == null) continue;

      try {
        debugPrint('Senkronize ediliyor: ${item.action} -> ${item.entityType}');

        final userId = StorageHelper.getUserId();
        if (userId == null || userId <= 0) {
          debugPrint('Geçerli kullanıcı bulunamadı, senkronizasyon iptal edildi.');
          continue;
        }

        final payload = jsonDecode(item.payload);

        // Kategoriye ve action'a göre servisleri çağır
        if (item.entityType == 'workout') {
          final workoutService = WorkoutService();
          if (item.action == 'create') {
            await workoutService.createWorkout(userId, WorkoutRequest.fromJson(payload));
          } else if (item.action == 'update') {
            final workoutId = payload['id'] as int;
            final reqData = WorkoutRequest.fromJson(payload['data']);
            await workoutService.updateWorkout(userId, workoutId, reqData);
          } else if (item.action == 'delete') {
            final workoutId = payload['id'] as int;
            await workoutService.deleteWorkout(userId, workoutId);
          }
        } 
        else if (item.entityType == 'body_measurement') {
          final trackingService = TrackingService();
          if (item.action == 'create') {
            await trackingService.createBodyMeasurement(userId, BodyMeasurementRequest.fromJson(payload));
          } else if (item.action == 'update') {
            final measurementId = payload['id'] as int;
            final reqData = BodyMeasurementRequest.fromJson(payload['data']);
            await trackingService.updateBodyMeasurement(userId, measurementId, reqData);
          } else if (item.action == 'delete') {
            final measurementId = payload['id'] as int;
            await trackingService.deleteBodyMeasurement(userId, measurementId);
          }
        }

        await _syncBox.delete(key);
        debugPrint('Başarılı şekilde senkronize edildi: ${item.id}');
      } catch (e) {
        debugPrint('Senkronizasyon hatası: ${item.id} - Hata: $e');
        item.retryCount++;
        await item.save(); // Retry sayısını güncelleyip tut
      }
    }

    _isSyncing = false;
  }
}
