import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable/foldable.dart';

import 'stylist_library_test.dart' show completed, libraryCatalog;
import 'stylist_store_helpers.dart';
import 'stylist_product_options_test.dart' show settleTurn;

class _PhoneFoldable extends FoldablePlatform {
  _PhoneFoldable(this.data);
  final FoldableData data;
  @override
  Future<FoldableData> getSnapshot() async => data;
  @override
  Stream<FoldableData> get events => const Stream.empty();
}

void main() {
  for (final (size, foldStatus, showBag) in [
    (const Size(390, 844), null, true),
    (const Size(466, 678), null, true),
    (const Size(844, 390), null, false),
    (const Size(466, 678), HingeStatus.closed, true),
    (const Size(678, 466), HingeStatus.closed, false),
    (const Size(669, 951), HingeStatus.partiallyOpen, false),
    (const Size(951, 669), HingeStatus.fullyOpen, false),
  ]) {
    testWidgets('persistent phone bag: $size, $foldStatus', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var modelCalls = 0;
      final agent = (await tester.runAsync(() async {
        final store = MemoryStylistStore();
        final seed = await completed(store: store);
        await seed.dispose();
        final snapshot = (await store.read())!;
        snapshot['bag'] = {libraryCatalog.first.id: 1};
        await store.write(snapshot);
        final agent = GenkitAgent(
          StylistRuntime(
            products: libraryCatalog,
            store: store,
            onModelRequest: (_) => modelCalls++,
          ),
        );
        await agent.resumeLocalState();
        return agent;
      }))!;
      addTearDown(agent.dispose);
      final fold = foldStatus == null
          ? FoldableData.unsupported
          : FoldableData(
              capabilities: const FoldableCapabilities(
                supportLevel: FoldableSupportLevel.available,
                isFoldable: true,
                hingeApiPresent: true,
                regionApiPresent: true,
                angleUnitVerified: false,
                strategy: 'test',
              ),
              status: foldStatus,
              angleDegrees: foldStatus == HingeStatus.closed ? 0 : 90,
              regions: const [],
              displayFeatures: const [],
            );
      final previous = FoldablePlatform.instance;
      FoldablePlatform.instance = _PhoneFoldable(fold);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        FoldablePlatform.instance = previous;
        debugDefaultTargetPlatformOverride = null;
      });
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('phone-header-bag'));
      expect(button, showBag ? findsOneWidget : findsNothing);
      if (showBag) {
        final before = tester.getRect(button);
        final viewport = find.byKey(const ValueKey('compact-pane-scroll'));
        final scroll = tester
            .state<ScrollableState>(
              find
                  .descendant(of: viewport, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        expect(scroll.maxScrollExtent, greaterThan(0));
        scroll.jumpTo(scroll.maxScrollExtent);
        await settleTurn(tester, agent);
        expect(tester.getRect(button), before);
        expect(button.hitTestable(), findsOneWidget);
        expect(
          find.descendant(
            of: button,
            matching: find.bySemanticsLabel('Bag, 1 item'),
          ),
          findsOneWidget,
        );
        await tester.runAsync(() async {
          await tester.tap(button);
        });
        await settleTurn(tester, agent);
        expect(
          find.byKey(const ValueKey('stylist-bag-dialog')),
          findsOneWidget,
        );
        expect(find.text('Your bag — 1 item'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(OutlinedButton, 'Keep styling'));
        });
        await settleTurn(tester, agent);
        expect(find.byKey(const ValueKey('stylist-bag-dialog')), findsNothing);
        expect(button.hitTestable(), findsOneWidget);
      }
      expect(modelCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
