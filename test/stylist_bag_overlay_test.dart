import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/layout/stylist_bag_overlay.dart';
import 'package:a2ui_flutter_commerce/src/theme.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_right_components.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_shared_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stylist_library_test.dart' show completed, libraryCatalog;
import 'stylist_store_helpers.dart';

void main() {
  for (final (size, scale, keyboard, pinned) in [
    (const Size(951, 669), 1.0, 0.0, true),
    (const Size(669, 951), 1.0, 0.0, true),
    (const Size(390, 844), 1.0, 0.0, true),
    (const Size(390, 844), 2.0, 0.0, true),
    (const Size(390, 844), 3.0, 0.0, false),
    (const Size(390, 844), 1.0, 300.0, true),
    (const Size(844, 390), 2.0, 0.0, false),
    (const Size(390, 320), 3.0, 0.0, false),
  ]) {
    testWidgets(
      'five-item bag keeps actions reachable: $size, text $scale, keyboard $keyboard',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        var calls = 0;
        final agent = (await tester.runAsync(() async {
          final store = MemoryStylistStore();
          final seed = await completed(store: store);
          await seed.dispose();
          final snapshot = (await store.read())!;
          snapshot['bag'] = {for (final p in libraryCatalog.take(5)) p.id: 1};
          await store.write(snapshot);
          final agent = GenkitAgent(
            StylistRuntime(
              products: libraryCatalog,
              store: store,
              onModelRequest: (_) => calls++,
            ),
          );
          await agent.resumeLocalState();
          await agent.openBag();
          return agent;
        }))!;
        addTearDown(agent.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: AnimatedBuilder(
                animation: agent,
                builder: (_, _) =>
                    StylistBagOverlay(agent: agent, child: const Text('Chat')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final panel = tester.getRect(find.byType(FinalizedBagPreview));
        expect(panel.top, greaterThanOrEqualTo(24));
        expect(panel.bottom, lessThanOrEqualTo(size.height - keyboard - 24));
        expect(find.text('Your bag — 5 items'), findsOneWidget);
        final keep = find.widgetWithText(OutlinedButton, 'Keep styling');
        if (pinned) {
          final list = find.byKey(const ValueKey('bag-items-scroll'));
          expect(list, findsOneWidget);
          expect(find.text('Check out').hitTestable(), findsOneWidget);
          expect(keep.hitTestable(), findsOneWidget);
          final footer = tester.getRect(
            find.byKey(const ValueKey('bag-footer')),
          );
          expect(footer.bottom, lessThanOrEqualTo(panel.bottom - 17));
          final header = tester.getRect(find.text('Your bag — 5 items'));
          await tester.drag(list, const Offset(0, -600));
          await tester.pumpAndSettle();
          final scroll = tester
              .state<ScrollableState>(
                find
                    .descendant(of: list, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          if (scroll.maxScrollExtent > 0) {
            expect(scroll.pixels, greaterThan(0));
          } else {
            expect(scroll.pixels, 0);
          }
          expect(
            tester.getRect(find.byKey(const ValueKey('bag-footer'))),
            footer,
          );
          expect(tester.getRect(find.text('Your bag — 5 items')), header);
          expect(keep.hitTestable(), findsOneWidget);
        } else {
          expect(
            find.byKey(const ValueKey('bag-content-scroll')),
            findsOneWidget,
          );
          await tester.ensureVisible(keep);
          await tester.pumpAndSettle();
          expect(keep.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(keep).bottom,
            lessThanOrEqualTo(panel.bottom - 17),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          await tester.tap(keep);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('stylist-bag-dialog')), findsNothing);
        expect(agent.bagCount, 5);
        expect(calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (size, textScale) in [
    (const Size(951, 669), 1.0),
    (const Size(669, 951), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
  ]) {
    testWidgets(
      'bag modal fits $size at $textScale text and dismisses without a model',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        var calls = 0;
        final agent = (await tester.runAsync(() async {
          final store = MemoryStylistStore();
          final seed = await completed(store: store);
          await seed.dispose();
          final agent = GenkitAgent(
            StylistRuntime(
              products: libraryCatalog,
              store: store,
              onModelRequest: (_) => calls++,
            ),
          );
          await agent.resumeLocalState();
          await agent.openBag();
          return agent;
        }))!;
        addTearDown(agent.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: AnimatedBuilder(
                animation: agent,
                builder: (_, _) => StylistBagOverlay(
                  agent: agent,
                  child: const Text('Chat context'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dialog = find.byKey(const ValueKey('stylist-bag-dialog'));
        expect(dialog, findsOneWidget);
        final card = tester.getRect(find.byType(FinalizedBagPreview));
        expect(card.width, lessThanOrEqualTo(400));
        expect(card.left, greaterThanOrEqualTo(24));
        expect(card.right, lessThanOrEqualTo(size.width - 24));
        expect(card.center.dx, closeTo(size.width / 2, 1));
        expect(find.byKey(const ValueKey('bag-modal-barrier')), findsOneWidget);
        expect(find.text('Check out'), findsOneWidget);
        expect(find.text('Your bag — 1 item'), findsOneWidget);
        final keepStyling = find.widgetWithText(OutlinedButton, 'Keep styling');
        expect(keepStyling, findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(keepStyling)
              .style!
              .textStyle!
              .resolve({})!
              .fontWeight,
          FontWeight.w600,
        );
        expect(find.textContaining('Demo bag'), findsNothing);
        expect(find.textContaining('Choose demo size'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.runAsync(() async {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(find.text('Chat context'), findsOneWidget);
        await tester.runAsync(agent.openBag);
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        await tester.runAsync(() async {
          await tester.tapAt(const Offset(4, 4));
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(agent.bagCount, 1);
        expect(calls, 0);
        expect(tester.takeException(), isNull);
        await tester.runAsync(agent.openBag);
        await tester.pumpAndSettle();
        final remove = find.byTooltip('Remove ${libraryCatalog.first.name}');
        await tester.ensureVisible(remove);
        await tester.runAsync(() async {
          await tester.tap(remove);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(find.text('Item removed'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
        expect(agent.bagCount, 0);
        if (textScale == 1) {
          expect(
            tester.getSize(find.byType(FinalizedToast)).height,
            lessThanOrEqualTo(48),
          );
        }
        await tester.runAsync(() async {
          await tester.tap(find.text('Undo'));
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(agent.bagCount, 1);
        expect(calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
