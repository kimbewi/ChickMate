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
  bool isLoading = true;

  // 🔧 CHANGE THIS TO YOUR PC’s IP address
  final String baseUrl = 'http://192.168.100.88:5000/api/sensors';

  // Function to fetch sensor data from Node.js API
  Future<void> fetchSensors() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        setState(() {
          sensors = data;
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

  @override
  void initState() {
    super.initState();
    fetchSensors();
  }

  String formatTimestamp(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime).toLocal(); // convert UTC → local
      return DateFormat('MMMM dd, yyyy – hh:mm a').format(dateTime);
    } catch (e) {
      return isoTime; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sensor History"),
        backgroundColor: const Color(0xFFFFE66A),
        foregroundColor: Colors.black87,
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : sensors.isEmpty
              ? const Center(child: Text("No sensor data found"))
              : RefreshIndicator(
                  onRefresh: fetchSensors,
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
                        child: ListTile(
                          leading: const Icon(Icons.sensors, color: Colors.amber),
                          title: Text(
                            "Sensor Reading",
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
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