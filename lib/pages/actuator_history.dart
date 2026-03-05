import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  // --- Safe field access ---
  T? getField<T>(Map data, String key) {
    if (data.containsKey(key) && data[key] != null) return data[key] as T;
    return null;
  }

  Future<void> fetchActuatorData() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.0.104:5000/api/actuators'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          actuators = data;
          filteredActuators = data;
          isLoading = false;
        });
      } else {
        debugPrint("Failed to load actuator data");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Actuator fetch error: $e");
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

  // --- Convert actuator status/value to display text ---
  String statusText(Map actuator) {
    final status = getField<String>(actuator, 'status');
    if (status != null) return status;
    final value = getField<dynamic>(actuator, 'value');
    if (value != null) return value.toString();
    return 'N/A';
  }

  // --- Filters ---
  void filterToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    setState(() {
      filteredActuators = actuators.where((a) {
        final ts = parseTimestamp(a);
        if (ts == null) return true; // include missing timestamp
        return ts.isAfter(start) && ts.isBefore(end);
      }).toList();
    });
  }

  void filterYesterday() {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startYesterday = startToday.subtract(const Duration(days: 1));

    setState(() {
      filteredActuators = actuators.where((a) {
        final ts = parseTimestamp(a);
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
      filteredActuators = actuators.where((a) {
        final ts = parseTimestamp(a);
        if (ts == null) return true;
        return ts.isAfter(now.subtract(duration));
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Filter Actuator Data", style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                      child: OutlinedButton(onPressed: () { Navigator.pop(context); filterToday(); }, child: const Text("Today")),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(onPressed: () { Navigator.pop(context); filterYesterday(); }, child: const Text("Yesterday")),
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
                if (value == null || value <= 0) { setModalState(() { errorText = "Please enter a valid number"; }); return; }
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
          IconButton(icon: const Icon(Icons.filter_list), onPressed: showFilterOptions, tooltip: "Filter Data"),
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
                      final formattedTime = formatTimestamp(actuator);
                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          leading: const Icon(Icons.settings_remote, color: Colors.amber),
                          title: Text(
                            "${changeName(getField<String>(actuator, 'actuator_id'))} — ${getField(actuator, 'status') != null ? 'Status' : 'Value'}: ${statusText(actuator)}",
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