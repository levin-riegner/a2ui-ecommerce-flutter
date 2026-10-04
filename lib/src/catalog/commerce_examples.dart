import 'package:flutter/material.dart';

import '../data/models.dart';
import 'commerce_components.dart';

/// Gallery definitions consume the same presentation widgets as A2UI bindings.
class CommerceComponentExample {
  const CommerceComponentExample({
    required this.name,
    required this.description,
    required this.previewBuilder,
  });

  final String name;
  final String description;
  final WidgetBuilder previewBuilder;
}

final commerceComponentExamples = <CommerceComponentExample>[
  CommerceComponentExample(
    name: 'StylistMessage',
    description:
        'Guidance wraps at the pane width and follows system text size.',
    previewBuilder: (_) => const CommerceStylistMessage(
      text: 'That knit is a good starting point. Let’s find trousers that work for the first day and stay within your remaining budget.',
    ),
  ),
  CommerceComponentExample(
    name: 'Eyebrow',
    description:
        'A shared label for grouping recommendations or outfit pieces.',
    previewBuilder: (_) =>
        const CommerceEyebrow(text: 'YOUR NEXT PIECE · TROUSERS'),
  ),
  CommerceComponentExample(
    name: 'ChoiceChip',
    description:
        'Selected, unselected, and unavailable choices with 48 px targets.',
    previewBuilder: (_) => const _ChoiceExample(group: false),
  ),
  CommerceComponentExample(
    name: 'ChoiceGroup',
    description:
        'One local selection; longer choices wrap inside narrow panes.',
    previewBuilder: (_) => const _ChoiceExample(group: true),
  ),
  CommerceComponentExample(
    name: 'BudgetSlider',
    description:
        'An interactive budget range; the amount wraps at large text sizes.',
    previewBuilder: (_) => const _BudgetExample(),
  ),
  CommerceComponentExample(
    name: 'PrimaryButton',
    description:
        'Enabled and disabled actions share a full-width presentation.',
    previewBuilder: (_) => const _ButtonExample(),
  ),
  CommerceComponentExample(
    name: 'ProductCard',
    description: 'Choose and remove states use one catalog photograph card; tap to switch.',
    previewBuilder: (_) => const _ProductExample(),
  ),
  CommerceComponentExample(
    name: 'PieceSlot',
    description:
        'Empty, next, and filled slots retain labels without clipping.',
    previewBuilder: (_) => const Column(
      children: [
        CommercePieceSlot(
          label: 'A layer',
          meta: 'Not yet',
          state: 'Empty',
          swatch: '#e4e4e7',
        ),
        CommercePieceSlot(
          label: 'Trousers',
          meta: 'Choosing now',
          state: 'Next',
          swatch: '#e4e4e7',
        ),
        CommercePieceSlot(
          label: 'Tide Crew Knit',
          meta: 'Cotton · €95',
          state: 'Filled',
          swatch: '#596c64',
        ),
      ],
    ),
  ),
  CommerceComponentExample(
    name: 'DressingRoom',
    description: 'The current outfit, next category, and completion share one adaptive rack.',
    previewBuilder: (_) => const _DressingExample(),
  ),
];

class _ChoiceExample extends StatefulWidget {
  const _ChoiceExample({required this.group});
  final bool group;
  @override
  State<_ChoiceExample> createState() => _ChoiceExampleState();
}

class _ChoiceExampleState extends State<_ChoiceExample> {
  String selected = 'Smart casual';
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in [
        'Smart casual',
        'Formal',
        if (widget.group) 'Relaxed layers for a countryside weekend',
      ])
        CommerceChoice(
          label: option,
          selected: option == selected,
          onPressed: () => setState(() => selected = option),
        ),
      if (!widget.group)
        const CommerceChoice(label: 'Unavailable', selected: false),
    ],
  );
}

class _BudgetExample extends StatefulWidget {
  const _BudgetExample();
  @override
  State<_BudgetExample> createState() => _BudgetExampleState();
}

