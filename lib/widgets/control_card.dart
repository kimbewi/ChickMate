import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final cardColor = isOn ? const Color(0xFFF9A825) : Colors.white;
    final iconColor = isOn ? Colors.white : const Color(0xFFF9A825);
    final titleColor = isOn ? Colors.white : Colors.black87;
    final statusColor = isOn ? Colors.white70 : Colors.black54;

    return Card(
      color: cardColor,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 150,
        height: 150,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 40),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isOn,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.white.withAlpha(128),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor)),
                Text(isOn ? 'On' : 'Off',
                    style: GoogleFonts.inter(fontSize: 14, color: statusColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}