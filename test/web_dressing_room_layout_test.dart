import 'package:a2ui_flutter_commerce/app/l10n/l10n.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/theme/app_theme.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_right_components.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/layout/duo_layout_adapter.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_inspector_bloc.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/views/stylist_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable/foldable.dart';

import 'stylist_runtime_test.dart' show products;

void main() {
  for (final layout in [
    (size: const Size(1456, 840), status: null),
    (size: const Size(1920, 1080), status: null),
    (size: const Size(951, 669), status: HingeStatus.fullyOpen),
    (size: const Size(951, 669), status: HingeStatus.partiallyOpen),
    (size: const Size(669, 951), status: HingeStatus.fullyOpen),
  ]) {
    final size = layout.size;
    testWidgets('room controls at $size / ${layout.status}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final agent = (await tester.runAsync(() async {
        final catalog = buildCommerceCatalog();
        final inspector = CommerceInspectorBloc(
          catalog: buildModelUiCatalog(catalog),
        );
        final agent = GenkitAgent(
          StylistRuntime(products: products),
          catalog: catalog,
          inspector: inspector,
        );
        await agent.startJourney(DemoJourney.lisbon);
        return agent;
      }))!;
      addTearDown(agent.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DuoLayoutScope(
            data: layout.status == null
                ? FoldableData.unsupported
                : FoldableData.unsupported.copyWith(
                    status: layout.status,
                    capabilities: const FoldableCapabilities(
                      supportLevel: FoldableSupportLevel.available,
                      isFoldable: true,
                      hingeApiPresent: true,
                      regionApiPresent: true,
                      angleUnitVerified: false,
                      strategy: 'test',
                    ),
                  ),
            child: StylistPage(
              agent: agent,
              onConnected: (_) {},
              connectionFactory: (_) async => throw UnimplementedError(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (size.height > size.width) {
        final inspect = find.byKey(const ValueKey('commerce-inspect-button'));
        final icon = find.descendant(
          of: inspect,
          matching: find.byIcon(Icons.data_object),
        );
        expect(
          find.byKey(const ValueKey('commerce-inspect-circle')),
          findsOneWidget,
        );
        expect(IconTheme.of(tester.element(icon)).color, Colors.white);
        expect(inspect.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        return;
      }
      expect(find.byKey(const ValueKey('dressing-room-rack')), findsNothing);
      final slots = find.byType(FinalizedPieceSlot);
      expect(slots, findsAtLeastNWidgets(3));
      expect(
        tester
            .widgetList<FinalizedPieceSlot>(slots)
            .every((slot) => !slot.compactHorizontal),
        isTrue,
      );
      final first = tester.getRect(slots.at(0));
      final second = tester.getRect(slots.at(1));
      final third = tester.getRect(slots.at(2));
      expect(first.height, greaterThan(first.width));
      expect(first.width, lessThanOrEqualTo(223));
      expect(
        third.bottom,
        lessThanOrEqualTo(
          size.height - (layout.status == HingeStatus.partiallyOpen ? 0 : 12),
        ),
      );
      expect(first.top, second.top);
      expect(second.left, greaterThan(first.right));
      expect(third.left, first.left);
      expect(third.top, greaterThan(first.bottom));
      final rail = find.byKey(const ValueKey('dressing-room-side-rail'));
      expect(
        tester.widget<ColoredBox>(rail).color,
        layout.status == HingeStatus.fullyOpen ? Colors.white : Colors.black,
      );
      final inspect = find.byKey(const ValueKey('commerce-inspect-button'));
      final close = find.descendant(
        of: rail,
        matching: find.byIcon(Icons.close),
      );
      expect(tester.getCenter(inspect).dx, tester.getCenter(close).dx);
      if (layout.status != null) {
        // System indicator centre: Figma rail gutters are 12 left / 24 right.
        expect(tester.getCenter(inspect).dx, size.width - 48);
      }
      expect(
        find.byKey(const ValueKey('commerce-inspect-circle')),
        findsNothing,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: inspect,
                matching: find.byIcon(Icons.data_object),
              ),
            )
            .size,
        24,
      );
      expect(
        tester.getRect(inspect).top,
        greaterThan(tester.getRect(close).bottom),
      );
      expect(tester.getRect(inspect).overlaps(tester.getRect(close)), isFalse);
      expect(inspect.hitTestable(), findsOneWidget);
      await tester.tap(inspect);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commerce-inspector-close')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
