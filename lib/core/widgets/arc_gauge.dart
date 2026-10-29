import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reusable semicircle arc gauge widget.
/// Used in WiFi Scanner, App Scanner, and Home dashboard.
class ArcGauge extends StatefulWidget {
  /// Value between 0 and [maxValue]
  final double value;
  final double maxValue;

  /// Color of the filled arc
  final Color color;

  /// Background track color
  final Color trackColor;

  /// Widget displayed in the center
  final Widget? centerChild;

  /// Arc thickness
  final double strokeWidth;

  /// Total sweep angle in degrees (default 210 for a nice semicircle)
  final double sweepDegrees;

  /// Animate on first build
  final bool animate;

  const ArcGauge({
    super.key,
    required this.value,
    this.maxValue = 5.0,
    required this.color,
    this.trackColor = const Color(0xFF2A2A2A),
    this.centerChild,
    this.strokeWidth = 18,
    this.sweepDegrees = 210,
    this.animate = true,
  });

  @override
  State<ArcGauge> createState() => _ArcGaugeState();
}

class _ArcGaugeState extends State<ArcGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.animate) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final progress = (_anim.value * widget.value / widget.maxValue).clamp(
          0.0,
          1.0,
        );
        return CustomPaint(
          painter: _ArcPainter(
            progress: progress,
            sweepDegrees: widget.sweepDegrees,
            arcColor: widget.color,
            trackColor: widget.trackColor,
            strokeWidth: widget.strokeWidth,
          ),
          child: widget.centerChild != null
              ? Center(child: widget.centerChild)
              : null,
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final double sweepDegrees;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.sweepDegrees,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth / 2;

    final startAngle = (180 - sweepDegrees) / 2 + 90; // degrees
    final startRad = _toRad(startAngle + 90);
    final sweepRad = _toRad(sweepDegrees);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startRad, sweepRad, false, trackPaint);

    // Filled arc
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startRad, sweepRad * progress, false, arcPaint);
    }
  }

  double _toRad(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}
