import 'package:flutter/material.dart';

class HONotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime timestamp;
  bool isRead;

  HONotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}

class HONotificationProvider extends ChangeNotifier {
  final List<HONotification> _notifications = [];
  int _unreadCount = 0;

  List<HONotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;

  void addNotification(Map<String, dynamic> activity) {
    final notification = HONotification(
      id: activity['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: activity['user_name'] ?? 'System Alert',
      body: activity['description'] ?? '',
      type: activity['action_type'] ?? 'info',
      timestamp: DateTime.tryParse(activity['created_at'] ?? '') ?? DateTime.now(),
    );

    _notifications.insert(0, notification);
    _unreadCount++;
    
    // Keep only last 50 notifications
    if (_notifications.length > 50) {
      _notifications.removeLast();
    }
    
    notifyListeners();
  }

  void markAsRead() {
    _unreadCount = 0;
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    // Recalculate unread if needed, or just notify
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
}
