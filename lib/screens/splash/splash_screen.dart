import 'package:flutter/material.dart';

/// Background color used by the splash screen (CSS "MediumSlateBlue").
const kSplashBackgroundColor = Color(0xFF7B68EE);

/// Splash screen shown on app start:
/// - Solid [kSplashBackgroundColor] background.
/// - App logo fades in at the center.
/// - After the fade completes (+ a short hold), replaces itself with
///   [nextScreenBuilder]'s screen (normally the auth/root router).
class SplashScreen extends StatefulWidget {
  final WidgetBuilder nextScreenBuilder;
  final Duration fadeDuration;
  final Duration holdDuration;

  const SplashScreen({
    super.key,
    required this.nextScreenBuilder,
    this.fadeDuration = const Duration(milliseconds: 1200),
    this.holdDuration = const Duration(milliseconds: 500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.fadeDuration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(widget.fadeDuration + widget.holdDuration);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.nextScreenBuilder),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSplashBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Image.asset(
            'assets/logo.png',
            width: 160,
            height: 160,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.icecream,
              size: 120,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
