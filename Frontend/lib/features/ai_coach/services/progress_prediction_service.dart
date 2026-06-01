import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/storage_helper.dart';
import 'package:dio/dio.dart';

/// Backend'den kullanıcının ilerleme tahminlerini çeker.
class ProgressPredictionService {
  final ApiClient _apiClient = ApiClient();

  Future<ProgressPrediction?> fetchPrediction() async {
    try {
      final token = StorageHelper.getToken();
      if (token == null || token.isEmpty) return null;

      final response = await _apiClient.get(
        '${ApiConstants.apiPrefix}/ai/progress-prediction',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return ProgressPrediction.fromJson(response.data);
      }
      return null;
    } catch (_) {
      return null; // Sessizce fail et, kullanıcıya hata gösterme
    }
  }
}

class ProgressPrediction {
  final WeightProjection? weightProjection;
  final CalorieBalance? calorieBalance;

  ProgressPrediction({this.weightProjection, this.calorieBalance});

  factory ProgressPrediction.fromJson(Map<String, dynamic> json) {
    return ProgressPrediction(
      weightProjection: json['weightProjection'] != null
          ? WeightProjection.fromJson(json['weightProjection'])
          : null,
      calorieBalance: json['calorieBalance'] != null
          ? CalorieBalance.fromJson(json['calorieBalance'])
          : null,
    );
  }
}

class WeightProjection {
  final double currentWeight;
  final double targetWeight;
  final double weeklyChangeKg;
  final double? weeksToTarget;
  final String status; // ON_TRACK | STAGNANT | WRONG_DIRECTION
  final String message;

  WeightProjection({
    required this.currentWeight,
    required this.targetWeight,
    required this.weeklyChangeKg,
    this.weeksToTarget,
    required this.status,
    required this.message,
  });

  factory WeightProjection.fromJson(Map<String, dynamic> json) {
    return WeightProjection(
      currentWeight: (json['currentWeight'] as num).toDouble(),
      targetWeight: (json['targetWeight'] as num).toDouble(),
      weeklyChangeKg: (json['weeklyChangeKg'] as num).toDouble(),
      weeksToTarget: json['weeksToTarget'] != null
          ? (json['weeksToTarget'] as num).toDouble()
          : null,
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }
}

class CalorieBalance {
  final int avgDailyCalories;
  final double tdee;
  final double dailyBalance;
  final String insight;

  CalorieBalance({
    required this.avgDailyCalories,
    required this.tdee,
    required this.dailyBalance,
    required this.insight,
  });

  factory CalorieBalance.fromJson(Map<String, dynamic> json) {
    return CalorieBalance(
      avgDailyCalories: json['avgDailyCalories'] as int,
      tdee: (json['tdee'] as num).toDouble(),
      dailyBalance: (json['dailyBalance'] as num).toDouble(),
      insight: json['insight'] as String,
    );
  }
}
