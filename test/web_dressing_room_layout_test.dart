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
  for (final size in [const Size(1456, 840), const Size(1920, 1080)]) {
    testWidgets('roomy desktop uses Duo grid and aligned black rail at $size', (
      tester,
    ) async {
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
            data: FoldableData.unsupported,
            child: StylistPage(
              agent: agent,
              onConnected: (_) {},
              connectionFactory: (_) async => throw UnimplementedError(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
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
      expect(third.bottom, lessThanOrEqualTo(size.height - 12));
      expect(first.top, second.top);
      expect(second.left, greaterThan(first.right));
      expect(third.left, first.left);
      expect(third.top, greaterThan(first.bottom));
      final rail = find.byKey(const ValueKey('dressing-room-side-rail'));
      expect(tester.widget<ColoredBox>(rail).color, Colors.black);
      final inspect = find.byKey(const ValueKey('commerce-inspect-button'));
      final close = find.descendant(
        of: rail,
        matching: find.byIcon(Icons.close),
      );
      expect(tester.getCenter(inspect).dx, tester.getCenter(close).dx);
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
