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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.center, // center vertically
          // crossAxisAlignment: CrossAxisAlignment.center, // center horizontally
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12, // 🔧 fixed static size for title
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // center horizontally
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 6),
                Text(
                  '$data $unit',
                  style: const TextStyle(
                    fontSize: 16, // 🔧 fixed static size for values
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// class StatusCard extends StatelessWidget {
//   final String title;
//   final String data;
//   final String unit;
//   final IconData icon;
//   final Color iconColor;

//   const StatusCard({
//     super.key,
//     required this.title,
//     required this.data,
//     required this.unit,
//     required this.icon,
//     required this.iconColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       color: Colors.white,
//       elevation: 1,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Container(
//         width: 150,
//         height: 110,
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(title,
//                 style: GoogleFonts.inter(fontSize: 14, color: Colors.black54)),
//             const SizedBox(height: 17),
//             Wrap(
//               children: [
//                 Icon(icon, color: iconColor, size: 35),
//                 const SizedBox(width: 5),
//                 Text(data,
//                     style: GoogleFonts.inter(
//                         fontSize: 19.5, fontWeight: FontWeight.bold)),
//                 Text(unit,
//                     style: GoogleFonts.inter(
//                         fontSize: 19.5, fontWeight: FontWeight.bold)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }