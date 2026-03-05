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

  static const String apiUrl = "http://192.168.0.104:5000/api/notifications";

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  // --- ✅ Safe field access helper ---
  T? getField<T>(Map data, String key) {
    if (data.containsKey(key) && data[key] != null) {
      return data[key] as T;
    }
    return null;
  }

  // --- Fetch notifications ---
  Future<void> fetchNotifications() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          notifications = data;
          filteredNotifications = data;
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

  // --- Parse timestamp safely ---
  DateTime? parseTimestamp(Map n, {String key = 'created_at'}) {
    final isoTime = getField<String>(n, key);
    if (isoTime == null || isoTime.isEmpty) return null;
    try {
      return DateTime.parse(isoTime).toLocal();
    } catch (_) {
      return null;
    }
  }

  // --- Format timestamp ---
  String formatTimestamp(Map n, {String key = 'created_at'}) {
    final dt = parseTimestamp(n, key: key);
    if (dt == null) return "No timestamp";
    return DateFormat('MMMM dd, yyyy – hh:mm a').format(dt);
  }

  // --- Filters ---
  void filterToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    setState(() {
      filteredNotifications = notifications.where((n) {
        final ts = parseTimestamp(n);
        if (ts == null) return true; // ✅ include notifications without timestamp
        return ts.isAfter(start) && ts.isBefore(end);
      }).toList();
    });
  }

  void filterYesterday() {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startYesterday = startToday.subtract(const Duration(days: 1));

    setState(() {
      filteredNotifications = notifications.where((n) {
        final ts = parseTimestamp(n);
        if (ts == null) return true;
        return ts.isAfter(startYesterday) && ts.isBefore(startToday);
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
      filteredNotifications = notifications.where((n) {
        final ts = parseTimestamp(n);
        if (ts == null) return true;
        return ts.isAfter(now.subtract(duration));
      }).toList();
    });
  }

  void resetFilter() {
    setState(() {
      filteredNotifications = notifications;
    });
  }

  // --- Filter dialog ---
  void showFilterOptions() {
    final TextEditingController controller = TextEditingController();
    String selectedUnit = "Minutes";
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Filter Notifications",
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Quick Filters", style: TextStyle(fontWeight: FontWeight.w600)),
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
                const Text("Custom Duration", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: "Enter value", border: const OutlineInputBorder(), errorText: errorText),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  items: ["Minutes", "Hours", "Days"].map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                  onChanged: (value) => setModalState(() => selectedUnit = value!),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () { Navigator.pop(context); resetFilter(); }, child: const Text("Reset")),
            ElevatedButton(
              onPressed: () {
                final int? value = int.tryParse(controller.text);
                if (value == null || value <= 0) {
                  setModalState(() { errorText = "Please enter a valid number"; });
                  return;
                }
                if (selectedUnit == "Minutes" && value > 60) { setModalState(() { errorText = "Maximum allowed is 60 minutes"; }); return; }
                if (selectedUnit == "Hours" && value > 24) { setModalState(() { errorText = "Maximum allowed is 24 hours"; }); return; }
                if (selectedUnit == "Days" && value > 7) { setModalState(() { errorText = "Maximum allowed is 7 days"; }); return; }
                Navigator.pop(context);
                filterByCustomDuration(value, selectedUnit);
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }

  // --- Severity helpers ---
  Color severityColor(String? severity) {
    switch (severity) {
      case "HIGH": return Colors.redAccent;
      case "MEDIUM": return Colors.orangeAccent;
      case "LOW": return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData severityIcon(String? severity) {
    switch (severity) {
      case "HIGH": return Icons.error_outline;
      case "MEDIUM": return Icons.warning_amber_outlined;
      case "LOW": return Icons.info_outline;
      default: return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notifications", style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFFFE66A),
        elevation: 1,
        actions: [IconButton(icon: const Icon(Icons.filter_list), onPressed: showFilterOptions, tooltip: "Filter Data")],
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

                      final severity = getField<String>(n, 'severity');
                      final type = getField<String>(n, 'type') ?? "Unknown";
                      final message = getField<String>(n, 'message') ?? "No message";
                      final sensor = getField<String>(n, 'sensor') ?? "Unknown sensor";
                      final isRead = getField<bool>(n, 'is_read') ?? true;

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(severityIcon(severity), color: severityColor(severity), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(type, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: severityColor(severity))),
                                    const SizedBox(height: 4),
                                    Text(message, style: GoogleFonts.inter(fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text("Sensor: $sensor", style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700])),
                                    const SizedBox(height: 4),
                                    Text(formatTimestamp(n), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
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