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