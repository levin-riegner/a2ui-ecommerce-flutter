import 'package:flutter/material.dart';

import '../catalog/finalized_left_components.dart';

/// The shared docked input for a new occasion and an ongoing stylist thread.
/// Its controller belongs to the screen so a layout change keeps the draft.
class StylistComposer extends StatelessWidget {
  const StylistComposer({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.enabled = true,
    this.fieldKey,
    this.fieldLabel = 'Message your stylist',
    this.submitLabel = 'Send',
    this.padding = EdgeInsets.zero,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool enabled;
  final Key? fieldKey;
  final String fieldLabel;
  final String submitLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: FinalizedChatInput(
      externalController: controller,
      enabled: enabled,
      fieldKey: fieldKey,
      fieldLabel: fieldLabel,
      submitLabel: submitLabel,
      onSend: onSubmitted,
    ),
  );
}
