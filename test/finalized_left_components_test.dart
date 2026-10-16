import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/occasion_collage_a2ui.dart';

import 'dart:convert';
import 'dart:io';

import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/finalized_left_a2ui.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/finalized_screen_examples.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui/test/validation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

Map<String, Object?> action(
  String name, [
  Map<String, Object?> context = const {},
]) => {
  'event': {'name': name, 'context': context},
};

Widget component(
  String name,
  Map<String, Object?> data, {
  double width = 400,
  double scale = 1,
  InMemoryDataModel? model,
  List<UiEvent>? events,
}) {
  final item = finalizedLeftItems.singleWhere((item) => item.name == name);
  final dataModel = model ?? InMemoryDataModel();
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(
          size: const Size(1200, 2000),
          textScaler: TextScaler.linear(scale),
        ),
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Builder(
                builder: (context) => item.widgetBuilder(
                  CatalogItemContext(
                    data: data,
                    id: 'test-root',
                    type: name,
                    buildChild: (_, [context]) => const SizedBox(),
                    dispatchEvent: (event) => events?.add(event),
                    buildContext: context,
                    dataContext: DataContext(dataModel, DataPath('/')),
                    getComponent: (_) => null,
                    getCatalogItem: (_) => null,
                    surfaceId: 'test',
                    reportError: (error, stack) => Error.throwWithStackTrace(
                      error,
                      stack ?? StackTrace.current,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final name in ['PicksStrip', 'ThisOrThat']) {
    testWidgets(
      '$name fades only unchosen alternatives and can change selection',
      (tester) async {
        final model = InMemoryDataModel();
        model.update(DataPath('/choice'), '');
        final fixture = finalizedLeftFixtures[name]!.first;
        final listKey = name == 'PicksStrip' ? 'products' : 'options';
        final selectionKey = name == 'PicksStrip'
            ? 'selectedProductId'
            : 'picked';
        final rows = (fixture[listKey] as List).cast<Map>();
        final firstId = rows.first['productId'];
        final secondId = rows[1]['productId'];
        final events = <UiEvent>[];
        await tester.pumpWidget(
          component(
            name,
            {
              ...fixture,
              selectionKey: {'path': '/choice'},
            },
            model: model,
            events: events,
          ),
        );
        await tester.pumpAndSettle();
        List<double> opacities() => tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((w) => w.opacity)
            .toList();
        expect(opacities(), everyElement(1.0));
        model.update(DataPath('/choice'), firstId);
        await tester.pump();
        expect(opacities().first, 1);
        expect(opacities().skip(1), everyElement(.45));
        await tester.pump(const Duration(milliseconds: 120));
        final fade = tester
            .widgetList<FadeTransition>(find.byType(FadeTransition))
            .last
            .opacity
            .value;
        expect(fade, greaterThan(.45));
        expect(fade, lessThan(1));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(InkWell).at(1));
        await tester.pumpAndSettle();
        expect(
          (events.single as UserActionEvent).context['productId'],
          secondId,
        );
        expect(opacities()[0], .45);
        expect(opacities()[1], 1);
        model.update(DataPath('/choice'), '');
        await tester.pumpAndSettle();
        expect(opacities(), everyElement(1.0));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'product cards preserve a clear selected state while alternatives fade',
    (tester) async {
      final model = InMemoryDataModel();
      model.update(DataPath('/selected'), false);
      model.update(DataPath('/dimmed'), false);
      await tester.pumpWidget(
        component('ProductCard', {
          ...finalizedLeftFixtures['ProductCard']!.first,
          'selected': {'path': '/selected'},
          'dimmed': {'path': '/dimmed'},
        }, model: model),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      model.update(DataPath('/dimmed'), true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        .45,
      );
      model.update(DataPath('/dimmed'), false);
      model.update(DataPath('/selected'), true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      expect(find.text('In your dressing room'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stylist emphasis renders semibold text without Markdown markers',
    (tester) async {
      await tester.pumpWidget(
        component('StylistMessage', {
          'text':
              'Choose the **Black Sheer-Panel Maxi Dress** with **a jacket**.',
        }),
      );
      await tester.pumpAndSettle();
      final message = tester.widget<Text>(
        find.descendant(
          of: find.byType(FinalizedStylistMessage),
          matching: find.byType(Text),
        ),
      );
      expect(
        message.textSpan!.toPlainText(),
        'Choose the Black Sheer-Panel Maxi Dress with a jacket.',
      );
      final spans = (message.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(
        spans
            .where((s) => s.style?.fontWeight == FontWeight.w600)
            .map((s) => s.text),
        ['Black Sheer-Panel Maxi Dress', 'a jacket'],
      );
      expect(message.style!.height, 1.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unmatched emphasis stays literal without hiding text', (
    tester,
  ) async {
    await tester.pumpWidget(
      component('StylistMessage', {'text': 'Choose **this dress'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose **this dress'), findsOneWidget);
  });
  test(
    'all 14 screen compositions validate runtime schemas and child references',
    () async {
      final catalog = buildCommerceCatalog().copyWith(
        newItems: finalizedScreenItems,
      );
      expect(finalizedScreenExamples.length, 14);
      for (final screen in finalizedScreenExamples) {
        for (final rows in [
          screen.chatComponents(),
          screen.roomComponents(),
          screen.overlayComponents(),
          screen.components(),
          screen.components(portrait: true),
        ]) {
          final ids = rows.map((r) => r['id']).toSet();
          expect(ids.length, rows.length, reason: screen.id);
          for (final row in rows) {
            final item = catalog.items.singleWhere(
              (i) => i.name == row['component'],
            );
            final errors = await item.dataSchema.validate(
              row,
              schemaRegistry: createSchemaRegistryWithCommonTypes(),
            );
            expect(
              errors,
              isEmpty,
              reason: '${screen.id} ${row['component']}: $errors',
            );
            if (row['children'] is List) {
              for (final child in row['children'] as List) {
                expect(
                  ids.contains(child),
                  isTrue,
                  reason: '${screen.id}: $child',
                );
              }
            }
          }
        }
      }
    },
  );

  testWidgets(
    'QuickAdjust emits bound category with stable product and adjustment',
    (tester) async {
      final model = InMemoryDataModel();
      model.update(DataPath('/category'), 'shoes');
      final events = <UiEvent>[];
      await tester.pumpWidget(
        component(
          'QuickAdjust',
          {
            ...finalizedLeftFixtures['QuickAdjust']!.first,
            'category': {'path': '/category'},
          },
          model: model,
          events: events,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Cheaper'));
      await tester.pump();
      expect((events.single as UserActionEvent).context, {
        'productId': 'paris-dress-1',
        'category': 'shoes',
        'adjustment': 'Cheaper',
      });
    },
  );

  testWidgets('maximum-text product tag stays outside clipped shoe image', (
    tester,
  ) async {
    await tester.pumpWidget(
      component(
        'ProductCard',
        {
          ...finalizedLeftFixtures['ProductCard']!.first,
          'category': 'shoes',
          'tag': 'Best for all day',
        },
        width: 280,
        scale: 3.117,
      ),
    );
    await tester.pump();
    final tag = tester.getRect(
      find.byKey(const ValueKey('finalized-product-tag')),
    );
    final image = tester.getRect(
      find.byKey(const ValueKey('finalized-product-image')),
    );
    final text = tester.getRect(find.text('Best for all day'));
    expect(tag.bottom, lessThanOrEqualTo(image.top));
    expect(tag.contains(text.topLeft), isTrue);
    expect(tag.contains(text.bottomRight - const Offset(.001, .001)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'external chat draft retains selection and host ownership when disabled',
    (tester) async {
      final controller = TextEditingController.fromValue(
        const TextEditingValue(
          text: 'Draft',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      Widget host(bool enabled) => MaterialApp(
        home: Scaffold(
          body: FinalizedChatInput(
            externalController: controller,
            value: 'Never overwrite',
            enabled: enabled,
            fieldKey: const ValueKey('host-field'),
            submitLabel: 'Continue',
            onSend: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(host(true));
      expect(controller.text, 'Draft');
      expect(controller.selection.baseOffset, 2);
      final send = find.byKey(const ValueKey('stylist-submit-Continue'));
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
      await tester.pumpWidget(host(false));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('host-field')))
            .enabled,
        isFalse,
      );
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
      controller.text = 'Still host-owned';
      expect(controller.text, 'Still host-owned');
      controller.dispose();
    },
  );

  test(
    'every design variant fixture validates against its actual runtime schema',
    () async {
      expect(finalizedLeftItems.length, 15);
      for (final item in finalizedLeftItems) {
        expect(item.exampleData, isNotEmpty, reason: item.name);
        for (final example in item.exampleData) {
          final rows = jsonDecode(example()) as List;
          expect(rows.single['id'], 'root');
          final errors = await item.dataSchema.validate(
            rows.single,
            schemaRegistry: createSchemaRegistryWithCommonTypes(),
          );
          expect(errors, isEmpty, reason: '${item.name}: $errors');
        }
      }
      expect(
        finalizedLeftItems
            .singleWhere((item) => item.name == 'ProductCard')
            .exampleData
            .length,
        13,
      );
      expect(
        finalizedLeftItems
            .singleWhere((item) => item.name == 'ThisOrThat')
            .exampleData
            .length,
        3,
      );
      expect(
        finalizedLeftItems
            .singleWhere((item) => item.name == 'PhotoUpload')
            .exampleData
            .length,
        2,
      );
    },
  );

  for (final width in [280.0, 400.0, 700.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all left design variants fit $width pane at ${scale * 100}% text',
        (tester) async {
          for (final item in finalizedLeftItems) {
            for (final example in item.exampleData) {
              final props = Map<String, Object?>.from(
                (jsonDecode(example()) as List).single as Map,
              );
              await tester.pumpWidget(
                component(item.name, props, width: width, scale: scale),
              );
              await tester.pump(const Duration(milliseconds: 80));
              expect(
                tester.takeException(),
                isNull,
                reason: '${item.name} $props',
              );
            }
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'fit size writes supplied paths and preserves configured event context',
    (tester) async {
      final model = InMemoryDataModel();
      model.update(DataPath('/preferences'), {
        'size': '38',
        'fit': 'True to size',
      });
      final events = <UiEvent>[];
      await tester.pumpWidget(
        component(
          'FitSize',
          {
            'size': {'path': '/preferences/size'},
            'fit': {'path': '/preferences/fit'},
            'action': action('set_fit_size', {'session': 'retained'}),
          },
          model: model,
          events: events,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('40'));
      await tester.pump();
      expect(model.getValue<String>(DataPath('/preferences/size')), '40');
      expect((events.single as UserActionEvent).context, {
        'session': 'retained',
        'size': '40',
        'fit': 'True to size',
      });
      await tester.tap(find.text('Relaxed'));
      await tester.pump();
      expect(model.getValue<String>(DataPath('/preferences/fit')), 'Relaxed');
      expect((events.last as UserActionEvent).context['size'], '40');
      model.dispose();
    },
  );

  testWidgets(
    'literal gallery colour choices toggle locally and bound choices update array',
    (tester) async {
      final events = <UiEvent>[];
      await tester.pumpWidget(
        component('ColourPicker', {
          'selected': ['Black'],
          'action': action('set_colours'),
        }, events: events),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Navy'));
      await tester.pump();
      expect(find.text('2 chosen · Black, Navy'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Black'));
      await tester.pump();
      expect(find.text('1 chosen · Navy'), findsOneWidget);
      expect((events.last as UserActionEvent).context['colours'], ['Navy']);
      final model = InMemoryDataModel();
      model.update(DataPath('/colours'), ['Black']);
      await tester.pumpWidget(
        component('ColourPicker', {
          'selected': {'path': '/colours'},
          'action': action('set_colours'),
        }, model: model),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Navy'));
      await tester.pump();
      expect(model.getValue<List>(DataPath('/colours')), ['Black', 'Navy']);
      model.dispose();
    },
  );

  testWidgets(
    'chat cannot send whitespace; entered draft binds and emits actual text',
    (tester) async {
      final model = InMemoryDataModel();
      model.update(DataPath('/draft'), '');
      final events = <UiEvent>[];
      await tester.pumpWidget(
        component(
          'ChatInput',
          {
            'value': {'path': '/draft'},
            'action': action('send_message'),
          },
          model: model,
          events: events,
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('stylist-submit-Send message')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('stylist-submit-Send message')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '  Paris dinner  ');
      await tester.pump();
      expect(model.getValue<String>(DataPath('/draft')), '  Paris dinner  ');
      await tester.tap(
        find.byKey(const ValueKey('stylist-submit-Send message')),
      );
      await tester.pump();
      expect((events.single as UserActionEvent).context, {
        'text': 'Paris dinner',
      });
      model.dispose();
    },
  );

  testWidgets(
    'timeline editor saves only edited segment and cancels without dispatch',
    (tester) async {
      final model = InMemoryDataModel();
      model.update(DataPath('/day'), [
        {
          'id': 'ceremony',
          'time': '15:00',
          'label': 'Ceremony',
          'location': 'Outdoors',
        },
        {
          'id': 'dinner',
          'time': '20:00',
          'label': 'Dinner',
          'location': 'Indoors',
        },
      ]);
      final events = <UiEvent>[];
      await tester.pumpWidget(
        component(
          'OccasionTimeline',
          {
            'segments': {'path': '/day'},
            'action': action('edit_occasion_segment'),
          },
          model: model,
          events: events,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Ceremony'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'Indoors');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final day = model.getValue<List>(DataPath('/day'))!;
      expect(day[0]['location'], 'Indoors');
      expect(day[1]['time'], '20:00');
      expect((events.single as UserActionEvent).context['segment'], day[0]);
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(events.length, 1);
      expect(tester.takeException(), isNull);
      model.dispose();
    },
  );

  testWidgets(
    'brand list toggles remain disjoint and custom brand input updates local state',
    (tester) async {
      final events = <UiEvent>[];
      await tester.pumpWidget(
        component('BrandPreferences', {
          'brands': ['The Row', 'COS'],
          'love': ['The Row'],
          'skip': [],
          'action': action('set_brand_preferences'),
        }, events: events),
      );
      await tester.pump();
      await tester.tap(find.text('COS').last);
      await tester.pump();
      expect((events.last as UserActionEvent).context['love'], ['The Row']);
      expect((events.last as UserActionEvent).context['skip'], ['COS']);
      await tester.ensureVisible(find.text('+ Add'));
      await tester.tap(find.text('+ Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Alder');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect((events.last as UserActionEvent).context['love'], [
        'The Row',
        'Alder',
      ]);
      expect(find.text('Alder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo actions emit host requests and never synthesize uploaded state',
    (tester) async {
      final events = <UiEvent>[];
      await tester.pumpWidget(
        component('PhotoUpload', {
          'state': 'Empty',
          'chooseAction': action('choose_photo'),
        }, events: events),
      );
      await tester.pump();
      await tester.tap(find.text('Take a photo or choose from your library'));
      await tester.pump();
      expect((events.single as UserActionEvent).name, 'choose_photo');
      expect(find.text('Use it'), findsNothing);
      await tester.pumpWidget(
        component('PhotoUpload', {
          'state': 'Uploaded',
          'photoId': 'fixture-photo',
          'description': 'Host supplied note',
          'chooseAction': action('choose_photo'),
          'useAction': action('use_photo'),
          'replaceAction': action('replace_photo'),
        }, events: events),
      );
      await tester.pump();
      await tester.tap(find.text('Use it'));
      await tester.pump();
      expect((events.last as UserActionEvent).context, {
        'photoId': 'fixture-photo',
      });
    },
  );

  testWidgets('selection and removal preserve stable product IDs', (
    tester,
  ) async {
    final events = <UiEvent>[];
    final data = {
      ...finalizedLeftFixtures['ProductCard']!.first,
      'action': action('select_product', {'productId': 'paris-dress-1'}),
    };
    await tester.pumpWidget(component('ProductCard', data, events: events));
    await tester.pump();
    await tester.tap(find.text('Add to dressing room'));
    await tester.pump();
    expect((events.single as UserActionEvent).name, 'select_product');
    expect((events.single as UserActionEvent).context, {
      'productId': 'paris-dress-1',
    });
    await tester.pumpWidget(
      component('ProductCard', {
        ...data,
        'selected': true,
        'action': action('remove_product', {'productId': 'paris-dress-1'}),
      }, events: events),
    );
    await tester.pump();
    await tester.tap(find.text('Remove'));
    await tester.pump();
    expect((events.last as UserActionEvent).name, 'remove_product');
  });

  test(
    'every exact Figma asset is bundled and has its intrinsic root dimensions',
    () {
      for (final entry in FinalizedLeftIcon.dimensions.entries) {
        final file = File('assets/icons/finalized_left/${entry.key}');
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(0));
        final root = RegExp(r'<svg\b[^>]*>')
            .firstMatch(file.readAsStringSync())!
            .group(0)!;
        for (final attr in ['width', 'height']) {
          final raw = RegExp('$attr="([^"]+)"').firstMatch(root)!.group(1)!;
          expect(
            double.parse(raw),
            closeTo(
              attr == 'width' ? entry.value.width : entry.value.height,
              .0001,
            ),
          );
        }
      }
    },
  );
}