class _BudgetExampleState extends State<_BudgetExample> {
  double value = 900;
  @override
  Widget build(BuildContext context) => CommerceBudgetControl(
    value: value,
    min: 100,
    max: 2000,
    onChanged: (next) => setState(() => value = next),
  );
}

class _ButtonExample extends StatefulWidget {
  const _ButtonExample();
  @override
  State<_ButtonExample> createState() => _ButtonExampleState();
}

class _ButtonExampleState extends State<_ButtonExample> {
  bool submitted = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CommercePrimaryButton(
        label: 'Find options',
        onPressed: () => setState(() => submitted = !submitted),
      ),
      const SizedBox(height: 8),
      const CommercePrimaryButton(label: 'Choose an occasion to continue'),
      if (submitted) ...[
        const SizedBox(height: 8),
        const Text('Preview action received'),
      ],
    ],
  );
}

class _ProductExample extends StatefulWidget {
  const _ProductExample();
  @override
  State<_ProductExample> createState() => _ProductExampleState();
}

class _ProductExampleState extends State<_ProductExample> {
  bool selected = false;
  @override
  Widget build(BuildContext context) => CommerceProductCard(
    name: 'Tide Crew Knit',
    price: '€95.00',
    brandLine: 'Soft Current · Cotton',
    tag: 'Easy to layer',
    imageAsset: 'assets/images/products/demo-0018.jpg',
    swatch: '#596c64',
    removal: selected,
    onPressed: () => setState(() => selected = !selected),
  );
}

class _DressingExample extends StatefulWidget {
  const _DressingExample();
  @override
  State<_DressingExample> createState() => _DressingExampleState();
}

class _DressingExampleState extends State<_DressingExample> {
  bool complete = false;
  bool? dark;
  @override
  Widget build(BuildContext context) {
    final inherited = CommerceDressingRoomStyle.maybeOf(context);
    final effectiveDark = dark ?? inherited?.dark ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CommerceChoice(
              label: 'Light panel',
              selected: !effectiveDark,
              onPressed: () => setState(() => dark = false),
            ),
            CommerceChoice(
              label: 'Formal dark panel',
              selected: effectiveDark,
              onPressed: () => setState(() => dark = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CommerceChoice(
              label: 'Building the look',
              selected: !complete,
              onPressed: () => setState(() => complete = false),
            ),
            CommerceChoice(
              label: 'Complete look',
              selected: complete,
              onPressed: () => setState(() => complete = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CommerceDressingRoomStyle(
          dark: effectiveDark,
          contextImages: inherited?.contextImages ?? const [],
          child: CommerceDressingRoom(
            brief: 'Berlin first day · Spring · smart layers · under €900',
            spent: complete
                ? '€335.00 spent · 3 pieces'
                : '€95.00 spent · 1 piece',
            left: complete ? '€565.00 left' : '€805.00 left',
            progress: complete ? 335 / 900 : 95 / 900,
            planCaption: complete
                ? 'Your look is complete'
                : '1 of 3 pieces selected',
            pieces: [
              const CommercePieceData(
                ProductCategory.top,
                'A top',
                'Tide Crew Knit',
                'Cotton · €95',
                '#596c64',
                'Filled',
                imageAsset: 'assets/images/products/demo-0018.jpg',
              ),
              CommercePieceData(
                ProductCategory.bottom,
                'Trousers',
                complete ? 'Vale Straight Trousers' : '',
                complete ? 'Quiet Meridian · €145' : 'Choosing now',
                '#737373',
                complete ? 'Filled' : 'Next',
              ),
              CommercePieceData(
                ProductCategory.shoes,
                'Shoes',
                complete ? 'Hearth Low Sneakers' : '',
                complete ? 'Morrow Fold · €95' : 'Not yet',
                '#44403c',
                complete ? 'Filled' : 'Empty',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
