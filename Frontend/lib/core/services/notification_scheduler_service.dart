import 'package:flutter/material.dart';

import '../utils/storage_helper.dart';
import 'local_notification_service.dart';
import 'meal_reminder_service.dart';
import 'water_reminder_service.dart';

/// Keeps the device-level scheduled notifications aligned with saved settings.
class NotificationSchedulerService {
  static NotificationSchedulerService? _instance;
  static NotificationSchedulerService get instance {
    _instance ??= NotificationSchedulerService._();
    return _instance!;
  }

  NotificationSchedulerService._();

  Future<void> syncScheduledNotifications() async {
    final notifications = LocalNotificationService.instance;
    await notifications.init();

    if (!StorageHelper.getNotifEnabled()) {
      await notifications.cancelAll();
      debugPrint('NotificationSchedulerService: Tüm bildirimler kapatıldı');
      return;
    }

    if (StorageHelper.getNotifWater()) {
      final intervalHours = await WaterReminderService.instance
          .getIntervalHours();
      await notifications.scheduleWaterReminders(intervalHours);
    } else {
      await notifications.cancelWaterReminders();
    }

    final mealSettings = await MealReminderService.instance.getSettings();
    if (mealSettings.enabled) {
      await notifications.scheduleMealReminders(
        breakfast: mealSettings.breakfastEnabled
            ? mealSettings.breakfastTime
            : null,
        lunch: mealSettings.lunchEnabled ? mealSettings.lunchTime : null,
        dinner: mealSettings.dinnerEnabled ? mealSettings.dinnerTime : null,
        snack: mealSettings.snackEnabled ? mealSettings.snackTime : null,
      );
    } else {
      await notifications.cancelMealReminders();
    }

    if (StorageHelper.getNotifWorkout()) {
      final wt = StorageHelper.getNotifWorkoutTime();
      await notifications.scheduleWorkoutReminder(
        time: TimeOfDay(hour: wt[0], minute: wt[1]),
      );
    } else {
      await notifications.cancelWorkoutReminder();
    }

    if (StorageHelper.getNotifDailySummary()) {
      await notifications.scheduleDailySummaryReminder();
      await notifications.scheduleMorningRecoveryReminder(); // Sabah da toparlanma skoru at
    } else {
      await notifications.cancelDailySummaryReminder();
      await notifications.cancelMorningRecoveryReminder();
    }

    debugPrint('NotificationSchedulerService: Bildirim planı senkronlandı');
  }
}
