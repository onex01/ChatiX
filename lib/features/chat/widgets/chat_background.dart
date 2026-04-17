import 'package:flutter/material.dart';
import 'dart:math' as math;

class ChatBackground extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final String? wallpaperUrl;
  final bool enableEffects;

  const ChatBackground({
    super.key,
    required this.child,
    required this.backgroundColor,
    this.wallpaperUrl,
    this.enableEffects = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Фоновый слой
        if (wallpaperUrl != null && wallpaperUrl!.isNotEmpty)
          Image.network(
            wallpaperUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        else if (enableEffects)
          const _ProceduralGradientBackground()
        else
          Container(color: backgroundColor),
        // Контент поверх фона
        child,
      ],
    );
  }
}

class _ProceduralGradientBackground extends StatefulWidget {
  const _ProceduralGradientBackground();

  @override
  State<_ProceduralGradientBackground> createState() => _ProceduralGradientBackgroundState();
}

class _ProceduralGradientBackgroundState extends State<_ProceduralGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(math.sin(t) * 0.5, math.cos(t * 0.7) * 0.3),
              radius: 1.5,
              colors: const [
                Color(0xFF1a1a2e),
                Color(0xFF16213e),
                Color(0xFF0f3460),
                Color(0xFFe94560),
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }
}