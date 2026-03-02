import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List notifications = [];
  List filteredNotifications = [];
  bool isLoading = true;

  // 🔁 CHANGE THIS TO YOUR SERVER IP
  static const String apiUrl =
      "http://192.168.0.104:5000/api/notifications";
      // OR http://localhost:5000 when emulator

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  // Future<void> fetchNotifications() async {
  //   try {
  //     final response = await http.get(Uri.parse(apiUrl));

  //     if (response.statusCode == 200) {
  //       setState(() {
  //         notifications = json.decode(response.body);
  //         isLoading = false;
  //       });
  //     } else {
  //       throw Exception("Failed to load notifications");
  //     }
  //   } catch (e) {
  //     debugPrint("❌ Notification fetch error: $e");
  //     setState(() => isLoading = false);
  //   }
  // }

  Future<void> fetchNotifications() async {
  try {
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        notifications = data;
        filteredNotifications = data; // ✅ THIS LINE
        isLoading = false;
      });
    } else {
      throw Exception("Failed to load notifications");
    }
  } catch (e) {
    debugPrint("❌ Notification fetch error: $e");
    setState(() => isLoading = false);
  }
}

String formatTimestamp(String? isoTime) {
  if (isoTime == null || isoTime.isEmpty) return "No timestamp";

  // Example: 2026-01-07T14:30:00+08:00
  try {
    final date = isoTime.substring(0, 10); // YYYY-MM-DD
    final time = isoTime.substring(11, 16); // HH:mm

    final year = date.substring(0, 4);
    final month = date.substring(5, 7);
    final day = date.substring(8, 10);

    final hour = int.parse(time.substring(0, 2));
    final minute = time.substring(3, 5);

    final dt = DateTime(
      int.parse(year),
      int.parse(month),
      int.parse(day),
      hour,
      int.parse(minute),
    );

    return DateFormat('MMMM dd, yyyy – hh:mm a').format(dt);
  } catch (_) {
    return isoTime;
  }
}

  // --- 📅 FILTER FUNCTIONS ---
  void filterByDate(DateTime date) {
    setState(() {
      filteredNotifications = notifications.where((sensor) {
        final timestamp = DateTime.tryParse(sensor['created_at'] ?? '');
        if (timestamp == null) return false;
        return timestamp.year == date.year &&
            timestamp.month == date.month &&
            timestamp.day == date.day;
      }).toList();
    });
  }

  void filterByDateRange(DateTimeRange range) {
    setState(() {
      filteredNotifications = notifications.where((sensor) {
        final timestamp = DateTime.tryParse(sensor['created_at'] ?? '');
        if (timestamp == null) return false;
        return timestamp.isAfter(range.start.subtract(const Duration(days: 1))) &&
            timestamp.isBefore(range.end.add(const Duration(days: 1)));
      }).toList();
    });
  }

  void resetFilter() {
    setState(() {
      filteredNotifications = notifications;
    });
  }

  void showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text("Filter by Specific Date"),
                onTap: () async {
                  Navigator.pop(context);
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) filterByDate(picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text("Filter by Date Range"),
                onTap: () async {
                  Navigator.pop(context);
                  final DateTimeRange? range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100),
                    initialDateRange: DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 7)),
                      end: DateTime.now(),
                    ),
                  );
                  if (range != null) filterByDateRange(range);
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text("Reset Filter"),
                onTap: () {
                  Navigator.pop(context);
                  resetFilter();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color severityColor(String severity) {
    switch (severity) {
      case "HIGH":
        return Colors.redAccent;
      case "MEDIUM":
        return Colors.orangeAccent;
      case "LOW":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData severityIcon(String severity) {
    switch (severity) {
      case "HIGH":
        return Icons.error_outline;
      case "MEDIUM":
        return Icons.warning_amber_outlined;
      case "LOW":
        return Icons.info_outline;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFFFFE66A),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: showFilterOptions,
            tooltip: "Filter Data",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchNotifications,
        color: Colors.orange,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredNotifications.isEmpty
                ? const Center(child: Text("No notifications"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final n = filteredNotifications[index];

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                severityIcon(n['severity']),
                                color: severityColor(n['severity']),
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n['type'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: severityColor(n['severity']),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n['message'],
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Sensor: ${n['sensor']}",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatTimestamp(n['created_at']),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (n['is_read'] == false)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}