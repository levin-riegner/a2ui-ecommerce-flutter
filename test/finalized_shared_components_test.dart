import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_bindings_a2ui.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_shared_components.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/finalized_shared_a2ui.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genui/genui.dart';
import 'package:genui/test/validation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

Widget harness(Widget child, {double scale = 1, double width = 320}) =>
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  test(
    'every shared example validates against the registered A2UI schema',
    () async {
      for (final item in finalizedSharedItems) {
        for (final example in item.exampleData) {
          final props = (jsonDecode(example()) as List).single;
          expect(
            await item.dataSchema.validate(
              props,
              schemaRegistry: createSchemaRegistryWithCommonTypes(),
            ),
            isEmpty,
            reason: '${item.name}: $props',
          );
        }
      }
    },
  );
  test(
    'replacement contracts preserve value types and allow bound chip drafts',
    () {
      for (final old in [
        chipCatalogItem,
        primaryButtonCatalogItem,
        eyebrowCatalogItem,
      ]) {
        final item = finalizedSharedItems.singleWhere(
          (i) => i.name == old.name,
        );
        expect(
          item.dataSchema.value['properties'],
          old.dataSchema.value['properties'],
        );
        if (old.name == 'ChoiceChip') {
          expect(item.dataSchema.value['required'], contains('label'));
          expect(item.dataSchema.value['required'], isNot(contains('action')));
        } else {
          expect(
            item.dataSchema.value['required'],
            old.dataSchema.value['required'],
          );
        }
      }
      expect(finalizedSharedItems.map((i) => i.name).toSet(), hasLength(10));
    },
  );

  testWidgets('chip toggles locally and button includes full 48 px target', (
    tester,
  ) async {
    final values = <bool>[];
    var taps = 0;
    await tester.pumpWidget(
      harness(
        Column(
          children: [
            FinalizedChip(label: 'Black tie', onChanged: values.add),
            FinalizedPrimaryButton(
              label: 'Find options',
              onPressed: () => taps++,
            ),
          ],
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(InkWell).last).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Black tie'));
    await tester.pump();
    await tester.tap(find.text('Black tie'));
    await tester.pump();
    expect(values, [true, false]);
    final rect = tester.getRect(find.byType(InkWell).last);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 1));
    expect(taps, 1);
  });

  testWidgets('quantity is bounded and one decrement removes once', (
    tester,
  ) async {
    final quantities = <int>[];
    var removes = 0;
    await tester.pumpWidget(
      harness(
        FinalizedQuantityStepper(
          value: 1,
          max: 2,
          onChanged: quantities.add,
          onRemove: () => removes++,
        ),
      ),
    );
    await tester.tap(find.text('+'));
    await tester.pump();
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(quantities, [2]);
    await tester.tap(find.text('−'));
    await tester.pump();
    await tester.tap(find.text('−'));
    await tester.pump();
    await tester.tap(find.text('−'));
    await tester.pump();
    expect(quantities, [2, 1]);
    expect(removes, 1);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('shared controls fit narrow panes with maximum Duo text', (
    tester,
  ) async {
    for (final widget in <Widget>[
      FinalizedPrimaryButton(
        label: 'Find options for a longer occasion',
        onPressed: () {},
      ),
      FinalizedChip(label: 'Country wedding with friends', onChanged: (_) {}),
      const FinalizedEyebrow(text: 'How formal should the whole outfit be?'),
      FinalizedToast(
        message: 'Four items added to your bag',
        actionLabel: 'View bag',
        onPressed: () {},
      ),
      FinalizedQuantityStepper(value: 99, max: 999, onChanged: (_) {}),
      FinalizedBagIcon(count: 999, onPressed: () {}),
    ]) {
      await tester.pumpWidget(harness(widget, width: 220, scale: 3.12));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: widget.runtimeType.toString(),
      );
    }
  });

  testWidgets(
    'native category slots retain category proportions and exact glyph assets',
    (tester) async {
      for (final category in finalizedCategories) {
        await tester.pumpWidget(
          harness(
            FinalizedLookTile(category: category, label: '$category slot'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(
                find.byWidgetPredicate(
                  (widget) => widget is SizedBox && widget.width == 120,
                ),
              )
              .width,
          120,
        );
        expect(
          tester.getSize(find.byType(FinalizedLookTile)).height,
          FinalizedLookTile.heights[category],
        );
        expect(tester.takeException(), isNull);
        final tile = find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 120,
        );
        expect(
          tester.getSize(find.byType(SvgPicture)),
          FinalizedLookTile.glyphSizes[category],
        );
        expect(
          tester.getTopLeft(find.byType(SvgPicture)) - tester.getTopLeft(tile),
          FinalizedLookTile.origins[category],
        );
        expect(
          File('assets/icons/finalized_shared/look-$category.svg').lengthSync(),
          greaterThan(0),
        );
        expect(
          File('assets/icons/finalized_shared/silhouette-$category.svg')
              .lengthSync(),
          greaterThan(0),
        );
      }
    },
  );

  testWidgets(
    'all manifest fixtures ingest and dispatch resolved stable JSON actions',
    (tester) async {
      final manifest = jsonDecode(
        File('docs/design/finalized-shared.json').readAsStringSync(),
      ) as Map;
      final catalog = buildCommerceCatalog().copyWith(
        newItems: finalizedSharedItems,
      );
      for (final fixture in manifest['fixtures'] as List) {
        final sent = <ChatMessage>[];
        final controller = SurfaceController(catalogs: [catalog]);
        final transport = A2uiTransportAdapter(
          onSend: (m) async => sent.add(m),
        );
        final conversation = Conversation(
          controller: controller,
          transport: transport,
        );
        addTearDown(conversation.dispose);
        addTearDown(controller.dispose);
        for (final msg in fixture['messages'] as List) {
          transport.addMessage(
            core.A2uiMessage.fromJson(Map<String, dynamic>.from(msg as Map)),
          );
        }
        await tester.pumpWidget(
          harness(
            Surface(
              surfaceContext: controller.contextFor(
                fixture['surfaceId'] as String,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: fixture['name'].toString(),
        );
        if (fixture['name'] == 'shared-primary-and-eyebrow') {
          expect(find.text('How formal?'), findsOneWidget);
          await tester.tap(find.text('Find options'));
          await tester.pumpAndSettle();
          expect(sent, hasLength(1));
          final payload = jsonDecode(
            sent.single.parts.uiInteractionParts.single.interaction,
          ) as Map;
          expect(payload['action']['name'], 'find_options');
          expect(payload['action']['context'], {
            'occasion': 'Berlin first day',
          });
        }
        if (fixture['name'] == 'shared-quantity') {
          await tester.tap(find.text('+'));
          await tester.pumpAndSettle();
          expect(
            controller
                .contextFor(fixture['surfaceId'] as String)
                .dataModel
                .getValue<num>(DataPath('/quantity')),
            2,
          );
          final payload = jsonDecode(
            sent.single.parts.uiInteractionParts.single.interaction,
          ) as Map;
          expect(payload['action']['name'], 'change_quantity');
          expect(payload['action']['context'], {
            'productId': 'demo-0001',
            'quantity': 2,
          });
        }
      }
    },
  );
  testWidgets('every catalog example ingests without a prototype renderer', (
    tester,
  ) async {
    final catalog = buildCommerceCatalog().copyWith(
      newItems: finalizedSharedItems,
    );
    var exampleCount = 0;
    for (final item in finalizedSharedItems) {
      expect(item.exampleData, isNotEmpty, reason: item.name);
      for (final example in item.exampleData) {
        final components = jsonDecode(example()) as List;
        final sid = 'shared-example-${exampleCount++}';
        final controller = SurfaceController(catalogs: [catalog]);
        final transport = A2uiTransportAdapter(onSend: (_) async {});
        final conversation = Conversation(
          controller: controller,
          transport: transport,
        );
        addTearDown(conversation.dispose);
        addTearDown(controller.dispose);
        transport.addMessage(
          core.A2uiMessage.fromJson({
            'version': 'v0.9',
            'createSurface': {'surfaceId': sid, 'catalogId': commerceCatalogId},
          }),
        );
        transport.addMessage(
          core.A2uiMessage.fromJson({
            'version': 'v0.9',
            'updateComponents': {'surfaceId': sid, 'components': components},
          }),
        );
        await tester.pumpWidget(
          harness(Surface(surfaceContext: controller.contextFor(sid))),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${item.name} example $sid',
        );
      }
    }
    expect(exampleCount, 32); // Accessory LookTile and silhouette examples.
  });

  test('manifest exact static SVG roots agree with local files', () {
    final manifest = jsonDecode(
      File('docs/design/finalized-shared.json').readAsStringSync(),
    ) as Map;
    var assetCount = 0;
    for (final item in manifest['components'] as List) {
      for (final asset in item['assetMappings'] as List) {
        final file = File(asset['asset'] as String);
        expect(file.lengthSync(), greaterThan(0));
        final root = RegExp(r'<svg\s[^>]+>')
            .firstMatch(file.readAsStringSync())!
            .group(0)!;
        expect(root, contains('width="${asset['rootWidth']}"'));
        expect(root, contains('height="${asset['rootHeight']}"'));
        assetCount++;
      }
    }
    expect(assetCount, 18);
  });
}
