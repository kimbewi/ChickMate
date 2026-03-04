import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:google_fonts/google_fonts.dart';

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
        await http.get(Uri.parse('http://192.168.0.104:5000/api/actuators'));
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

//   String formatTimestamp(String? isoTime) {
//   if (isoTime == null || isoTime.isEmpty) return "No timestamp";
//   try {
//     final utcTime = DateTime.parse(isoTime).toUtc();
//     final manila = tz.getLocation('Asia/Manila');
//     final manilaTime = tz.TZDateTime.from(utcTime, manila);
//     return DateFormat('MMMM dd, yyyy – hh:mm a').format(manilaTime);
//   } catch (e) {
//     return isoTime;
//   }
// }

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

void filterToday() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  setState(() {
    filteredActuators = actuators.where((sensor) {
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
    filteredActuators = actuators.where((sensor) {
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
    filteredActuators = actuators.where((sensor) {
      final timestamp = DateTime.tryParse(sensor['timestamp'] ?? '');
      if (timestamp == null) return false;
      return timestamp.isAfter(now.subtract(duration));
    }).toList();
  });
}

  void resetFilter() {
    setState(() {
      filteredActuators = actuators;
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

  // --- 🧱 UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Actuator History",
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