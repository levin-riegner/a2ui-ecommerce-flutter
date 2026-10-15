import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models.dart';

Color commerceColorFromHex(
  Object? value, {
  Color fallback = const Color(0xffe4e4e7),
}) {
  final raw = value?.toString().replaceFirst('#', '');
  if (raw == null || (raw.length != 6 && raw.length != 8)) return fallback;
  final parsed = int.tryParse(raw, radix: 16);
  if (parsed == null) return fallback;
  return Color(raw.length == 6 ? 0xff000000 | parsed : parsed);
}

/// Resolves bundled catalog photographs and rejects arbitrary paths or URLs.
class CommerceProductImage extends StatelessWidget {
  const CommerceProductImage({
    super.key,
    this.imageAsset,
    this.swatch,
    this.fit = BoxFit.contain,
  });
  final String? imageAsset;
  final String? swatch;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: commerceColorFromHex(swatch),
      child: const Center(
        child: Icon(Icons.checkroom_outlined, color: Colors.white70),
      ),
    );
    if (imageAsset == null ||
        !RegExp(r'^assets/images/products/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$')
            .hasMatch(imageAsset!)) {
      return fallback;
    }
    return Image.asset(
      imageAsset!,
      fit: fit,
      width: double.infinity,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, error, stackTrace) => fallback,
    );
  }
}

/// Shared single-choice control used by bound A2UI controls and the gallery.
class CommerceChoice extends StatelessWidget {
  const CommerceChoice({
    super.key,
    required this.label,
    required this.selected,
    this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onPressed != null,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? const Color(0xff18181b) : Colors.white,
              border: Border.all(
                color: selected
                    ? const Color(0xff18181b)
                    : const Color(0xffe4e4e7),
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              displayDetail(label),
              style: TextStyle(
                color: onPressed == null
                    ? selected
                          ? Colors.white70
                          : const Color(0xff71717a)
                    : selected
                    ? Colors.white
                    : const Color(0xff18181b),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CommercePrimaryButton extends StatelessWidget {
  const CommercePrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style,
  });
  final String label;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: style,
      onPressed: onPressed,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class CommerceBudgetControl extends StatelessWidget {
  const CommerceBudgetControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
  });
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  @override
  Widget build(BuildContext context) {
    final current = value.clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Budget for the whole outfit',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              '€${current.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          value: current,
          min: min,
          max: max,
          divisions: ((max - min) / 50).round().clamp(1, 100),
          label: '€${current.toStringAsFixed(0)}',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class CommerceStylistMessage extends StatelessWidget {
  const CommerceStylistMessage({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyLarge
        ?.copyWith(height: 1.35, color: const Color(0xff18181b)),
  );
}

class CommerceEyebrow extends StatelessWidget {
  const CommerceEyebrow({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: const Color(0xff71717a),
      fontSize: 10,
      letterSpacing: 1,
      fontWeight: FontWeight.w500,
    ),
  );
}

/// A recommendation/removal card which uses its own pane width and text scale.
class CommerceProductCard extends StatelessWidget {
  const CommerceProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.brandLine,
    required this.tag,
    this.imageAsset,
    this.swatch,
    this.removal = false,
    this.onPressed,
  });
  final String name;
  final String price;
  final String brandLine;
  final String tag;
  final String? imageAsset;
  final String? swatch;
  final bool removal;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    selected: removal,
    child: Material(
      color: removal ? const Color(0xfff4f4f5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: removal ? const Color(0xff18181b) : const Color(0xffe4e4e7),
          width: removal ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
              final stacked = constraints.maxWidth < 300 || largeText;
              final image = ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: stacked ? double.infinity : 120,
                  height: stacked ? 144 : 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CommerceProductImage(
                        imageAsset: imageAsset,
                        swatch: swatch,
                      ),
                      if (tag.isNotEmpty)
                        Positioned(
                          left: 6,
                          right: 6,
                          top: 6,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tag,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xff18181b)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.bodyLarge),
                      Text(price, style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    brandLine,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xff71717a)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        removal ? 'Remove' : 'Choose this',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ],
              );
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [image, const SizedBox(height: 12), details],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        image,
                        const SizedBox(width: 14),
                        Expanded(child: details),
                      ],
                    );
            },
          ),
        ),
      ),
    ),
  );
}

