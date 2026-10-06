import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'duo_layout_adapter.dart';

/// A screen-sized conversation/content layout with independently scrolling
/// panes on wide windows and one ordered scroll on compact windows.
///
/// The secondary pane comes first in compact mode. Header and footer stay
/// reachable, and keyed children retain their state when the window changes.
/// Display features use viewport coordinates, so place this directly in a
/// Scaffold body rather than inside an already inset or centered container.
class AdaptivePaneLayout extends StatefulWidget {
  static const transitionDuration = Duration(milliseconds: 320);
  const AdaptivePaneLayout({
    super.key,
    required this.primary,
    required this.secondary,
    required this.header,
    required this.footer,
    this.rail,
    this.minPrimaryWidth = 360,
    this.minSecondaryWidth = 320,
    this.maxWidth = 1200,
    this.railWidth = 60,
    this.railMinWidth = 900,
    this.panePadding = const EdgeInsets.all(16),
    this.secondaryPadding,
    this.secondaryBackgroundColor,
    this.secondaryBackgroundOnlyInBookMode = false,
    this.secondaryScrollable = true,
    this.compactSecondaryFirst = true,
    this.overlayFooter = false,
  });

  /// Pane contents should not introduce their own vertical scroll view.
  final Widget primary;
  final Widget secondary;
  final Widget header;
  final Widget footer;
  final Widget? rail;
  final double minPrimaryWidth;
  final double minSecondaryWidth;
  final double maxWidth;
  final double railWidth;
  final double railMinWidth;
  final EdgeInsets panePadding;
  final EdgeInsets? secondaryPadding;

  /// Paints the split pane through safe-area margins without moving controls
  /// into hardware-reserved regions. Compact layouts keep the page background.
  final Color? secondaryBackgroundColor;

  /// Leaves split-pane margins in the page color when Duo is fully open.
  final bool secondaryBackgroundOnlyInBookMode;
  final bool secondaryScrollable;
  final bool compactSecondaryFirst;

  /// Scrolls content behind a translucent footer, reserving its measured height
  /// at the end of the scroll so the final controls remain reachable.
  final bool overlayFooter;

  @override
  State<AdaptivePaneLayout> createState() => _AdaptivePaneLayoutState();
}

class _AdaptivePaneLayoutState extends State<AdaptivePaneLayout> {
  final _primaryKey = GlobalKey();
  final _secondaryKey = GlobalKey();
  final _headerKey = GlobalKey();
  final _footerKey = GlobalKey();
  final _canvasKey = GlobalKey();
  final _compactScroll = ScrollController();
  final _primaryScroll = ScrollController();
  final _secondaryScroll = ScrollController();
  double _footerHeight = 84;
  bool _footerMeasurementPending = false;

  @override
  void dispose() {
    _compactScroll.dispose();
    _primaryScroll.dispose();
    _secondaryScroll.dispose();
    super.dispose();
  }

