import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ActuatorHistoryPage extends StatefulWidget {
  const ActuatorHistoryPage({Key? key}) : super(key: key);

  @override
  _ActuatorHistoryPageState createState() => _ActuatorHistoryPageState();
}

class _ActuatorHistoryPageState extends State<ActuatorHistoryPage> {
  List<dynamic> actuators = [];

  @override
  void initState() {
    super.initState();
    fetchActuatorData();
  }

  Future<void> fetchActuatorData() async {
    final response = await http.get(Uri.parse('http://192.168.100.88:5000/api/actuators'));
    if (response.statusCode == 200) {
      setState(() {
        actuators = json.decode(response.body);
      });
    } else {
      print("Failed to load actuator data");
    }
  }

  String formatTimestamp(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return "No timestamp";
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      return DateFormat('MMMM dd, yyyy – hh:mm a').format(dateTime);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Actuator History"),
        backgroundColor: const Color(0xFFFFE66A),
        foregroundColor: Colors.black87,
        elevation: 2,
      ),
      body: actuators.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: actuators.length,
              itemBuilder: (context, index) {
                final actuator = actuators[index];
                final formattedTime = formatTimestamp(actuator['timestamp']);
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(
                      "${changeName(actuator['actuator_id'])} — ${actuator.containsKey('status') ? 'Status' : 'Value'}: ${statusText(actuator)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("Date & Time: $formattedTime"),
                  ),
                );
              },
            ),
    );
  }
}