class CommercePieceSlot extends StatelessWidget {
  const CommercePieceSlot({
    super.key,
    required this.label,
    required this.meta,
    required this.state,
    this.swatch,
  });
  final String label;
  final String meta;
  final String state;
  final String? swatch;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xffe4e4e7))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 52,
          decoration: BoxDecoration(
            color: commerceColorFromHex(swatch),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            state == 'Filled' ? Icons.check : Icons.add,
            color: state == 'Filled' ? Colors.white70 : const Color(0xffa1a1aa),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                meta,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: const Color(0xff71717a)),
              ),
              const SizedBox(height: 4),
              Text(
                state,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: const Color(0xff71717a)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CommercePieceData {
  const CommercePieceData(
    this.category,
    this.label,
    this.name,
    this.meta,
    this.swatch,
    this.state, {
    this.imageAsset = '',
  });

  final ProductCategory category;
  final String label;
  final String name;
  final String meta;
  final String? swatch;
  final String state;
  final String imageAsset;
}

/// Screen-owned style and context passed through A2UI without adding schema fields.
class CommerceDressingRoomStyle extends InheritedWidget {
  const CommerceDressingRoomStyle({
    super.key,
    required this.dark,
    this.compact = false,
    this.contextImages = const [],
    this.minHeight = 0,
    required super.child,
  });
  final bool dark;
  final bool compact;
  final List<String> contextImages;
  final double minHeight;
  static CommerceDressingRoomStyle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommerceDressingRoomStyle>();
  @override
  bool updateShouldNotify(CommerceDressingRoomStyle oldWidget) =>
      dark != oldWidget.dark ||
      compact != oldWidget.compact ||
      minHeight != oldWidget.minHeight ||
      contextImages != oldWidget.contextImages;
}

class CommerceDressingRoom extends StatelessWidget {
  const CommerceDressingRoom({
    super.key,
    this.title = 'Dressing room',
    required this.brief,
    required this.spent,
    required this.left,
    required this.progress,
    required this.pieces,
    required this.planCaption,
  });

  final String title;
  final String brief;
  final String spent;
  final String left;
  final double progress;
  final List<CommercePieceData> pieces;
  final String planCaption;

  @override
  Widget build(BuildContext context) {
    final style = CommerceDressingRoomStyle.maybeOf(context);
    final dark = style?.dark ?? false;
    final foreground = dark ? Colors.white : const Color(0xff18181b);
    final muted = dark ? Colors.white60 : const Color(0xff71717a);
    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.black : const Color(0xfff4f4f5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          final fourAcross = !dark && constraints.maxWidth >= 520 && !largeText;
          final budget = CommerceBudgetSummary(
            spent: spent,
            left: left,
            progress: progress,
          );
          final rack = LayoutBuilder(
            builder: (_, rackConstraints) {
              final minimum = largeText
                  ? 240.0
                  : dark
                  ? 120.0
                  : 140.0;
              final columns = ((rackConstraints.maxWidth + 12) / (minimum + 12))
                  .floor()
                  .clamp(1, fourAcross ? 4 : 2);
              final cardWidth =
                  (rackConstraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  for (final piece in pieces)
                    SizedBox(
                      width: cardWidth,
                      child: CommercePieceCard(
                        piece: piece,
                        compact: fourAcross,
                      ),
                    ),
                ],
              );
            },
          );
          final images = style?.contextImages ?? const <String>[];
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dark ? 24 : 20,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 20, color: foreground),
                ),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        for (var index = 0; index < images.length; index++) ...[
                          if (index > 0) const SizedBox(width: 4),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                images[index],
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  brief,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted),
                ),
                if (planCaption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    planCaption,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: muted),
                  ),
                ],
                const SizedBox(height: 14),
                if (dark || progress == 0) ...[
                  budget,
                  const SizedBox(height: 14),
                  rack,
                ] else ...[
                  rack,
                  const SizedBox(height: 14),
                  budget,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class CommerceBudgetSummary extends StatelessWidget {
  const CommerceBudgetSummary({
    super.key,
    required this.spent,
    required this.left,
    required this.progress,
  });

  final String spent;
  final String left;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final dark = CommerceDressingRoomStyle.maybeOf(context)?.dark ?? false;
    final foreground = dark ? Colors.white : const Color(0xff18181b);
    final muted = dark ? Colors.white60 : const Color(0xff71717a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 4,
          children: [
            Text(
              spent,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: foreground),
            ),
            Text(
              left,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: dark ? Colors.white10 : const Color(0xffe4e4e7),
            color: foreground,
          ),
        ),
      ],
    );
  }
}

