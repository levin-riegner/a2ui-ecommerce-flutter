import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import '../shared/layout/adaptive_pane_layout.dart';
import '../stylist/a2ui/catalog/commerce_catalog.dart';
import '../shared/design_system/views/commerce/commerce_components.dart';
import 'finalized_screen_examples.dart';

/// Executable design examples with native Duo geometry and independent panes.
/// Fixtures emit observable events and never connect a provider or checkout.
class FinalizedScreenGallery extends StatefulWidget {
  const FinalizedScreenGallery({
    super.key,
    this.initialIndex = 0,
    this.showControls = true,
  });
  final int initialIndex;
  final bool showControls;
  @override
  State<FinalizedScreenGallery> createState() => FinalizedScreenGalleryState();
}

class FinalizedScreenGalleryState extends State<FinalizedScreenGallery> {
  late int index = widget.initialIndex;
  late final catalog = buildCommerceCatalog();
  late final controller = SurfaceController(catalogs: [catalog]);
  late final StreamSubscription<ChatMessage> subscription;
  int revision = 0;
  String action = '';
  bool overlayVisible = true;
  bool hasComposer = false;
  final choiceGroups = <String, Map<String, String>>{};
  String id(String pane) => 'design-$revision-$pane';
  FinalizedScreenExample get example => finalizedScreenExamples[index];

