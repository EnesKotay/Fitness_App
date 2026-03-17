import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/services/tracking_service.dart';
import '../../../core/models/body_measurement.dart';
import '../../../core/api/api_exception.dart';
import '../../sync/domain/entities/pending_sync.dart';
import '../../sync/services/offline_sync_service.dart';

class TrackingProvider with ChangeNotifier {
  final TrackingService _trackingService = TrackingService();

  // State
  List<BodyMeasurement> _bodyMeasurements = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<BodyMeasurement> get bodyMeasurements => _bodyMeasurements;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Vücut Ölçülerini Yükle
  Future<void> loadBodyMeasurements(int userId) async {
    if (userId <= 0) {
      _bodyMeasurements = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _bodyMeasurements = await _trackingService.getUserBodyMeasurements(userId);
      // Sort newest first
      _bodyMeasurements.sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Vücut ölçüleri yüklenemedi: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Yeni Vücut Ölçüsü Oluştur
  Future<bool> createBodyMeasurement(int userId, BodyMeasurementRequest request) async {
    if (userId <= 0) {
      _errorMessage = 'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final measurement = await _trackingService.createBodyMeasurement(userId, request);
      _upsertMeasurement(measurement);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.message.contains('SocketException') || e.message.contains('Failed host lookup')) {
        // Çevrimdışı senaryo: Sıraya ekle ve optimistic olarak UI'a ekle
        final id = const Uuid().v4();
        await OfflineSyncService().addToQueue(
          PendingSync(
            id: id,
            entityType: 'body_measurement',
            action: 'create',
            payload: jsonEncode(request.toJson()),
          ),
        );
        // Optimizasyon için sahte bir BodyMeasurement oluştur
        final fakeMeasurement = BodyMeasurement(
          id: DateTime.now().millisecondsSinceEpoch,
          userId: userId,
          date: request.date,
          chest: request.chest,
          waist: request.waist,
          hips: request.hips,
          leftArm: request.leftArm,
          rightArm: request.rightArm,
          leftLeg: request.leftLeg,
          rightLeg: request.rightLeg,
        );
        _upsertMeasurement(fakeMeasurement);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Vücut ölçüsü kaydedilemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Vücut Ölçüsünü Güncelle
  Future<bool> updateBodyMeasurement(
    int userId,
    int measurementId,
    BodyMeasurementRequest request,
  ) async {
    if (userId <= 0) {
      _errorMessage = 'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _trackingService.updateBodyMeasurement(
        userId,
        measurementId,
        request,
      );

      _bodyMeasurements.removeWhere((m) => m.id == measurementId && m.id != updated.id);
      _upsertMeasurement(updated);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.message.contains('SocketException') || e.message.contains('Failed host lookup')) {
        final id = const Uuid().v4();
        await OfflineSyncService().addToQueue(
          PendingSync(
            id: id,
            entityType: 'body_measurement',
            action: 'update',
            payload: jsonEncode({'id': measurementId, 'data': request.toJson()}),
          ),
        );
        // Optimistic UI Update
        final existingIndex = _bodyMeasurements.indexWhere((m) => m.id == measurementId);
        if (existingIndex != -1) {
          final previous = _bodyMeasurements[existingIndex];
          _bodyMeasurements[existingIndex] = BodyMeasurement(
            id: previous.id,
            userId: previous.userId,
            date: request.date,
            chest: request.chest,
            waist: request.waist,
            hips: request.hips,
            leftArm: request.leftArm,
            rightArm: request.rightArm,
            leftLeg: request.leftLeg,
            rightLeg: request.rightLeg,
          );
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Vücut ölçüsü güncellenemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Vücut Ölçüsünü Sil
  Future<bool> deleteBodyMeasurement(int userId, int measurementId) async {
    if (userId <= 0) {
      _errorMessage = 'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _trackingService.deleteBodyMeasurement(userId, measurementId);
      _bodyMeasurements.removeWhere((m) => m.id == measurementId);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.message.contains('SocketException') || e.message.contains('Failed host lookup')) {
        final id = const Uuid().v4();
        await OfflineSyncService().addToQueue(
          PendingSync(
            id: id,
            entityType: 'body_measurement',
            action: 'delete',
            payload: jsonEncode({'id': measurementId}),
          ),
        );
        // Optimistic UI Delete
        _bodyMeasurements.removeWhere((m) => m.id == measurementId);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Vücut ölçüsü silinemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset provider state (Logout vb. durumlarda)
  void reset() {
    _bodyMeasurements = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _upsertMeasurement(BodyMeasurement measurement) {
    final index = _bodyMeasurements.indexWhere((m) => m.id == measurement.id);
    if (index == -1) {
      _bodyMeasurements.add(measurement);
    } else {
      _bodyMeasurements[index] = measurement;
    }
    _bodyMeasurements.sort((a, b) => b.date.compareTo(a.date));
  }
}
