import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/history_service.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

class SensorHistoryPage extends StatefulWidget {
  const SensorHistoryPage({super.key});

  @override
  State<SensorHistoryPage> createState() => _SensorHistoryPageState();
}

class _SensorHistoryPageState extends State<SensorHistoryPage> {
  List sensors = [];
  List filteredSensors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSensors();
  }

  Future<void> fetchSensors() async {
    try {
      final data = await HistoryService.fetchSensors();

      setState(() {
        sensors = data;
        filteredSensors = data;
        isLoading = false;
      });

    } catch (e) {
      print("Error fetching sensors: $e");
      setState(() => isLoading = false);
    }
  }

  String displaySensor(dynamic value, {String unit = ''}) {
    if (value is num) return "$value $unit";
    if (value is String) return value; // show error messages like "Error: Read Failure"
    return value.toString();
  }

  // --- ✅ NEW: parse timestamp safely ---
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
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    setState(() {
      filteredSensors = sensors.where((sensor) {
        final ts = parseTimestamp(sensor);
        if (ts == null) return true; // keep sensor even if timestamp is missing
        return ts.isAfter(start) && ts.isBefore(end);
      }).toList();
    });
  }

  void filterYesterday() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    setState(() {
      filteredSensors = sensors.where((sensor) {
        final ts = parseTimestamp(sensor);
        if (ts == null) return true;
        return ts.isAfter(startOfYesterday) && ts.isBefore(startOfToday);
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
      filteredSensors = sensors.where((sensor) {
        final ts = parseTimestamp(sensor);
        if (ts == null) return true; // keep entries without timestamp
        return ts.isAfter(now.subtract(duration));
      }).toList();
    });
  }

  void resetFilter() {
    setState(() {
      filteredSensors = sensors;
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
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: showFilterOptions,
            tooltip: "Filter Data",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredSensors.isEmpty
              ? const Center(child: Text("No sensor data found"))
              : RefreshIndicator(
                  onRefresh: fetchSensors,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredSensors.length,
                    itemBuilder: (context, index) {
                      final sensor = filteredSensors[index];
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