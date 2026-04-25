import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/history_service.dart';
import '../widgets/filter_dialog.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List notifications = [];
  List filteredNotifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  T? getField<T>(Map data, String key) {
    if (data.containsKey(key) && data[key] != null) return data[key] as T;
    return null;
  }

  Future<void> fetchNotifications() async {
    try {
      final data = await HistoryService.fetchNotifications();
      setState(() {
        notifications = data;
        filteredNotifications = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Notification fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  DateTime? parseTimestamp(Map n, {String key = 'created_at'}) {
    final isoTime = getField<String>(n, key);
    if (isoTime == null || isoTime.isEmpty) return null;
    try {
      return DateTime.parse(isoTime).toLocal();
    } catch (_) {
      return null;
    }
  }

  String formatTimestamp(Map n, {String key = 'created_at'}) {
    final dt = parseTimestamp(n, key: key);
    if (dt == null) return "No timestamp";
    return DateFormat('MMMM dd, yyyy – hh:mm a').format(dt);
  }

  String formatTimestampRaw(String? isoTime) {
  if (isoTime == null || isoTime.isEmpty) return "No timestamp";
  try {
    final dt = DateTime.parse(isoTime).toLocal();
    return DateFormat('MMMM dd, yyyy – hh:mm a').format(dt);
  } catch (_) {
    return "No timestamp";
  }
}

  void filterToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    setState(() {
      filteredNotifications = notifications.where((n) {
        final ts = parseTimestamp(n);
        if (ts == null) return true;
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

  void filterLast30Mins() {
    final now = DateTime.now();
    setState(() {
      filteredNotifications = notifications.where((n) {
        final ts = parseTimestamp(n);
        if (ts == null) return true;
        return ts.isAfter(now.subtract(const Duration(minutes: 30)));
      }).toList();
    });
  }

  void filterLast10Mins() {
    final now = DateTime.now();
    setState(() {
      filteredNotifications = notifications.where((n) {
        final ts = parseTimestamp(n);
        if (ts == null) return true;
        return ts.isAfter(now.subtract(const Duration(minutes: 10)));
      }).toList();
    });
  }

  void filterLast24Hours() {
    final now = DateTime.now();
    setState(() {
      filteredNotifications = notifications.where((n) {
        final ts = parseTimestamp(n);
        if (ts == null) return true;
        return ts.isAfter(now.subtract(const Duration(hours: 24)));
      }).toList();
    });
  }

  void resetFilter() {
    setState(() {
      filteredNotifications = notifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notifications", style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFFFE66A),
        foregroundColor: Colors.black87,
        elevation: 2,
        actions: [
          Builder(
            builder: (BuildContext innerContext) => IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => FilterDialog.show(
                innerContext,
                title: "Filter Notifications",
                quickFilters: [
                    FilterOption(label: "10 Minutes", onTap: filterLast10Mins),
                    FilterOption(label: "30 Minutes", onTap: filterLast30Mins),
                    FilterOption(label: "24 Hours",   onTap: filterLast24Hours),
                    FilterOption(label: "Yesterday",  onTap: filterYesterday),
                  ],
                onReset: resetFilter,
                onCustomDuration: filterByCustomDuration,
              ),
              tooltip: "Filter Data",
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchNotifications,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredNotifications.isEmpty
                ? const Center(child: Text("No notifications"))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final n = filteredNotifications[index];
                      final sensor = getField<String>(n, 'sensor') ?? "Unknown Sensor";
                      final message = getField<String>(n, 'message') ?? "No message";
                      final isRead = getField<bool>(n, 'is_read') ?? true;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sensor,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(message, style: const TextStyle(fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(formatTimestamp(n), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    if (getField<bool>(n, 'resolved') ?? false) ...[
                                      const SizedBox(height: 8),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                                          const SizedBox(width: 6),
                                          const Text(
                                            "Sensor recovered",
                                            style: TextStyle(fontSize: 13, color: Colors.green),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatTimestamp(n, key: 'resolved_at'),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!isRead)
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