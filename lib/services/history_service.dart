import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class HistoryService {

  static Future<List<dynamic>> fetchSensors() async {
    final response = await http.get(Uri.parse(ApiConfig.sensors));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load sensors");
    }
  }

  static Future<List<dynamic>> fetchActuators() async {
    final response = await http.get(Uri.parse(ApiConfig.actuators));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load actuators");
    }
  }

  static Future<List<dynamic>> fetchNotifications() async {
    final response = await http.get(Uri.parse(ApiConfig.notifications));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load notifications");
    }
  }

  static Future<int> fetchUnreadCount() async {
    final response = await http.get(Uri.parse(ApiConfig.notificationsUnreadCount));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['unreadCount'] ?? 0;
    } else {
      throw Exception("Failed to load unread count");
    }
  }

  static Future<void> markAllNotificationsRead() async {
    await http.put(Uri.parse(ApiConfig.notificationsMarkAllRead));
  }

  static Future<void> saveDeviceToken(String token) async {
    await http.post(
      Uri.parse(ApiConfig.saveToken),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token}),
    );
  }

}