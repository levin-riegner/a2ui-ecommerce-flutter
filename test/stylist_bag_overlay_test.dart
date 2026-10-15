import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/layout/stylist_bag_overlay.dart';
import 'package:a2ui_flutter_commerce/src/theme.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_right_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stylist_library_test.dart' show completed, libraryCatalog;
import 'stylist_store_helpers.dart';
import 'progressive_agent_test.dart' show action;

void main() {
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
          await agent.conversation.sendRequest(action('add_look_to_bag', {}));
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
      },
    );
  }
}