  @override
  void initState() {
    super.initState();
    subscription = controller.onSubmit.listen((message) {
      if (!mounted) return;
      final interactions = message.parts
          .where((part) => part.isUiInteractionPart)
          .map((part) => part.asUiInteractionPart?.interaction ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
      for (final interaction in interactions) {
        final payload = jsonDecode(interaction) as Map;
        final event = payload['action'] as Map?;
        final context = event?['context'] as Map?;
        if (event?['name'] == 'set_brief_choice' && context != null) {
          final field = context['field'];
          final value = context['value'];
          final choices = choiceGroups[field];
          if (field is String &&
              value is String &&
              choices != null &&
              choices.containsValue(value)) {
            final model = controller.contextFor(id('chat')).dataModel;
            model.update(DataPath('/$field'), value);
            for (final choice in choices.entries) {
              model.update(
                DataPath('/previewChoices/${choice.key}'),
                choice.value == value,
              );
            }
          }
        }
      }
      setState(() => action = interactions.join('\n'));
    });
    publish();
  }

  void publishPane(
    String pane,
    List<Map<String, Object?>> components, {
    Map<String, Object?>? data,
  }) {
    for (final message in [
      {
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': id(pane),
          'catalogId': commerceCatalogId,
        },
      },
      {
        'version': 'v0.9',
        'updateComponents': {'surfaceId': id(pane), 'components': components},
      },
      {
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': id(pane),
          'value': data ?? example.data,
        },
      },
    ]) {
      controller.handleMessage(core.A2uiMessage.fromJson(message));
    }
  }

  void publish() {
    final chat = example.chatComponents();
    final data = example.data;
    final selectedChoices = <String, Object?>{};
    choiceGroups.clear();
    for (final row in chat) {
      final definition = row['action'];
      final event = definition is Map ? definition['event'] : null;
      if (row['component'] != 'ChoiceChip' ||
          event is! Map ||
          event['name'] != 'set_brief_choice') {
        continue;
      }
      final label = row['label']! as String;
      final field = _choiceField(label);
      if (field == null) continue;
      final value = label.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      final componentId = row['id']! as String;
      (choiceGroups[field] ??= {})[componentId] = value;
      if (row['selected'] == true &&
          !choiceGroups[field]!.containsValue(data[field])) {
        data[field] = value;
      }
      selectedChoices[componentId] = row['selected'] == true;
      row['selected'] = {'path': '/previewChoices/$componentId'};
      row['action'] = {
        'event': {
          'name': 'set_brief_choice',
          'context': {'field': field, 'value': value},
        },
      };
    }
    for (final choices in choiceGroups.entries) {
      for (final choice in choices.value.entries) {
        selectedChoices[choice.key] = choice.value == data[choices.key];
      }
    }
    data['previewChoices'] = selectedChoices;
    final root = chat.first;
    final children = List<String>.from(root['children']! as List);
    final composer = chat
        .where((row) => row['component'] == 'ChatInput')
        .firstOrNull;
    hasComposer = composer != null;
    if (composer != null) {
      children.remove(composer['id']);
      chat.remove(composer);
      publishPane('composer', [
        {...composer, 'id': 'root'},
      ]);
    }
    // The brand is a host header, rather than a caption inside the chat.
    final brand = chat
        .where((row) => row['component'] == 'Text' && row['text'] == 'ALDER')
        .firstOrNull;
    if (brand != null) {
      children.remove(brand['id']);
      chat.remove(brand);
    }
    root['children'] = children;
    publishPane('chat', chat, data: data);
    final room = example.roomComponents();
    // The collage fills its pane. A wrapping Column would give it unbounded
    // height and expand it beyond the actual landscape pane.
    publishPane(
      'room',
      room.length == 2 && room.last['component'] == 'OccasionCollage'
          ? [
              {...room.last, 'id': 'root'},
            ]
          : room,
    );
    if (example.hasOverlay) publishPane('overlay', example.overlayComponents());
  }

  void select(int value) {
    if (value < 0 || value >= finalizedScreenExamples.length) {
      throw RangeError.index(value, finalizedScreenExamples);
    }
    for (final pane in ['chat', 'room', 'composer', 'overlay']) {
      if (controller.activeSurfaceIds.contains(id(pane))) {
        controller.handleMessage(
          core.A2uiMessage.fromJson({
            'version': 'v0.9',
            'deleteSurface': {'surfaceId': id(pane)},
          }),
        );
      }
    }
    setState(() {
      index = value;
      revision++;
      action = '';
      overlayVisible = true;
      publish();
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    controller.dispose();
    super.dispose();
  }

  Widget surface(String pane) => Surface(
    key: ValueKey(id(pane)),
    surfaceContext: controller.contextFor(id(pane)),
  );

  Widget dock(Widget child, double maxHeight) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(child: child),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          AdaptivePaneLayout(
            secondaryBackgroundOnlyInBookMode: true,
            secondaryBackgroundColor: example.id == 'start'
                ? null
                : Colors.black,
            compactSecondaryFirst: example.id != 'start',
            secondaryScrollable: example.id != 'start',
            header: dock(
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showControls)
                      DropdownButton<int>(
                        isExpanded: true,
                        itemHeight:
                            56 *
                            MediaQuery.textScalerOf(context).scale(14) /
                            14,
                        value: index,
                        items: [
                          for (
                            var i = 0;
                            i < finalizedScreenExamples.length;
                            i++
                          )
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                finalizedScreenExamples[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) select(value);
                        },
                      ),
                    Row(
                      children: [
                        if (widget.showControls)
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        Container(
                          color: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: const Text(
                            'ALDER',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              constraints.maxHeight * .30,
            ),
            primary: surface('chat'),
            footer: dock(
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasComposer) surface('composer'),
                    if (widget.showControls)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 96),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            action.isEmpty
                                ? 'Tap a control to inspect its A2UI action'
                                : action,
                            key: const ValueKey('screen-preview-action'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              constraints.maxHeight * .40,
            ),
            secondary: example.id == 'start'
                ? surface('room')
                : Builder(
                    builder: (context) => CommerceDressingRoomStyle(
                      dark: true,
                      compact: !AdaptivePaneScope.isSplitOf(context),
                      child: Container(
                        color: Colors.black,
                        child: surface('room'),
                      ),
                    ),
                  ),
          ),
          if (example.hasOverlay && overlayVisible)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Close preview',
                              onPressed: () =>
                                  setState(() => overlayVisible = false),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          surface('overlay'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

String? _choiceField(String label) => switch (label.trim()) {
  'Black tie' ||
  'Cocktail' ||
  'Smart Elegant' ||
  'Polished' ||
  'Relaxed' ||
  'A bit bold' => 'dressCode',
  'Spring' || 'Summer' || 'Autumn' || 'Winter' => 'season',
  'Trousers + Shirt' || 'Denim' || 'A dress' => 'foundation',
  'Yes' || 'No' => 'walking',
  'An hour or two' || 'Half days' || 'All day' => 'walkingDuration',
  'Yes, a pub' || 'Something nicer' || 'Just walking' => 'destination',
  _ => null,
};
