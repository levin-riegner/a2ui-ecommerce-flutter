import 'package:flutter/widgets.dart';

/// Measurements shared by the host layout and its catalog components.
/// Source: Figma Designs section 205:7995, landscape and portrait picks.
abstract final class StylistLayout {
  static const gutter = 32.0;
  static const compactGutter = 16.0;
  static const startContentMaxWidth = 400.0;
  static const composerBottomClearance = 32.0;
  static const sectionGap = 16.0;
  static const itemGap = 8.0;
  static const roomGutter = 24.0;
  static const productImage = 104.0;
  static const pieceImage = 168.0;
}

/// Screen captions use the Designs page's Jost treatment; standalone catalog
/// examples retain their component-specific typography.
class StylistSurfaceScope extends InheritedWidget {
  const StylistSurfaceScope({
    super.key,
    required super.child,
    this.enqueueMessages = false,
    this.textAlreadyVisible = false,
  });

  final bool enqueueMessages;
  final bool textAlreadyVisible;

  static bool textAlreadyVisibleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StylistSurfaceScope>()
          ?.textAlreadyVisible ??
      false;

  static bool enqueueMessagesOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StylistSurfaceScope>()
          ?.enqueueMessages ??
      false;

  static bool isJourneyOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StylistSurfaceScope>() != null;

  @override
  bool updateShouldNotify(StylistSurfaceScope oldWidget) =>
      enqueueMessages != oldWidget.enqueueMessages ||
      textAlreadyVisible != oldWidget.textAlreadyVisible;
}

/// Utility entry points belong in the host menu, outside conversation replies.
bool isStylistUtilityComponent(String id) =>
    id == 'edit-preferences' ||
    id == 'local-library' ||
    id == 'compare-options' ||
    id == 'saved-looks-button' ||
    id == 'bag-button' ||
    id.startsWith('details-');
