import 'package:a2ui_flutter_commerce/src/catalog/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/src/layout/adaptive_pane_layout.dart';
import 'package:a2ui_flutter_commerce/src/theme.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

import 'protocol_fixture_helpers.dart';

void main() {
  test('display casing preserves names and raw catalog facts', () {
    const product = Product(
      id: 'p',
      category: ProductCategory.layer,
      name: 'eBay x Fable',
      brand: 'i-D Studio',
      price: 50,
      meta: 'tan · cotton blend',
      tag: 'evening',
      swatch: '#fff',
      color: 'tan',
      material: 'cotton blend',
    );
    expect(product.brandLine, 'i-D Studio · Tan · Cotton blend');
    expect(product.name, 'eBay x Fable');
    expect(product.color, 'tan');
    expect(product.material, 'cotton blend');
    expect(displayDetail('evening'), 'Evening');
    expect(displayDetail(''), '');
  });
  for (final category in ['dress', 'top', 'bottom', 'layer', 'shoes', 'bag']) {
    testWidgets(
      '$category recommendations keep the same card and image geometry',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 411,
                  child: FinalizedProductCard(
                    name: 'Knit',
                    price: '€85',
                    brandLine: 'Wool',
                    tag: 'evening',
                    category: category,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Evening'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('finalized-product-image'))),
          const Size(104, 104),
        );
        expect(
          tester.getSize(find.byType(FinalizedProductCard)).height,
          closeTo(122, .01),
        );
        final card = tester.getRect(find.byType(FinalizedProductCard));
        expect(
          tester.getRect(find.text('Add to dressing room')).right,
          closeTo(card.right - 9, .01),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact recommendations scroll to the same bound product action',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(466, 678);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = ProtocolFixtureHarness();
      addTearDown(harness.dispose);
      harness.publish('recommendations');
      Widget view(double scale) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AdaptivePaneScope(
            isSplit: false,
            child: MediaQuery(
              data: MediaQueryData(
                size: const Size(466, 678),
                textScaler: TextScaler.linear(scale),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Surface(
                    surfaceContext: harness.controller.contextFor('inline-1'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view(1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('recommendation-carousel')),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('recommendation-carousel')),
        const Offset(-420, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FinalizedProductCard).last);
      await tester.pumpAndSettle();
      expect(harness.submittedAction['context'], {'productId': 'demo-0002'});
      await tester.pumpWidget(view(3.12));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('recommendation-carousel')),
        findsNothing,
      );
      expect(find.text('Solstice Brown Knit Top'), findsOneWidget);
      expect(find.text('Arc Forest Ribbed Cardigan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
