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

    final bool isSoundCard = title.contains("Sounds");

    final Map<String, Map<String, String>> behaviorMap = {
      'HOT': {
        'label': 'DISPERSED',
        'description': 'Chicks are spread out or lethargic; possible heat stress.',
      },
      'NORMAL': {
        'label': 'EVENLY DISTRIBUTED',
        'description': 'Chicks are active and evenly distributed; possible optimal condition.',
      },
      'COLD': {
        'label': 'HUDDLING',
        'description': 'Chicks are grouped closely together; possible cold stress.',
      },
    };

    final Map<String, Map<String, String>> soundMap = {
      'HOT': {
        'label': 'IRREGULAR',
        'description': 'Reduced and inconsistent chirping; possible heat stress.',
      },
      'NORMAL': {
        'label': 'MODERATE',
        'description': 'Steady and calm chirping; possible optimal condition.',
      },
      'COLD': {
        'label': 'HIGH-INTENSITY',
        'description': 'Repetitive and high-pitched chirping; possible cold stress.',
      },
      'REJECTION': {
        'label': 'UNDETECTED',
        'description': 'No clear chick vocalization detected.',
      },
    };

    final selectedMap = isSoundCard ? soundMap : behaviorMap;

    final data = selectedMap[status] ?? {
      'label': 'UNKNOWN',
      'description': 'No data available.',
    };

    final String displayValue = data['label']!;
    final String description = data['description']!;

    if (status == 'HOT') {
      statusColor = const Color.fromARGB(255, 211, 47, 47);
    } else if (status == 'COLD') {
      statusColor = Colors.blueAccent;
    } else if (status == 'NORMAL') {
      statusColor = Colors.green;
    } else if (status == 'REJECTION') {
      statusColor = Colors.grey; 
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            
            // --- TOP GROUP: Icon & Title ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tinted Icon Box
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
                
                const SizedBox(height: 12),
                
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color.fromRGBO(30, 30, 30, 1.0), 
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6), 

            // --- BOTTOM GROUP: Result & Interpretation ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large Status Label
                FittedBox(
                  fit: BoxFit.scaleDown, 
                  alignment: Alignment.centerLeft, 
                  child: Text(
                    displayValue,
                    style: GoogleFonts.inter(
                      fontSize: 22, 
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      height: 1.1,
                    ),
                    maxLines: 1, 
                  ),
                ),

                const SizedBox(height: 4), 

                // AI Description
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                    height: 1.3,
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