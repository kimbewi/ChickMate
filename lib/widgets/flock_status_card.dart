import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FlockStatusCard extends StatelessWidget {
  final String title;
  final String status;
  final String iconAsset;

  const FlockStatusCard({
    Key? key,
    required this.title,
    required this.status,
    required this.iconAsset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    String tooltipMsg = 'Waiting for data...';

    bool isSoundCard = title.contains("Sounds");

    if (status == 'HOT') {
      statusColor = const Color.fromARGB(255, 211, 47, 47);;
      tooltipMsg = isSoundCard
          ? 'Flock is unusually quiet or panting heavily.'
          : 'Chicks are panting and avoiding the heat source.';
    } else if (status == 'COLD') {
      statusColor = Colors.blueAccent;
      tooltipMsg = isSoundCard
          ? 'Loud, high-pitched distress peeps.'
          : 'Chicks are huddling together to stay warm.';
    } else if (status == 'NORMAL') {
      statusColor = Colors.green;
      tooltipMsg = isSoundCard
          ? 'Calm and normal chirping.'
          : 'Chicks are active and spread out evenly.';
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8), 
              decoration: BoxDecoration(
                color: const Color(0xFFF6E19A).withValues(alpha: 0.2), 
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                iconAsset,
                height: 33, 
                width: 33,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.pets, size: 24),
              ),
            ),
            const SizedBox(height: 8),
            
            // "Flock Behavior" title
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color.fromRGBO(30, 30, 30, 1.0), 
              ),
            ),
            const SizedBox(height: 4),
            
            // Status and Tooltip Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: tooltipMsg,
                  textAlign: TextAlign.center,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 3),
                  preferBelow: true,
                  verticalOffset: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8), 
                  ),
                  
                  textStyle: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Colors.grey.shade400,
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