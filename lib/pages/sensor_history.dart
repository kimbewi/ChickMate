import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class SensorHistoryPage extends StatefulWidget {
  const SensorHistoryPage({super.key});

  @override
  State<SensorHistoryPage> createState() => _SensorHistoryPageState();
}

class _SensorHistoryPageState extends State<SensorHistoryPage> {
  List sensors = [];
  List filteredSensors = [];
  bool isLoading = true;

  final String baseUrl = 'http://100.68.113.75:5000/api/sensors';

  @override
  void initState() {
    super.initState();
    fetchSensors();
  }

  Future<void> fetchSensors() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          sensors = data;
          filteredSensors = data;
          isLoading = false;
        });
      } else {
        print('Failed to load sensors: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching sensors: $e');
      setState(() => isLoading = false);
    }
  }

  String formatTimestamp(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      return DateFormat('MMMM dd, yyyy – hh:mm a').format(dateTime);
    } catch (e) {
      return isoTime;
    }
  }

  // --- 📅 FILTER FUNCTIONS ---
  void filterByDate(DateTime date) {
    setState(() {
      filteredSensors = sensors.where((sensor) {
        final timestamp = DateTime.tryParse(sensor['timestamp'] ?? '');
        if (timestamp == null) return false;
        return timestamp.year == date.year &&
            timestamp.month == date.month &&
            timestamp.day == date.day;
      }).toList();
    });
  }

  void filterByDateRange(DateTimeRange range) {
    setState(() {
      filteredSensors = sensors.where((sensor) {
        final timestamp = DateTime.tryParse(sensor['timestamp'] ?? '');
        if (timestamp == null) return false;
        return timestamp.isAfter(range.start.subtract(const Duration(days: 1))) &&
            timestamp.isBefore(range.end.add(const Duration(days: 1)));
      }).toList();
    });
  }

  void resetFilter() {
    setState(() {
      filteredSensors = sensors;
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

  // --- 🧱 UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sensor History"),
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
                        child: ListTile(
                          leading:
                              const Icon(Icons.sensors, color: Colors.amber),
                          title: const Text(
                            "Sensor Reading",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Temperature: ${sensor['temperature']} °C"),
                              Text("Humidity: ${sensor['humidity']} %"),
                              Text("Ammonia: ${sensor['ammonia']} ppm"),
                              Text("Light: ${sensor['light']} lx"),
                              const SizedBox(height: 4),
                              Text(
                                "Date & Time: ${formatTimestamp(sensor['timestamp'])}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
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