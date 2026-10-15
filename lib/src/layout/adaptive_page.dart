import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'duo_layout_adapter.dart';

/// A bounded, safe, scrollable frame shared by the landing and catalog pages.
/// On a separating display feature it uses one unobstructed sub-screen.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.child,
    this.maxWidth = 980,
    this.padding = const EdgeInsets.all(28),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = DuoLayoutScope.mediaForLayout(
        context,
        viewportSize: constraints.biggest,
      );
      final safe = Rect.fromLTRB(
        media.padding.left,
        media.padding.top,
        math.max(
          media.padding.left,
          constraints.maxWidth - media.padding.right,
        ),
        math.max(
          media.padding.top,
          constraints.maxHeight - media.padding.bottom,
        ),
      );
      final regions =
          DisplayFeatureSubScreen.subScreensInBounds(
                safe,
                DisplayFeatureSubScreen.avoidBounds(media),
              )
              .map((region) => region.intersect(safe))
              .where((region) => region.width > 0 && region.height > 0)
              .toList();
      final region = regions.isEmpty ? safe : regions.first;
      final bottomMargin = Rect.fromLTRB(
        region.left,
        region.bottom,
        region.right,
        constraints.maxHeight,
      );
      // Ambient bottom clearance belongs inside the scroll content, so it
      // doesn't leave a fixed blank strip over cards as they scroll past.
      final bottomClearance =
          region.bottom == safe.bottom &&
              media.viewInsets.bottom == 0 &&
              !media.displayFeatures.any(
                (feature) => feature.bounds.overlaps(bottomMargin),
              )
          ? constraints.maxHeight - region.bottom
          : 0.0;
      final viewport = Rect.fromLTRB(
        region.left,
        region.top,
        region.right,
        region.bottom + bottomClearance,
      );
      return Stack(
        children: [
          Positioned.fromRect(
            rect: viewport,
            child: Center(
              child: SingleChildScrollView(
                padding: padding + EdgeInsets.only(bottom: bottomClearance),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
