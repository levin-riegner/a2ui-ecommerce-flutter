import 'package:flutter/material.dart';

import '../../app/l10n/l10n.dart';
import '../../app/navigation/router/app_router.dart';
import '../shared/design_system/views/brand_lockup.dart';
import '../shared/layout/adaptive_page.dart';
import 'commerce_examples.dart';

const _basicComponentGalleryNames = <String>[
  'Button',
  'Card',
  'CheckBox',
  'Column',
  'ChoicePicker',
  'DateTimeInput',
  'Divider',
  'Icon',
  'List',
  'Modal',
  'Row',
  'Slider',
  'Tabs',
  'Text',
  'TextField',
];

class ComponentCatalogPage extends StatelessWidget {
  const ComponentCatalogPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdaptivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: context.l10n.back,
                ),
                const SizedBox(width: 4),
                const Expanded(child: BrandLockup()),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              context.l10n.catalogTitle,
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.catalogDescription,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: const Color(0xff71717a), height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.catalogCounts,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  const FinalizedComponentsRoute().push<void>(context),
              child: Text(context.l10n.finalizedComponents),
            ),
            OutlinedButton(
              onPressed: () =>
                  const FinalizedScreensRoute().push<void>(context),
              child: Text(context.l10n.finalizedScreens),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth < 680
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final example in commerceComponentExamples)
                      _GalleryTile(
                        width: tileWidth,
                        name: example.name,
                        description: example.description,
                        preview: example.previewBuilder(context),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
            Text(
              context.l10n.basicComponents,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.basicComponentsDescription,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: const Color(0xff71717a), height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _basicComponentGalleryNames)
                  Chip(
                    avatar: const Icon(Icons.widgets_outlined, size: 16),
                    label: Text(name),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              context.l10n.catalogGuidance,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: const Color(0xff71717a), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.width,
    required this.name,
    required this.description,
    required this.preview,
  });

  final double width;
  final String name;
  final String description;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe4e4e7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: const Color(0xff71717a)),
            ),
            const SizedBox(height: 16),
            preview,
          ],
        ),
      ),
    );
  }
}
