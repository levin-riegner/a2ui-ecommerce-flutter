import 'dart:async';

import 'package:a2ui_flutter_commerce/app/l10n/l10n.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/theme/app_theme.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/layout/duo_layout_adapter.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/views/stylist_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable/foldable.dart';
import 'package:genkit/genkit.dart' as g;

import 'stylist_runtime_test.dart' show products;

void main() {
  for (final scenario in [
    (size: const Size(390, 844), typed: false, fails: false, cover: false),
    (size: const Size(390, 844), typed: true, fails: true, cover: false),
    (size: const Size(951, 669), typed: false, fails: false, cover: false),
    (size: const Size(466, 678), typed: false, fails: false, cover: true),
  ]) {
    testWidgets('room appears before model response: $scenario', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scenario.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final release = Completer<void>();
      final entered = Completer<void>();
      final agent = GenkitAgent(
        StylistRuntime(
          products: products,
          providerModel: g.Model(
            name: 'test/slow-first-turn',
            fn: (request, _) async {
              if (!entered.isCompleted) entered.complete();
              await release.future;
              if (scenario.fails) {
                throw StateError('Simulated unavailable provider');
              }
              return offlineStylistModel(request);
            },
          ),
        ),
      );
      addTearDown(agent.dispose);
      final fold = scenario.cover
          ? FoldableData(
              status: HingeStatus.closed,
              capabilities: const FoldableCapabilities(
                supportLevel: FoldableSupportLevel.available,
                isFoldable: true,
                hingeApiPresent: true,
                regionApiPresent: true,
                angleUnitVerified: false,
                strategy: 'test',
              ),
              angleDegrees: 0,
              regions: const [],
              displayFeatures: const [],
            )
          : FoldableData.unsupported;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DuoLayoutScope(
            data: fold,
            child: StylistPage(
              agent: agent,
              onConnected: (_) {},
              connectionFactory: (_) async => throw UnimplementedError(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario.typed) {
        await tester.enterText(
          find.byKey(const ValueKey('custom-brief-occasion')),
          'A summer lunch in Lisbon in June — a midi dress and sandals, under €500 for the whole outfit',
        );
        await tester.testTextInput.receiveAction(TextInputAction.send);
      } else {
        final suggestion = find.textContaining('A summer lunch in Lisbon');
        await Scrollable.ensureVisible(
          tester.element(suggestion),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(suggestion);
      }
      for (var i = 0; i < 10 && !entered.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(entered.isCompleted, isTrue);
      expect(agent.isBusy, isTrue);
      expect(agent.hasDressingRoomSurface, isTrue);
      final room = find.byKey(const ValueKey('finalized-dressing-room'));
      expect(room, findsOneWidget);
      expect(
        tester.getRect(room).overlaps(Offset.zero & scenario.size),
        isTrue,
      );
      expect(find.text('Dressing room'), findsOneWidget);
      expect(find.byKey(const ValueKey('dressing-slot-dress')), findsOneWidget);
      expect(find.text('€500 left'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is LinearProgressIndicator && widget.value == null,
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('dressing-room-pending')), findsNothing);
      expect(find.byKey(const ValueKey('occasion-mosaic')), findsNothing);
      expect(tester.takeException(), isNull);
      release.complete();
      for (var i = 0; i < 200 && agent.isBusy; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(agent.isBusy, isFalse);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('occasion-mosaic')), findsNothing);
      if (scenario.fails) {
        expect(agent.connectionError, isNotNull);
        expect(room, findsOneWidget);
      } else {
        expect(agent.connectionError, isNull);
        expect(agent.hasDressingRoomSurface, isTrue);
        expect(
          find.byKey(const ValueKey('dressing-room-ready')),
          findsOneWidget,
        );
        expect(room, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