class CommercePieceCard extends StatelessWidget {
  const CommercePieceCard({
    super.key,
    required this.piece,
    required this.compact,
  });

  final CommercePieceData piece;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = CommerceDressingRoomStyle.maybeOf(context)?.dark ?? false;
    final filled = piece.name.isNotEmpty;
    final isChoosing =
        piece.state == 'Next' || piece.state == 'Choosing on the left';
    final thumbHeight = switch (piece.category) {
      ProductCategory.dress => compact ? 118.0 : 200.0,
      ProductCategory.top => compact ? 92.0 : 100.0,
      ProductCategory.bottom => compact ? 92.0 : 130.0,
      ProductCategory.layer => compact ? 92.0 : 90.0,
      ProductCategory.shoes ||
      ProductCategory.bag ||
      ProductCategory.accessory => compact ? 76.0 : 64.0,
    };
    final foreground = dark ? Colors.white : const Color(0xff18181b);
    final muted = dark ? Colors.white60 : const Color(0xff71717a);
    final labelColor = filled || isChoosing ? foreground : muted;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(dark ? 8 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark && isChoosing
              ? null
              : filled
              ? Colors.white
              : dark
              ? Colors.white10
              : isChoosing
              ? Colors.white
              : commerceColorFromHex(piece.swatch),
          gradient: dark && isChoosing
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff737373), Color(0xffa1a1aa)],
                )
              : null,
          border: !dark
              ? Border.all(
                  color: isChoosing
                      ? const Color(0xff18181b)
                      : const Color(0xffe4e4e7),
                  width: isChoosing ? 1.5 : 1,
                )
              : null,
          borderRadius: BorderRadius.circular(dark ? 8 : 12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (filled)
              CommerceProductImage(
                imageAsset: piece.imageAsset,
                swatch: piece.swatch,
              ),
            if (dark && !filled)
              Center(
                child: isChoosing
                    ? SvgPicture.asset(
                        'assets/icons/commerce/choosing-dots.svg',
                        width: 26,
                        height: 6,
                      )
                    : Opacity(
                        opacity: .6,
                        child: SvgPicture.asset(
                          'assets/icons/commerce/locked-piece.svg',
                          width: 13.3333,
                          height: 14.6667,
                        ),
                      ),
              ),
            if (!dark && isChoosing)
              Positioned(
                left: 7,
                right: 7,
                top: 7,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _ChoosingBadge(dark: false),
                ),
              ),
          ],
        ),
      ),
    );
    return Column(
      key: ValueKey('dressing-slot-${piece.category.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dark)
          AspectRatio(aspectRatio: 172 / 200, child: image)
        else
          SizedBox(height: thumbHeight, width: double.infinity, child: image),
        const SizedBox(height: 6),
        Text(
          filled ? piece.name : piece.label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: labelColor),
        ),
        const SizedBox(height: 4),
        if (dark && isChoosing)
          const _ChoosingBadge(dark: true)
        else
          Text(
            filled || isChoosing ? piece.meta : 'Not yet',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
      ],
    );
  }
}

class _ChoosingBadge extends StatelessWidget {
  const _ChoosingBadge({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: dark ? Colors.white : const Color(0xff18181b),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'Choosing now',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: dark ? Colors.black : Colors.white),
    ),
  );
}
