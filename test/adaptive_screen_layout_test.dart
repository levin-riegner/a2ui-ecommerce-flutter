import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:a2ui_flutter_commerce/src/layout/adaptive_pane_layout.dart';
import 'package:a2ui_flutter_commerce/src/layout/adaptive_page.dart';
import 'package:a2ui_flutter_commerce/src/layout/stylist_composer.dart';
import 'package:a2ui_flutter_commerce/src/layout/duo_layout_adapter.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/agent/stub_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/conversation_entry.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable/foldable.dart';

void main() {
  void setWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  for (final safeBottom in [0.0, 34.0]) {
    testWidgets('composer matches Figma dock clearance, safe=$safeBottom', (
      tester,
    ) async {
      setWindow(tester, const Size(951, 669));
      tester.view.padding = FakeViewPadding(bottom: safeBottom);
      addTearDown(tester.view.resetPadding);
      final agent = _SpacingAgent();
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final openingBottom = tester.getRect(find.byType(StylistComposer)).bottom;
      expect(openingBottom, 669 - (safeBottom > 32 ? safeBottom : 32));
      final opening = tester.getRect(find.byType(StylistComposer));
      final card = tester.getRect(find.byType(InkWell).first);
      expect(opening.left, card.left);
      expect(opening.right, 475.5 - 32);
      await tester.runAsync(() => agent.startJourney(DemoJourney.paris));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(StylistComposer)).bottom,
        669 - (safeBottom > 32 ? safeBottom : 32),
      );
      expect(tester.getRect(find.byType(StylistComposer)).left, opening.left);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'resting conversation has clear gaps below header and above composer',
    (tester) async {
      setWindow(tester, const Size(951, 669));
      final agent = _SpacingAgent();
      await tester.runAsync(() => agent.startJourney(DemoJourney.paris));
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final viewport = find.byKey(const ValueKey('primary-pane-scroll'));
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(of: viewport, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      position.jumpTo(0);
      await tester.pumpAndSettle();
      final header = tester.getRect(
        find.byKey(const ValueKey('alder-journey-header')),
      );
      expect(
        tester.getRect(find.text('First dinner in Brooklyn')).top,
        greaterThanOrEqualTo(header.bottom + 32),
      );
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Find options')).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byType(StylistComposer)).top - 16,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'journey glass header stays fixed and composer clears native bottom inset',
    (tester) async {
      setWindow(tester, const Size(951, 669));
      tester.view.padding = const FakeViewPadding(bottom: 64);
      addTearDown(tester.view.resetPadding);
      final agent = StubAgent();
      await tester.runAsync(() => agent.startJourney(DemoJourney.berlin));
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('alder-journey-header'));
      final before = tester.getRect(header);
      final viewport = find.byKey(const ValueKey('primary-pane-scroll'));
      expect(tester.getRect(viewport).top, before.top);
      expect(
        find.descendant(of: header, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      await tester.drag(viewport, const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(tester.getRect(header), before);
      expect(
        tester.getRect(find.byType(StylistComposer)).bottom,
        lessThanOrEqualTo(669 - 64),
      );
      expect(tester.takeException(), isNull);
    },
  );

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

  for (final obstructed in [false, true]) {
    testWidgets(
      'split background covers safe margins while controls avoid them, hinge=$obstructed',
      (tester) async {
        setWindow(tester, const Size(951, 669));
        await tester.pumpWidget(
          _Harness(
            secondaryBackgroundColor: Colors.black,
            padding: const EdgeInsets.fromLTRB(0, 20, 84, 34),
            features: obstructed
                ? const [
                    DisplayFeature(
                      bounds: Rect.fromLTWH(455.5, 0, 40, 669),
                      type: DisplayFeatureType.hinge,
                      state: DisplayFeatureState.postureHalfOpened,
                    ),
                  ]
                : const [],
          ),
        );
        await tester.pumpAndSettle();
        final background = tester.getRect(
          find.byKey(const ValueKey('secondary-pane-background')),
        );
        expect(background.top, 0);
        expect(background.bottom, 669);
        expect(background.right, 951);
        expect(background.left, obstructed ? 495.5 : 453.5);
        final content = tester.getRect(find.byKey(const ValueKey('secondary')));
        expect(content.left, greaterThanOrEqualTo(background.left + 16));
        expect(content.right, lessThanOrEqualTo(951 - 84 - 16));
        expect(content.top, greaterThanOrEqualTo(20 + 16));
        expect(
          tester
              .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
              )
              .value
              .statusBarBrightness,
          Brightness.dark,
        );
        await tester.enterText(find.byKey(const ValueKey('draft')), 'Keep me');
        tester.view.physicalSize = const Size(466, 678);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('secondary-pane-background')),
          findsNothing,
        );
        expect(find.text('Keep me'), findsOneWidget);
        expect(
          tester
              .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
              )
              .value
              .statusBarBrightness,
          Brightness.light,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'roomy portrait keeps the dressing room above its own chat scroll',
    (tester) async {
      setWindow(tester, const Size(669, 951));
      await tester.pumpWidget(
        const _Harness(
          stackSecondaryInPortrait: true,
          padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
        ),
      );
      await tester.pumpAndSettle();
      final room = tester.getRect(
        find.byKey(const ValueKey('portrait-dressing-pane')),
      );
      final chat = tester.getRect(
        find.byKey(const ValueKey('portrait-conversation-pane')),
      );
      expect(room.top, 88);
      expect(room.bottom, 443.5);
      expect(chat.top, room.bottom);
      expect(chat.bottom, 919);
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('primary-pane-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('portrait-dressing-pane'))),
        room,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('interactive extended pane reserves its rail beside the camera', (
    tester,
  ) async {
    setWindow(tester, const Size(951, 669));
    await tester.pumpWidget(
      const _Harness(
        extendSecondaryToEdges: true,
        reserveRailInExtendedSecondary: true,
        railWidth: 84,
        padding: EdgeInsets.fromLTRB(0, 0, 84, 34),
      ),
    );
    await tester.pumpAndSettle();
    final rail = tester.getRect(find.byKey(const ValueKey('rail')));
    final pane = tester.getRect(find.byKey(const ValueKey('secondary')));
    expect(rail.left, 867);
    expect(rail.right, 951);
    expect(pane.left, 475.5);
    expect(pane.right, rail.left);
    expect(tester.takeException(), isNull);
  });

  for (final obstructed in [false, true]) {
    testWidgets(
      'decorative pane reaches the edges while controls remain safe, hinge=$obstructed',
      (tester) async {
        setWindow(tester, const Size(951, 669));
        await tester.pumpWidget(
          _Harness(
            extendSecondaryToEdges: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 84, 34),
            features: obstructed
                ? const [
                    DisplayFeature(
                      bounds: Rect.fromLTWH(455.5, 0, 40, 669),
                      type: DisplayFeatureType.hinge,
                      state: DisplayFeatureState.postureHalfOpened,
                    ),
                  ]
                : const [],
          ),
        );
        await tester.pumpAndSettle();
        final artwork = tester.getRect(find.byKey(const ValueKey('secondary')));
        final primary = tester.getRect(find.byKey(const ValueKey('primary')));
        final draft = tester.getRect(find.byKey(const ValueKey('draft')));
        expect(artwork.top, 0);
        expect(artwork.bottom, 669);
        expect(artwork.right, 951);
        expect(artwork.left, greaterThan(primary.right));
        expect(artwork.left, 951 / 2);
        expect(artwork.width, 951 / 2);
        expect(primary.left, greaterThanOrEqualTo(20));
        expect(primary.top, greaterThanOrEqualTo(20));
        expect(draft.bottom, lessThanOrEqualTo(635));
        await tester.enterText(find.byKey(const ValueKey('draft')), 'Keep me');
        tester.view.physicalSize = const Size(466, 678);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('compact-pane-layout')),
          findsOneWidget,
        );
        expect(find.text('Keep me'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('secondary'))).right,
          lessThanOrEqualTo(466 - 84),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('opening mosaic fills outer margins on the inner display', (
    tester,
  ) async {
    setWindow(tester, const Size(951, 669));
    tester.view.padding = const FakeViewPadding(
      left: 20,
      top: 20,
      right: 84,
      bottom: 34,
    );
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const ReferenceApp());
    await tester.pumpAndSettle();
    final mosaic = tester.getRect(
      find.byKey(const ValueKey('occasion-mosaic')),
    );
    expect(mosaic.top, 0);
    expect(mosaic.left, 951 / 2);
    expect(mosaic.width, 951 / 2);
    expect(mosaic.right, 951);
    expect(mosaic.bottom, 669);
    expect(
      tester.getRect(find.text('Where are you going?')).left,
      greaterThanOrEqualTo(20 + 16),
    );
    expect(
      tester.getRect(find.text('Connect your model')).bottom,
      lessThanOrEqualTo(669 - 34),
    );
    final header = find.byKey(const ValueKey('alder-header'));
    final headerBefore = tester.getRect(header);
    final scroll = find.byKey(const ValueKey('primary-pane-scroll'));
    expect(tester.getRect(scroll).top, headerBefore.top);
    expect(
      find.descendant(of: header, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    await tester.drag(scroll, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getRect(header), headerBefore);
    expect(
      tester.getRect(find.text('Where are you going?')).bottom,
      lessThan(headerBefore.bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Book background fades and reverses without losing the draft', (
    tester,
  ) async {
    setWindow(tester, const Size(951, 669));
    Future<void> posture(HingeStatus status) => tester.pumpWidget(
      _Harness(
        secondaryBackgroundColor: Colors.black,
        secondaryBackgroundOnlyInBookMode: true,
        foldData: FoldableData.unsupported.copyWith(status: status),
        padding: const EdgeInsets.fromLTRB(0, 20, 84, 34),
        features: status == HingeStatus.partiallyOpen
            ? const [
                DisplayFeature(
                  bounds: Rect.fromLTWH(455.5, 0, 40, 669),
                  type: DisplayFeatureType.hinge,
                  state: DisplayFeatureState.postureHalfOpened,
                ),
              ]
            : const [],
      ),
    );
    Color background() => tester
        .widget<ColoredBox>(
          find.byKey(const ValueKey('secondary-pane-background')),
        )
        .color;

    await posture(HingeStatus.fullyOpen);
    expect(background(), Colors.white);
    await tester.enterText(
      find.byKey(const ValueKey('draft')),
      'Keep the draft',
    );
    final field = tester.state<EditableTextState>(find.byType(EditableText));
    await posture(HingeStatus.partiallyOpen);
    expect(background(), Colors.white);
    await tester.pump(const Duration(milliseconds: 160));
    final intermediate = background();
    expect(intermediate.r, greaterThan(0));
    expect(intermediate.r, lessThan(1));
    await posture(HingeStatus.fullyOpen);
    expect(background(), intermediate);
    await tester.pump(const Duration(milliseconds: 160));
    expect(background().r, greaterThan(intermediate.r));
    await tester.pumpAndSettle();
    expect(background(), Colors.white);
    await posture(HingeStatus.partiallyOpen);
    await tester.pumpAndSettle();
    expect(background(), Colors.black);
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(field),
    );
    expect(field.widget.controller.text, 'Keep the draft');
    expect(field.widget.focusNode.hasFocus, isTrue);
    tester.view.physicalSize = const Size(466, 678);
    await posture(HingeStatus.closed);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('secondary-pane-background')),
      findsNothing,
    );
    expect(
      tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value
          .statusBarBrightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Book background honours Reduce Motion', (tester) async {
    setWindow(tester, const Size(951, 669));
    Future<void> posture(HingeStatus status) => tester.pumpWidget(
      _Harness(
        secondaryBackgroundColor: Colors.black,
        secondaryBackgroundOnlyInBookMode: true,
        foldData: FoldableData.unsupported.copyWith(status: status),
        disableAnimations: true,
      ),
    );
    await posture(HingeStatus.fullyOpen);
    await posture(HingeStatus.partiallyOpen);
    await tester.pump();
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('secondary-pane-background')),
          )
          .color,
      Colors.black,
    );
    expect(tester.takeException(), isNull);
  });

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

  for (final obstructed in [false, true]) {
    testWidgets(
      'catalog scroll reaches the bottom edge unless it contains hardware, cutout=$obstructed',
      (tester) async {
        setWindow(tester, const Size(466, 678));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(466, 678),
                padding: const EdgeInsets.only(top: 24, bottom: 34),
                displayFeatures: [
                  if (obstructed)
                    const DisplayFeature(
                      bounds: Rect.fromLTWH(200, 644, 66, 34),
                      type: DisplayFeatureType.cutout,
                      state: DisplayFeatureState.unknown,
                    ),
                ],
              ),
              child: Scaffold(
                body: AdaptivePage(
                  child: Column(
                    children: [
                      const SizedBox(height: 1200),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Last control'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = find.byType(SingleChildScrollView);
        expect(tester.getRect(scroll).bottom, obstructed ? 644 : 678);
        expect(tester.getRect(scroll).top, 24);
        await tester.ensureVisible(find.text('Last control'));
        await tester.pumpAndSettle();
        expect(find.text('Last control').hitTestable(), findsOneWidget);
        expect(
          tester.getRect(find.text('Last control')).bottom,
          lessThanOrEqualTo(644),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
        const Size(44, 48),
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
    await Scrollable.ensureVisible(
      tester.element(find.text('Explore component catalog')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Explore component catalog').hitTestable(),
      findsOneWidget,
    );
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

class _SpacingAgent extends StubAgent {
  @override
  bool get canStartBrief => true;
  @override
  List<CommerceConversationEntry> get conversationEntries => [
    const CommerceUserMessage(id: 'spacing', text: 'First dinner in Brooklyn'),
    if (latestInlineSurfaceId != null)
      CommerceSurfaceEntry(surfaceId: latestInlineSurfaceId!),
  ];
}

class _Harness extends StatelessWidget {
  const _Harness({
    this.features = const [],
    this.padding = EdgeInsets.zero,
    this.keyboardHeight = 0,
    this.longContent = false,
    this.secondaryBackgroundColor,
    this.secondaryBackgroundOnlyInBookMode = false,
    this.extendSecondaryToEdges = false,
    this.reserveRailInExtendedSecondary = false,
    this.railWidth = 60,
    this.stackSecondaryInPortrait = false,
    this.foldData = FoldableData.unsupported,
    this.disableAnimations = false,
  });

  final List<DisplayFeature> features;
  final EdgeInsets padding;
  final double keyboardHeight;
  final bool longContent;
  final Color? secondaryBackgroundColor;
  final bool secondaryBackgroundOnlyInBookMode;
  final bool extendSecondaryToEdges;
  final bool reserveRailInExtendedSecondary;
  final double railWidth;
  final bool stackSecondaryInPortrait;
  final FoldableData foldData;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) => DuoLayoutScope(
    data: foldData,
    child: MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              displayFeatures: features,
              padding: padding,
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
              disableAnimations: disableAnimations,
            ),
            child: Scaffold(
              body: AdaptivePaneLayout(
                extendSecondaryToEdges: extendSecondaryToEdges,
                reserveRailInExtendedSecondary: reserveRailInExtendedSecondary,
                railWidth: railWidth,
                stackSecondaryInPortrait: stackSecondaryInPortrait,
                secondaryScrollable: !extendSecondaryToEdges,
                secondaryPadding: extendSecondaryToEdges
                    ? EdgeInsets.zero
                    : null,
                secondaryBackgroundColor: secondaryBackgroundColor,
                secondaryBackgroundOnlyInBookMode:
                    secondaryBackgroundOnlyInBookMode,
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
    ),
  );
}
