import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

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
    this.compactSecondaryPadding,
    this.secondaryBackgroundColor,
    this.secondaryBackgroundOnlyInBookMode = false,
    this.secondaryScrollable = true,
    this.extendSecondaryToEdges = false,
    this.reserveRailInExtendedSecondary = false,
    this.compactPaneGap = 24,
    this.compactSecondaryFirst = true,
    this.showSecondaryInCompact = true,
    this.primaryBottomInset,
    this.extendPrimaryIntoBottomPadding = false,
    this.overlayHeader = false,
    this.overlayFooter = false,
    this.followPrimaryEnd = false,
    this.holdInitialPrimaryBeginning = false,
    this.stackSecondaryInPortrait = false,
    this.portraitHeaderHeight = 56,
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
  final EdgeInsets? compactSecondaryPadding;

  /// Paints the split pane through safe-area margins without moving controls
  /// into hardware-reserved regions. Compact layouts keep the page background.
  final Color? secondaryBackgroundColor;

  /// Leaves split-pane margins in the page color when Duo is fully open.
  final bool secondaryBackgroundOnlyInBookMode;
  final bool secondaryScrollable;

  /// Lets decorative artwork fill the top, bottom, and trailing safe margins
  /// in split layouts. Keep interactive content within the default bounds.
  final bool extendSecondaryToEdges;

  /// Interactive edge-to-edge panes reserve the rail inside their full bounds.
  /// Decorative panes retain their existing safe-area rail policy.
  final bool reserveRailInExtendedSecondary;
  final double compactPaneGap;
  final bool compactSecondaryFirst;
  final bool showSecondaryInCompact;

  /// Optional bottom clearance for primary content. Its horizontal bounds
  /// still respect reserved regions; keyboard and horizontal-fold insets win.
  final double? primaryBottomInset;

  /// Allows an inner-display pane to use ambient bottom padding. Keyboard,
  /// cutout and horizontal-fold bounds still constrain the pane.
  final bool extendPrimaryIntoBottomPadding;

  /// Lets scrolling content pass underneath a translucent fixed header.
  final bool overlayHeader;

  /// Scrolls content behind a translucent footer, reserving its measured height
  /// at the end of the scroll so the final controls remain reachable.
  final bool overlayFooter;

  /// Follows renderer growth only while the person is keeping up with the chat.
  final bool followPrimaryEnd;

  /// Keeps the opening reply at its beginning until the person scrolls or a
  /// later reply arrives. Subsequent reading-position rules remain unchanged.
  final bool holdInitialPrimaryBeginning;
  final bool stackSecondaryInPortrait;
  final double portraitHeaderHeight;

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
  double _headerHeight = 71;
  bool _headerMeasurementPending = false;
  bool _footerMeasurementPending = false;
  bool _followingPrimary = true;
  bool _holdingInitialBeginning = false;
  bool _userScrolling = false;
  bool _followScheduled = false;
  bool _autoScrolling = false;
  int _followRevision = 0;
  double? _followTarget;

  @override
  void initState() {
    super.initState();
    _holdingInitialBeginning = widget.holdInitialPrimaryBeginning;
    _followingPrimary = !_holdingInitialBeginning;
  }

  @override
  void didUpdateWidget(AdaptivePaneLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_holdingInitialBeginning && !widget.holdInitialPrimaryBeginning) {
      _holdingInitialBeginning = false;
      _followingPrimary = true;
      _followEnd(_primaryScroll.hasClients ? _primaryScroll : _compactScroll);
    }
  }

  bool _atEnd(ScrollMetrics metrics) => metrics.extentAfter <= 48;

  bool _trackScroll(ScrollNotification notification) {
    if (!widget.followPrimaryEnd ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is UserScrollNotification) {
      _userScrolling = notification.direction != ScrollDirection.idle;
      if (_userScrolling) {
        _holdingInitialBeginning = false;
        _autoScrolling = false;
        _followRevision++;
      }
      if (notification.direction == ScrollDirection.forward) {
        _followingPrimary = false;
      } else if (notification.direction == ScrollDirection.idle) {
        _followingPrimary = _atEnd(notification.metrics);
      }
    } else if (notification is ScrollUpdateNotification &&
        (_userScrolling ||
            notification.dragDetails != null ||
            !_autoScrolling)) {
      _followingPrimary = _atEnd(notification.metrics);
    }
    return false;
  }

  Widget _followable(ScrollController controller, Widget child) =>
      NotificationListener<ScrollNotification>(
        onNotification: _trackScroll,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) _followEnd(controller);
            return false;
          },
          child: NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              _followEnd(controller);
              return false;
            },
            child: child,
          ),
        ),
      );

  void _followEnd(ScrollController controller) {
    if (!widget.followPrimaryEnd ||
        _holdingInitialBeginning ||
        !_followingPrimary ||
        _followScheduled) {
      return;
    }
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (!mounted || !_followingPrimary || !controller.hasClients) return;
      final position = controller.position;
      if (!position.hasContentDimensions || position.extentAfter <= .5) return;
      if (_autoScrolling && _followTarget == position.maxScrollExtent) return;
      _followTarget = position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _autoScrolling = true;
        position.jumpTo(position.maxScrollExtent);
        _autoScrolling = false;
      } else {
        _autoScrolling = true;
        final revision = ++_followRevision;
        position
            .animateTo(
              position.maxScrollExtent,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() {
              if (mounted && revision == _followRevision) {
                _autoScrolling = false;
              }
            });
      }
    });
  }

  @override
  void dispose() {
    _compactScroll.dispose();
    _primaryScroll.dispose();
    _secondaryScroll.dispose();
    super.dispose();
  }

  Widget _primary() => KeyedSubtree(
    key: _primaryKey,
    child: SizeChangedLayoutNotifier(child: widget.primary),
  );
  Widget _secondary() =>
      KeyedSubtree(key: _secondaryKey, child: widget.secondary);
  Widget _header() {
    final header = KeyedSubtree(key: _headerKey, child: widget.header);
    if (!widget.overlayHeader) return header;
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _measureHeader();
        return true;
      },
      child: SizeChangedLayoutNotifier(child: header),
    );
  }

  void _measureHeader() {
    if (_headerMeasurementPending) return;
    _headerMeasurementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerMeasurementPending = false;
      if (!mounted || !widget.overlayHeader) return;
      final box = _headerKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.size.height != _headerHeight) {
        setState(() => _headerHeight = box.size.height);
      }
    });
  }

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

  Widget _pane(
    Widget Function(EdgeInsets padding) scroll, {
    bool showHeader = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showHeader && !widget.overlayHeader) _header(),
      Expanded(
        child: widget.overlayFooter || (showHeader && widget.overlayHeader)
            ? Stack(
                fit: StackFit.expand,
                children: [
                  scroll(
                    widget.panePadding.copyWith(
                      top:
                          widget.panePadding.top +
                          (showHeader && widget.overlayHeader
                              ? _headerHeight
                              : 0),
                      bottom:
                          widget.panePadding.bottom +
                          (widget.overlayFooter ? _footerHeight : 0),
                    ),
                  ),
                  if (showHeader && widget.overlayHeader)
                    Align(alignment: Alignment.topCenter, child: _header()),
                  if (widget.overlayFooter)
                    Align(alignment: Alignment.bottomCenter, child: _footer()),
                ],
              )
            : scroll(widget.panePadding),
      ),
      if (!widget.overlayFooter) _footer(),
    ],
  );

  Widget _primaryPane({bool showHeader = true}) => _pane(
    (padding) => _followable(
      _primaryScroll,
      SingleChildScrollView(
        key: const ValueKey('primary-pane-scroll'),
        controller: _primaryScroll,
        padding: padding,
        child: _primary(),
      ),
    ),
    showHeader: showHeader,
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

  Rect _secondaryBounds(Rect pane, Size viewport) =>
      widget.extendSecondaryToEdges
      ? Rect.fromLTRB(viewport.width / 2, 0, viewport.width, viewport.height)
      : pane;

  Rect _primaryBounds(Rect pane, Size viewport, MediaQueryData media) {
    if (widget.primaryBottomInset == null ||
        media.viewInsets.bottom > 0 ||
        pane.bottom != viewport.height - media.padding.bottom) {
      return pane;
    }
    final bottomPadding = Rect.fromLTRB(
      pane.left,
      pane.bottom,
      pane.right,
      viewport.height,
    );
    final bottomCutout = media.displayFeatures.any(
      (feature) =>
          feature.type == DisplayFeatureType.cutout &&
          feature.bounds.overlaps(bottomPadding),
    );
    final clearance = widget.extendPrimaryIntoBottomPadding && !bottomCutout
        ? widget.primaryBottomInset!
        : math.max(media.padding.bottom, widget.primaryBottomInset!);
    return Rect.fromLTRB(
      pane.left,
      pane.top,
      pane.right,
      math.max(pane.top, viewport.height - clearance),
    );
  }

  Widget _compact() => _pane(
    (padding) => _followable(
      _compactScroll,
      SingleChildScrollView(
        key: const ValueKey('compact-pane-scroll'),
        controller: _compactScroll,
        padding: padding.copyWith(left: 0, right: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: !widget.showSecondaryInCompact
              ? [_compactPrimary(padding)]
              : widget.compactSecondaryFirst
              ? [
                  _compactSecondary(padding),
                  SizedBox(height: widget.compactPaneGap),
                  _compactPrimary(padding),
                ]
              : [
                  _compactPrimary(padding),
                  SizedBox(height: widget.compactPaneGap),
                  _compactSecondary(padding),
                ],
        ),
      ),
    ),
  );

  Widget _compactPrimary(EdgeInsets padding) => Padding(
    padding: EdgeInsets.only(left: padding.left, right: padding.right),
    child: _primary(),
  );

  Widget _compactSecondary(EdgeInsets padding) => Padding(
    padding: EdgeInsets.only(
      left:
          widget.compactSecondaryPadding?.left ??
          widget.secondaryPadding?.left ??
          padding.left,
      right:
          widget.compactSecondaryPadding?.right ??
          widget.secondaryPadding?.right ??
          padding.right,
    ),
    child: _secondary(),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.overlayHeader) _measureHeader();
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
                    _background(
                      widget.extendSecondaryToEdges
                          ? size.width / 2
                          : regions[1].left,
                    ),
                  Positioned.fromRect(
                    rect: _primaryBounds(regions[0], size, media),
                    child: _primaryPane(),
                  ),
                  Positioned.fromRect(
                    rect: _secondaryBounds(regions[1], size),
                    child: _secondaryPane(
                      showRail:
                          widget.rail != null &&
                          size.width >= widget.railMinWidth &&
                          (widget.reserveRailInExtendedSecondary
                                      ? _secondaryBounds(regions[1], size).width
                                      : regions[1].width) -
                                  widget.railWidth >=
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
        final midpoint = size.width / 2;
        final split =
            width >= minPrimaryWidth + minSecondaryWidth &&
            (!widget.extendSecondaryToEdges ||
                (midpoint - centered.left >= minPrimaryWidth &&
                    centered.right - midpoint >= minSecondaryWidth));
        final duoPortrait =
            DuoLayoutScope.of(context).capabilities.isFoldable &&
            size.height > size.width;
        final horizontalRegions = List<Rect>.of(regions)
          ..sort((a, b) => a.top.compareTo(b.top));
        final horizontalSplit =
            horizontalRegions.length == 2 &&
            horizontalRegions[0].left == horizontalRegions[1].left &&
            horizontalRegions[0].right == horizontalRegions[1].right &&
            horizontalRegions[0].bottom <= horizontalRegions[1].top;
        final portraitBounds = _primaryBounds(
          horizontalSplit ? safeBounds : centered,
          size,
          media,
        );
        final portraitDivision = horizontalSplit
            ? horizontalRegions[0].bottom
            : duoPortrait
            ? size.height / 2
            : (size.height - 64) / 2;
        final conversationTop = horizontalSplit
            ? horizontalRegions[1].top
            : portraitDivision;
        final portraitRoomTop =
            portraitBounds.top + widget.portraitHeaderHeight;
        if (!split &&
            portraitDivision - portraitRoomTop >= (duoPortrait ? 160 : 240) &&
            portraitBounds.bottom - conversationTop >=
                (duoPortrait ? 96 : 240) &&
            widget.stackSecondaryInPortrait &&
            (regions.length == 1 || horizontalSplit) &&
            portraitBounds.width >= (duoPortrait ? 320 : 600) &&
            (duoPortrait || size.height >= 800) &&
            size.height > size.width &&
            (duoPortrait || textScale <= 1.5)) {
          final bounds = portraitBounds;
          final division = portraitDivision;
          final roomTop = portraitRoomTop;
          return AdaptivePaneScope(
            isSplit: false,
            child: KeyedSubtree(
              key: const ValueKey('compact-pane-layout'),
              child: _canvas(
                split: false,
                children: [
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(
                      bounds.left,
                      bounds.top,
                      bounds.width,
                      widget.portraitHeaderHeight,
                    ),
                    child: _header(),
                  ),
                  Positioned.fromRect(
                    key: const ValueKey('portrait-dressing-pane'),
                    rect: Rect.fromLTRB(
                      bounds.left,
                      roomTop,
                      bounds.right,
                      division,
                    ),
                    child: _compactSecondary(widget.panePadding),
                  ),
                  Positioned.fromRect(
                    key: const ValueKey('portrait-conversation-pane'),
                    rect: Rect.fromLTRB(
                      bounds.left,
                      conversationTop,
                      bounds.right,
                      bounds.bottom,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: widget.overlayHeader ? 0 : widget.compactPaneGap,
                      ),
                      child: _primaryPane(showHeader: false),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final showRail =
            split &&
            widget.rail != null &&
            (widget.reserveRailInExtendedSecondary ? size.width : width) >=
                widget.railMinWidth &&
            (widget.reserveRailInExtendedSecondary ? size.width : width) -
                    widget.railWidth >=
                minPrimaryWidth + minSecondaryWidth;
        final primaryWidth =
            minPrimaryWidth +
            math.max(
                  0.0,
                  width -
                      (showRail ? widget.railWidth : 0) -
                      minPrimaryWidth -
                      minSecondaryWidth,
                ) /
                2;
        if (split && widget.extendSecondaryToEdges) {
          // Artwork uses half the full viewport, including the trailing safe
          // margin. Using the safe-area split here would enlarge its share.
          final secondaryLeft = midpoint;
          return AdaptivePaneScope(
            isSplit: true,
            child: KeyedSubtree(
              key: const ValueKey('split-pane-layout'),
              child: _canvas(
                split: true,
                children: [
                  if (widget.secondaryBackgroundColor != null)
                    _background(secondaryLeft),
                  Positioned.fromRect(
                    rect: _primaryBounds(
                      Rect.fromLTWH(
                        centered.left,
                        centered.top,
                        midpoint - centered.left,
                        centered.height,
                      ),
                      size,
                      media,
                    ),
                    child: _primaryPane(),
                  ),
                  Positioned.fromRect(
                    rect: _secondaryBounds(
                      Rect.fromLTRB(
                        secondaryLeft,
                        centered.top,
                        centered.right,
                        centered.bottom,
                      ),
                      size,
                    ),
                    child: _secondaryPane(showRail: showRail),
                  ),
                ],
              ),
            ),
          );
        }
        return AdaptivePaneScope(
          isSplit: split,
          child: _canvas(
            split: split,
            children: [
              if (split && widget.secondaryBackgroundColor != null)
                _background(centered.left + primaryWidth),
              Positioned.fromRect(
                rect: !split ? _primaryBounds(centered, size, media) : centered,
                child: split
                    ? Row(
                        key: const ValueKey('split-pane-layout'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: primaryWidth, child: _primaryPane()),
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
