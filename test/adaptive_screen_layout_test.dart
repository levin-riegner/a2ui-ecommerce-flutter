import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:a2ui_flutter_commerce/src/layout/adaptive_pane_layout.dart';
import 'package:a2ui_flutter_commerce/src/layout/adaptive_page.dart';
import 'package:a2ui_flutter_commerce/src/layout/stylist_composer.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/agent/stub_agent.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void setWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  for (final entry in <Size, bool>{
    const Size(360, 780): false,
    const Size(600, 320): false,
    const Size(669, 951): false,
    const Size(951, 669): true,
    const Size(720, 540): true,
    const Size(1024, 768): true,
    const Size(1440, 900): true,
  }.entries) {
    testWidgets('adapts ordered panes to ${entry.key}', (tester) async {
      setWindow(tester, entry.key);
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          ValueKey(entry.value ? 'split-pane-layout' : 'compact-pane-layout'),
        ),
        findsOneWidget,
      );
      final primary = tester.getRect(find.byKey(const ValueKey('primary')));
      final secondary = tester.getRect(find.byKey(const ValueKey('secondary')));
      if (entry.value) {
        expect(primary.right, lessThan(secondary.left));
      } else {
        expect(secondary.bottom, lessThan(primary.top));
      }
      final footer = tester.getRect(find.byKey(const ValueKey('draft')));
      expect(footer.bottom, lessThanOrEqualTo(entry.key.height));
      expect(
        find.byKey(const ValueKey('rail')),
        entry.key.width >= 900 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('draft and focus survive compact/split resize', (tester) async {
    setWindow(tester, const Size(390, 844));
    await tester.pumpWidget(const _Harness());
    await tester.enterText(
      find.byKey(const ValueKey('draft')),
      'Keep this draft',
    );
    final before = tester.widget<TextField>(
      find.byKey(const ValueKey('draft')),
    );
    final editableBefore = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableBefore.widget.focusNode.hasFocus, isTrue);
    tester.view.physicalSize = const Size(760, 600);
    await tester.pumpAndSettle();
    final editableAfter = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableAfter, same(editableBefore));
    expect(editableAfter.widget.controller.text, 'Keep this draft');
    expect(editableAfter.widget.focusNode.hasFocus, isTrue);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('draft'))).key,
      before.key,
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editableBefore),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical obstruction leaves each pane inside its safe region', (
    tester,
  ) async {
    setWindow(tester, const Size(800, 800));
    await tester.pumpWidget(
      _Harness(
        padding: const EdgeInsets.fromLTRB(18, 44, 18, 24),
        features: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(390, 0, 20, 800),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('obstructed-split-layout')),
      findsOneWidget,
    );
    final primary = tester.getRect(find.byKey(const ValueKey('primary')));
    final secondary = tester.getRect(find.byKey(const ValueKey('secondary')));
    expect(primary.left, greaterThanOrEqualTo(18));
    expect(primary.right, lessThanOrEqualTo(390));
    expect(secondary.left, greaterThanOrEqualTo(410));
    expect(secondary.right, lessThanOrEqualTo(782));
    expect(primary.top, greaterThanOrEqualTo(44));
    expect(
      tester.getRect(find.byKey(const ValueKey('draft'))).bottom,
      lessThanOrEqualTo(776),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow obstructed side falls back to one usable region', (
    tester,
  ) async {
    setWindow(tester, const Size(720, 800));
    await tester.pumpWidget(
      _Harness(
        features: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(490, 0, 20, 800),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compact-pane-layout')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('draft'))).right,
      lessThanOrEqualTo(490),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal obstruction uses one unobstructed scroll region', (
    tester,
  ) async {
    setWindow(tester, const Size(390, 844));
    await tester.pumpWidget(
      _Harness(
        features: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 350, 390, 20),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final draft = tester.getRect(find.byKey(const ValueKey('draft')));
    expect(draft.top, greaterThanOrEqualTo(370));
    expect(draft.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard insets leave the composer above the keyboard', (
    tester,
  ) async {
    setWindow(tester, const Size(390, 844));
    await tester.pumpWidget(
      const _Harness(
        padding: EdgeInsets.only(top: 44, bottom: 24),
        keyboardHeight: 300,
      ),
    );
    await tester.pumpAndSettle();
    final draft = tester.getRect(find.byKey(const ValueKey('draft')));
    expect(draft.bottom, lessThanOrEqualTo(544));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a fold covered by the keyboard cannot expand the pane viewport',
    (tester) async {
      setWindow(tester, const Size(390, 844));
      await tester.pumpWidget(
        const _Harness(
          keyboardHeight: 600,
          features: [
            DisplayFeature(
              bounds: Rect.fromLTWH(0, 350, 390, 20),
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureHalfOpened,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('draft'))).bottom,
        lessThanOrEqualTo(244),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a catalog page also respects a fold covered by the keyboard', (
    tester,
  ) async {
    setWindow(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: const EdgeInsets.only(bottom: 600),
                displayFeatures: const [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(0, 350, 390, 20),
                    type: DisplayFeatureType.hinge,
                    state: DisplayFeatureState.postureHalfOpened,
                  ),
                ],
              ),
              child: const Scaffold(
                body: AdaptivePage(
                  child: SizedBox(height: 1000, child: Text('Catalog content')),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(SingleChildScrollView)).bottom,
      lessThanOrEqualTo(244),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the real session preserves the draft and agent across rotation',
    (tester) async {
      setWindow(tester, const Size(669, 951));
      final agent = StubAgent();
      await tester.runAsync(() => agent.startJourney(DemoJourney.berlin));
      final controller = agent.controller;
      final surface = agent.latestInlineSurfaceId;
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('stylist-composer')),
        'Keep the top but change the shoes',
      );
      final before = tester.state<EditableTextState>(find.byType(EditableText));
      tester.view.physicalSize = const Size(951, 669);
      await tester.pumpAndSettle();
      final after = tester.state<EditableTextState>(find.byType(EditableText));
      expect(after, same(before));
      expect(after.widget.controller.text, 'Keep the top but change the shoes');
      expect(after.widget.focusNode.hasFocus, isTrue);
      expect(agent.controller, same(controller));
      expect(agent.latestInlineSurfaceId, surface);
      expect(agent.activeJourney, DemoJourney.berlin);
      expect(find.byKey(const ValueKey('split-pane-layout')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared composer disables blank input and keeps a full tap target',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StylistComposer(
              controller: controller,
              onSubmitted: sent.add,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('stylist-submit-Send')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('stylist-submit-Send'))),
        const Size(48, 48),
      );
      await tester.enterText(find.byType(TextField), '  a spring wedding  ');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      expect(sent, ['a spring wedding']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text keeps the phone landing and catalog reachable', (
    tester,
  ) async {
    setWindow(tester, const Size(320, 720));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const ReferenceApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore component catalog'));
    await tester.tap(find.text('Explore component catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog components'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact content remains reachable through a single scroll', (
    tester,
  ) async {
    setWindow(tester, const Size(360, 640));
    await tester.pumpWidget(const _Harness(longContent: true));
    await tester.scrollUntilVisible(
      find.text('Last recommendation'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Last recommendation').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('draft')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({
    this.features = const [],
    this.padding = EdgeInsets.zero,
    this.keyboardHeight = 0,
    this.longContent = false,
  });

  final List<DisplayFeature> features;
  final EdgeInsets padding;
  final double keyboardHeight;
  final bool longContent;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            displayFeatures: features,
            padding: padding,
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: Scaffold(
            body: AdaptivePaneLayout(
              primary: Column(
                key: const ValueKey('primary'),
                children: [
                  const Text('Conversation'),
                  if (longContent) const SizedBox(height: 1000),
                  const Text('Last recommendation'),
                ],
              ),
              secondary: const SizedBox(
                key: ValueKey('secondary'),
                height: 180,
                child: Text('Dressing room'),
              ),
              header: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Stylist'),
              ),
              footer: const Padding(
                padding: EdgeInsets.all(12),
                child: TextField(key: ValueKey('draft')),
              ),
              rail: const ColoredBox(
                key: ValueKey('rail'),
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    ),
  );
}
