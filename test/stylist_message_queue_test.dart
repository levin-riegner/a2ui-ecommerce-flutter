import 'package:a2ui_flutter_commerce/presentation/shared/layout/stylist_message_queue.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/layout/stylist_layout.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

Widget host({
  bool enabled = true,
  bool reduceMotion = false,
  Set<String> initiallyVisible = const {},
  Map<String, Widget>? children,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: StylistMessageQueue(
        enabled: enabled,
        initiallyVisible: initiallyVisible,
        spacing: 16,
        children:
            children ??
            {
              'ack': const Text('Got it'),
              'message': const Text('Here is my suggestion'),
              'options': TextButton(
                onPressed: () {},
                child: const Text('Choose'),
              ),
            },
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'real GenUI queues root messages and reveals nested controls together',
    (tester) async {
      final controller = SurfaceController(catalogs: [buildCommerceCatalog()]);
      addTearDown(controller.dispose);
      await tester.runAsync(() async {
        controller.handleMessage(
          core.CreateSurfaceMessage(
            surfaceId: 'reply',
            catalogId: commerceCatalogId,
          ),
        );
        controller.handleMessage(
          core.UpdateComponentsMessage(
            surfaceId: 'reply',
            components: [
              {
                'id': 'root',
                'component': 'StylistSection',
                'children': ['message', 'controls'],
              },
              {
                'id': 'message',
                'component': 'StylistMessage',
                'text': {'path': '/reply'},
              },
              {
                'id': 'controls',
                'component': 'StylistSection',
                'children': ['label', 'action'],
              },
              {
                'id': 'label',
                'component': 'Eyebrow',
                'text': 'Ready to choose',
              },
              {
                'id': 'action',
                'component': 'PrimaryButton',
                'label': 'Next piece',
                'action': {
                  'event': {'name': 'next'},
                },
              },
            ],
          ),
        );
        controller.handleMessage(
          core.A2uiMessage.fromJson({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'reply',
              'value': {'reply': 'Got it\n\nYour outfit'},
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StylistSurfaceScope(
              enqueueMessages: true,
              child: Surface(surfaceContext: controller.contextFor('reply')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Your outfit'), findsNothing);
      expect(find.text('READY TO CHOOSE'), findsNothing);
      expect(find.text('Next piece'), findsNothing);
      await tester.pump(
        StylistMessageQueue.interval + const Duration(milliseconds: 1),
      );
      expect(find.text('Your outfit'), findsOneWidget);
      expect(find.text('Next piece'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('READY TO CHOOSE'), findsOneWidget);
      expect(find.text('Next piece'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Your outfit')).dx,
        tester.getTopLeft(find.text('Got it')).dx,
      );
      expect(
        tester.getTopLeft(find.text('READY TO CHOOSE')).dx,
        tester.getTopLeft(find.text('Got it')).dx,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'streamed prose remains fully visible while cards wait their turn',
    (tester) async {
      await tester.pumpWidget(host(initiallyVisible: {'ack', 'message'}));
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Here is my suggestion'), findsOneWidget);
      expect(find.text('Choose'), findsNothing);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Here is my suggestion'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      final size = tester.widget<SizeTransition>(
        find
            .ancestor(
              of: find.text('Here is my suggestion'),
              matching: find.byType(SizeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
      expect(size.sizeFactor.value, 1);
      final before = tester.getTopLeft(find.text('Here is my suggestion'));
      await tester.pumpAndSettle();
      expect(find.text('Choose'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Here is my suggestion')), before);
    },
  );

  testWidgets('reveals one section at a time and hides queued actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Here is my suggestion'), findsNothing);
    expect(find.text('Choose'), findsNothing);
    expect(find.bySemanticsLabel('Your stylist is replying'), findsOneWidget);

    await tester.pump(
      StylistMessageQueue.interval + const Duration(milliseconds: 1),
    );
    expect(find.text('Here is my suggestion'), findsOneWidget);
    expect(find.text('Choose'), findsNothing);
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Here is my suggestion'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 0);
    await tester.pump(StylistMessageQueue.revealDuration ~/ 2);
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.text('Choose'), findsOneWidget);
    expect(find.bySemanticsLabel('Your stylist is replying'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('surface updates keep pacing and existing controls intact', (
    tester,
  ) async {
    final field = TextField(key: const ValueKey('draft'));
    await tester.pumpWidget(
      host(children: {'field': field, 'message': const Text('Original')}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    final state = tester.state(find.byType(TextField));
    await tester.pumpWidget(
      host(
        children: {
          'field': field,
          'message': const Text('Updated'),
          'options': const Text('Options'),
        },
      ),
    );
    expect(find.text('Updated'), findsNothing);
    await tester.pump(const Duration(milliseconds: 401));
    expect(find.text('Updated'), findsOneWidget);
    expect(find.text('Options'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(identical(tester.state(find.byType(TextField)), state), isTrue);
    expect(find.text('Options'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets(
      'history and reduced motion reveal immediately ($reduceMotion)',
      (tester) async {
        await tester.pumpWidget(
          host(enabled: reduceMotion, reduceMotion: reduceMotion),
        );
        expect(find.text('Got it'), findsOneWidget);
        expect(find.text('Here is my suggestion'), findsOneWidget);
        expect(find.text('Choose'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }

  testWidgets(
    'superseded responses finish immediately and disposal cancels pacing',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(host(enabled: false));
      expect(find.text('Choose'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(StylistMessageQueue.interval * 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removed sections never reappear and appended ones join the queue',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpWidget(
        host(
          children: {
            'ack': const Text('Got it'),
            'options': const Text('Replacement'),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Here is my suggestion'), findsNothing);
      expect(find.text('Replacement'), findsOneWidget);
      await tester.pumpWidget(
        host(
          children: {
            'ack': const Text('Got it'),
            'options': const Text('Replacement'),
            'new': const Text('Appended'),
          },
        ),
      );
      expect(find.text('Appended'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Appended'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduce Motion can interrupt a queue and an active queue can be disposed',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(host(reduceMotion: true));
      expect(find.text('Choose'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Choose'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(StylistMessageQueue.interval * 3);
      expect(tester.takeException(), isNull);
    },
  );
}
