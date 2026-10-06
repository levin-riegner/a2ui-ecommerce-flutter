import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/catalog/finalized_screen_examples.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_screen_gallery.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_shared_components.dart';
import 'package:a2ui_flutter_commerce/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

Widget _gallery({double scale = 1, int index = 0, bool controls = true}) =>
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: FinalizedScreenGallery(initialIndex: index, showControls: controls),
    );

void main() {
  testWidgets(
    'brief choices update bound state and submit the preserved budget/draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(951, 669));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final index = finalizedScreenExamples.indexWhere((e) => e.id == 'brief');
      await tester.pumpWidget(_gallery(index: index));
      await tester.pumpAndSettle();
      final state = tester.state<FinalizedScreenGalleryState>(
        find.byType(FinalizedScreenGallery),
      );
      final chat = state.controller.contextFor(state.id('chat')).dataModel;
      final composer = state.controller
          .contextFor(state.id('composer'))
          .dataModel;
      chat.update(DataPath('/budget'), 1600);
      composer.update(DataPath('/draft'), 'Keep my draft');
      await tester.pumpAndSettle();
      for (final label in ['Cocktail', 'Summer']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(chat.getValue<String>(DataPath('/dressCode')), 'cocktail');
      expect(chat.getValue<String>(DataPath('/season')), 'summer');
      expect(chat.getValue<num>(DataPath('/budget')), 1600);
      expect(composer.getValue<String>(DataPath('/draft')), 'Keep my draft');
      for (final label in ['Cocktail', 'Summer', 'Black tie', 'Autumn']) {
        final chip = tester.widget<FinalizedChip>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(FinalizedChip),
              )
              .first,
        );
        expect(chip.selected, ['Cocktail', 'Summer'].contains(label));
      }
      await tester.ensureVisible(find.text('Find options'));
      await tester.tap(find.text('Find options'));
      await tester.pumpAndSettle();
      final event = (jsonDecode(state.action) as Map)['action'] as Map;
      expect(event['name'], 'find_options');
      expect(event['context'], {
        'budget': 1600,
        'dressCode': 'cocktail',
        'season': 'summer',
      });
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('screen-preview-action')))
            .data,
        state.action,
      );
      expect(tester.takeException(), isNull);
      state.select(finalizedScreenExamples.indexWhere((e) => e.id == 'start'));
      await tester.pumpAndSettle();
      expect(state.controller.activeSurfaceIds, hasLength(3));
      expect(
        state.controller.activeSurfaceIds.every(
          (id) => id.startsWith('design-1-'),
        ),
        isTrue,
      );
    },
  );

  testWidgets('native preview can hide all inspection controls', (
    tester,
  ) async {
    await tester.pumpWidget(_gallery(controls: false));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.byKey(const ValueKey('screen-preview-action')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(466, 678),
    const Size(669, 951),
    const Size(951, 669),
  ]) {
    for (final scale in [1.0, 3.12]) {
      testWidgets('all 14 screen surfaces render at $size / $scale text', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_gallery(scale: scale));
        await tester.pumpAndSettle();
        final state = tester.state<FinalizedScreenGalleryState>(
          find.byType(FinalizedScreenGallery),
        );
        for (var index = 0; index < finalizedScreenExamples.length; index++) {
          state.select(index);
          await tester.pumpAndSettle();
          final error = tester.takeException();
          expect(
            error,
            isNull,
            reason:
                '${finalizedScreenExamples[index].id}: ${error is FlutterError ? error.diagnostics.map((d) => d.toStringDeep()).join('\n') : error}',
          );
        }
      });
    }
  }
}
