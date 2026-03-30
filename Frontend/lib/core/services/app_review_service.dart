import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppReviewService {
  static final AppReviewService instance = AppReviewService._();
  AppReviewService._();

  final InAppReview _inAppReview = InAppReview.instance;

  Future<void> requestReviewIfNeeded(int completedWorkoutsCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRequested = prefs.getBool('has_requested_review') ?? false;
      if (hasRequested) return;

      final firstLaunch = prefs.getInt('first_launch_time');
      if (firstLaunch == null) {
        await prefs.setInt(
          'first_launch_time',
          DateTime.now().millisecondsSinceEpoch,
        );
        return;
      }

      final daysSinceLaunch =
          DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(firstLaunch))
              .inDays;

      if (completedWorkoutsCount >= 5 || daysSinceLaunch >= 7) {
        if (await _inAppReview.isAvailable()) {
          await _inAppReview.requestReview();
          await prefs.setBool('has_requested_review', true);
        }
      }
    } catch (e) {
      debugPrint('AppReviewService error: $e');
    }
  }
}
