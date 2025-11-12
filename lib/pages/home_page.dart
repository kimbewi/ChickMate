import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
//import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/live_clock.dart';
import '../widgets/status_card.dart';
import '../widgets/control_card.dart';
import 'sensor_history.dart';
import 'actuator_history.dart';

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // SENSOR VARIABLES
  String ammoniaLevel = "--";
  String temperature = "--";
  String humidity = "--";

  // CONTROL STATES
  bool isExhaustFanOn = false;
  bool isIntakeFanOn = false;
  bool isHeaterOn = false;

  late DatabaseReference _sensorDataRef;
  late DatabaseReference _controlsRef;
  StreamSubscription? _sensorDataSubscription;
  StreamSubscription? _controlsSubscription;

  @override
  void initState() {
    super.initState();
    _sensorDataRef = FirebaseDatabase.instance.ref('sensorData');
    _controlsRef = FirebaseDatabase.instance.ref('controls');

    _sensorDataSubscription = _sensorDataRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          ammoniaLevel = data['ammonia']?.toString() ?? '--';
          temperature = data['temperature']?.toString() ?? '--';
          humidity = data['humidity']?.toString() ?? '--';
        });
      }
    });

    _controlsSubscription = _controlsRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          isExhaustFanOn = data['exhaustFan'] ?? false;
          isIntakeFanOn = data['intakeFan'] ?? false;
          isHeaterOn = data['heater'] ?? false;
        });
      }
    });
  }

  void _updateControl(String controlName, bool value) {
    _controlsRef.child(controlName).set(value);
  }

  @override
  void dispose() {
    _sensorDataSubscription?.cancel();
    _controlsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(253, 253, 253, 1.0),
        automaticallyImplyLeading: false,
        elevation: 2,
        title: Row(
          children: [
            Image.asset('assets/images/chickmateLogo.png', height: 40),
            const SizedBox(width: 8),
            Text(
              "ChickMate",
              style: GoogleFonts.inter(
                fontSize: 30.0,
                fontWeight: FontWeight.w800,
                color: const Color.fromRGBO(32, 32, 32, 1.0),
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(child: LiveClock()),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(248, 248, 255, 1.0),
              Color.fromRGBO(255, 247, 209, 1.0)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Video Feed",
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Card(
                  color: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(19),
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          'Video feed is offline',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text('Environmental Status',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatusCard(
                      title: 'Ammonia Level',
                      data: ammoniaLevel,
                      unit: '%',
                      icon: Icons.dangerous_outlined,
                      iconColor: Colors.green,
                    ),
                    StatusCard(
                      title: 'Temperature',
                      data: temperature,
                      unit: '°C',
                      icon: Icons.thermostat,
                      iconColor: Colors.redAccent,
                    ),
                    StatusCard(
                      title: 'Humidity',
                      data: humidity,
                      unit: '%',
                      icon: Icons.water_drop_outlined,
                      iconColor: Colors.blueAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text('Controls',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ControlCard(
                      title: 'Exhaust Fan',
                      icon: Icons.air_outlined,
                      isOn: isExhaustFanOn,
                      onChanged: (value) {
                        setState(() => isExhaustFanOn = value);
                        _updateControl('exhaustFan', value);
                      },
                    ),
                    ControlCard(
                      title: 'Intake Fan',
                      icon: Icons.air_outlined,
                      isOn: isIntakeFanOn,
                      onChanged: (value) {
                        setState(() => isIntakeFanOn = value);
                        _updateControl('intakeFan', value);
                      },
                    ),
                    ControlCard(
                      title: 'Heater',
                      icon: Icons.whatshot_outlined,
                      isOn: isHeaterOn,
                      onChanged: (value) {
                        setState(() => isHeaterOn = value);
                        _updateControl('heater', value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text('History',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // aligns children to left
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) =>  SensorHistoryPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 255, 230, 106),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.history, color: Color.fromRGBO(32, 32, 32, 1.0)),
                        label: const Text(
                          'View Sensor History',
                          style: TextStyle(fontSize: 16, color: Color.fromRGBO(32, 32, 32, 1.0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ActuatorHistoryPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 255, 230, 106),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.history, color: Color.fromRGBO(32, 32, 32, 1.0)),
                        label: const Text(
                          'View Actuator History',
                          style: TextStyle(fontSize: 16, color: Color.fromRGBO(32, 32, 32, 1.0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30), // space below the button
                  ],
                )
              ],             
            ),
          ),
        ),
      ),
    );
  }
}