import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusCard extends StatelessWidget {
  final String title;
  final String data;
  final String unit;
  final IconData icon;
  final Color iconColor;

  const StatusCard({
    Key? key,
    required this.title,
    required this.data,
    required this.unit,
    required this.icon,
    required this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isNumeric = double.tryParse(data) != null;

    bool isError = !isNumeric && data != '--';

    // for units formatting
    String displayData;
    if (isNumeric) {
      displayData = (unit == '°C' || unit == '%') 
          ? '$data$unit' 
          : '$data $unit'.trim();
    } else {
      displayData = data; 
    }

    return Card(
      color: isError ? const Color(0xFFF2F2F2) : Colors.white,
      margin: EdgeInsets.zero,
      elevation: isError ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack( 
        children: [
          Opacity(
            opacity: isError ? 0.25 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // --- tinted icon box ---
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15), 
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon, 
                      color: iconColor, 
                      size: 28
                    ),
                  ),

                  const SizedBox(height: 12),
                  
                  // --- widget title ---
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child:
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13, 
                          fontWeight: FontWeight.w500,
                          color: const Color.fromRGBO(30, 30, 30, 1.0),
                        ),
                      ),
                  ),

                  const SizedBox(height: 4),

                  // --- data value ---
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isError ? '--' : displayData, 
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color.fromRGBO(30, 30, 30, 1.0),
                        height: 1.0, 
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isError)
            const Positioned(
              top: 16,
              right: 16,
              child: Icon(
                Icons.warning_rounded,
                color: Color(0xFFD32F2F), 
                size: 28,
              ),
            ),
            
          if (isError)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end, 
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ERROR",
                      style: GoogleFonts.inter(
                        fontSize: 24, 
                        fontWeight: FontWeight.w900,
                        color: const Color.fromARGB(255, 211, 47, 47), 
                        height: 1.0, 
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Please check your internet connection and ensure the sensor wiring is secure.",
                      maxLines: 3, 
                      overflow: TextOverflow.ellipsis, 
                      style: GoogleFonts.inter(
                        fontSize: 10, 
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700, 
                        height: 1.2, 
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
