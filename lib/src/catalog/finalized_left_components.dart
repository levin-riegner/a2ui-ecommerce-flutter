import 'dart:convert';
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'commerce_components.dart';
import '../layout/stylist_layout.dart';
import '../data/models.dart' show displayDetail;

const _ink = Color(0xff000000);
const _muted = Color(0xff666666);
const _wash = Color(0xfff2f2f2);
const _line = Color(0xffe4e4e7);
const _body = TextStyle(fontSize: 16, height: 1.4, letterSpacing: -.25);
const _small = TextStyle(fontSize: 12, height: 1.2, color: _muted);

/// Exact exported SVGs. The SVG's intrinsic root dimensions remain intact;
/// scaling belongs to the containing design slot.
class FinalizedLeftIcon extends StatelessWidget {
  const FinalizedLeftIcon(this.file, {super.key, this.slot});
  final String file;
  final Size? slot;
  static const dimensions = <String, Size>{
    '357bc.svg': Size(11.6667, 14.3333),
    'ba79f.svg': Size(14.2575, 14.2575),
    'efdf2.svg': Size(20, 20),
    'c22cb.svg': Size(56, 88),
    '28493.svg': Size(68, 72),
    '5f3fb.svg': Size(56, 92),
    'a2efe.svg': Size(72, 89),
    '98299.svg': Size(88, 56),
    'd6108.svg': Size(76, 68),
    'eb269.svg': Size(100, 100),
    '73eb0.svg': Size(100, 100),
    'c3a13.svg': Size(100, 100),
    '735f4.svg': Size(40, 40),
    '27acc.svg': Size(40, 40),
    'b55ec.svg': Size(40, 40),
    '470fb.svg': Size(24, 24),
    '3932e.svg': Size(48, 88),
    '177cc.svg': Size(26, 6),
  };
  @override
  Widget build(BuildContext context) {
    final intrinsic = dimensions[file]!;
    final child = SizedBox(
      width: intrinsic.width,
      height: intrinsic.height,
      child: SvgPicture.asset('assets/icons/finalized_left/$file'),
    );
    if (slot == null) return child;
    return SizedBox(
      width: slot!.width,
      height: slot!.height,
      child: FittedBox(child: child),
    );
  }
}

Widget _stack(List<Widget> children, {double gap = 10}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      children[i],
    ],
  ],
);

class FinalizedUserMessage extends StatelessWidget {
  const FinalizedUserMessage({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Text(text, style: _body.copyWith(color: Colors.white)),
    ),
  );
}

class FinalizedStylistMessage extends StatelessWidget {
  const FinalizedStylistMessage({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: _body.copyWith(
      height: 1.5,
      color: CommerceDressingRoomStyle.maybeOf(context)?.dark == true
          ? Colors.white
          : _ink,
    ),
  );
}

class FinalizedSuggestion extends StatelessWidget {
  const FinalizedSuggestion({super.key, required this.text, this.onPressed});
  final String text;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: _wash,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: FinalizedLeftIcon('ba79f.svg', slot: Size(16, 16)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: _body)),
          ],
        ),
      ),
    ),
  );
}

class FinalizedChatInput extends StatefulWidget {
  const FinalizedChatInput({
    super.key,
    this.value = '',
    this.placeholder = 'Tell me about the occasion…',
    this.onChanged,
    this.onSend,
    this.onMicrophone,
    this.onEditing,
    this.isDictating = false,
    this.microphoneLabel = 'Dictate message',
    this.externalController,
    this.enabled = true,
    this.glassBackground = false,
    this.fieldKey,
    this.submitLabel = 'Send message',
    this.fieldLabel = 'Tell me about the occasion',
  });
  final String value;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSend;
  final VoidCallback? onMicrophone;
  final VoidCallback? onEditing;
  final bool isDictating;
  final String microphoneLabel;
  final TextEditingController? externalController;
  final bool enabled;
  final bool glassBackground;
  final Key? fieldKey;
  final String submitLabel, fieldLabel;
  @override
  State<FinalizedChatInput> createState() => _FinalizedChatInputState();
}

class _FinalizedChatInputState extends State<FinalizedChatInput> {
  TextEditingController? ownedController;
  TextEditingController get controller =>
      widget.externalController ?? ownedController!;
  @override
  void initState() {
    super.initState();
    if (widget.externalController == null) {
      ownedController = TextEditingController(text: widget.value);
    }
  }

  @override
  void didUpdateWidget(FinalizedChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalController != null &&
        widget.externalController == null) {
      ownedController = TextEditingController.fromValue(
        oldWidget.externalController!.value,
      );
    } else if (oldWidget.externalController == null &&
        widget.externalController != null) {
      ownedController?.dispose();
      ownedController = null;
    }
    if (widget.externalController == null &&
        oldWidget.value != widget.value &&
        controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    ownedController?.dispose();
    super.dispose();
  }

