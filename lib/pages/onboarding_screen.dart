import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_page.dart'; 

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Smart Climate Control",
      "description": "The system automatically adapts the temperature, humidity and ammonia level based on the chicks' behavior, keeping them comfortable around the clock",
      "image": "assets/images/onboarding-1.png", 
    },
    {
      "title": "Live Updates From Anywhere", 
      "description": "Check on the chicks anytime. View the live video feed and environmental status directly from your phone, no matter where you are.",
      "image": "assets/images/onboarding-2.png", 
    },
    {
      "title": "Watch While Away", 
      "description": "To watch the live video when you aren't at home, securely link your device using the provided Tailscale invite.",
      "image": "assets/images/onboarding-3.png", 
    },
  ];

  Future<void> _launchTailscale() async {
    const url = 'https://login.tailscale.com/admin/invite/DYKcAAWNYqXLDcN7MSeU11';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch Tailscale: $e");
    }
  }

  // Logic to save seen preference and enter Home Page
  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_onboarding', false);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MyHomePage(title: 'ChickMate'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLastPage = _currentPage == onboardingData.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP RIGHT SKIP BUTTON 
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  "Skip",
                  style: GoogleFonts.montserrat(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            // 2. SWIPABLE CONTENT (Responsive Layout)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() {
                    _currentPage = value;
                  });
                },
                itemCount: onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Responsive Image using Flexible
                        Flexible(
                          flex: 3,
                          child: Image.asset(
                            onboardingData[index]["image"]!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Text Content
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              onboardingData[index]["title"]!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color.fromRGBO(30, 30, 30, 1.0),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              onboardingData[index]["description"]!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color.fromRGBO(146, 138, 138, 1.0),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                        // Spacer for layout balance
                        const Flexible(flex: 1, child: SizedBox(height: 20)),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 3. BOTTOM CONTROLS
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      onboardingData.length,
                      (index) => buildDot(index, context),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Conditional Action Buttons
                  if (isLastPage)
                    Column(
                      children: [
                        // Yellow Button: Tailscale
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFCA28),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _launchTailscale,
                            child: Text(
                              "Connect to Tailscale",
                              style: GoogleFonts.montserrat(
                                color: const Color.fromRGBO(30, 30, 30, 1.0),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Grey Button: Skip to Home
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _completeOnboarding,
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  color: const Color.fromRGBO(30, 30, 30, 1.0),
                                ),
                                children: [
                                  TextSpan(
                                    text: "Skip",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900, // Black weight
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const TextSpan(text: ", I'm on Brooder's Built-in Wi-Fi"),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFCA28),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Indicator Dot Widget
  AnimatedContainer buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 5),
      height: 4,
      width: _currentPage == index ? 24 : 16,
      decoration: BoxDecoration(
        color: _currentPage == index 
            ? const Color(0xFFFFCA28) 
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}