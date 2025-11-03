import 'dart:async'; // for timer
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // for date formatting
import 'package:firebase_core/firebase_core.dart'; // for firebase
import 'firebase_options.dart'; // for firebase
import 'package:firebase_database/firebase_database.dart'; // for firebase

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  await Firebase.initializeApp( 
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  // LOGIC FOR GETTING THE DATA FROM ESP32 WILL ALSO BE PLACED HERE
  // PLACEHOLDER TEXT ONLY FOR ESP32 DATA
  String ammoniaLevel = "--";
  String temperature = "--";
  String humidity = "--";

  late DatabaseReference _sensorDataRef; // Reference to your data
  late StreamSubscription _sensorDataSubscription; // Listener

  @override
  void initState() {
    super.initState();
    // Point the reference to the "node" or "path" in your database
    // We'll tell the ESP32 to write to this same "sensorData" path
    _sensorDataRef = FirebaseDatabase.instance.ref('sensorData');

    // Start listening for changes
    _sensorDataSubscription = _sensorDataRef.onValue.listen((DatabaseEvent event) {
      // Data from Firebase comes as a "snapshot"
      if (event.snapshot.value != null) {
        // The data is a Map. We cast it to be sure.
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        // Call setState to rebuild the UI with the new data
        setState(() {
          // Use .toString() to safely handle data (Firebase might send numbers)
          // The '??' (null-check operator) keeps "--" if a value is missing
          ammoniaLevel = data['ammonia']?.toString() ?? '--';
          temperature = data['temperature']?.toString() ?? '--';
          humidity = data['humidity']?.toString() ?? '--';
        });
      }
    });
  }

  @override
  void dispose() {
    // ALWAYS cancel the subscription when the widget is removed
    _sensorDataSubscription.cancel();
    super.dispose();
  }
  // --- END OF NEW FIREBASE SETUP ---

  @override
  Widget build(BuildContext context) {

    return Scaffold(
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
      
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(248, 248, 255, 1.0),
              Color.fromRGBO(255, 247, 209, 1.0)
            ],
            // start and end points of the gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VIDEO FEED SECTION
          Text(
            "Video Feed",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            ),

            // a space between text and video
            const SizedBox(height:10),

            Card(
            color: const Color(0xFFFAF6EE),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),  
            child: Padding(
            padding:EdgeInsets.all(19),
            child:Container(
            height: 300,
            width: double.infinity,
            color: Colors.black,
            // video player from the Raspberry Pi will go here
            child: const Center(
              child: Text(
                'Video feed is offline',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          ),
        ),

        const SizedBox(height:30),

        // ENVIRONMENTAL STATUS SECTION
        Text(
          'Environmental Status',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // wrap - for responsiveness
        Wrap(
          spacing: 12.0, // horizontal space between cards
          runSpacing: 12.0, // vertical space between rows of cards
          children: [
            // from custom widget below
            StatusCard(
              title: 'Ammonia Level',
              data: ammoniaLevel, // data from ESP32
              unit: '%',
              icon: Icons.dangerous_outlined,
              iconColor: Colors.green,
            ),
            StatusCard(
              title: 'Temperature',
              data: temperature, // data from ESP32
              unit: '°C',
              icon: Icons.thermostat,
              iconColor: Colors.redAccent,
            ),
            StatusCard(
              title: 'Humidity',
              data: humidity, // data from ESP32
              unit: '%',
              icon: Icons.water_drop_outlined,
              iconColor: Colors.blueAccent,
            ),

          ],
          
        )
        ]),
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
    return Card(
      color: const Color(0xFFFAF6EE),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 150, // fixed width for each card
        height: 110,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 17),
            Wrap(
              //spacing: 5,
              children: [
                Icon(icon, color: iconColor, size: 35),
                const SizedBox(width: 8),
                Text(
                  data, // data from ESP32 will go here
                  style: GoogleFonts.inter(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                Text(
                  unit, // units like "%" or "°C"
                  style: GoogleFonts.inter(fontSize: 25, fontWeight: FontWeight.bold),
                ),
              ],
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
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) => _updateTime());
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
    // Format the date and time exactly like in your image
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