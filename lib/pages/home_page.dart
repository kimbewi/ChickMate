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
import 'notification_page.dart';
import 'full_screen.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_webrtc/flutter_webrtc.dart'; // for webrtc
import 'package:web_socket_channel/io.dart'; // for websocket
import 'dart:convert'; // for json decoding

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey _dropdownKey = GlobalKey();

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

  late DatabaseReference _sensorDataRef; 
  late DatabaseReference _controlsRef; 
  StreamSubscription? _sensorDataSubscription;
  StreamSubscription? _controlsSubscription;

  late DatabaseReference _settingsRef;
  StreamSubscription? _settingsSubscription;
  bool isManualMode = false; 

  bool isViewingNotifications = false;
  int unreadCount = 0;
  Timer? _notificationTimer;

  int selectedWeek = 1; // default week
  late DatabaseReference _chickInfoRef;
  StreamSubscription? _chickInfoSubscription;

  bool isDropdownOpen = false;
  final LayerLink _dropdownLink = LayerLink();
  OverlayEntry? _dropdownOverlay;

  void _toggleMode(bool value) {
  setState(() {
    isManualMode = value;
  });

    _settingsRef.child('manualOverride').set(value);
  }

  void _updateChickWeek(int week) {
    _chickInfoRef.child('ageWeeks').set(week);
  }

  void _removeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  void _showDropdown() {
  final overlay = Overlay.of(context)!;
  final renderBox = _dropdownKey.currentContext!.findRenderObject() as RenderBox;
  final size = renderBox.size;
  final offset = renderBox.localToGlobal(Offset.zero);

  _dropdownOverlay = OverlayEntry(
    builder: (context) => Positioned(
      left: offset.dx,
      top: offset.dy + size.height + 4, 
      width: size.width,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(6, (index) {
            int week = index + 1;
            return InkWell(
              onTap: () {
                setState(() {
                  selectedWeek = week;
                });
                _updateChickWeek(week);
                _removeDropdown();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: selectedWeek == week
                    ? Colors.white.withOpacity(0.08)
                    : Colors.transparent,
                child: Text(
                  "Week $week",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: selectedWeek == week
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );

    overlay.insert(_dropdownOverlay!);
  }

  @override
  void initState() {
    super.initState();
    _connect(); // WebRTC INIT
    fetchUnreadCount();
    setupFCM();
    _chickInfoRef = FirebaseDatabase.instance.ref('chickInfo');

    _chickInfoSubscription = _chickInfoRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          selectedWeek = data['ageWeeks'] ?? 1;
        });
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground message received");

      if (message.notification != null) {
        flutterLocalNotificationsPlugin.show(
          0,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel_v2', // id
              'High Importance Notifications', // name
              importance: Importance.high,
              priority: Priority.high,
              icon: 'app_logo'
            ),
          ),
        );
      }
    });

     _notificationTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => fetchUnreadCount(),
      );

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
    _settingsRef = FirebaseDatabase.instance.ref('currentSettings');

    _settingsSubscription = _settingsRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          isManualMode = data['manualOverride'] ?? false;
        });
      }
    });
  }

Future<void> setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Ask permission
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get device token
  String? token = await messaging.getToken();
  print("🔥 DEVICE TOKEN: $token");

  // Send token to Node server
  await http.post(
    Uri.parse("http://192.168.0.104:5000/api/save-token"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"token": token}),
  );
}

Future<void> fetchUnreadCount() async {
  if (!mounted || isViewingNotifications) return;

  try {
    final response = await http.get(
      Uri.parse("http://192.168.0.104:5000/api/notifications/unread-count"),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        unreadCount = data['unreadCount'] ?? 0;
      });
    }
  } catch (e) {
    debugPrint("❌ Failed to fetch unread count: $e");
  }
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
    _notificationTimer?.cancel(); // cancel timer FIRST
    _sensorDataSubscription?.cancel();
    _controlsSubscription?.cancel();
    _chickInfoSubscription?.cancel();
    _settingsSubscription?.cancel();

    _remoteRenderer.dispose();
    _pc?.close();
    _channel?.sink.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60), 
        child: AppBar(
          backgroundColor: const Color.fromRGBO(253, 253, 253, 1.0),
          automaticallyImplyLeading: false,
          elevation: 2,
          title: Row(
            children: [
              Image.asset('assets/images/appLogo.png', height: 45),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "ChickMate",
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color.fromRGBO(32, 32, 32, 1.0),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(height: 18, child: LiveClock()),
                ],
              ),
            ],
          ),
          actions: [
            SizedBox(
            width: 48, // typical IconButton size
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none_outlined,
                    color: Color.fromRGBO(32, 32, 32, 1.0),
                  ),
                  tooltip: 'Notifications',
                  onPressed: () async {
                    setState(() {
                      isViewingNotifications = true;
                      unreadCount = 0;
          });

          await http.put(
            Uri.parse("http://192.168.0.104:5000/api/notifications/mark-all-read"),
          );

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationPage()),
          );

          setState(() {
            isViewingNotifications = false;
          });
        },
      ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: IgnorePointer(  // <-- prevent blocking taps
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
          ]
        ),
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
              Text(
                "System Mode",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),

              Text(
                "Switch between Automatic and Manual control",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isManualMode ? Icons.handyman_outlined : Icons.smart_toy_outlined,
                      color: const Color.fromRGBO(32, 32, 32, 1.0),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isManualMode ? "Manual Mode" : "Automatic Mode",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            isManualMode
                                ? "User controls all devices"
                                : "AI controls the system",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Switch(
                      value: isManualMode,
                      // activeColor: Colors.orange,
                      activeThumbColor: Colors.white,
                      inactiveThumbColor: Colors.grey.shade700,

                      // 👇 KEY PART: prevent solid fill look
                      activeTrackColor: const Color(0xFFF9A825),
                      inactiveTrackColor: Colors.grey.shade200,

                      onChanged: _toggleMode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "Chick Age",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),

              Text(
                "Select the age of the chicks",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 12),

              Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [

                  CompositedTransformTarget(
                    link: _dropdownLink,
                    child: InkWell(
                      key: _dropdownKey, // ✅ attach key here
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (_dropdownOverlay == null) {
                          _showDropdown();
                        } else {
                          _removeDropdown();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: Color.fromRGBO(32, 32, 32, 1.0),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Week $selectedWeek",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              _dropdownOverlay != null
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              const SizedBox(height: 30),
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