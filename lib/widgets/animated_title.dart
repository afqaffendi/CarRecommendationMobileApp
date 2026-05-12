import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Typewriter effect for screen titles.
/// Reveals text character by character with a blinking rose cursor.
class AnimatedTitle extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration delay;
  final int charDelayMs;

  const AnimatedTitle({
    super.key,
    required this.text,
    this.style,
    this.delay = Duration.zero,
    this.charDelayMs = 38,
  });

  @override
  State<AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<AnimatedTitle> {
  int _chars = 0;
  bool _cursorOn = true;
  Timer? _typeTimer;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, _beginTyping);
  }

  void _beginTyping() {
    if (!mounted) return;

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });

    _typeTimer = Timer.periodic(
      Duration(milliseconds: widget.charDelayMs),
      (t) {
        if (!mounted) { t.cancel(); return; }
        if (_chars < widget.text.length) {
          setState(() => _chars++);
        } else {
          t.cancel();
          // Blink cursor a couple more times then hide
          Future.delayed(const Duration(milliseconds: 900), () {
            _cursorTimer?.cancel();
            if (mounted) setState(() => _cursorOn = false);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(0, _chars);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: visible),
          if (_cursorOn)
            TextSpan(
              text: '|',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w300,
                fontSize: widget.style?.fontSize,
              ),
            ),
        ],
      ),
      style: widget.style,
    );
  }
}

/// Fades in + slides up from below. Use for subtitles that appear after the title.
class AnimatedFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;

  const AnimatedFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.slideOffset = 18,
  });

  @override
  State<AnimatedFadeSlide> createState() => _AnimatedFadeSlideState();
}

class _AnimatedFadeSlideState extends State<AnimatedFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: widget.slideOffset, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
