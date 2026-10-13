import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../catalog/finalized_left_components.dart';
import '../input/speech_dictation.dart';

/// Shared text and dictation input. The host keeps ownership of the draft.
class StylistComposer extends StatefulWidget {
  const StylistComposer({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.enabled = true,
    this.fieldKey,
    this.fieldLabel = 'Message your stylist',
    this.submitLabel = 'Send',
    this.padding = EdgeInsets.zero,
    this.dictation,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool enabled;
  final Key? fieldKey;
  final String fieldLabel;
  final String submitLabel;
  final EdgeInsets padding;
  final SpeechDictation? dictation;

  @override
  State<StylistComposer> createState() => _StylistComposerState();
}

class _StylistComposerState extends State<StylistComposer>
    with WidgetsBindingObserver {
  SpeechDictation get dictation => widget.dictation ?? SpeechDictation.shared;
  bool _writingTranscript = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dictation.addListener(_changed);
    widget.controller.addListener(_draftChanged);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _draftChanged() {
    // A manual edit takes precedence over any recognizer result still in flight.
    if (!_writingTranscript) unawaited(dictation.cancel(this));
  }

  @override
  void didUpdateWidget(StylistComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.dictation ?? SpeechDictation.shared;
    if (previous != dictation) {
      previous.removeListener(_changed);
      unawaited(previous.cancel(this));
      dictation.addListener(_changed);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_draftChanged);
      widget.controller.addListener(_draftChanged);
      unawaited(dictation.cancel(this));
    }
    if (!widget.enabled) unawaited(dictation.cancel(this));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS permission prompts briefly make the app inactive during startup.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        (state == AppLifecycleState.inactive &&
            dictation.phase != DictationPhase.starting)) {
      unawaited(dictation.cancel(this));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_draftChanged);
    dictation.removeListener(_changed);
    unawaited(dictation.cancel(this));
    super.dispose();
  }

  void _microphone() {
    if (!widget.enabled) return;
    if (dictation.owns(this)) {
      if (dictation.phase == DictationPhase.listening) {
        unawaited(dictation.stop(this));
      } else {
        unawaited(dictation.cancel(this));
      }
      return;
    }
    // Capture the insertion point before dismissing the keyboard.
    final draft = widget.controller.value;
    final selection = draft.selection.isValid
        ? draft.selection
        : TextSelection.collapsed(offset: draft.text.length);
    final prefix = draft.text.substring(0, selection.start);
    final suffix = draft.text.substring(selection.end);
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      dictation.start(
        this,
        onWords: (words) {
          if (!mounted || !widget.enabled || words.trim().isEmpty) return;
          final transcript = words.trim();
          final before = prefix.isNotEmpty && !RegExp(r'\s$').hasMatch(prefix)
              ? '$prefix '
              : prefix;
          final after =
              suffix.isNotEmpty && !RegExp(r'^\s|^[,.!?;:]').hasMatch(suffix)
              ? ' $suffix'
              : suffix;
          _writingTranscript = true;
          try {
            widget.controller.value = TextEditingValue(
              text: '$before$transcript$after',
              selection: TextSelection.collapsed(
                offset: before.length + transcript.length,
              ),
            );
          } finally {
            _writingTranscript = false;
          }
        },
        onError: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = dictation.owns(this);
    return Padding(
      padding: widget.padding,
      child: Semantics(
        liveRegion: active,
        label: active ? 'Dictation active' : null,
        child: FinalizedChatInput(
          externalController: widget.controller,
          enabled: widget.enabled,
          fieldKey: widget.fieldKey,
          fieldLabel: widget.fieldLabel,
          submitLabel: widget.submitLabel,
          onMicrophone: _microphone,
          isDictating: active,
          microphoneLabel: active
              ? dictation.phase == DictationPhase.listening
                    ? 'Stop dictation'
                    : 'Cancel dictation'
              : 'Dictate message',
          onEditing: () => unawaited(dictation.cancel(this)),
          onSend: (text) {
            unawaited(dictation.cancel(this));
            widget.onSubmitted(text);
          },
        ),
      ),
    );
  }
}

/// Fades the fixed header/footer into scrolling content while keeping controls
/// sharp. srcOver keeps the underlying display intact at the transparent edge.
class StylistGlassBackdrop extends StatelessWidget {
  const StylistGlassBackdrop({super.key, this.fadeTowardsBottom = false});
  final bool fadeTowardsBottom;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: 12,
        sigmaY: 12,
        tileMode: TileMode.decal,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Keep white RGB at zero alpha so interpolation cannot darken the
            // transparent edge on the native renderer.
            colors: fadeTowardsBottom
                ? [
                    Colors.white.withValues(alpha: .95),
                    Colors.white.withValues(alpha: .82),
                    Colors.white.withValues(alpha: 0),
                  ]
                : [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: .82),
                    Colors.white.withValues(alpha: .95),
                  ],
            stops: fadeTowardsBottom ? [0, .6, 1] : [0, .4, 1],
          ),
        ),
      ),
    ),
  );
}

/// A fading glass backdrop for the composer where content scrolls underneath.
/// Safe-area insets belong to AdaptivePaneLayout; this adds only a small gap.
class StylistComposerDock extends StatelessWidget {
  const StylistComposerDock({
    super.key,
    required this.child,
    this.horizontalPadding = 16,
    this.padding,
  });
  final Widget child;
  final double horizontalPadding;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: IgnorePointer(child: StylistGlassBackdrop())),
      Padding(
        padding:
            padding ??
            EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 8),
        child: child,
      ),
    ],
  );
}