  void send() {
    final text = controller.text.trim();
    if (widget.enabled && text.isNotEmpty) widget.onSend?.call(text);
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, textValue, child) => Container(
          decoration: BoxDecoration(
            color: widget.glassBackground ? null : _wash,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              if (widget.glassBackground)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 12,
                          sigmaY: 12,
                          tileMode: TileMode.decal,
                        ),
                        child: ColoredBox(color: _wash.withValues(alpha: .82)),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 96, 8),
                child: Semantics(
                  label: widget.fieldLabel,
                  child: TextField(
                    key: widget.fieldKey,
                    enabled: widget.enabled,
                    controller: controller,
                    onTap: widget.onEditing,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 14, height: 20 / 14),
                    decoration: InputDecoration(
                      hintText: widget.isDictating
                          ? 'Listening…'
                          : widget.placeholder,
                      hintMaxLines: 1,
                      hintStyle: const TextStyle(
                        color: _muted,
                        fontSize: 14,
                        height: 20 / 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      widget.onChanged?.call(value);
                    },
                    onSubmitted: (_) => send(),
                  ),
                ),
              ),
              // Figma's circles are 36 points. The invisible 44 × 48 targets
              // remain disjoint within the 52-point composer.
              Positioned(
                right: 48,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    key: const ValueKey('stylist-microphone'),
                    tooltip: widget.onMicrophone == null
                        ? 'Voice input unavailable'
                        : widget.microphoneLabel,
                    onPressed: widget.enabled ? widget.onMicrophone : null,
                    icon: Container(
                      key: const ValueKey('stylist-microphone-circle'),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isDictating
                            ? _ink
                            : const Color(0xffe6e6e6),
                      ),
                      alignment: Alignment.center,
                      child: widget.isDictating
                          ? const Icon(
                              Icons.stop_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : const FinalizedLeftIcon('357bc.svg'),
                    ),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(44, 48),
                      minimumSize: const Size(44, 48),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    key: ValueKey('stylist-submit-${widget.submitLabel}'),
                    tooltip: widget.submitLabel,
                    onPressed:
                        !widget.enabled ||
                            controller.text.trim().isEmpty ||
                            widget.onSend == null
                        ? null
                        : send,
                    icon: Container(
                      key: const ValueKey('stylist-submit-circle'),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            !widget.enabled ||
                                controller.text.trim().isEmpty ||
                                widget.onSend == null
                            ? _line
                            : _ink,
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/images/occasions/send-arrow.svg',
                        colorFilter: ColorFilter.mode(
                          !widget.enabled ||
                                  controller.text.trim().isEmpty ||
                                  widget.onSend == null
                              ? _muted
                              : Colors.white,
                          BlendMode.srcIn,
                        ),
                        excludeFromSemantics: true,
                      ),
                    ),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(44, 48),
                      minimumSize: const Size(44, 48),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class FinalizedBudgetSlider extends StatelessWidget {
  const FinalizedBudgetSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
  });
  final double value, min, max;
  final ValueChanged<double>? onChanged;
  @override
  Widget build(BuildContext context) {
    final low = min.isFinite ? min : 0.0;
    final high = max.isFinite && max > low ? max : low + 1;
    final current = value.isFinite ? value.clamp(low, high) : low;
    return _stack([
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          const CommerceEyebrow(text: 'BUDGET FOR THE WHOLE OUTFIT'),
          Text(
            '€${current.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, constraints) => Stack(
          alignment: Alignment.center,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: _ink,
                inactiveTrackColor: _wash,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                thumbColor: Colors.transparent,
                padding: EdgeInsets.zero,
              ),
              child: SizedBox(
                height: 20,
                child: Slider(
                  value: current,
                  min: low,
                  max: high,
                  onChanged: onChanged,
                ),
              ),
            ),
            Positioned(
              left:
                  ((constraints.maxWidth - 20) * (current - low) / (high - low))
                      .clamp(0, constraints.maxWidth - 20),
              child: const IgnorePointer(child: FinalizedLeftIcon('efdf2.svg')),
            ),
          ],
        ),
      ),
    ], gap: 8);
  }
}

const _silhouettes = <String, String>{
  'dress': 'c22cb.svg',
  'top': '28493.svg',
  'bottom': '5f3fb.svg',
  'layer': 'a2efe.svg',
  'shoes': '98299.svg',
  'bag': 'd6108.svg',
};
const _tileHeight = <String, double>{
  'dress': 240,
  'top': 96,
  'bottom': 136,
  'layer': 136,
  'shoes': 64,
  'bag': 64,
};

Widget _productVisual(
  String category,
  String? asset,
  String? swatch, {
  bool tile = false,
  BoxFit fit = BoxFit.contain,
}) {
  if (asset != null &&
      RegExp(r'^assets/images/products/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$')
          .hasMatch(asset)) {
    return CommerceProductImage(imageAsset: asset, swatch: swatch, fit: fit);
  }
  final file = tile
      ? switch (category) {
          'dress' => 'eb269.svg',
          'top' => '73eb0.svg',
          'shoes' => 'c3a13.svg',
          _ => _silhouettes[category] ?? 'c22cb.svg',
        }
      : _silhouettes[category] ?? 'c22cb.svg';
  final intrinsic = FinalizedLeftIcon.dimensions[file]!;
  final glyph = tile
      ? FinalizedLeftIcon(
          file,
          slot: Size.square(
            category == 'dress'
                ? 96
                : category == 'top'
                ? 70
                : 50,
          ),
        )
      : SizedBox.square(
          dimension: 56,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: intrinsic.width,
            maxWidth: intrinsic.width,
            minHeight: intrinsic.height,
            maxHeight: intrinsic.height,
            child: FinalizedLeftIcon(file),
          ),
        );
  return ColoredBox(
    color: commerceColorFromHex(swatch),
    child: Center(child: glyph),
  );
}

