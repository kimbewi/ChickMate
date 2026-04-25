import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/history_service.dart';
import '../widgets/filter_dialog.dart'; 
// import 'dart:convert';
// import 'package:http/http.dart' as http;

class ActuatorHistoryPage extends StatefulWidget {
  const ActuatorHistoryPage({Key? key}) : super(key: key);

  @override
  _ActuatorHistoryPageState createState() => _ActuatorHistoryPageState();
}

class _ActuatorHistoryPageState extends State<ActuatorHistoryPage> {
  List actuators = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    fetchData(today);
  }

  // --- Safe field access ---
  T? getField<T>(Map data, String key) {
    if (data.containsKey(key) && data[key] != null) return data[key] as T;
    return null;
  }

  Future<void> fetchData(DateTime since, {DateTime? until}) async {
    setState(() => isLoading = true);
    try {
      final data = await HistoryService.fetchActuators(since: since, until: until); 
      setState(() {
        actuators = data;       
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  // --- Timestamp parsing & formatting ---
  DateTime? parseTimestamp(Map actuator, {String key = 'timestamp'}) {
    final isoTime = getField<String>(actuator, key);
    if (isoTime == null || isoTime.isEmpty) return null;
    try {
      return DateTime.parse(isoTime).toLocal();
    } catch (_) {
      return null;
    }
  }

  String formatTimestamp(Map actuator, {String key = 'timestamp'}) {
    final dt = parseTimestamp(actuator, key: key);
    if (dt == null) return "No timestamp";
    return DateFormat('MMMM dd, yyyy – hh:mm a').format(dt);
  }

  // --- Convert actuator ID to friendly name ---
  String changeName(String? actuatorId) {
    switch (actuatorId) {
      case 'lightBrightness':
        return 'Light';
      case 'fans':
        return 'Exhaust/Intake Fan';
      case 'heater':
        return 'Heater';
      default:
        return actuatorId ?? 'Unknown';
    }
  }

  IconData getActuatorIcon(String? actuatorId) {
    switch (actuatorId) {
      case 'lightBrightness':
        return Icons.lightbulb_outline;
      case 'fans':
        return Icons.air;
      case 'heater':
        return Icons.thermostat;
      default:
        return Icons.settings_remote;
    }
  }

  // --- Convert actuator status/value to display text ---
  String statusText(Map actuator) {
    final status = getField<String>(actuator, 'status');
    if (status != null) return status;
    final value = getField<dynamic>(actuator, 'value');
    if (value != null) return value.toString();
    return 'N/A';
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

  // --- 🧱 UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Actuator History", style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                  title: "Filter Actuator Data",
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
          : actuators.isEmpty
              ? const Center(child: Text("No actuator data found"))
              : RefreshIndicator(
                  onRefresh: () async {
                    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    await fetchData(today);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: actuators.length,
                    itemBuilder: (context, index) {
                      final actuator = actuators[index];
                      final actuatorId = getField<String>(actuator, 'actuator_id');
                      final hasStatus = getField(actuator, 'status') != null;

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
                              Icon(getActuatorIcon(actuatorId), color: Colors.amber, size: 24),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      changeName(actuatorId),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${hasStatus ? 'Status' : 'Value'}: ${statusText(actuator)}",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatTimestamp(actuator),
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