  Widget _primary() => KeyedSubtree(key: _primaryKey, child: widget.primary);
  Widget _secondary() =>
      KeyedSubtree(key: _secondaryKey, child: widget.secondary);
  Widget _header() => KeyedSubtree(key: _headerKey, child: widget.header);
  Widget _footer() {
    final footer = KeyedSubtree(key: _footerKey, child: widget.footer);
    if (!widget.overlayFooter) return footer;
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _measureFooter();
        return true;
      },
      child: SizeChangedLayoutNotifier(child: footer),
    );
  }

  void _measureFooter() {
    if (_footerMeasurementPending) return;
    _footerMeasurementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _footerMeasurementPending = false;
      if (!mounted || !widget.overlayFooter) return;
      final box = _footerKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.size.height != _footerHeight) {
        setState(() => _footerHeight = box.size.height);
      }
    });
  }

  Widget _background(double left) => Positioned(
    left: left,
    top: 0,
    right: 0,
    bottom: 0,
    child: Builder(
      builder: (context) => ColoredBox(
        key: const ValueKey('secondary-pane-background'),
        color: AdaptivePaneScope.secondaryBackgroundColorOf(context)!,
      ),
    ),
  );

  Widget _canvas({required bool split, required List<Widget> children}) {
    final canvas = Stack(children: children);
    if (widget.secondaryBackgroundColor == null) return canvas;
    final useSecondaryColor =
        split &&
        (!widget.secondaryBackgroundOnlyInBookMode ||
            DuoLayoutScope.of(context).isPartiallyOpen);
    final color = useSecondaryColor
        ? widget.secondaryBackgroundColor!
        : Theme.of(context).scaffoldBackgroundColor;
    // Keep the tween's identity while the panes move between flat and
    // hinge-separated parents, so a fold event cannot restart the fade.
    return TweenAnimationBuilder<Color?>(
      key: _canvasKey,
      tween: ColorTween(end: color),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AdaptivePaneLayout.transitionDuration,
      curve: Curves.easeInOutCubic,
      child: canvas,
      builder: (context, animatedColor, child) => AdaptivePaneScope(
        isSplit: split,
        secondaryBackgroundColor: animatedColor,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: (split ? animatedColor! : color).computeLuminance() < .5
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: child!,
        ),
      ),
    );
  }

  Widget _pane(Widget Function(EdgeInsets padding) scroll) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(),
      Expanded(
        child: widget.overlayFooter
            ? Stack(
                fit: StackFit.expand,
                children: [
                  scroll(
                    widget.panePadding.copyWith(
                      bottom: widget.panePadding.bottom + _footerHeight,
                    ),
                  ),
                  Align(alignment: Alignment.bottomCenter, child: _footer()),
                ],
              )
            : scroll(widget.panePadding),
      ),
      if (!widget.overlayFooter) _footer(),
    ],
  );

  Widget _primaryPane() => _pane(
    (padding) => SingleChildScrollView(
      key: const ValueKey('primary-pane-scroll'),
      controller: _primaryScroll,
      padding: padding,
      child: _primary(),
    ),
  );

  Widget _secondaryPane({required bool showRail}) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: widget.secondaryScrollable
            ? SingleChildScrollView(
                key: const ValueKey('secondary-pane-scroll'),
                controller: _secondaryScroll,
                padding: widget.secondaryPadding ?? widget.panePadding,
                child: _secondary(),
              )
            : Padding(
                padding: widget.secondaryPadding ?? widget.panePadding,
                child: _secondary(),
              ),
      ),
      if (showRail) SizedBox(width: widget.railWidth, child: widget.rail),
    ],
  );

  Widget _compact() => _pane(
    (padding) => SingleChildScrollView(
      key: const ValueKey('compact-pane-scroll'),
      controller: _compactScroll,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.compactSecondaryFirst
            ? [_secondary(), const SizedBox(height: 24), _primary()]
            : [_primary(), const SizedBox(height: 24), _secondary()],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.overlayFooter) _measureFooter();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final media = DuoLayoutScope.mediaForLayout(
          context,
          viewportSize: size,
        );
        final textScale = math.max(1.0, media.textScaler.scale(14) / 14);
        final minPrimaryWidth = widget.minPrimaryWidth * textScale;
        final minSecondaryWidth = widget.minSecondaryWidth * textScale;
        final safeBounds = Rect.fromLTRB(
          media.padding.left,
          media.padding.top,
          math.max(media.padding.left, size.width - media.padding.right),
          math.max(media.padding.top, size.height - media.padding.bottom),
        );
        final regions =
            DisplayFeatureSubScreen.subScreensInBounds(
                  safeBounds,
                  DisplayFeatureSubScreen.avoidBounds(media),
                )
                .map((region) => region.intersect(safeBounds))
                .where((region) => region.width > 0 && region.height > 0)
                .toList()
              ..sort((a, b) => a.left.compareTo(b.left));
        final separatingRegions =
            regions.length == 2 &&
            regions[0].top == regions[1].top &&
            regions[0].bottom == regions[1].bottom &&
            regions[0].width >= minPrimaryWidth &&
            regions[1].width >= minSecondaryWidth;
        if (separatingRegions) {
          return AdaptivePaneScope(
            isSplit: true,
            child: KeyedSubtree(
              key: const ValueKey('obstructed-split-layout'),
              child: _canvas(
                split: true,
                children: [
                  if (widget.secondaryBackgroundColor != null)
                    _background(regions[1].left),
                  Positioned.fromRect(rect: regions[0], child: _primaryPane()),
                  Positioned.fromRect(
                    rect: regions[1],
                    child: _secondaryPane(
                      showRail:
                          widget.rail != null &&
                          size.width >= widget.railMinWidth &&
                          regions[1].width - widget.railWidth >=
                              minSecondaryWidth,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // An unusably narrow side or a horizontal fold gets one unobstructed
        // region. This keeps every control reachable without crossing a hinge.
        final usable = regions.isEmpty
            ? safeBounds
            : regions.reduce(
                (a, b) => a.width * a.height >= b.width * b.height ? a : b,
              );
        final width = math.min(usable.width, widget.maxWidth);
        final centered = Rect.fromLTWH(
          usable.left + (usable.width - width) / 2,
          usable.top,
          width,
          usable.height,
        );
        final split = width >= minPrimaryWidth + minSecondaryWidth + 1;
        final showRail =
            split &&
            widget.rail != null &&
            width >= widget.railMinWidth &&
            width - widget.railWidth >= minPrimaryWidth + minSecondaryWidth + 1;
        final primaryWidth =
            minPrimaryWidth +
            math.max(
                  0.0,
                  width -
                      1 -
                      (showRail ? widget.railWidth : 0) -
                      minPrimaryWidth -
                      minSecondaryWidth,
                ) /
                2;
        return AdaptivePaneScope(
          isSplit: split,
          child: _canvas(
            split: split,
            children: [
              if (split && widget.secondaryBackgroundColor != null)
                _background(centered.left + primaryWidth + 1),
              Positioned.fromRect(
                rect: centered,
                child: split
                    ? Row(
                        key: const ValueKey('split-pane-layout'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: primaryWidth, child: _primaryPane()),
                          const VerticalDivider(width: 1),
                          Expanded(child: _secondaryPane(showRail: showRail)),
                        ],
                      )
                    : KeyedSubtree(
                        key: const ValueKey('compact-pane-layout'),
                        child: _compact(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lets reusable pane content select a compact or split visual treatment.
class AdaptivePaneScope extends InheritedWidget {
  const AdaptivePaneScope({
    super.key,
    required this.isSplit,
    this.secondaryBackgroundColor,
    required super.child,
  });

  final bool isSplit;
  final Color? secondaryBackgroundColor;

  static Color? secondaryBackgroundColorOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AdaptivePaneScope>()
      ?.secondaryBackgroundColor;

  static bool isSplitOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AdaptivePaneScope>()
          ?.isSplit ??
      false;

  @override
  bool updateShouldNotify(AdaptivePaneScope oldWidget) =>
      isSplit != oldWidget.isSplit ||
      secondaryBackgroundColor != oldWidget.secondaryBackgroundColor;
}
