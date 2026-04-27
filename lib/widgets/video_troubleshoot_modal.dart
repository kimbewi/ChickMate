import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// Notice we removed the "_" so it can be accessed from outside this file
void showVideoTroubleshootModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: const Color(0xFFF5F5F5), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              // 1. Close Button (Top Right)
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                ),
              ),
              
              // 2. Monitor Icon
              const SizedBox(height: 8),
              Icon(
                Icons.tv_off_rounded, 
                size: 90,
                color: Colors.grey.shade500,
              ),
              
              // 3. Title
              const SizedBox(height: 16),
              Text(
                "Video Not Showing?",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color.fromRGBO(32, 32, 32, 1.0),
                ),
              ),
              
              // 4. Subtitle
              const SizedBox(height: 16),
              Text(
                "Check if you're connected to Brooder's Built-in Wi-Fi",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color.fromRGBO(50, 50, 50, 1.0),
                ),
              ),
              
              // 5. "OR" Divider
              const SizedBox(height: 10),
              Text(
                "OR",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
              
              // 6. Action Button
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCA28), 
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    debugPrint("🚀 Attempting to launch URL...");
                    const tailscaleInviteUrl = 'https://login.tailscale.com/admin/invite/DYKcAAWNYqXLDcN7MSeU11'; 
                    final uri = Uri.parse(tailscaleInviteUrl);

                    try {
                      // Attempt to launch directly
                      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                        debugPrint("🚨 ERROR: Could not launch $uri");
                      } else {
                        debugPrint("✅ Success!");
                      }
                    } catch (e) {
                      debugPrint('💥 CRITICAL CRASH: $e');
                    }

                    // Only close the modal AFTER everything is done
                    if (context.mounted) {
                      Navigator.of(context).pop(); 
                    }
                  },
                  child: Text(
                    "Connect to Tailscale",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color.fromRGBO(32, 32, 32, 1.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}