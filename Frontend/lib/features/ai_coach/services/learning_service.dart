import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/storage_helper.dart';
import 'package:dio/dio.dart';

/// Backend'den kullanıcının öğrenme istatistiklerini çeker.
class LearningService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>?> getStats() async {
    try {
      final token = StorageHelper.getToken();
      if (token == null || token.isEmpty) return null;

      final response = await _apiClient.get(
        '${ApiConstants.apiPrefix}/ai/learning-stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null; // Sessizce fail et
    }
  }
}
