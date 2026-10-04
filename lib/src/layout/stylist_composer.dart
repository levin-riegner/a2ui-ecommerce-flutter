import 'package:flutter/material.dart';

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
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final canSubmit = enabled && value.text.trim().isNotEmpty;
      void submit() {
        if (canSubmit) onSubmitted(controller.text.trim());
      }

      return Padding(
        padding: padding,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xfff4f4f5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: fieldLabel,
                    child: TextField(
                      key: fieldKey,
                      controller: controller,
                      enabled: enabled,
                      onSubmitted: (_) => submit(),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Tell me about the occasion…',
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                // Keep the Figma 36 px circle inside a 48 px touch target.
                IconButton(
                  key: ValueKey('stylist-submit-$submitLabel'),
                  onPressed: canSubmit ? submit : null,
                  tooltip: submitLabel,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  padding: const EdgeInsets.all(6),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: canSubmit ? Colors.black : const Color(0xffe4e4e7),
                    ),
                    child: Icon(
                      Icons.arrow_upward,
                      size: 22,
                      color: canSubmit ? Colors.white : const Color(0xffa1a1aa),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
