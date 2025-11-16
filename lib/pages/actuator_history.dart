import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

class ActuatorHistoryPage extends StatefulWidget {
  const ActuatorHistoryPage({Key? key}) : super(key: key);

  @override
  _ActuatorHistoryPageState createState() => _ActuatorHistoryPageState();
}

class _ActuatorHistoryPageState extends State<ActuatorHistoryPage> {
  List<dynamic> actuators = [];
  List<dynamic> filteredActuators = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchActuatorData();
  }

  Future<void> fetchActuatorData() async {
    final response =
        await http.get(Uri.parse('http://100.76.87.115:5000/api/actuators'));
    if (response.statusCode == 200) {
      setState(() {
        actuators = json.decode(response.body);
        filteredActuators = actuators;
        isLoading = false;
      });
    } else {
      print("Failed to load actuator data");
      setState(() => isLoading = false);
    }
  }

  String formatTimestamp(String? isoTime) {
  if (isoTime == null || isoTime.isEmpty) return "No timestamp";
  try {
    final utcTime = DateTime.parse(isoTime).toUtc();
    final manila = tz.getLocation('Asia/Manila');
    final manilaTime = tz.TZDateTime.from(utcTime, manila);
    return DateFormat('MMMM dd, yyyy – hh:mm a').format(manilaTime);
  } catch (e) {
    return isoTime;
  }
}

  // Convert actuator_id to user-friendly name
  String changeName(String? actuatorId) {
    switch (actuatorId) {
      case 'lightBrightness':
        return 'Light';
      case 'exhaustFan':
        return 'Exhaust Fan';
      case 'intakeFan':
        return 'Intake Fan';
      case 'heater':
        return 'Heater';
      default:
        return actuatorId ?? 'Unknown';
    }
  }

  // Convert actuator status/value to display text
  String statusText(Map actuator) {
    if (actuator.containsKey('status') && actuator['status'] != null) {
      // Show ON/OFF
      return actuator['status'];
    } else if (actuator.containsKey('value') && actuator['value'] != null) {
      // Show numeric value
      return actuator['value'].toString();
    } else {
      return 'N/A';
    }
  }

  // --- 📅 FILTER FUNCTIONS ---
  void filterByDate(DateTime date) {
    setState(() {
      filteredActuators = actuators.where((actuator) {
        final timestamp = DateTime.tryParse(actuator['timestamp'] ?? '');
        if (timestamp == null) return false;
        return timestamp.year == date.year &&
            timestamp.month == date.month &&
            timestamp.day == date.day;
      }).toList();
    });
  }

  void filterByDateRange(DateTimeRange range) {
    setState(() {
      filteredActuators = actuators.where((actuator) {
        final timestamp = DateTime.tryParse(actuator['timestamp'] ?? '');
        if (timestamp == null) return false;
        return timestamp.isAfter(range.start.subtract(const Duration(days: 1))) &&
            timestamp.isBefore(range.end.add(const Duration(days: 1)));
      }).toList();
    });
  }

  void resetFilter() {
    setState(() {
      filteredActuators = actuators;
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
        title: const Text("Actuator History"),
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
          : filteredActuators.isEmpty
              ? const Center(child: Text("No actuator data found"))
              : RefreshIndicator(
                  onRefresh: fetchActuatorData,
                  child: ListView.builder(
                    itemCount: filteredActuators.length,
                    itemBuilder: (context, index) {
                      final actuator = filteredActuators[index];
                      final formattedTime =
                          formatTimestamp(actuator['timestamp']);
                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          leading:
                              const Icon(Icons.settings_remote, color: Colors.amber),
                          title: Text(
                            "${changeName(actuator['actuator_id'])} — ${actuator.containsKey('status') ? 'Status' : 'Value'}: ${statusText(actuator)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Date & Time: $formattedTime"),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}