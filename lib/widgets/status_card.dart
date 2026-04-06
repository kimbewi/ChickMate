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
      color: Colors.white,
      margin: EdgeInsets.zero,
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
            if (isNumeric || data == '--')
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  displayData,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color.fromRGBO(30, 30, 30, 1.0),
                    height: 1.0, 
                  ),
                ),
              )
            
            else
              Text(
                displayData,
                maxLines: 2, 
                overflow: TextOverflow.ellipsis, 
                style: GoogleFonts.inter(
                  fontSize: 22, 
                  fontWeight: FontWeight.w800,
                  color: const Color.fromARGB(255, 255, 0, 0), 
                  height: 1.2, 
                ),
            ),
          ],
        ),
      ),
    );
  }
}