class FinalizedProductCard extends StatelessWidget {
  const FinalizedProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.brandLine,
    required this.tag,
    this.category = 'dress',
    this.selected = false,
    this.removal = false,
    this.imageAsset,
    this.swatch,
    this.onPressed,
  });
  final String name, price, brandLine, tag, category;
  final bool selected, removal;
  final String? imageAsset, swatch;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: selected ? _wash : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? _ink : _line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(16) > 24;
                final badge = Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    key: const ValueKey('finalized-product-tag'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      displayDetail(tag),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        letterSpacing: -.1,
                        color: _ink,
                      ),
                    ),
                  ),
                );
                final image = SizedBox(
                  key: const ValueKey('finalized-product-image'),
                  width: StylistLayout.productImage,
                  height: StylistLayout.productImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _productVisual(
                          category.toLowerCase(),
                          imageAsset,
                          swatch,
                          fit: BoxFit.cover,
                        ),
                        if (!largeText)
                          Positioned(left: 6, top: 6, right: 6, child: badge),
                      ],
                    ),
                  ),
                );
                final body = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(name, style: _body)),
                        Text(price, style: _body),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(brandLine, style: _small),
                    const SizedBox(height: 4),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            category.isEmpty
                                ? ''
                                : '${category[0].toUpperCase()}${category.substring(1)}',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xff999999),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            removal
                                ? 'Remove'
                                : selected
                                ? 'In your dressing room'
                                : 'Add to dressing room',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
                if (constraints.maxWidth < 280 || largeText) {
                  return _stack([
                    if (largeText) badge, image,
                    // Large text grows naturally rather than using a flex spacer.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(name, style: _body),
                        Text(price, style: _body),
                        const SizedBox(height: 4),
                        Text(brandLine, style: _small),
                        const SizedBox(height: 8),
                        Text(
                          category,
                          style: _small.copyWith(
                            color: const Color(0xff999999),
                          ),
                        ),
                        Text(
                          removal
                              ? 'Remove'
                              : selected
                              ? 'In your dressing room'
                              : 'Add to dressing room',
                          style: _body,
                        ),
                      ],
                    ),
                  ]);
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      image,
                      const SizedBox(width: 14),
                      Expanded(child: body),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class FinalizedPicksStrip extends StatelessWidget {
  const FinalizedPicksStrip({
    super.key,
    required this.products,
    this.category = 'dress',
    this.selectedProductId = '',
    this.onSelected,
  });
  final List<Map<String, Object?>> products;
  final String category, selectedProductId;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Semantics(
            label: products[i]['name']?.toString(),
            button: true,
            selected: products[i]['productId'] == selectedProductId,
            child: Material(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: products[i]['productId'] == selectedProductId
                      ? _ink
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: InkWell(
                onTap: onSelected == null
                    ? null
                    : () => onSelected!(products[i]['productId'].toString()),
                child: SizedBox(
                  width: 120,
                  height: _tileHeight[category.toLowerCase()] ?? 240,
                  child: _productVisual(
                    category.toLowerCase(),
                    products[i]['imageAsset']?.toString(),
                    products[i]['swatch']?.toString(),
                    tile: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class FinalizedThisOrThat extends StatelessWidget {
  const FinalizedThisOrThat({
    super.key,
    required this.options,
    this.picked = '',
    this.question = 'Which do you prefer?',
    this.onSelected,
  });
  final List<Map<String, Object?>> options;
  final String picked, question;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => _stack([
    Text(question, style: _body),
    LayoutBuilder(
      builder: (context, constraints) {
        Widget tile(Map<String, Object?> option) => Semantics(
          selected: option['productId'] == picked,
          button: true,
          child: Material(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: option['productId'] == picked ? _ink : _line,
                width: option['productId'] == picked ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSelected == null
                  ? null
                  : () => onSelected!(option['productId'].toString()),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _stack([
                  SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _productVisual(
                        option['category']?.toString().toLowerCase() ?? 'shoes',
                        option['imageAsset']?.toString(),
                        option['swatch']?.toString(),
                        tile: true,
                      ),
                    ),
                  ),
                  Text(
                    option['label']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ], gap: 6),
              ),
            ),
          ),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 24) {
          return _stack(options.take(2).map(tile).toList(), gap: 8);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < options.take(2).length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tile(options[i])),
            ],
          ],
        );
      },
    ),
  ]);
}

const finalizedColourOptions = <Map<String, Object?>>[
  {'name': 'Black', 'hex': '#161616'},
  {'name': 'Ivory', 'hex': '#f1ece2'},
  {'name': 'Navy', 'hex': '#192c46'},
  {'name': 'Camel', 'hex': '#b8935a'},
  {'name': 'Olive', 'hex': '#5c6644'},
  {'name': 'Burgundy', 'hex': '#6b1f2e'},
  {'name': 'Grey', 'hex': '#9a9a9a'},
  {'name': 'Chocolate', 'hex': '#473528'},
];

