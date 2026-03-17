import '../api_client.dart';
import '../api_exception.dart';
import '../../constants/api_constants.dart';
import '../../models/weight_record.dart';
import '../../models/weight_record_models.dart';
import '../../models/body_measurement.dart';

class TrackingService {
  final ApiClient _apiClient = ApiClient();

  /// Yeni kilo kaydı oluştur
  Future<WeightRecord> createWeightRecord(
    int userId,
    WeightRecordRequest request,
  ) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.weightRecords,
        data: request.toJson(),
      );

      return WeightRecord.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Kilo kaydı oluşturulamadı');
    }
  }

  /// Kullanıcının kilo kayıtlarını getir (Filtreli ve Sayfalı)
  Future<List<WeightRecord>> getUserWeightRecords(
    int userId, {
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? size,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (page != null) queryParams['page'] = page;
      if (size != null) queryParams['size'] = size;

      final response = await _apiClient.get(
        ApiConstants.weightRecords,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => WeightRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Kilo kayıtları alınamadı');
    }
  }

  /// Kilo kaydını güncelle
  Future<WeightRecord> updateWeightRecord(
    int userId,
    int recordId,
    WeightRecordRequest request,
  ) async {
    try {
      final response = await _apiClient.put(
        ApiConstants.weightRecord(recordId),
        data: request.toJson(),
      );

      return WeightRecord.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Kilo kaydı güncellenemedi');
    }
  }

  /// Kilo kaydını sil
  Future<void> deleteWeightRecord(int userId, int recordId) async {
    try {
      await _apiClient.delete(ApiConstants.weightRecord(recordId));
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Kilo kaydı silinemedi');
    }
  }

  /// Kullanıcının vücut ölçülerini getir (Filtreli)
  Future<List<BodyMeasurement>> getUserBodyMeasurements(
    int userId, {
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? size,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String().split('T')[0];
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String().split('T')[0];
      if (page != null) queryParams['page'] = page;
      if (size != null) queryParams['size'] = size;

      final response = await _apiClient.get(
        ApiConstants.bodyMeasurements,
        queryParameters: queryParams,
      );
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => BodyMeasurement.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Vücut ölçüleri alınamadı');
    }
  }

  /// Yeni vücut ölçüsü oluştur
  Future<BodyMeasurement> createBodyMeasurement(
    int userId,
    BodyMeasurementRequest request,
  ) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.bodyMeasurements,
        data: request.toJson(),
      );
      return BodyMeasurement.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Vücut ölçüsü oluşturulamadı');
    }
  }

  /// Vücut ölçüsünü güncelle
  Future<BodyMeasurement> updateBodyMeasurement(
    int userId,
    int recordId,
    BodyMeasurementRequest request,
  ) async {
    try {
      final response = await _apiClient.put(
        ApiConstants.bodyMeasurement(recordId),
        data: request.toJson(),
      );
      return BodyMeasurement.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Vücut ölçüsü güncellenemedi');
    }
  }

  /// Vücut ölçüsünü sil
  Future<void> deleteBodyMeasurement(int userId, int recordId) async {
    try {
      await _apiClient.delete(ApiConstants.bodyMeasurement(recordId));
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Vücut ölçüsü silinemedi');
    }
  }
}
