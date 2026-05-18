import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double scaleTo;
  final bool glass;

  const PressableButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color = AppTheme.accent,
    this.borderRadius = const BorderRadius.all(Radius.circular(100)),
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    this.scaleTo = 0.96,
    this.glass = false,
  });

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleTo).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    HapticFeedback.lightImpact();
    _ctrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: widget.onPressed != null ? _onTapUp : null,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: widget.glass ? _darkPillBody() : _solidBody(),
      ),
    );
  }

  Widget _solidBody() {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );
  }

  /// Primary dark pill button — matches the editorial dark button style
  /// from the warm minimal design reference.
  Widget _darkPillBody() {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: AppTheme.textPrimary,
        borderRadius: widget.borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: widget.child,
        ),
      ),
    );
  }
}
