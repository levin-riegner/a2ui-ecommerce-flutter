import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/commerce_components.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/commerce_examples.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget harness(Widget child, {double width = 320, double scale = 1}) =>
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: const Size(1200, 900),
            textScaler: TextScaler.linear(scale),
          ),
          child: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );

void main() {
  test('example vocabulary matches all registered commerce components', () {
    final names = commerceComponentExamples
        .map((example) => example.name)
        .toSet();
    expect(names.length, 9);
    final registered = buildCommerceCatalog().items
        .map((item) => item.name)
        .toSet();
    expect(registered.containsAll(names), isTrue);
  });

  for (final width in [280.0, 420.0, 700.0]) {
    testWidgets('production examples fit a $width pane at 200% text', (
      tester,
    ) async {
      for (final example in commerceComponentExamples) {
        await tester.pumpWidget(
          harness(
            Builder(builder: example.previewBuilder),
            width: width,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${example.name} at width $width',
        );
      }
    });
  }

  testWidgets(
    'product keeps long name, amount, reason and removal accessible',
    (tester) async {
      var taps = 0;
      const name =
          'Extra long product name for a very comfortable countryside weekend';
      const tag = 'A practical layer for changeable weather on your first day';
      await tester.pumpWidget(
        harness(
          CommerceProductCard(
            name: name,
            price: '€12,345.00',
            brandLine: 'Alder · Responsibly sourced cotton in a relaxed fit',
            tag: tag,
            removal: true,
            onPressed: () => taps++,
          ),
          width: 280,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(name), findsOneWidget);
      expect(find.text(tag), findsOneWidget);
      expect(find.text('€12,345.00'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      await tester.ensureVisible(find.text('Remove'));
      await tester.tap(find.text('Remove'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'product example uses the production card and switches select/remove',
    (tester) async {
      final example = commerceComponentExamples.singleWhere(
        (item) => item.name == 'ProductCard',
      );
      await tester.pumpWidget(
        harness(Builder(builder: example.previewBuilder)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CommerceProductCard), findsOneWidget);
      expect(find.text('Choose this'), findsOneWidget);
      await tester.tap(find.text('Choose this'));
      await tester.pump();
      expect(find.text('Remove'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pump();
      expect(find.text('Choose this'), findsOneWidget);
    },
  );

  testWidgets(
    'choice retains selected semantics and full minimum touch target',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        harness(
          CommerceChoice(
            label: 'Formal',
            selected: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(CommerceChoice)).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSemantics(find.byType(CommerceChoice)),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          label: 'Formal',
        ),
      );
      await tester.tap(find.text('Formal'));
      expect(taps, 1);
      semantics.dispose();
    },
  );

  testWidgets('disabled primary button does not dispatch', (tester) async {
    await tester.pumpWidget(
      harness(
        const CommercePrimaryButton(label: 'Choose an occasion to continue'),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Choose an occasion to continue'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dressing room layout follows pane width instead of window width',
    (tester) async {
      final example = commerceComponentExamples.singleWhere(
        (item) => item.name == 'DressingRoom',
      );
      await tester.pumpWidget(
        harness(Builder(builder: example.previewBuilder), width: 300),
      );
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(
        find.byKey(const ValueKey('dressing-slot-top')),
      );
      final bottom = tester.getTopLeft(
        find.byKey(const ValueKey('dressing-slot-bottom')),
      );
      expect(bottom.dy, greaterThan(top.dy));
      expect(find.text('Choosing now'), findsNWidgets(2));
      await tester.tap(find.text('Complete look'));
      await tester.pumpAndSettle();
      expect(find.text('Your look is complete'), findsOneWidget);
      expect(find.text('€335.00 spent · 3 pieces'), findsOneWidget);
      expect(find.text('€565.00 left'), findsOneWidget);
      expect(find.text('Choosing now'), findsNothing);
      await tester.ensureVisible(find.text('Formal dark panel'));
      await tester.tap(find.text('Formal dark panel'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Dressing room')).style!.color,
        Colors.white,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'formal dark rack keeps budget above slots and renders exact next/empty icons',
    (tester) async {
      final example = commerceComponentExamples.singleWhere(
        (item) => item.name == 'DressingRoom',
      );
      await tester.pumpWidget(
        harness(
          CommerceDressingRoomStyle(
            dark: true,
            child: Builder(builder: example.previewBuilder),
          ),
          width: 420,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Choosing now'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNWidgets(2));
      final icons = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .toList();
      expect(
        icons.map((icon) => (icon.width, icon.height)),
        containsAll([(26.0, 6.0), (13.3333, 14.6667)]),
      );
      final budget = tester.getTopLeft(find.text('€95.00 spent · 1 piece')).dy;
      final top = tester
          .getTopLeft(find.byKey(const ValueKey('dressing-slot-top')))
          .dy;
      expect(budget, lessThan(top));
      final label = tester.widget<Text>(find.text('Dressing room'));
      expect(label.style!.color, Colors.white);
    },
  );

  testWidgets(
    'catalog photo primitive rejects remote and outside asset paths',
    (tester) async {
      for (final path in [
        'https://example.com/product.jpg',
        'assets/private/product.jpg',
        '../secret.jpg',
      ]) {
        await tester.pumpWidget(
          harness(
            SizedBox(
              height: 100,
              child: CommerceProductImage(imageAsset: path),
            ),
          ),
        );
        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(Icons.checkroom_outlined), findsOneWidget);
      }
    },
  );
}