class FinalizedColourPicker extends StatelessWidget {
  const FinalizedColourPicker({
    super.key,
    this.options = finalizedColourOptions,
    this.selected = const [],
    this.onChanged,
    this.question = 'Any colours you’re drawn to? Pick a few.',
  });
  final List<Map<String, Object?>> options;
  final List<String> selected;
  final ValueChanged<List<String>>? onChanged;
  final String question;
  @override
  Widget build(BuildContext context) => _stack([
    Text(question, style: _body),
    Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in options)
          Semantics(
            label: option['name']?.toString(),
            selected: selected.contains(option['name']),
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onChanged == null
                  ? null
                  : () {
                      final next = [...selected];
                      final name = option['name'].toString();
                      next.contains(name) ? next.remove(name) : next.add(name);
                      onChanged!(next);
                    },
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(child: _swatch(option)),
              ),
            ),
          ),
      ],
    ),
    Text(
      '${selected.length} chosen${selected.isEmpty ? '' : ' · ${selected.join(', ')}'}',
      style: _small.copyWith(color: const Color(0xff999999)),
    ),
  ]);
  Widget _swatch(Map<String, Object?> option) {
    final name = option['name']?.toString();
    final asset = {
      'Black': '735f4.svg',
      'Navy': '27acc.svg',
      'Chocolate': 'b55ec.svg',
    }[name];
    if (selected.contains(name) &&
        asset != null &&
        finalizedColourOptions.any(
          (row) => row['name'] == name && row['hex'] == option['hex'],
        )) {
      return FinalizedLeftIcon(asset);
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: commerceColorFromHex(option['hex']),
        border: Border.all(
          color: selected.contains(name) ? _ink : _line,
          width: selected.contains(name) ? 2 : 1,
        ),
      ),
      child: selected.contains(name)
          ? const Center(
              child: SizedBox(
                width: 4,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class FinalizedPhotoUpload extends StatelessWidget {
  const FinalizedPhotoUpload({
    super.key,
    this.uploaded = false,
    this.photo,
    this.description = '',
    this.onChoose,
    this.onUse,
    this.onReplace,
  });
  final bool uploaded;
  final Widget? photo;
  final String description;
  final VoidCallback? onChoose, onUse, onReplace;
  @override
  Widget build(BuildContext context) => _stack([
    const Text(
      'Got a photo of you, or a piece you already own?\nI’ll build around it.',
      style: _body,
    ),
    if (!uploaded)
      Material(
        color: _wash,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xffe6e6e6)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onChoose,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            child: Row(
              children: [
                const FinalizedLeftIcon('470fb.svg'),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Take a photo or choose from your library',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    if (uploaded)
      LayoutBuilder(
        builder: (context, constraints) {
          final image = SizedBox(
            width: 132,
            height: 176,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo ??
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xffc7b8a8), Color(0xff73665c)],
                          ),
                        ),
                      ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'YOUR PHOTO',
                        style: TextStyle(fontSize: 10, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          final detail = _stack([
            const Text('What I’m seeing', style: _small),
            Text(description, style: _body),
            Wrap(
              spacing: 14,
              children: [
                TextButton(onPressed: onUse, child: const Text('Use it')),
                TextButton(onPressed: onReplace, child: const Text('Replace')),
              ],
            ),
          ], gap: 8);
          if (constraints.maxWidth < 350 ||
              MediaQuery.textScalerOf(context).scale(16) > 24) {
            return _stack([image, detail]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              const SizedBox(width: 12),
              Expanded(child: detail),
            ],
          );
        },
      ),
  ]);
}

class FinalizedFitSize extends StatelessWidget {
  const FinalizedFitSize({
    super.key,
    this.sizes = const ['34', '36', '38', '40', '42'],
    this.fits = const ['Fitted', 'True to size', 'Relaxed'],
    this.size = '',
    this.fit = '',
    this.onSize,
    this.onFit,
  });
  final List<String> sizes, fits;
  final String size, fit;
  final ValueChanged<String>? onSize, onFit;
  @override
  Widget build(BuildContext context) => _stack([
    const Text('Your usual size, and how you like it to sit?', style: _body),
    const CommerceEyebrow(text: 'DRESS SIZE'),
    _choices(sizes, [size], onSize),
    const CommerceEyebrow(text: 'FIT'),
    _choices(fits, [fit], onFit),
  ]);
}

Widget _choices(
  List<String> values,
  List<String> selected,
  ValueChanged<String>? callback,
) => Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    for (final value in values)
      CommerceChoice(
        label: value,
        selected: selected.contains(value),
        onPressed: callback == null ? null : () => callback(value),
      ),
  ],
);

class FinalizedOccasionTimeline extends StatelessWidget {
  const FinalizedOccasionTimeline({
    super.key,
    required this.segments,
    this.selected = '',
    this.onEdit,
  });
  final List<Map<String, Object?>> segments;
  final String selected;
  final ValueChanged<Map<String, Object?>>? onEdit;
  @override
  Widget build(BuildContext context) => _stack([
    const Text(
      'Here’s the day as I understand it — tap anything to fix it.',
      style: _body,
    ),
    LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final segment in segments)
            SizedBox(
              width:
                  constraints.maxWidth < 330 ||
                      MediaQuery.textScalerOf(context).scale(14) > 24
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 3,
              child: Material(
                color: segment['id'] == selected ? _ink : _wash,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onEdit == null
                      ? null
                      : () async {
                          final changed = await _editSegment(context, segment);
                          if (changed != null) onEdit!(changed);
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: _stack([
                      Text(
                        segment['time']?.toString() ?? '',
                        style: _small.copyWith(
                          color: segment['id'] == selected
                              ? Colors.white70
                              : _muted,
                        ),
                      ),
                      Text(
                        segment['label']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: segment['id'] == selected
                              ? Colors.white
                              : _ink,
                        ),
                      ),
                      Text(
                        segment['location']?.toString() ?? '',
                        style: _small.copyWith(
                          color: segment['id'] == selected
                              ? Colors.white70
                              : _muted,
                        ),
                      ),
                    ], gap: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ]);
}

Future<Map<String, Object?>?> _editSegment(
  BuildContext context,
  Map<String, Object?> segment,
) async {
  final values = await showDialog<List<String>>(
    context: context,
    builder: (_) => _FinalizedEditor(
      title: 'Edit occasion',
      labels: const ['Time', 'Activity', 'Location'],
      values: [
        segment['time']?.toString() ?? '',
        segment['label']?.toString() ?? '',
        segment['location']?.toString() ?? '',
      ],
      saveLabel: 'Save',
    ),
  );
  return values == null
      ? null
      : {
          ...segment,
          'time': values[0],
          'label': values[1],
          'location': values[2],
        };
}

class _FinalizedEditor extends StatefulWidget {
  const _FinalizedEditor({
    required this.title,
    required this.labels,
    required this.values,
    required this.saveLabel,
  });
  final String title, saveLabel;
  final List<String> labels, values;
  @override
  State<_FinalizedEditor> createState() => _FinalizedEditorState();
}

class _FinalizedEditorState extends State<_FinalizedEditor> {
  late final controllers = widget.values
      .map((value) => TextEditingController(text: value))
      .toList();
  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: _stack([
        for (var i = 0; i < controllers.length; i++)
          TextField(
            controller: controllers[i],
            decoration: InputDecoration(labelText: widget.labels[i]),
          ),
      ]),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(
          context,
          controllers.map((controller) => controller.text.trim()).toList(),
        ),
        child: Text(widget.saveLabel),
      ),
    ],
  );
}

class FinalizedQuickAdjust extends StatelessWidget {
  const FinalizedQuickAdjust({
    super.key,
    required this.productName,
    this.imageAsset,
    this.category = 'dress',
    this.options = const [
      'Cheaper',
      'Dressier',
      'Warmer',
      'Another colour',
      'Shorter',
      'Something similar',
    ],
    this.selected = '',
    this.onSelected,
  });
  final String productName, category, selected;
  final String? imageAsset;
  final List<String> options;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => _stack([
    Row(
      children: [
        SizedBox(
          width: 36,
          height: 44,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageAsset == null || imageAsset!.isEmpty
                ? const ColoredBox(
                    color: Color(0xffb8a98e),
                    child: Center(
                      child: FinalizedLeftIcon('3932e.svg', slot: Size(22, 40)),
                    ),
                  )
                : _productVisual(category, imageAsset, null),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('$productName — want it different?', style: _body),
        ),
      ],
    ),
    _choices(options, [selected], onSelected),
  ]);
}

