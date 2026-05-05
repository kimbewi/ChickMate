import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/live_clock.dart';
import '../widgets/status_card.dart';
import '../widgets/control_card.dart';
import '../widgets/video_troubleshoot_modal.dart';
import 'sensor_history.dart';
import 'actuator_history.dart';
import 'notification_page.dart';
import '../services/history_service.dart';
import 'full_screen.dart';
import '../widgets/flock_status_card.dart';

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
  bool isFansOn = false;
  bool isHeaterOn = false;
  double lightBrightness = 0.0;

  // STATE VARIABLES FOR AI PREDICTIONS
  String flockBehavior = "--";
  String flockSound = "--";
  String flockInterpretation = "--";

  // WebRTC VARIABLES
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  IOWebSocketChannel? _channel;

  late DatabaseReference _sensorDataRef;
  late DatabaseReference _controlsRef;
  late DatabaseReference _flockStatusRef;
  StreamSubscription? _flockStatusSubscription;
  StreamSubscription? _sensorDataSubscription;
  StreamSubscription? _controlsSubscription;

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

  // NAVIGATION VARIABLES (for navbar navigation)
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _configKey = GlobalKey();
  final GlobalKey _videoKey = GlobalKey();
  final GlobalKey _envKey = GlobalKey();
  final GlobalKey _controlsKey = GlobalKey();

  int _activeIndex = 0;

  void _scrollToSection(GlobalKey key, int index) {
    setState(() => _activeIndex = index);
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.001, // puts the section right near the top of the screen
      );
    }
  }

  void _toggleMode(bool value) {
    setState(() {
      isManualMode = value;
    });

    _controlsRef.child('manualOverride').set(value);
  }

  void _updateChickWeek(int week) {
    _chickInfoRef.child('ageWeeks').set(week);
  }

  void _removeDropdown() {
    _dropdownOverlay?.remove();
    setState(() {
      _dropdownOverlay = null;
    });
  }

  void _showDropdown() {
    final overlay = Overlay.of(context)!;
    final renderBox =
        _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    setState(() {
      _dropdownOverlay = OverlayEntry(
        builder: (context) => Stack(
          children: [
            TapRegion(
              groupId: 'chickDropdown',
              onTapOutside: (_) => _removeDropdown(),
              child: CompositedTransformFollower(
                link: _dropdownLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 4),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    color: Colors.white,
                    child: SizedBox(
                      width: size.width,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              color: selectedWeek == week
                                  ? Colors.grey.shade100
                                  : Colors.transparent,
                              child: Text(
                                "Week $week",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
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
                ),
              ),
            ),
          ],
        ),
      );
    });

    overlay.insert(_dropdownOverlay!);
  }

  @override
  void initState() {
    super.initState();
    _connect(); // WebRTC INIT
    fetchUnreadCount();
    setupFCM();
    _chickInfoRef = FirebaseDatabase.instance.ref('chickInfo');
    _scrollController.addListener(_onScroll);

    // Listen to AI inferences for flock status
    _flockStatusRef = FirebaseDatabase.instance.ref('aiResult');
    _flockStatusSubscription = _flockStatusRef.onValue.listen((
      DatabaseEvent event,
    ) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          flockBehavior = data['cv']?.toString().toUpperCase() ?? '--';
          flockSound = data['bioacoustic']?.toString().toUpperCase() ?? '--';
          flockInterpretation = data['interpretation']?.toString() ?? '--';
        });
      }
    });

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
              icon: 'app_logo',
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
          var rawAmmonia = data['ammonia'];
          if (rawAmmonia is num) {
            ammoniaLevel = rawAmmonia.toStringAsFixed(3);
          } else {
            ammoniaLevel = rawAmmonia?.toString() ?? '--';
          }

          var rawLight = data['lightLevel'];
          if (rawLight is num) {
            lightLevel = rawLight.toStringAsFixed(3);
          } else {
            lightLevel = rawLight?.toString() ?? '--';
          }
          
          temperature = data['temperature']?.toString() ?? '--';
          humidity = data['humidity']?.toString() ?? '--';
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
          isFansOn = data['fans'] ?? false;
          isHeaterOn = data['heater'] ?? false;
          lightBrightness = (data['lightBrightness'] ?? 0.0).toDouble();
          isManualMode = data['manualOverride'] ?? false;
        });
      }
      // If snapshot doesn't exist, they will keep their default values
    });
  }

  Future<void> setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Ask permission
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Get device token
    String? token = await messaging.getToken();
    print("🔥 DEVICE TOKEN: $token");

    if (token != null) {
      await HistoryService.saveDeviceToken(token);
    }
  }

  Future<void> fetchUnreadCount() async {
    if (!mounted || isViewingNotifications) return;

    try {
      final count = await HistoryService.fetchUnreadCount();
      setState(() {
        unreadCount = count;
      });
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

  void _onScroll() {
    // If scrolled to the bottom, always highlight Controls
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      if (_activeIndex != 3) setState(() => _activeIndex = 3);
      return;
    }

    final sections = [
      (_configKey, 0),
      (_videoKey, 1),
      (_envKey, 2),
      (_controlsKey, 3),
    ];

    for (int i = sections.length - 1; i >= 0; i--) {
      final key = sections[i].$1;
      final index = sections[i].$2;
      final context = key.currentContext;
      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);

      if (position.dy <= 120) {
        if (_activeIndex != index) {
          setState(() => _activeIndex = index);
        }
        break;
      }
    }
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

    // 1. GET THE LATEST LOCAL IP FROM FIREBASE
    String currentLocalIp = '192.168.8.95'; // Default fallback just in case
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('network/localIp')
          .get();
      if (snapshot.exists) {
        currentLocalIp = snapshot.value.toString();
        debugPrint("Fetched Pi IP from Firebase: $currentLocalIp");
      }
    } catch (e) {
      debugPrint("Failed to fetch IP from Firebase: $e");
    }

    // 2. DEFINE THE TWO CONNECTION PATHS
    final tailscaleIp = 'ws://100.68.113.75:8765';
    final localIp = 'ws://$currentLocalIp:8765';

    WebSocket? rawSocket;

    // 3. SCENARIO A: Try Tailscale First (3-second timeout)
    try {
      debugPrint("Attempting Tailscale Connection...");
      rawSocket = await WebSocket.connect(
        tailscaleIp,
      ).timeout(const Duration(seconds: 3));
      debugPrint("✅ Connected via Tailscale!");
    } catch (e) {
      debugPrint("Tailscale failed. Switching to Local Wi-Fi...");

      // 4. SCENARIO B: Try Local Wi-Fi (3-second timeout)
      try {
        rawSocket = await WebSocket.connect(
          localIp,
        ).timeout(const Duration(seconds: 3));
        debugPrint("✅ Connected via Local Wi-Fi!");
      } catch (e) {
        debugPrint("❌ Both connections failed: $e");
        return; // Stop here if neither connects
      }
    }

    // 5. ATTACH THE SUCCESSFUL CONNECTION
    if (rawSocket != null) {
      _channel = IOWebSocketChannel(rawSocket);
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
  }

  @override
  void dispose() {
    _notificationTimer?.cancel(); // cancel timer FIRST
    _sensorDataSubscription?.cancel();
    _controlsSubscription?.cancel();
    _chickInfoSubscription?.cancel();

    _remoteRenderer.dispose();
    _scrollController.dispose();
    _pc?.close();
    _channel?.sink.close();
    _flockStatusSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color.fromRGBO(249, 250, 251, 1.0),
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
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color.fromRGBO(32, 32, 32, 1.0),
                    ),
                  ),
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

                      await HistoryService.markAllNotificationsRead();

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationPage(),
                        ),
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
                      child: IgnorePointer(
                        // <-- prevent blocking taps
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
          ],
        ),
      ),

      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(249, 250, 251, 1.0),
                  Color.fromRGBO(249, 250, 251, 1.0),
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
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -- configuration section --
                      Text(
                        key: _configKey,
                        "SYSTEM MODE",
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color.fromRGBO(30, 30, 30, 1.0),
                          height: 1.0,
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment
                            .start, // Aligns the bottoms of the containers (configuration section)
                        children: [
                          // -- SYSTEM MODE --
                          Expanded(
                            flex: 20, // flexible width
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Select System Mode:",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: const Color.fromRGBO(
                                          30,
                                          30,
                                          30,
                                          1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Tooltip(
                                      message:
                                          "Select if you want the brooder to run\non its own or if you want to control it.",
                                      textAlign: TextAlign.center,
                                      triggerMode: TooltipTriggerMode.tap,
                                      showDuration: const Duration(seconds: 5),
                                      preferBelow: true,
                                      verticalOffset: 12,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade700.withValues(
                                          alpha: 0.8,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),

                                      textStyle: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      child: const Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 4,
                                ), // margin between "system mode" and toggle
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.all(
                                    1,
                                  ), //border-like padding
                                  decoration: BoxDecoration(
                                    color: Colors
                                        .grey
                                        .shade200, // Light gray background for the toggle area
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      // Automatic Button
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _toggleMode(false),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: !isManualMode
                                                  ? const Color(0xFF4A85F6)
                                                  : Colors
                                                        .transparent, // Blue when active
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.auto_awesome_outlined,
                                                  size: 18,
                                                  color: !isManualMode
                                                      ? Colors.white
                                                      : Colors.grey.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Automatic",
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: !isManualMode
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    color: !isManualMode
                                                        ? Colors.white
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Manual Button
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _toggleMode(true),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isManualMode
                                                  ? const Color(0xFF4A85F6)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.pan_tool_outlined,
                                                  size: 18,
                                                  color: isManualMode
                                                      ? Colors.white
                                                      : Colors.grey.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Manual",
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: isManualMode
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    color: isManualMode
                                                        ? Colors.white
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            width: 16,
                          ), // margin between system mode and chick age
                          // CHICK AGE
                          Expanded(
                            flex: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Chicks' Age:",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: const Color.fromRGBO(
                                      30,
                                      30,
                                      30,
                                      1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                CompositedTransformTarget(
                                  link: _dropdownLink,
                                  child: TapRegion(
                                    groupId: 'chickDropdown',
                                    child: InkWell(
                                      key: _dropdownKey,
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        if (_dropdownOverlay == null) {
                                          _showDropdown();
                                        } else {
                                          _removeDropdown();
                                        }
                                      },
                                      child: Container(
                                        height:
                                            48, // Matches height of the toggle
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors
                                              .white, // White background for dropdown
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 18,
                                              color: Color.fromRGBO(
                                                50,
                                                50,
                                                50,
                                                1.0,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "Week $selectedWeek",
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color.fromRGBO(
                                                    32,
                                                    32,
                                                    32,
                                                    1.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              _dropdownOverlay != null
                                                  ? Icons
                                                        .keyboard_arrow_up_rounded
                                                  : Icons
                                                        .keyboard_arrow_down_rounded,
                                              color: Colors.grey.shade700,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      Row(
                        key: _videoKey,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "VIDEO FEED",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => showVideoTroubleshootModal(context),
                            child: Icon(
                              Icons.help_outline,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                                    objectFit: RTCVideoViewObjectFit
                                        .RTCVideoViewObjectFitContain,
                                    mirror: false,
                                  ),
                                ),

                                // 2. The Full Screen Button (Bottom Right)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(
                                        0.5,
                                      ), // Semi-transparent background
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.fullscreen,
                                        color: Colors.white,
                                      ),
                                      tooltip: "Full Screen",
                                      onPressed: () {
                                        // Navigate to the full screen page
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FullScreenVideoPage(
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
                      const SizedBox(height: 24),

                      Text(
                        "AI PREDICTION",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // FLOCK STATUS WIDGETS
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: FlockStatusCard(
                                title: 'Flock Behavior:',
                                status: flockBehavior,
                                iconAsset:
                                    'assets/images/flockBehaviorIcon.png',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FlockStatusCard(
                                title: 'Flock Sounds:',
                                status: flockSound,
                                iconAsset: 'assets/images/flockSoundsIcon.png',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // -- environmental status section --
                      Row(
                        key: _envKey,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'ENVIRONMENTAL STATUS',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height:
                                  1.0, // removing extra space in text's height
                            ),
                            // removing extra space in text's height
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.history,
                              color: Color.fromRGBO(146, 138, 138, 1.0),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SensorHistoryPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // -- environmental status widgets --
                      Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: StatusCard(
                                    title: 'Ammonia Level',
                                    data: ammoniaLevel,
                                    unit: 'ppm',
                                    icon: Icons.dangerous_outlined,
                                    iconColor: Colors.green,
                                    selectedWeek: selectedWeek,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: StatusCard(
                                    title: 'Temperature',
                                    data: temperature,
                                    unit: '°C',
                                    icon: Icons.thermostat,
                                    iconColor: Colors.redAccent,
                                    selectedWeek: selectedWeek,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: StatusCard(
                                    title: 'Humidity',
                                    data: humidity,
                                    unit: '%',
                                    icon: Icons.water_drop_outlined,
                                    iconColor: Colors.blueAccent,
                                    selectedWeek: selectedWeek,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: StatusCard(
                                    title: 'Light Level',
                                    data: lightLevel,
                                    unit: 'lux',
                                    icon: Icons.wb_sunny_outlined,
                                    iconColor: Colors.yellowAccent,
                                    selectedWeek: selectedWeek,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // -- controls section --
                      Row(
                        key: _controlsKey,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'CONTROLS',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.history,
                              color: Color.fromRGBO(146, 138, 138, 1.0),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActuatorHistoryPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: isManualMode ? 12.0 : 4.0),

                      // -- controls widgets --
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isManualMode
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isManualMode
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFF8AB4F8),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start, // align icon to top
                          children: [
                            Icon(
                              isManualMode
                                  ? Icons.recommend_outlined
                                  : Icons.auto_awesome,
                              color: isManualMode
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF1967D2),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: isManualMode
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "AI RECOMMENDED ACTION",
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2E7D32),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          flockInterpretation,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF2E7D32),
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      "Controls are locked while in Automatic Mode. Switch to Manual to take over.",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1967D2),
                                        height: 1.3,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      IgnorePointer(
                        ignoring: !isManualMode,
                        child: Opacity(
                          opacity: isManualMode ? 1.0 : 0.4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ControlCard(
                                        title: 'Fans',
                                        icon: Icons.air_outlined,
                                        isOn: isFansOn,
                                        onChanged: (value) {
                                          setState(() {
                                            isFansOn = value;
                                          });
                                          _updateControl('fans', value);
                                        },
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: ControlCard(
                                        title: 'Heater',
                                        icon: Icons.whatshot_outlined,
                                        isOn: isHeaterOn,
                                        onChanged: (value) {
                                          setState(() => isHeaterOn = value);
                                          _updateControl('heater', value);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                                },
                                onChangeEnd: (newValue) {
                                  _updateControl(
                                    'lightBrightness',
                                    newValue.round(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildFloatingNavBar(),
          ),
        ],
      ),
    );
  }

  // for bottom navigation
  Widget _buildFloatingNavBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 1),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 8,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.tune_rounded, "Configuration", _configKey),
            _buildNavItem(
              1,
              Icons.smart_display_outlined,
              "Video Feed",
              _videoKey,
            ),
            _buildNavItem(
              2,
              Icons.device_thermostat_rounded,
              "Environmental\nStatus",
              _envKey,
            ),
            _buildNavItem(
              3,
              Icons.settings_remote_outlined,
              "Controls",
              _controlsKey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, GlobalKey key) {
    final isActive = _activeIndex == index;
    final color = isActive ? const Color(0xFFF9A825) : Colors.grey.shade400;

    return GestureDetector(
      onTap: () => _scrollToSection(key, index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
