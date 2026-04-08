class ApiConfig {
  static const String baseUrl = "http://100.68.113.75:5000";

  static const String sensors = "$baseUrl/api/sensors";
  static const String actuators = "$baseUrl/api/actuators";
  static const String notifications = "$baseUrl/api/notifications";
  static const String notificationsUnreadCount = "$baseUrl/api/notifications/unread-count";
  static const String notificationsMarkAllRead = "$baseUrl/api/notifications/mark-all-read";
  static const String saveToken = "$baseUrl/api/save-token";
}