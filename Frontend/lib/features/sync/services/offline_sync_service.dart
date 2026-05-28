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

  Box<PendingSync>? _syncBox;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  String? _activeSuffix;

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(44)) {
      Hive.registerAdapter(PendingSyncAdapter());
    }
    await _ensureBox();

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
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
    final box = _syncBox;
    if (box != null && box.isOpen) {
      await box.close();
    }
  }

  /// Yeni bir çevrimdışı işlem eklendiğinde kuyruğa kaydeder
  Future<void> addToQueue(PendingSync item) async {
    final box = await _ensureBox();
    await box.put(item.id, item);
    _updatePendingCount();
    debugPrint('Sıraya eklendi (Çevrimdışı): ${item.toString()}');
  }

  Future<Box<PendingSync>> _ensureBox() async {
    final suffix = StorageHelper.getUserStorageSuffix();
    final box = _syncBox;
    if (box != null && box.isOpen && _activeSuffix == suffix) {
      _updatePendingCount();
      return box;
    }
    if (box != null && box.isOpen) {
      await box.close();
    }
    _activeSuffix = suffix;
    _syncBox = await Hive.openBox<PendingSync>('pending_sync$suffix');
    _updatePendingCount();
    return _syncBox!;
  }

  void _updatePendingCount() {
    final box = _syncBox;
    pendingCount.value = box != null && box.isOpen ? box.length : 0;
  }

  Future<void> _syncPendingItems() async {
    if (_isSyncing) return;
    final box = await _ensureBox();

    if (box.isEmpty) return;

    _isSyncing = true;
    isSyncing.value = true;
    final keys = box.keys.toList();

    for (var key in keys) {
      final item = box.get(key);
      if (item == null) continue;

      try {
        debugPrint('Senkronize ediliyor: ${item.action} -> ${item.entityType}');

        final userId = StorageHelper.getUserId();
        if (userId == null || userId <= 0) {
          debugPrint(
            'Geçerli kullanıcı bulunamadı, senkronizasyon iptal edildi.',
          );
          continue;
        }

        final payload = jsonDecode(item.payload);

        // Kategoriye ve action'a göre servisleri çağır
        if (item.entityType == 'workout') {
          final workoutService = WorkoutService();
          if (item.action == 'create') {
            await workoutService.createWorkout(
              userId,
              WorkoutRequest.fromJson(payload),
            );
          } else if (item.action == 'update') {
            final workoutId = payload['id'] as int;
            final reqData = WorkoutRequest.fromJson(payload['data']);
            await workoutService.updateWorkout(userId, workoutId, reqData);
          } else if (item.action == 'delete') {
            final workoutId = payload['id'] as int;
            await workoutService.deleteWorkout(userId, workoutId);
          }
        } else if (item.entityType == 'workout_session') {
          final workoutService = WorkoutService();
          if (item.action == 'create') {
            await workoutService.createWorkoutSession(
              userId,
              WorkoutSessionRequest.fromJson(payload as Map<String, dynamic>),
            );
          }
        } else if (item.entityType == 'body_measurement') {
          final trackingService = TrackingService();
          if (item.action == 'create') {
            await trackingService.createBodyMeasurement(
              userId,
              BodyMeasurementRequest.fromJson(payload),
            );
          } else if (item.action == 'update') {
            final measurementId = payload['id'] as int;
            final reqData = BodyMeasurementRequest.fromJson(payload['data']);
            await trackingService.updateBodyMeasurement(
              userId,
              measurementId,
              reqData,
            );
          } else if (item.action == 'delete') {
            final measurementId = payload['id'] as int;
            await trackingService.deleteBodyMeasurement(userId, measurementId);
          }
        }

        await box.delete(key);
        _updatePendingCount();
        debugPrint('Başarılı şekilde senkronize edildi: ${item.id}');
      } catch (e) {
        debugPrint('Senkronizasyon hatası: ${item.id} - Hata: $e');
        item.retryCount++;
        await item.save(); // Retry sayısını güncelleyip tut
      }
    }

    _isSyncing = false;
    isSyncing.value = false;
    _updatePendingCount();
  }
}
