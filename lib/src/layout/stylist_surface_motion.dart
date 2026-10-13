import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

/// Reveals a new surface when GenUI has a renderable root. The Surface and its
/// bound controls retain their identity through later component/data updates.
class StylistSurfaceMotion extends StatefulWidget {
  const StylistSurfaceMotion({
    super.key,
    required this.surfaceContext,
    required this.child,
    this.enabled = true,
  });
  static const duration = Duration(milliseconds: 160);
  final SurfaceContext surfaceContext;
  final Widget child;
  final bool enabled;

  @override
  State<StylistSurfaceMotion> createState() => _StylistSurfaceMotionState();
}

class _StylistSurfaceMotionState extends State<StylistSurfaceMotion>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: StylistSurfaceMotion.duration,
    value:
        widget.enabled &&
            widget.surfaceContext.definition.value?.components.containsKey(
                  'root',
                ) ==
                true
        ? 0
        : 1,
  );
  Object? _lastDefinition;

  @override
  void initState() {
    super.initState();
    widget.surfaceContext.definition.addListener(_definitionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _definitionChanged();
    });
  }

  void _definitionChanged() {
    final definition = widget.surfaceContext.definition.value;
    if (!mounted ||
        identical(definition, _lastDefinition) ||
        definition?.components.containsKey('root') != true) {
      return;
    }
    final first = _lastDefinition == null;
    _lastDefinition = definition;
    if (widget.enabled && !MediaQuery.disableAnimationsOf(context)) {
      _reveal.forward(from: first ? 0 : .4);
    }
  }

  @override
  void didUpdateWidget(StylistSurfaceMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surfaceContext != widget.surfaceContext) {
      oldWidget.surfaceContext.definition.removeListener(_definitionChanged);
      widget.surfaceContext.definition.addListener(_definitionChanged);
      _lastDefinition = null;
      _definitionChanged();
    }
  }

  @override
  void dispose() {
    widget.surfaceContext.definition.removeListener(_definitionChanged);
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _reveal,
      child: widget.child,
      builder: (_, child) {
        final value = animate
            ? Curves.easeOutCubic.transform(_reveal.value)
            : 1.0;
        return Opacity(
          opacity: .75 + .25 * value,
          child: Transform.translate(
            offset: Offset(0, 4 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}