class FinalizedBrandPreferences extends StatelessWidget {
  const FinalizedBrandPreferences({
    super.key,
    this.brands = const [
      'The Row',
      'Toteme',
      'Zimmermann',
      'COS',
      'Gucci',
      'Balenciaga',
    ],
    this.love = const [],
    this.skip = const [],
    this.onChanged,
  });
  final List<String> brands, love, skip;
  final void Function(List<String> love, List<String> skip)? onChanged;
  @override
  Widget build(BuildContext context) => _stack([
    const Text('Any brands you love, or would rather I skip?', style: _body),
    const CommerceEyebrow(text: 'LOVE'),
    _choices(
      brands.where((brand) => !skip.contains(brand)).toList(),
      love,
      onChanged == null ? null : (brand) => _toggle(brand, true),
    ),
    const CommerceEyebrow(text: 'SKIP'),
    _choices(
      brands.where((brand) => !love.contains(brand)).toList(),
      skip,
      onChanged == null ? null : (brand) => _toggle(brand, false),
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onChanged == null
            ? null
            : () async {
                final brand = await _newBrand(context);
                if (brand != null && brand.isNotEmpty) {
                  onChanged!([
                    ...love.where((item) => item != brand),
                    brand,
                  ], skip.where((item) => item != brand).toList());
                }
              },
        child: const Text('+ Add'),
      ),
    ),
  ]);
  void _toggle(String brand, bool loving) {
    final nextLove = [...love], nextSkip = [...skip];
    final target = loving ? nextLove : nextSkip;
    target.contains(brand) ? target.remove(brand) : target.add(brand);
    (loving ? nextSkip : nextLove).remove(brand);
    onChanged!(nextLove, nextSkip);
  }
}

Future<String?> _newBrand(BuildContext context) async {
  final values = await showDialog<List<String>>(
    context: context,
    builder: (_) => const _FinalizedEditor(
      title: 'Add a brand',
      labels: ['Brand name'],
      values: [''],
      saveLabel: 'Add',
    ),
  );
  return values?.first;
}

