import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/notification_model.dart';
import '../utils/storage_helper.dart';
import 'local_notification_service.dart';

class NotificationService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications({bool presentUnreadLocally = false}) async {
    final token = StorageHelper.getToken();
    if (token == null || token.isEmpty) {
      _notifications = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '/api/notifications',
        queryParameters: {'limit': 50},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _notifications = data
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        if (presentUnreadLocally) {
          await _presentUnreadNotificationsLocally();
        }
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final response = await _apiClient.patch('/api/notifications/$id/read');
      if (response.statusCode == 204) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          final n = _notifications[index];
          _notifications[index] = NotificationModel(
            id: n.id,
            title: n.title,
            message: n.message,
            isRead: true,
            createdAt: n.createdAt,
            type: n.type,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? appVersion,
  }) async {
    if (token.trim().isEmpty) return;
    try {
      final payload = <String, dynamic>{
        'token': token.trim(),
        'platform': platform.trim(),
      };
      if (appVersion != null) {
        payload['appVersion'] = appVersion;
      }
      await _apiClient.post('/api/notifications/devices', data: payload);
    } catch (e) {
      debugPrint('Error registering notification token: $e');
    }
  }

  Future<void> unregisterDeviceToken(String token) async {
    if (token.trim().isEmpty) return;
    try {
      await _apiClient.delete(
        '/api/notifications/devices',
        data: {'token': token.trim()},
      );
    } catch (e) {
      debugPrint('Error unregistering notification token: $e');
    }
  }

  Future<void> _presentUnreadNotificationsLocally() async {
    final shown = StorageHelper.getShownRemoteNotificationIds().toSet();
    var changed = false;
    var presentedCount = 0;
    for (final notification in _notifications) {
      if (presentedCount >= 3) break;
      final key = notification.id.toString();
      if (notification.isRead || shown.contains(key)) continue;
      await LocalNotificationService.instance.showRemoteNotification(
        id: notification.id,
        title: notification.title,
        body: notification.message,
      );
      shown.add(key);
      presentedCount++;
      changed = true;
    }
    if (changed) {
      await StorageHelper.saveShownRemoteNotificationIds(shown.toList());
    }
  }
}
