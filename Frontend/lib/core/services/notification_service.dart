import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/notification_model.dart';

class NotificationService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/api/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _notifications = data.map((json) => NotificationModel.fromJson(json)).toList();
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
}
