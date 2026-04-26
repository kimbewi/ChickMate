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
    // String tooltipMsg = 'Waiting for data...';

    final bool isSoundCard = title.contains("Sounds");

    // final Map<String, Map<String, String>> behaviorMap = {
    //   'HOT': {
    //     'label': 'DISPERSED',
    //     'tooltip': 'Chicks are panting and avoiding the heat source.',
    //   },
    //   'NORMAL': {
    //     'label': 'EVENLY DISTRIBUTED',
    //     'tooltip': 'Chicks are active and spread out evenly.',
    //   },
    //   'COLD': {
    //     'label': 'HUDDLING',
    //     'tooltip': 'Chicks are huddling together to stay warm.',
    //   },
    // };

    final Map<String, Map<String, String>> behaviorMap = {
      'HOT': {
        'label': 'DISPERSED',
        'tooltip': 'Chicks are spread out; possible heat stress.',
      },
      'NORMAL': {
        'label': 'EVENLY DISTRIBUTED',
        'tooltip': 'Chicks are active and evenly distributed; possible optimal condition.',
      },
      'COLD': {
        'label': 'HUDDLING',
        'tooltip': 'Chicks are grouped closely together; possible cold stress.',
      },
    };

    final Map<String, Map<String, String>> soundMap = {
      'HOT': {
        'label': 'IRREGULAR',
        'tooltip': 'Reduced and inconsistent; possible heat stress.',
      },
      'NORMAL': {
        'label': 'MODERATE',
        'tooltip': 'Steady and calm; possible optimal condition.',
      },
      'COLD': {
        'label': 'HIGH-INTENSITY',
        'tooltip': 'Repetitive and high-pitched; possible cold stress.',
      },
      'REJECTION': {
        'label': 'UNDETECTED',
        'tooltip': 'No clear chick vocalization detected.',
      },
    };

    final selectedMap = isSoundCard ? soundMap : behaviorMap;

    final data = selectedMap[status] ?? {
      'label': 'UNKNOWN',
      'tooltip': 'No data available.',
    };

    final String displayValue = data['label']!;
    final String tooltipMsg = data['tooltip']!;

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
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown, 
                    alignment: Alignment.centerLeft, 
                    child: Text(
                      displayValue,
                      style: GoogleFonts.inter(
                        fontSize: 22, 
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                      maxLines: 1, 
                    ),
                  ),
                ),
                Tooltip(
                  message: tooltipMsg,
                  child: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}