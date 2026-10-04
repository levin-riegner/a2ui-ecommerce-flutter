import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foldable/foldable.dart';

/// Apple hardware signals stay local to our layouts: dialogs keep their normal
/// Material sizing, and the navigator is never replaced when the device folds.
class DuoLayoutAdapter extends StatefulWidget {
  const DuoLayoutAdapter({super.key, required this.child, this.platform});

  final Widget child;
  final FoldablePlatform? platform;

  @override
  State<DuoLayoutAdapter> createState() => _DuoLayoutAdapterState();
}

class _DuoLayoutAdapterState extends State<DuoLayoutAdapter>
    with WidgetsBindingObserver {
  FoldableData _data = FoldableData.unsupported;
  StreamSubscription<FoldableData>? _events;
  FoldablePlatform? _replacementPlatform;
  bool _eventsCompleted = false;
  int _generation = 0;
  int _revision = 0;
  int _request = 0;

  FoldablePlatform get _platform =>
      _replacementPlatform ?? widget.platform ?? FoldablePlatform.instance;
  bool get _enabled =>
      widget.platform != null ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    final generation = ++_generation;
    if (!_enabled) return;
    _listen(generation);
    await _refresh();
  }

  void _listen(int generation) {
    if (!_enabled || _events != null) return;
    try {
      _events = _platform.events.listen(
        (next) {
          if (generation == _generation) _apply(next);
        },
        onError: (Object error, StackTrace stack) {
          if (!mounted || generation != _generation) return;
          _apply(FoldableData.unsupported);
        },
        onDone: () {
          if (generation == _generation) {
            _events = null;
            _eventsCompleted = true;
          }
        },
      );
    } catch (_) {
      _apply(FoldableData.unsupported);
    }
  }

  Future<void> _restartEvents() async {
    final generation = ++_generation;
    final previous = _events;
    _events = null;
    await previous?.cancel();
    if (!mounted || generation != _generation) return;
    if (_eventsCompleted && _platform is MethodChannelFoldable) {
      // The pinned plugin caches a stream that closes after an unsupported
      // snapshot, including transient startup failures. Recreate it locally;
      // never reset the singleton or other consumers' subscriptions.
      _replacementPlatform = MethodChannelFoldable();
    }
    _eventsCompleted = false;
    _listen(generation);
    await _refresh();
  }

  Future<void> _refresh() async {
    if (!_enabled) return;
    final generation = _generation;
    final revision = _revision;
    final request = ++_request;
    FoldableData next;
    try {
      next = await _platform.getSnapshot();
    } catch (_) {
      next = FoldableData.unsupported;
    }
    if (mounted &&
        generation == _generation &&
        revision == _revision &&
        request == _request) {
      _apply(next);
    }
  }

  void _apply(FoldableData next) {
    if (!mounted) return;
    _revision++;
    setState(() => _data = next);
  }

  @override
  void didChangeMetrics() =>
      unawaited(_eventsCompleted ? _restartEvents() : _refresh());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The plugin can absorb a native activation error while leaving its
      // Dart stream open. A new subscription retries that channel on resume.
      unawaited(_restartEvents());
    }
  }

  @override
  void didUpdateWidget(DuoLayoutAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.platform != oldWidget.platform) {
      unawaited(_events?.cancel());
      _events = null;
      _replacementPlatform = null;
      _eventsCompleted = false;
      _data = FoldableData.unsupported;
      unawaited(_start());
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      DuoLayoutScope(data: _data, child: widget.child);
}

class DuoLayoutScope extends InheritedWidget {
  const DuoLayoutScope({super.key, required this.data, required super.child});

  final FoldableData data;

  static FoldableData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuoLayoutScope>()?.data ??
      FoldableData.unsupported;

  /// Reserved regions are in logical viewport coordinates. Only our page and
  /// pane layouts consume these features; no global MediaQuery override.
  static MediaQueryData mediaForLayout(
    BuildContext context, {
    Size? viewportSize,
  }) {
    final media = MediaQuery.of(context);
    final size = viewportSize ?? media.size;
    final data = of(context);
    final regions = data.regions.where((region) {
      final bounds = region.bounds;
      return !bounds.isEmpty &&
          bounds.left.isFinite &&
          bounds.top.isFinite &&
          bounds.right.isFinite &&
          bounds.bottom.isFinite;
    }).toList();
    final features = media.displayFeatures.isNotEmpty
        ? media.displayFeatures
        : DisplayFeatureBridge.build(
            mode: DisplayFeatureBridgeMode.full,
            regions: regions,
            status: data.status,
          );
    var padding = media.padding;
    // An interior camera island does not split Flutter sub-screens. Reserve
    // its nearest edge strip so controls and scrolling content cannot hit it.
    for (final feature in features) {
      if (feature.type != DisplayFeatureType.cutout) continue;
      final bounds = feature.bounds.intersect(Offset.zero & size);
      if (bounds.isEmpty) continue;
      final distances = [
        bounds.right,
        bounds.bottom,
        size.width - bounds.left,
        size.height - bounds.top,
      ];
      final edge = distances.indexOf(distances.reduce(math.min));
      padding = EdgeInsets.fromLTRB(
        edge == 0 ? math.max(padding.left, bounds.right) : padding.left,
        edge == 1 ? math.max(padding.top, bounds.bottom) : padding.top,
        edge == 2
            ? math.max(padding.right, size.width - bounds.left)
            : padding.right,
        edge == 3
            ? math.max(padding.bottom, size.height - bounds.top)
            : padding.bottom,
      );
    }
    return media.copyWith(displayFeatures: features, padding: padding);
  }

  @override
  bool updateShouldNotify(DuoLayoutScope oldWidget) => data != oldWidget.data;
}
