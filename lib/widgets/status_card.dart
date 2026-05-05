import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusCard extends StatelessWidget {
  final String title;
  final String data;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final int selectedWeek; 
  
  const StatusCard({
    Key? key,
    required this.title,
    required this.data,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.selectedWeek,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double? parsedValue = double.tryParse(data);
    bool isNumeric = parsedValue != null && !parsedValue.isNaN;
    bool isError = !isNumeric && data != '--';

    // --- DEFAULT PLACEHOLDERS FOR LOGIC ---
    double targetMin = 0.0;
    double targetMax = 0.0;
    String highLabel = 'TOO HIGH';
    String lowLabel = 'TOO LOW';
    String highRec = 'Adjust settings to lower the value.';
    String lowRec = 'Adjust settings to increase the value.';
    String normalRec = 'Maintain current environmental settings.';
    String targetSubtitle = '';

    // --- SENSOR SPECIFIC TARGETS & RECOMMENDATIONS ---
    switch (title) {
      case 'Temperature':
        highLabel = 'TOO HOT';
        lowLabel = 'TOO COLD';
        highRec = 'Turn ON the fans and OFF the heater.';
        lowRec = 'Turn ON the heater and OFF the fans.';
        
        targetMin = 32.0 - (2 * (selectedWeek - 1));
        targetMax = 34.0 - (2 * (selectedWeek - 1));
        targetSubtitle = 'Target for Week $selectedWeek: ${targetMin.toInt()}-${targetMax.toInt()}$unit';
        break;
      

      case 'Ammonia Level':
        highLabel = 'DANGER';
        highRec = 'Turn ON the fans immediately.';
        
        targetMin = 0.0; 
        targetMax = 6.0; 
        targetSubtitle = 'Safe Threshold: 0-${targetMax.toInt()} $unit';
        break;

      case 'Humidity':
        highLabel = 'TOO HUMID';
        lowLabel = 'TOO DRY';
        highRec = 'Increase ventilation to lower humidity.';
        lowRec = 'Reduce ventilation slightly to retain moisture.';
        
        targetMin = 50.0;
        targetMax = 70.0;

        targetSubtitle = 'Recommended Range: ${targetMin.toInt()}-${targetMax.toInt()}$unit';        
        break;

      case 'Light Level':
        int currentHour = DateTime.now().hour;
        
        bool isRestPeriod = false;
        if (selectedWeek == 1 && currentHour == 0) {
          isRestPeriod = true; 
        } else if (selectedWeek >= 2 && currentHour >= 0 && currentHour < 8) {
          isRestPeriod = true; 
        }

        if (isRestPeriod) {
          highLabel = 'TOO BRIGHT';
          lowLabel = 'NORMAL'; 
          highRec = 'Ensure the brooder is dark for their resting period.';
          lowRec = 'Normal resting light level.';
          
          targetMin = 0.0; 
          targetMax = 20.0;
          
          targetSubtitle = 'Target for Rest Period: 0-${targetMax.toInt()} $unit';
        } else {
          highLabel = 'TOO BRIGHT';
          lowLabel = 'TOO DIM'; 
          highRec = 'Dim the lights.';
          lowRec = 'Check if the light bulb is broken or obscured.';
          targetMin = 30.0; 
          targetMax = 300.0; 
          
          targetSubtitle = 'Target for Active Period: ${targetMin.toInt()}-${targetMax.toInt()} $unit';
        }
        break;
    }

    // --- DETERMINE CURRENT STATUS ---
    String statusLabel = 'NORMAL';
    Color statusColor = const Color(0xFF2E7D32); 
    Color statusBgColor = const Color(0xFFE8F5E9); 
    String aiRecommendation = normalRec;
    Color recBgColor = const Color(0xFFE8F5E9); 
    Color recBorderColor = const Color(0xFF66BB6A);
    Color recTextColor = const Color(0xFF2E7D32);

    if (isNumeric) {
      if (parsedValue > targetMax) {
        statusLabel = highLabel;
        statusColor = const Color(0xFFD32F2F); 
        statusBgColor = const Color(0xFFFFEBEE); 
        aiRecommendation = highRec;
        recBgColor = const Color(0xFFFFEBEE); 
        recBorderColor = const Color(0xFFEF5350); 
        recTextColor = const Color(0xFFD32F2F);
      } else if (parsedValue < targetMin) {
        statusLabel = lowLabel;
        statusColor = const Color(0xFFD32F2F); 
        statusBgColor = const Color(0xFFFFEBEE); 
        aiRecommendation = lowRec;
        recBgColor = const Color(0xFFFFEBEE); 
        recBorderColor = const Color(0xFFEF5350); 
        recTextColor = const Color(0xFFD32F2F); 
      }
    }

    // For units formatting
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- TINTED ICON BOX & STATUS PILL ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      
                      if (isNumeric)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // --- AI RECOMMENDATION BOX ---
                  if (isNumeric)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: recBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: recBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI RECOMMENDATION:',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: recTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            aiRecommendation,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // --- WIDGET TITLE ---
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16, 
                        fontWeight: FontWeight.w400,
                        color: const Color.fromRGBO(30, 30, 30, 1.0),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // --- DATA VALUE ---
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isError ? '--' : displayData, 
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: const Color.fromRGBO(30, 30, 30, 1.0),
                        height: 1.0, 
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // --- TARGET SUBTITLE ---
                  if (isNumeric)
                    Text(
                      targetSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // --- ERROR OVERLAYS ---
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