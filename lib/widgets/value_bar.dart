import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A horizontal bar whose filled portion shows [text] inside it.
///
/// The fill is never allowed to be narrower than its own label: a small value
/// (e.g. 3% on a 300px track) used to produce a ~9px fill with the label
/// spilling out of it. The fill now grows to at least the width the label
/// needs (capped at the track), and a zero / empty fill shows the label on
/// the track instead so it is always readable and never leaves its box.
class ValueBar extends StatelessWidget {
  /// 0..1 share of the track to fill.
  final double fraction;
  final Color color;
  final String text;
  final Color textColor;
  final double height;
  final double fontSize;
  final double radius;

  /// Optional overlay drawn on top of the track (e.g. tier key dots). Receives
  /// the track width.
  final Widget Function(double trackWidth)? overlay;

  const ValueBar({
    super.key,
    required this.fraction,
    required this.color,
    required this.text,
    this.textColor = Colors.white,
    this.height = 26,
    this.fontSize = 13,
    this.radius = 8,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        final track = constraints.maxWidth;
        final frac = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
        // Rough label width: bold digits/letters ≈ 0.62em, plus side padding.
        final need = text.length * fontSize * 0.62 + 20;
        final double fill;
        if (frac <= 0) {
          fill = 0;
        } else {
          final wanted = track * frac;
          fill = (wanted < need ? need : wanted).clamp(0.0, track);
        }
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.colBorder,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            if (fill > 0)
              SizedBox(
                width: fill,
                height: height,
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: Text(
                    text,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: textColor),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppColors.colMuted),
                    ),
                  ),
                ),
              ),
            if (overlay != null) overlay!(track),
          ],
        );
      }),
    );
  }
}
