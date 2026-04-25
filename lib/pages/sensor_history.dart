import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/history_service.dart';
import '../widgets/filter_dialog.dart'; 
// import 'package:http/http.dart' as http;
// import 'dart:convert';

class SensorHistoryPage extends StatefulWidget {
  const SensorHistoryPage({super.key});

  @override
  State<SensorHistoryPage> createState() => _SensorHistoryPageState();
}

class _SensorHistoryPageState extends State<SensorHistoryPage> {
  List sensors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    fetchData(today);
  }

  Future<void> fetchData(DateTime since, {DateTime? until}) async {
    setState(() => isLoading = true);
    try {
      final data = await HistoryService.fetchSensors(since: since, until: until); 
      setState(() {
        sensors = data;       
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  String displaySensor(dynamic value, {String unit = ''}) {
    if (value is num) return "$value $unit";
    if (value is String) return value; 
    return value.toString();
  }

  // --- NEW: parse timestamp safely ---
  DateTime? parseTimestamp(Map sensor) {
    try {
      if (sensor['timestamp'] == null) return null;
      return DateTime.parse(sensor['timestamp']).toLocal();
    } catch (_) {
      return null;
    }
  }

  String formatTimestamp(Map sensor) {
    final dt = parseTimestamp(sensor);
    if (dt == null) return "No timestamp";
    return DateFormat('MMMM dd, yyyy – hh:mm a').format(dt);
  }

  void filterToday() {
    final now = DateTime.now();
    fetchData(DateTime(now.year, now.month, now.day));
  }

  void filterYesterday() {
    final now = DateTime.now();
    final yesterdayStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final yesterdayEnd = DateTime(now.year, now.month, now.day); 

    fetchData(yesterdayStart, until: yesterdayEnd);
  }

  void filterLast30Mins() {
    final now = DateTime.now();
    fetchData(now.subtract(const Duration(minutes: 30)));
  }

  void filterLast10Mins() {
    final now = DateTime.now();
    fetchData(now.subtract(const Duration(minutes: 10)));
  }

  void filterLast24Hours() {
    final now = DateTime.now();
    // This is a trailing window: Exactly 24 hours back from 'now'
    fetchData(now.subtract(const Duration(hours: 24)));
  }

  void filterByCustomDuration(int value, String unit) {
    Duration duration;
    switch (unit) {
      case "Minutes": duration = Duration(minutes: value); break;
      case "Hours":   duration = Duration(hours: value); break;
      case "Days":    duration = Duration(days: value); break;
      default:        duration = const Duration(hours: 1);
    }
    fetchData(DateTime.now().subtract(duration));
  }

  void resetFilter() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    fetchData(today);
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Sensor History",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFFFFE66A),
        foregroundColor: Colors.black87,
        elevation: 2,
        actions: [
          Builder(
            builder: (BuildContext innerContext) => IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                debugPrint("🔔 Filter button tapped");
                FilterDialog.show(
                  innerContext,
                  title: "Filter Sensor Data",
                  quickFilters: [
                    FilterOption(label: "10 Minutes", onTap: filterLast10Mins),
                    FilterOption(label: "30 Minutes", onTap: filterLast30Mins),
                    FilterOption(label: "24 Hours",   onTap: filterLast24Hours),
                    FilterOption(label: "Yesterday",  onTap: filterYesterday),
                  ],
                  onReset: resetFilter,
                  onCustomDuration: filterByCustomDuration,
                );
              },
              tooltip: "Filter Data",
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : sensors.isEmpty
              ? const Center(child: Text("No sensor data found"))
              : RefreshIndicator(
                  onRefresh: () async {
                    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    await fetchData(today);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sensors.length,
                    itemBuilder: (context, index) {
                      final sensor = sensors[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sensors, color: Colors.amber, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Sensor Reading",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                      Text("Temperature: ${displaySensor(sensor['temperature'], unit: '°C')}", style: const TextStyle(fontSize: 13)),
                                      Text("Humidity: ${displaySensor(sensor['humidity'], unit: '%')}", style: const TextStyle(fontSize: 13)),
                                      Text("Ammonia: ${displaySensor(sensor['ammonia'], unit: 'ppm')}", style: const TextStyle(fontSize: 13)),
                                      Text("Light: ${displaySensor(sensor['light'], unit: 'lx')}", style: const TextStyle(fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatTimestamp(sensor),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
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