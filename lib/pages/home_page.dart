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
import 'full_screen.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart'; // for webrtc
import 'package:web_socket_channel/io.dart'; // for websocket
import 'dart:convert'; // for json decoding

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // VARIABLES FOR SENSOR DATA
  String ammoniaLevel = "--";
  String temperature = "--";
  String humidity = "--";
  String lightLevel = "--";

  // STATE VARIABLES FOR CONTROLS
  bool isExhaustFanOn = false;
  bool isIntakeFanOn = false;
  bool isHeaterOn = false;
  double lightBrightness = 0.0;

  // WebRTC VARIABLES
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  IOWebSocketChannel? _channel;

  late DatabaseReference _sensorDataRef; // Reference for sensor data
  late DatabaseReference _controlsRef; // Reference for controls
  StreamSubscription? _sensorDataSubscription;
  StreamSubscription? _controlsSubscription;

  @override
  void initState() {
    super.initState();
    _connect(); // WebRTC INIT

    // Point the reference to the "node" or "path" in your database
    _sensorDataRef = FirebaseDatabase.instance.ref('sensorData');
    _controlsRef = FirebaseDatabase.instance.ref('controls');

    // Listen to the sensor data stream
    _sensorDataSubscription = _sensorDataRef.onValue.listen((
      DatabaseEvent event,
    ) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          ammoniaLevel = data['ammonia']?.toString() ?? '--';
          temperature = data['temperature']?.toString() ?? '--';
          humidity = data['humidity']?.toString() ?? '--';
          lightLevel = data['lightLevel']?.toString() ?? '--';
        });
      } else {
        // Handle case where data doesn't exist
        setState(() {
          ammoniaLevel = "--";
          temperature = "--";
          humidity = "--";
          lightLevel = "--";
        });
      }
    });

    //Listen to the controls data stream
    _controlsSubscription = _controlsRef.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          // Use '?? false' to default to 'Off' if data is missing
          isExhaustFanOn = data['exhaustFan'] ?? false;
          isIntakeFanOn = data['intakeFan'] ?? false;
          isHeaterOn = data['heater'] ?? false;
          lightBrightness = (data['lightBrightness'] ?? 0.0).toDouble();
        });
      }
      // If snapshot doesn't exist, they will keep their default values
    });
  }

  Future<void> _disconnect() async {
    _remoteRenderer.srcObject = null;
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    if (_pc != null) {
      await _pc!.close();
      _pc = null;
    }
    if (mounted) {
      setState(() {});
    }
  }
   
  Future<void> _handleRefresh() async {
    await _disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await _connect();
  }

  // FUNCTION TO SEND CONTROL COMMANDS
  void _updateControl(String controlName, dynamic value) {
    // This will update a specific child, e.g., "controls/exhaustFan"
    _controlsRef.child(controlName).set(value);
  }

  Future<void> _connect() async {
    await _remoteRenderer.initialize();

    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };

    // Connect to signaling server
    _channel = IOWebSocketChannel.connect(
      'ws://100.68.113.75:8765',
    ); // replace with tailscale ip x.x.x.x:8765

    _channel!.stream.listen((message) async {
      final data = json.decode(message);
      if (data['type'] == 'answer') {
        await _pc!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], 'answer'),
        );
      }
    });

    // Create and send offer
    RTCSessionDescription offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    _channel!.sink.add(json.encode({'type': 'offer', 'sdp': offer.sdp}));
  }

  @override
  void dispose() {
    // ALWAYS cancel the subscription when the widget is removed
    _sensorDataSubscription?.cancel();
    _controlsSubscription?.cancel();
    _remoteRenderer.dispose();
    _pc?.close();
    _channel?.sink.close();
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
            Image.asset('assets/images/appLogo.png', height: 40),
            const SizedBox(width: 8),
            Text(
              "ChickMate",
              style: GoogleFonts.inter(
                fontSize: 28.0,
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
          child: RefreshIndicator(
            onRefresh: _handleRefresh, 
            color: Colors.orange,    
            
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(19),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    // WE USE A STACK TO OVERLAY THE BUTTON
                    child: Stack(
                      children: [
                        // 1. The Video Player
                        Positioned.fill(
                          child: RTCVideoView(
                            _remoteRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                            mirror: false,
                          ),
                        ),
                        
                        // 2. The Full Screen Button (Bottom Right)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5), // Semi-transparent background
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.fullscreen, color: Colors.white),
                              tooltip: "Full Screen",
                              onPressed: () {
                                // Navigate to the full screen page
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenVideoPage(
                                      renderer: _remoteRenderer,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
// --- END OF UPDATED CARD ---
                const SizedBox(height: 30),
                Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Environmental Status',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Color.fromRGBO(32, 32, 32, 1.0)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SensorHistoryPage()),
                      );
                    },
                  ),
                ],
              ),
                const SizedBox(height: 10),
                 Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatusCard(
                            title: 'Ammonia Level',
                            data: ammoniaLevel,
                            unit: '%',
                            icon: Icons.dangerous_outlined,
                            iconColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 3.0),
                        Expanded(
                          child: StatusCard(
                            title: 'Temperature',
                            data: temperature,
                            unit: '°C',
                            icon: Icons.thermostat,
                            iconColor: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3.0), // spacing between rows
                    Row(
                      children: [
                        Expanded(
                          child: StatusCard(
                            title: 'Humidity',
                            data: humidity,
                            unit: '%',
                            icon: Icons.water_drop_outlined,
                            iconColor: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 3.0),
                        Expanded(
                          child: StatusCard(
                            title: 'Light Level',
                            data: lightLevel,
                            unit: 'lux',
                            icon: Icons.wb_sunny_outlined,
                            iconColor: Colors.yellowAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Controls',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Color.fromRGBO(32, 32, 32, 1.0)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ActuatorHistoryPage()),
                      );
                    },
                  ),
                ],
              ),
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
                    const SizedBox(height: 12),
                SliderControlCard(
                    title: 'Light Bulb',
                    icon: Icons.lightbulb_outline,
                    value: lightBrightness,
                    onChanged: (newValue) {
                      setState(() {
                        lightBrightness = newValue;
                      });
                      _updateControl('lightBrightness', newValue.round());
                    },
                  ),
                  ],
                ),
                const SizedBox(height: 30),
                // Text('History',
                //     style: GoogleFonts.inter(
                //         fontSize: 20, fontWeight: FontWeight.bold)),
                // const SizedBox(height: 10),
                // Column(
                //   crossAxisAlignment: CrossAxisAlignment.start, // aligns children to left
                //   children: [
                //     Align(
                //       alignment: Alignment.centerLeft,
                //       child: ElevatedButton.icon(
                //         onPressed: () {
                //           Navigator.push(
                //             context,
                //             MaterialPageRoute(builder: (context) =>  SensorHistoryPage()),
                //           );
                //         },
                //         style: ElevatedButton.styleFrom(
                //           backgroundColor: const Color.fromARGB(255, 255, 230, 106),
                //           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                //           shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(12),
                //           ),
                //         ),
                //         icon: const Icon(Icons.history, color: Color.fromRGBO(32, 32, 32, 1.0)),
                //         label: const Text(
                //           'View Sensor History',
                //           style: TextStyle(fontSize: 16, color: Color.fromRGBO(32, 32, 32, 1.0)),
                //         ),
                //       ),
                //     ),
                //     const SizedBox(height: 10),
                //     Align(
                //       alignment: Alignment.centerLeft,
                //       child: ElevatedButton.icon(
                //         onPressed: () {
                //           Navigator.push(
                //             context,
                //             MaterialPageRoute(builder: (context) => const ActuatorHistoryPage()),
                //           );
                //         },
                //         style: ElevatedButton.styleFrom(
                //           backgroundColor: const Color.fromARGB(255, 255, 230, 106),
                //           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                //           shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(12),
                //           ),
                //         ),
                //         icon: const Icon(Icons.history, color: Color.fromRGBO(32, 32, 32, 1.0)),
                //         label: const Text(
                //           'View Actuator History',
                //           style: TextStyle(fontSize: 16, color: Color.fromRGBO(32, 32, 32, 1.0)),
                //         ),
                //       ),
                //     ),
                //     const SizedBox(height: 30), // space below the button
                //   ],
                // )
              ],             
            ),
          ),
        ),
      ),
      ),
    ),
    );
  }
}