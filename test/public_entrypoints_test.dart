import 'package:a2ui_flutter_commerce/commerce_ui.dart' as ui;
import 'package:a2ui_flutter_commerce/commerce_a2ui.dart' as a2ui;
import 'package:a2ui_flutter_commerce/commerce_gallery.dart' as gallery;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public presentation widgets work with explicit callbacks', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ui.FinalizedPrimaryButton(
                label: 'Continue',
                onPressed: () => taps++,
              ),
              const ui.OccasionArtwork(seed: 1, width: 120, height: 160),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
    expect(find.byType(ui.OccasionArtwork), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('A2UI and galleries remain explicit opt-in entry points', () {
    final names = a2ui
        .buildCommerceCatalog()
        .items
        .map((item) => item.name)
        .toSet();
    expect(names, containsAll(['ProductCard', 'PieceSlot', 'OccasionCollage']));
    expect(gallery.commerceComponentExamples, isNotEmpty);
    expect(gallery.finalizedScreenExamples, isNotEmpty);
  });
}
