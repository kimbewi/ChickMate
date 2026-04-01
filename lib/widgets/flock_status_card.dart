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
      statusColor = Colors.red;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Image.asset(
              iconAsset,
              height: 45,
              width: 45,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.pets, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: tooltipMsg,
                        triggerMode: TooltipTriggerMode.tap,
                        showDuration: const Duration(seconds: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        child: Icon(
                          Icons.help_outline,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}