import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Wraps a stat so that PRESSING AND HOLDING it shows the stat's
/// explanation, and releasing dismisses it. Replaces the old "i" buttons.
///
/// * Uses Flutter's built-in long-press recognizer, which handles both a
///   held mouse button (desktop / web) and a held touch (iPhone / Android).
/// * Only long-press callbacks are registered, so normal taps still reach
///   whatever the child (or an ancestor) does with them, and vertical /
///   horizontal drags still scroll. Moving past the touch slop before the
///   hold completes cancels the gesture, so scrolling is never blocked.
/// * The popup is drawn in the app [Overlay] inside an [IgnorePointer], and
///   is clamped to the visible area (safe-area aware) so it can never run
///   off the edge of a phone or create horizontal overflow. It opens above
///   the stat when there is room, otherwise below.
///
/// When [description] is null the child is returned untouched.
class StatHoldInfo extends StatefulWidget {
  final String title;
  final String? description;
  final Widget child;

  const StatHoldInfo({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  State<StatHoldInfo> createState() => _StatHoldInfoState();
}

class _StatHoldInfoState extends State<StatHoldInfo> {
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null || widget.description == null) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Target rectangle in the overlay's (global) coordinate space.
    final topLeft = box.localToGlobal(Offset.zero);
    final target = topLeft & box.size;
    final media = MediaQuery.of(context);
    final title = widget.title;
    final description = widget.description!;

    HapticFeedback.selectionClick();
    _entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: SizedBox.expand(
          child: _StatInfoPopup(
            target: target,
            media: media,
            title: title,
            description: description,
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.description == null) return widget.child;
    return MouseRegion(
      // Subtle desktop hint that the stat can be held for an explanation.
      cursor: SystemMouseCursors.help,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (_) => _show(),
        onLongPressEnd: (_) => _hide(),
        onLongPressCancel: _hide,
        child: widget.child,
      ),
    );
  }
}

class _StatInfoPopup extends StatelessWidget {
  final Rect target;
  final MediaQueryData media;
  final String title;
  final String description;

  const _StatInfoPopup({
    required this.target,
    required this.media,
    required this.title,
    required this.description,
  });

  static const double _margin = 12;
  static const double _gap = 8;
  static const double _maxWidth = 320;

  @override
  Widget build(BuildContext context) {
    final safe = media.padding;
    final availW = media.size.width - safe.left - safe.right - _margin * 2;
    final width = availW < _maxWidth ? availW : _maxWidth;

    return CustomSingleChildLayout(
        delegate: _PopupLayout(
          target: target,
          safe: safe,
          size: media.size,
          margin: _margin,
          gap: _gap,
        ),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: (media.size.height - safe.top - safe.bottom) * 0.5,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blueMid.withOpacity(0.5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blueDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.colText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}

/// Centers the popup on the stat horizontally, then clamps it inside the
/// visible (safe) area. Prefers sitting above the stat; flips below when
/// there isn't room, and as a last resort is pinned inside the screen.
class _PopupLayout extends SingleChildLayoutDelegate {
  final Rect target;
  final EdgeInsets safe;
  final Size size;
  final double margin;
  final double gap;

  _PopupLayout({
    required this.target,
    required this.safe,
    required this.size,
    required this.margin,
    required this.gap,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(size);

  @override
  Offset getPositionForChild(Size _, Size child) {
    final minX = safe.left + margin;
    final maxX = size.width - safe.right - margin - child.width;
    var x = target.center.dx - child.width / 2;
    x = maxX < minX ? minX : x.clamp(minX, maxX).toDouble();

    final minY = safe.top + margin;
    final maxY = size.height - safe.bottom - margin - child.height;

    final above = target.top - gap - child.height;
    final below = target.bottom + gap;
    double y;
    if (above >= minY) {
      y = above;
    } else if (below <= maxY) {
      y = below;
    } else {
      // Neither fits cleanly (very tall stat / small window): keep it on
      // screen, on whichever side has more room.
      final roomAbove = target.top - minY;
      final roomBelow = maxY + child.height - target.bottom;
      y = roomBelow > roomAbove ? maxY : minY;
    }
    y = maxY < minY ? minY : y.clamp(minY, maxY).toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopupLayout old) =>
      old.target != target || old.safe != safe || old.size != size;
}
