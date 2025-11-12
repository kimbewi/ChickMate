import 'dart:async'; // for timer
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // for fonts
import 'package:intl/intl.dart'; // for date formatting
import 'package:firebase_core/firebase_core.dart'; // for firebase
import 'firebase_options.dart'; // for firebase
import 'package:firebase_database/firebase_database.dart'; // for firebase
import 'package:flutter_webrtc/flutter_webrtc.dart'; // for webrtc
import 'package:web_socket_channel/io.dart'; // for websocket
import 'dart:convert'; // for json decoding

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChickMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MyHomePage(title: 'ChickMate'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

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
      'ws://100.95.143.26:8765',
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
      // --- HEADER SECTION ---
      appBar: AppBar(
        //bg of appbar
        backgroundColor: Color.fromRGBO(253, 253, 253, 1.0),
        //to prevent pushing items to the left
        automaticallyImplyLeading: false,
        elevation: 2,

        title: Row(
          children: [
            Image.asset('assets/images/chickmateLogo.png', height: 40),

            const SizedBox(width: 8), // add space between widgets

            Text(
              "ChickMate",
              style: GoogleFonts.inter(
                fontSize: 30.0,
                fontWeight: FontWeight.w800,
                color: Color.fromRGBO(32, 32, 32, 1.0),
              ),
            ),
          ],
        ),

        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            // to vertically align clock in the AppBar
            child: Center(
              child: LiveClock(), // custom clock widget
            ),
          ),
        ],
      ),

      // --- BODY SECTION ---
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(248, 248, 255, 1.0),
              Color.fromRGBO(255, 247, 209, 1.0),
            ],
            // start and end points of the gradient
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
                // --- VIDEO FEED SECTION ---
                Text(
                  "Video Feed",
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // a space between text and video
                const SizedBox(height: 10),

                // ...
                Card(
                  color: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(19), // Keeping your padding
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black, // Background color
                        // This makes the video player have rounded corners
                        borderRadius: BorderRadius.circular(8),
                      ),
                      // This clips the video to the container's rounded shape
                      clipBehavior: Clip.antiAlias,
                      child: RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        mirror: false,
                      ),
                    ),
                  ),
                ),

                // ...,
                const SizedBox(height: 30),

                // --- ENVIRONMENTAL STATUS SECTION ---
                Text(
                  'Environmental Status',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatusCard(
                          title: 'Ammonia\nLevel',
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
                      const SizedBox(width: 3.0),
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
            
                // --- CONTROLS SECTION ---
                const SizedBox(height: 30),

                Text(
                  'Controls',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 12.0, // horizontal space
                  runSpacing: 12.0, // vertical space
                  children: [
                    // --- EXHAUST FAN CARD ---
                    ControlCard(
                      title: 'Exhaust Fan',
                      icon: Icons.air_outlined,
                      isOn: isExhaustFanOn,
                      onChanged: (bool value) {
                        setState(() {
                          isExhaustFanOn = value; // Update UI instantly
                        });
                        _updateControl(
                          'exhaustFan',
                          value,
                        ); // Send command to Firebase
                      },
                    ),

                    // --- INTAKE FAN CARD ---
                    ControlCard(
                      title: 'Intake Fan',
                      icon: Icons.air_outlined,
                      isOn: isIntakeFanOn,
                      onChanged: (bool value) {
                        setState(() {
                          isIntakeFanOn = value;
                        });
                        _updateControl('intakeFan', value);
                      },
                    ),

                    // --- HEATER CARD ---
                    ControlCard(
                      title: 'Heater',
                      icon: Icons.whatshot_outlined,
                      isOn: isHeaterOn,
                      onChanged: (bool value) {
                        setState(() {
                          isHeaterOn = value;
                        });
                        _updateControl('heater', value);
                      },
                    ),
                  ],
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
          ),
        ),
      ),
    );
  }
}

// REUSABLE CARD FOR SENSOR WIDGETS
class StatusCard extends StatelessWidget {
  final String title;
  final String data;
  final String unit;
  final IconData icon;
  final Color iconColor;

  const StatusCard({
    super.key,
    required this.title,
    required this.data,
    required this.unit,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBgColor = iconColor.withOpacity(0.1);

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 120, 
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6.0), 
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 6.0),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            SizedBox(
              width: double.infinity,
              child: Text(
              data == "--" ? "--" : '$data$unit',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 25, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
            ),),
          ],
        ),
      ),
    );
  }
}

// REUSABLE CARD FOR CONTROL CARDS ---
class ControlCard extends StatelessWidget {
  final String title;
  final bool isOn;
  final IconData icon;
  final Function(bool) onChanged;

  const ControlCard({
    super.key,
    required this.title,
    required this.isOn,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // --- Dynamic colors based on the 'isOn' state ---
    final Color cardColor = isOn ? const Color(0xFFF9A825) : Colors.white;
    final Color iconColor = isOn ? Colors.white : const Color(0xFFF9A825);
    final Color titleColor = isOn ? Colors.white : Colors.black87;
    final Color statusColor = isOn ? Colors.white70 : Colors.black54;

    return Card(
      color: cardColor,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 150, // Fixed width
        height: 150, // Fixed height to make it more square
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // Distributes space
          children: [
            // --- Row for Icon and Switch ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 40),
                Transform.scale(
                  // Makes the switch a bit smaller
                  scale: 0.8,
                  child: Switch(
                    value: isOn,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white, // Color of the switch knob
                    activeTrackColor: Colors.white.withAlpha(
                      128,
                    ), // 0.5 opacity
                  ),
                ),
              ],
            ),

            // --- Column for Title and Status ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                Text(
                  isOn ? 'On' : 'Off',
                  style: GoogleFonts.inter(
                    fontSize: 14, 
                    color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// REUSABLE WIDGET FOR SLIDER CONTROLS
class SliderControlCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double value; // The current brightness (0-100)
  final Function(double) onChanged; // Function to call when slider moves

  const SliderControlCard({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Row for Title and Icon ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: const Color(0xFFF9A825), size: 30),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // --- Text to show the current % value ---
                Text(
                  '${value.round()}%', // e.g., "50%"
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF9A825),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10), // Space

            // --- The Slider Itself ---
            Slider(
              value: value, // The current value from our state
              min: 0.0,     // Minimum brightness
              max: 100.0,   // Maximum brightness
              divisions: 100, // Snaps to 1% increments
              label: '${value.round()}%', // Label that pops up on drag
              activeColor: const Color(0xFFF9A825), // Slider "on" color
              inactiveColor: Colors.grey.shade300, // Slider "off" color
              onChanged: onChanged, // Function to call when user drags
            ),
          ],
        ),
      ),
    );
  }
}

// TIME AND DATE
class LiveClock extends StatefulWidget {
  const LiveClock({super.key});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late String _dateTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Initialize the time when the widget is created
    _dateTime = _formatDateTime(DateTime.now());

    // Create a timer that updates the time every minute
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (Timer t) => _updateTime(),
    );
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed to prevent memory leaks
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    // Update the state with the new time, which triggers a rebuild
    setState(() {
      _dateTime = _formatDateTime(DateTime.now());
    });
  }

  String _formatDateTime(DateTime dateTime) {
    // Format the date and time
    return DateFormat('MMM d, yyyy  HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _dateTime,
      style: GoogleFonts.inter(
        color: const Color.fromRGBO(32, 32, 32, 1.0),
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
