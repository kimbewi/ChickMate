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
      "http://100.68.113.75:5000/api/notifications";

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

void filterToday() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  setState(() {
    filteredNotifications = notifications.where((sensor) {
      final timestamp = DateTime.tryParse(sensor['timestamp'] ?? '');
      if (timestamp == null) return false;
      return timestamp.isAfter(start) && timestamp.isBefore(end);
    }).toList();
  });
}

void filterYesterday() {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

  setState(() {
    filteredNotifications = notifications.where((sensor) {
      final timestamp = DateTime.tryParse(sensor['timestamp'] ?? '');
      if (timestamp == null) return false;
      return timestamp.isAfter(startOfYesterday) &&
             timestamp.isBefore(startOfToday);
    }).toList();
  });
}

void filterByCustomDuration(int value, String unit) {
  Duration duration;

  switch (unit) {
    case "Minutes":
      duration = Duration(minutes: value);
      break;
    case "Hours":
      duration = Duration(hours: value);
      break;
    case "Days":
      duration = Duration(days: value);
      break;
    default:
      duration = const Duration(hours: 1);
  }

  final now = DateTime.now();

  setState(() {
    filteredNotifications = notifications.where((sensor) {
      final timestamp = DateTime.tryParse(sensor['timestamp'] ?? '');
      if (timestamp == null) return false;
      return timestamp.isAfter(now.subtract(duration));
    }).toList();
  });
}

  void resetFilter() {
    setState(() {
      filteredNotifications = notifications;
    });
  }

  void showFilterOptions() {
  final TextEditingController controller = TextEditingController();
  String selectedUnit = "Minutes";
  String? errorText;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "Filter Sensor Data",
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 🔹 QUICK FILTERS
                  const Text(
                    "Quick Filters",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            filterToday();
                          },
                          child: const Text("Today"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            filterYesterday();
                          },
                          child: const Text("Yesterday"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// 🔹 CUSTOM FILTER
                  const Text(
                    "Custom Duration",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Enter value",
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    items: ["Minutes", "Hours", "Days"]
                        .map((unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedUnit = value!;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  resetFilter();
                },
                child: const Text("Reset"),
              ),
              ElevatedButton(
                onPressed: () {
                  final int? value = int.tryParse(controller.text);

                  if (value == null || value <= 0) {
                    setModalState(() {
                      errorText = "Please enter a valid number";
                    });
                    return;
                  }

                  // 🚫 Restriction Rules
                  if (selectedUnit == "Minutes" && value > 60) {
                    setModalState(() {
                      errorText = "Maximum allowed is 60 minutes";
                    });
                    return;
                  }

                  if (selectedUnit == "Hours" && value > 24) {
                    setModalState(() {
                      errorText = "Maximum allowed is 24 hours";
                    });
                    return;
                  }

                  if (selectedUnit == "Days" && value > 7) {
                    setModalState(() {
                      errorText = "Maximum allowed is 7 days";
                    });
                    return;
                  }

                  Navigator.pop(context);
                  filterByCustomDuration(value, selectedUnit);
                },
                child: const Text("Apply"),
              ),
            ],
          );
        },
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
                                        fontWeight: FontWeight.bold,
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