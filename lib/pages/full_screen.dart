import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FullScreenVideoPage extends StatelessWidget {
  final RTCVideoRenderer renderer;

  const FullScreenVideoPage({super.key, required this.renderer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Transparent AppBar to show the back button over the video
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // extendBodyBehindAppBar allows the video to fill the top status bar area
      extendBodyBehindAppBar: true, 
      body: Center(
        child: RTCVideoView(
          renderer,
          // Use 'contain' for full screen so the whole video is visible without cropping
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain, 
          mirror: false,
        ),
      ),
    );
  }
}