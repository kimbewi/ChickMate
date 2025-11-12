import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
    _dateTime = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _dateTime = _formatDateTime(DateTime.now());
    });
  }

  String _formatDateTime(DateTime dateTime) {
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