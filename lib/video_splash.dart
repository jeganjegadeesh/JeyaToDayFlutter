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
                fit: BoxFit.cover, // 👈 changed from BoxFit.contain
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