class FinalizedStylistWorking extends StatelessWidget {
  const FinalizedStylistWorking({super.key, required this.text, this.progress});
  final String text;
  final double? progress;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: _stack([
      Row(
        children: [
          const FinalizedLeftIcon('177cc.svg'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xff999999),
              ),
            ),
          ),
        ],
      ),
      LinearProgressIndicator(
        value: progress?.clamp(0, 1),
        minHeight: 3,
        color: _ink,
        backgroundColor: _wash,
        borderRadius: BorderRadius.circular(2),
      ),
    ], gap: 8),
  );
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : {};
List<String> _strings(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : [];
List<Map<String, Object?>> _rows(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList()
    : [];
String _str(Map<String, Object?> data, String key, [String fallback = '']) =>
    data[key]?.toString() ?? fallback;

final _localWrites = Expando<void Function(String, Object?)>();

void _update(
  CatalogItemContext context,
  Map<String, Object?> raw,
  String field,
  Object? value, {
  String? fallback,
}) {
  final reference = raw[field];
  final path = reference is Map ? reference['path'] : raw['${field}Path'];
  final target = path is String && path.startsWith('/') ? path : fallback;
  if (target != null) context.dataContext.update(DataPath(target), value);
  if (path is! String) _localWrites[context]?.call(field, value);
}

Future<void> _event(
  CatalogItemContext context,
  Object? action,
  Map<String, Object?> values,
) async {
  final event = _map(_map(action)['event']);
  if (event['name'] is! String) return;
  final resolved = await resolveContext(
    context.dataContext,
    _map(event['context']),
  );
  context.dispatchEvent(
    UserActionEvent(
      name: event['name'] as String,
      sourceComponentId: context.id,
      context: {...resolved, ...values},
    ),
  );
}

/// Bound adapters remain separate from presentation. Local writes always use
/// the supplied reference/path; events preserve explicit action context.
class _FinalizedBindings extends StatefulWidget {
  const _FinalizedBindings({
    required this.context,
    required this.kinds,
    required this.builder,
  });
  final CatalogItemContext context;
  final Map<String, String> kinds;
  final Widget Function(Map<String, Object?> raw, Map<String, Object?> resolved)
  builder;
  @override
  State<_FinalizedBindings> createState() => _FinalizedBindingsState();
}

class _FinalizedBindingsState extends State<_FinalizedBindings> {
  final local = <String, Object?>{};
  void write(String field, Object? value) {
    if (mounted) setState(() => local[field] = value);
  }

  @override
  void didUpdateWidget(_FinalizedBindings oldWidget) {
    super.didUpdateWidget(oldWidget);
    _localWrites[oldWidget.context] = null;
    if (oldWidget.context.data != widget.context.data) local.clear();
  }

  @override
  void dispose() {
    _localWrites[widget.context] = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext buildContext) {
    final context = widget.context, kinds = widget.kinds;
    _localWrites[context] = write;
    final raw = _map(context.data), fields = kinds.keys.toList();
    Widget bind(int index, Map<String, Object?> values) {
      if (index == fields.length) {
        return widget.builder(raw, {...values, ...local});
      }
      final field = fields[index];
      Widget next(Object? value) => bind(index + 1, {...values, field: value});
      return switch (kinds[field]) {
        'list' => BoundList(
          dataContext: context.dataContext,
          value: raw[field] ?? const <Object?>[],
          builder: (_, value) => next(value),
        ),
        'number' => BoundNumber(
          dataContext: context.dataContext,
          value: raw[field],
          builder: (_, value) => next(value),
        ),
        'bool' => BoundBool(
          dataContext: context.dataContext,
          value: raw[field] ?? false,
          builder: (_, value) => next(value),
        ),
        _ => BoundString(
          dataContext: context.dataContext,
          value: raw[field],
          builder: (_, value) => next(value),
        ),
      };
    }

    return bind(0, {});
  }
}

Schema _schemaFor(String kind) => switch (kind) {
  'list' => A2uiSchemas.listOrReference(items: S.any()),
  'number' => A2uiSchemas.numberReference(),
  'bool' => A2uiSchemas.booleanReference(),
  _ => A2uiSchemas.stringReference(),
};
CatalogItem _item(
  String name,
  String description,
  Map<String, String> kinds,
  List<String> required,
  Widget Function(
    CatalogItemContext,
    Map<String, Object?>,
    Map<String, Object?>,
  )
  builder, {
  List<String> actions = const [],
  Map<String, Schema> extra = const {},
}) => CatalogItem(
  name: name,
  exampleData: [
    for (final props
        in finalizedLeftFixtures[name] ?? const <Map<String, Object?>>[])
      () => jsonEncode([
        {'id': 'root', 'component': name, ...props},
      ]),
  ],
  dataSchema: S.object(
    description: description,
    properties: {
      for (final entry in kinds.entries) entry.key: _schemaFor(entry.value),
      for (final action in actions) action: A2uiSchemas.action(),
      ...extra,
    },
    required: required,
  ),
  widgetBuilder: (context) => _FinalizedBindings(
    context: context,
    kinds: kinds,
    builder: (raw, values) => builder(context, raw, values),
  ),
);

final finalizedLeftItems = <CatalogItem>[
  _item(
    'UserMessage',
    'Right-aligned customer message; use actual typed or tapped text.',
    {'text': 'string'},
    ['text'],
    (_, raw, value) => FinalizedUserMessage(text: _str(value, 'text')),
  ),
  _item(
    'StylistMessage',
    'Plain assistant text with one idea and an explicit next step.',
    {'text': 'string'},
    ['text'],
    (_, raw, value) => FinalizedStylistMessage(text: _str(value, 'text')),
  ),
  _item(
    'ChatInput',
    'Bound draft and send action. Voice is disabled unless the host supplies microphoneAction.',
    {'value': 'string', 'placeholder': 'string'},
    ['value', 'action'],
    (context, raw, value) => FinalizedChatInput(
      value: _str(value, 'value'),
      placeholder: _str(value, 'placeholder', 'Tell me about the occasion…'),
      onChanged: (text) => _update(context, raw, 'value', text),
      onSend: (text) => _event(context, raw['action'], {'text': text}),
      onMicrophone: raw['microphoneAction'] == null
          ? null
          : () => _event(context, raw['microphoneAction'], {}),
    ),
    actions: ['action', 'microphoneAction'],
    extra: {'valuePath': S.string()},
  ),
  _item(
    'Suggestion',
    'Tappable example brief sends its exact text as a user message.',
    {'text': 'string'},
    ['text', 'action'],
    (context, raw, value) => FinalizedSuggestion(
      text: _str(value, 'text'),
      onPressed: () =>
          _event(context, raw['action'], {'text': _str(value, 'text')}),
    ),
    actions: ['action'],
  ),
  _item(
    'BudgetSlider',
    'Bound outfit budget. Retains value/min/max compatibility; default write path /budget.',
    {'value': 'number'},
    ['value', 'min', 'max'],
    (context, raw, value) => FinalizedBudgetSlider(
      value: (value['value'] as num?)?.toDouble() ?? 0,
      min: (raw['min'] as num?)?.toDouble() ?? 0,
      max: (raw['max'] as num?)?.toDouble() ?? 2000,
      onChanged: (next) {
        _update(context, raw, 'value', next, fallback: '/budget');
        _event(context, raw['action'], {'value': next});
      },
    ),
    actions: ['action'],
    extra: {'min': S.number(), 'max': S.number(), 'valuePath': S.string()},
  ),
  _item(
    'ProductCard',
    'Recommendation with six image proportions, Default/Selected states; stable select_product/remove_product actions.',
    {
      for (final field in [
        'name',
        'price',
        'brandLine',
        'tag',
        'swatch',
        'imageAsset',
        'category',
      ])
        field: 'string',
      'selected': 'bool',
    },
    ['name', 'price', 'brandLine', 'tag', 'swatch', 'action'],
    (context, raw, value) {
      final removal =
          _map(_map(raw['action'])['event'])['name'] == 'remove_product';
      return FinalizedProductCard(
        name: _str(value, 'name'),
        price: _str(value, 'price'),
        brandLine: _str(value, 'brandLine'),
        tag: _str(value, 'tag'),
        swatch: _str(value, 'swatch'),
        imageAsset: _str(value, 'imageAsset'),
        category: _str(value, 'category', 'dress'),
        selected: value['selected'] == true || removal,
        removal: removal,
        onPressed: () => _event(context, raw['action'], {}),
      );
    },
    actions: ['action'],
  ),
  _item(
    'PicksStrip',
    'Image-only product choices with real product IDs, category proportion and selected state.',
    {'products': 'list', 'category': 'string', 'selectedProductId': 'string'},
    ['products', 'action'],
    (context, raw, value) => FinalizedPicksStrip(
      products: _rows(value['products']),
      category: _str(value, 'category', 'dress'),
      selectedProductId: _str(value, 'selectedProductId'),
      onSelected: (id) {
        _update(context, raw, 'selectedProductId', id);
        _event(context, raw['action'], {'productId': id});
      },
    ),
    actions: ['action'],
    extra: {'selectedProductIdPath': S.string()},
  ),
  _item(
    'ThisOrThat',
    'Two product options, picked None/A/B, one tap returns a real product ID.',
    {'options': 'list', 'picked': 'string', 'question': 'string'},
    ['options', 'action'],
    (context, raw, value) => FinalizedThisOrThat(
      options: _rows(value['options']),
      picked: _str(value, 'picked'),
      question: _str(value, 'question', 'Which do you prefer?'),
      onSelected: (id) {
        _update(context, raw, 'picked', id);
        _event(context, raw['action'], {'productId': id});
      },
    ),
    actions: ['action'],
    extra: {'pickedPath': S.string()},
  ),
  _item(
    'ColourPicker',
    'Multi-select named colours, ring and dot, explicit selected array event.',
    {'options': 'list', 'selected': 'list', 'question': 'string'},
    ['selected', 'action'],
    (context, raw, value) => FinalizedColourPicker(
      options: raw.containsKey('options')
          ? _rows(value['options'])
          : finalizedColourOptions,
      selected: _strings(value['selected']),
      question: _str(
        value,
        'question',
        'Any colours you’re drawn to? Pick a few.',
      ),
      onChanged: (colours) {
        _update(context, raw, 'selected', colours);
        _event(context, raw['action'], {'colours': colours});
      },
    ),
    actions: ['action'],
    extra: {'selectedPath': S.string()},
  ),
  _item(
    'PhotoUpload',
    'Host-owned capture/library boundary. Never invent an upload or image analysis; choose/use/replace are explicit events. Bundled catalog imageAsset is a fixture only.',
    {
      'state': 'string',
      'photoId': 'string',
      'imageAsset': 'string',
      'description': 'string',
    },
    ['state', 'chooseAction'],
    (context, raw, value) => FinalizedPhotoUpload(
      uploaded: _str(value, 'state') == 'Uploaded',
      photo: _str(value, 'imageAsset').isEmpty
          ? null
          : CommerceProductImage(imageAsset: _str(value, 'imageAsset')),
      description: _str(value, 'description'),
      onChoose: () => _event(context, raw['chooseAction'], {}),
      onUse: raw['useAction'] == null
          ? null
          : () => _event(context, raw['useAction'], {
              'photoId': _str(value, 'photoId'),
            }),
      onReplace: raw['replaceAction'] == null
          ? null
          : () => _event(context, raw['replaceAction'], {
              'photoId': _str(value, 'photoId'),
            }),
    ),
    actions: ['chooseAction', 'useAction', 'replaceAction'],
  ),
  _item(
    'FitSize',
    'Usual size and preferred fit bind separately; host persists and applies to product availability/fit notes.',
    {'sizes': 'list', 'fits': 'list', 'size': 'string', 'fit': 'string'},
    ['size', 'fit', 'action'],
    (context, raw, value) => FinalizedFitSize(
      sizes: raw.containsKey('sizes')
          ? _strings(value['sizes'])
          : const ['34', '36', '38', '40', '42'],
      fits: raw.containsKey('fits')
          ? _strings(value['fits'])
          : const ['Fitted', 'True to size', 'Relaxed'],
      size: _str(value, 'size'),
      fit: _str(value, 'fit'),
      onSize: (size) {
        _update(context, raw, 'size', size);
        _event(context, raw['action'], {
          'size': size,
          'fit': _str(value, 'fit'),
        });
      },
      onFit: (fit) {
        _update(context, raw, 'fit', fit);
        _event(context, raw['action'], {
          'size': _str(value, 'size'),
          'fit': fit,
        });
      },
    ),
    actions: ['action'],
    extra: {'sizePath': S.string(), 'fitPath': S.string()},
  ),
  _item(
    'OccasionTimeline',
    'Editable activity/time/location segments. Host reruns recommendations from changed segments.',
    {'segments': 'list', 'selected': 'string'},
    ['segments', 'action'],
    (context, raw, value) => FinalizedOccasionTimeline(
      segments: _rows(value['segments']),
      selected: _str(value, 'selected'),
      onEdit: (segment) {
        final segments = _rows(value['segments'])
            .map((old) => old['id'] == segment['id'] ? segment : old)
            .toList();
        _update(context, raw, 'segments', segments);
        _update(context, raw, 'selected', segment['id']);
        _event(context, raw['action'], {'segment': segment});
      },
    ),
    actions: ['action'],
    extra: {'segmentsPath': S.string(), 'selectedPath': S.string()},
  ),
  _item(
    'QuickAdjust',
    'Change one selected piece, preserving the other outfit pieces; host-owned recommendation rerun.',
    {
      'productId': 'string',
      'productName': 'string',
      'imageAsset': 'string',
      'category': 'string',
      'options': 'list',
      'selected': 'string',
    },
    ['productId', 'productName', 'action'],
    (context, raw, value) => FinalizedQuickAdjust(
      productName: _str(value, 'productName'),
      imageAsset: _str(value, 'imageAsset'),
      category: _str(value, 'category', 'dress'),
      options: raw.containsKey('options')
          ? _strings(value['options'])
          : const [
              'Cheaper',
              'Dressier',
              'Warmer',
              'Another colour',
              'Shorter',
              'Something similar',
            ],
      selected: _str(value, 'selected'),
      onSelected: (adjustment) {
        _update(context, raw, 'selected', adjustment);
        _event(context, raw['action'], {
          'productId': _str(value, 'productId'),
          'category': _str(value, 'category', 'dress'),
          'adjustment': adjustment,
        });
      },
    ),
    actions: ['action'],
    extra: {'selectedPath': S.string()},
  ),
  _item(
    'BrandPreferences',
    'Disjoint love/skip lists. Love biases and skip filters host search; host owns cross-visit persistence.',
    {'brands': 'list', 'love': 'list', 'skip': 'list'},
    ['love', 'skip', 'action'],
    (context, raw, value) => FinalizedBrandPreferences(
      brands: {
        ..._strings(value['brands']),
        ..._strings(value['love']),
        ..._strings(value['skip']),
        if (!raw.containsKey('brands')) ...const [
          'The Row',
          'Toteme',
          'Zimmermann',
          'COS',
          'Gucci',
          'Balenciaga',
        ],
      }.toList(),
      love: _strings(value['love']),
      skip: _strings(value['skip']),
      onChanged: (love, skip) {
        _update(context, raw, 'love', love);
        _update(context, raw, 'skip', skip);
        _event(context, raw['action'], {'love': love, 'skip': skip});
      },
    ),
    actions: ['action'],
    extra: {'lovePath': S.string(), 'skipPath': S.string()},
  ),
  _item(
    'StylistWorking',
    'Honest host/provider work description; omit progress when no measured fraction is available.',
    {'text': 'string', 'progress': 'number'},
    ['text'],
    (_, raw, value) => FinalizedStylistWorking(
      text: _str(value, 'text'),
      progress: (value['progress'] as num?)?.toDouble(),
    ),
  ),
];

Map<String, Object?> _action(
  String name, [
  Map<String, Object?> context = const {},
]) => {
  'event': {'name': name, 'context': context},
};
const _exampleCards = [
  {
    'category': 'dress',
    'name': 'Indra Long Dress',
    'price': '€874',
    'brandLine': 'Zimmermann · Tan · Silk · Long',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'paris-dress-1',
  },
  {
    'category': 'top',
    'name': 'Silk Cami Shir',
    'price': '€290',
    'brandLine': 'Equipment · Ivory · Silk',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'example-top',
  },
  {
    'category': 'bottom',
    'name': 'Wide-leg Wool Trouser',
    'price': '€1,090',
    'brandLine': 'The Row · Black · Wool',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'example-bottom',
  },
  {
    'category': 'layer',
    'name': 'Wool Cape',
    'price': '€1,150',
    'brandLine': 'Max Mara · Camel · Wool',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'example-layer',
  },
  {
    'category': 'shoes',
    'name': 'Satin Pointed Pump',
    'price': '€545',
    'brandLine': 'Manolo Blahnik · Black · Satin · 70mm',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'paris-shoes-1',
  },
  {
    'category': 'bag',
    'name': 'Le Petit Bambino',
    'price': '€425',
    'brandLine': 'Jacquemus · Black · Leather',
    'tag': 'Most formal',
    'swatch': '#e4e4e7',
    'productId': 'example-bag',
  },
];

/// A2UI v0.9 flat component fixtures, consumed by CatalogItem.exampleData and
/// the exported runtime catalog. Placeholder recommendations are labelled as
/// design examples; host products continue to supply their actual catalog IDs.
final finalizedLeftFixtures = <String, List<Map<String, Object?>>>{
  'UserMessage': [
    {
      'text': 'Anniversary dinner at a smart restaurant in Paris in October, black tie optional, about €1,500',
    },
  ],
  'StylistMessage': [
    {
      'text': 'Perfect — anniversary in Paris in October. I’ll aim for something elegant with the option to go full black tie. Two quick things and I’ll pull options.',
    },
  ],
  'ChatInput': [
    {'value': '', 'action': _action('send_message')},
    {'value': 'A summer wedding in Lisbon', 'action': _action('send_message')},
  ],
  'Suggestion': [
    {
      'text': 'A summer wedding in Lisbon in late June: outdoor ceremony, cocktail dress code, around €1,200 for the whole outfit',
      'action': _action('send_message'),
    },
  ],
  'BudgetSlider': [
    {'value': 1500, 'min': 0, 'max': 3750},
  ],
  'ProductCard': [
    for (final row in _exampleCards)
      for (final selected in [false, true])
        {
          ...Map<String, Object?>.from(row)..remove('productId'),
          'selected': selected,
          'action': _action(selected ? 'remove_product' : 'select_product', {
            'productId': row['productId'],
          }),
        },
    {
      'name': 'Morrow Draped Top',
      'price': '€35',
      'brandLine': 'Fable Wardrobe · Brown',
      'category': 'top',
      'tag': 'Approved catalog image',
      'swatch': '#b8a98e',
      'imageAsset': 'assets/images/products/demo-0047.jpg',
      'action': _action('select_product', {'productId': 'demo-0047'}),
    },
  ],
  'PicksStrip': [
    for (final category in ['dress', 'top', 'shoes'])
      {
        'category': category,
        'selectedProductId': '',
        'products': [
          for (var i = 0; i < 3; i++)
            {
              'productId': 'design-$category-$i',
              'name': 'Design example ${i + 1}',
              'swatch': ['#b8a98e', '#3b3a38', '#e6e1d6'][i],
            },
        ],
        'action': _action('select_product'),
      },
  ],
  'ThisOrThat': [
    for (final picked in ['', 'option-a', 'option-b'])
      {
        'picked': picked,
        'options': [
          {
            'productId': 'option-a',
            'label': 'A · Satin pump',
            'category': 'shoes',
            'swatch': '#2b2a28',
          },
          {
            'productId': 'option-b',
            'label': 'B · Kitten heel',
            'category': 'shoes',
            'swatch': '#3a3835',
          },
        ],
        'action': _action('select_product'),
      },
  ],
  'ColourPicker': [
    {
      'selected': ['Black', 'Navy', 'Chocolate'],
      'action': _action('set_colours'),
    },
  ],
  'PhotoUpload': [
    {'state': 'Empty', 'chooseAction': _action('choose_photo')},
    {
      'state': 'Uploaded',
      'photoId': 'design-example-only',
      'description': 'Warm undertone · dark hair · you wear a lot of black — camel and olive would lift it.',
      'chooseAction': _action('choose_photo'),
      'useAction': _action('use_photo'),
      'replaceAction': _action('replace_photo'),
    },
  ],
  'FitSize': [
    {'size': '38', 'fit': 'True to size', 'action': _action('set_fit_size')},
  ],
  'OccasionTimeline': [
    {
      'segments': [
        {
          'id': 'ceremony',
          'time': '15:00',
          'label': 'Ceremony',
          'location': 'Outdoors',
        },
        {
          'id': 'drinks',
          'time': '17:30',
          'label': 'Drinks',
          'location': 'Terrace',
        },
        {
          'id': 'dinner',
          'time': '20:00',
          'label': 'Dinner',
          'location': 'Indoors',
        },
      ],
      'selected': 'ceremony',
      'action': _action('edit_occasion_segment'),
    },
  ],
  'QuickAdjust': [
    {
      'productId': 'paris-dress-1',
      'productName': 'Indra Long Dress',
      'category': 'dress',
      'action': _action('adjust_piece'),
    },
  ],
  'BrandPreferences': [
    {
      'love': ['The Row', 'Toteme'],
      'skip': ['Balenciaga'],
      'action': _action('set_brand_preferences'),
    },
  ],
  'StylistWorking': [
    {'text': 'Looking through 1,240 dresses under €1,500…', 'progress': .4},
    {'text': 'Looking for pieces that work together…'},
  ],
};
