import '../api_client.dart';
import '../api_exception.dart';
import '../../constants/api_constants.dart';
import '../../models/weight_record.dart';
import '../../models/weight_record_models.dart';

class TrackingService {
  final ApiClient _apiClient = ApiClient();

  /// Yeni kilo kaydı oluştur
  Future<WeightRecord> createWeightRecord(
    int userId,
    WeightRecordRequest request,
  ) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.weightRecords(userId),
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

  /// Kullanıcının tüm kilo kayıtlarını getir
  Future<List<WeightRecord>> getUserWeightRecords(int userId) async {
    try {
      final response = await _apiClient.get(ApiConstants.weightRecords(userId));

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
        ApiConstants.weightRecord(userId, recordId),
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
      await _apiClient.delete(ApiConstants.weightRecord(userId, recordId));
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Kilo kaydı silinemedi');
    }
  }
}
