import 'package:flutter/material.dart';

/// Paces the top-level sections of a reply. Nested forms and card groups appear
/// together, retaining their controls and bindings through surface updates.
class StylistMessageQueue extends StatefulWidget {
  const StylistMessageQueue({
    super.key,
    required this.children,
    required this.spacing,
    this.enabled = true,
    this.initiallyVisible = const {},
  });

  static const interval = Duration(milliseconds: 1100);
  static const revealDuration = Duration(milliseconds: 320);

  final Map<String, Widget> children;
  final double spacing;
  final bool enabled;
  final Set<String> initiallyVisible;

  @override
  State<StylistMessageQueue> createState() => _StylistMessageQueueState();
}

class _StylistMessageQueueState extends State<StylistMessageQueue>
    with SingleTickerProviderStateMixin {
  final _revealed = <String>{};
  bool _animate = false;
  late final _pacing =
      AnimationController(vsync: this, duration: StylistMessageQueue.interval)
        ..addStatusListener((status) {
          if (status != AnimationStatus.completed || !_hasQueued) return;
          setState(() {
            _revealed.add(
              widget.children.keys.firstWhere((id) => !_revealed.contains(id)),
            );
          });
          _scheduleNext();
        });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(StylistMessageQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    _animate = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    _revealed.retainAll(widget.children.keys);
    _revealed.addAll(
      widget.initiallyVisible.intersection(widget.children.keys.toSet()),
    );
    if (!_animate) {
      _pacing.stop();
      _revealed.addAll(widget.children.keys);
      return;
    }
    if (_revealed.isEmpty && widget.children.isNotEmpty) {
      _revealed.add(widget.children.keys.first);
    }
    _scheduleNext();
  }

  bool get _hasQueued =>
      widget.children.keys.any((id) => !_revealed.contains(id));

  void _scheduleNext() {
    if (!_hasQueued) {
      _pacing.stop();
    } else if (!_pacing.isAnimating) {
      _pacing.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pacing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: widget.spacing,
    children: [
      for (final entry in widget.children.entries)
        if (_revealed.contains(entry.key))
          _MessageReveal(
            key: ValueKey(entry.key),
            animate: _animate && !widget.initiallyVisible.contains(entry.key),
            child: entry.value,
          ),
      if (_hasQueued)
        Semantics(
          label: 'Your stylist is replying',
          child: const ExcludeSemantics(
            child: Text(
              '•••',
              style: TextStyle(color: Colors.grey, letterSpacing: 4),
            ),
          ),
        ),
    ],
  );
}

class _MessageReveal extends StatefulWidget {
  const _MessageReveal({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_MessageReveal> createState() => _MessageRevealState();
}

class _MessageRevealState extends State<_MessageReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: StylistMessageQueue.revealDuration,
    value: widget.animate ? 0 : 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(_MessageReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate) _controller.value = 1;
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _curve,
    alignment: Alignment.topCenter,
    child: FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .04),
          end: Offset.zero,
        ).animate(_curve),
        child: SizedBox(width: double.infinity, child: widget.child),
      ),
    ),
  );
}
