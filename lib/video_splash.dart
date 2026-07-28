// video_splash_screen.dart
//
// Plays a video as the app's splash screen, then navigates to your home page.
// Your video (10s, 1280x720, h264/aac) is at: assets/videos/splash.mp4
//
// SETUP:
// 1) Add the video_player package:
//      flutter pub add video_player
//
// 2) Add the asset to pubspec.yaml:
//      flutter:
//        assets:
//          - assets/videos/splash.mp4
//
// 3) Put splash.mp4 in <project_root>/assets/videos/
//
// 4) Use VideoSplashScreen as your app's home in MaterialApp, e.g.:
//      MaterialApp(home: VideoSplashScreen(nextScreen: const HomePage()))

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final String assetPath;

  const VideoSplashScreen({
    super.key,
    required this.nextScreen,
    this.assetPath = 'assets/videos/splash.mp4',
  });

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..setVolume(0) // splash plays silently, no audio
      ..initialize().then((_) {
        setState(() {}); // refresh once the first frame is ready
        _controller.play();
      });

    // Listen for playback completion to auto-navigate.
    _controller.addListener(_checkVideoEnd);

    // Safety fallback: never get stuck on splash longer than 12s
    // even if the video fails to load or play.
    Future.delayed(const Duration(seconds: 12), _goNext);
  }

  void _checkVideoEnd() {
    final value = _controller.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration &&
        value.duration > Duration.zero) {
      _goNext();
    }
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.nextScreen),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_checkVideoEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                // Video is now 1080x1920 (portrait), matching typical phone
                // screens, so BoxFit.contain shows it in full with no crop/zoom.
                // The video's own black background blends with any minor bars.
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }
}