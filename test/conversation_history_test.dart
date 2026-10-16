import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/commerce_agent.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/conversation_entry.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  testWidgets(
    'history preserves order and disables old controls for all input',
    (tester) async {
      _setViewport(tester, const Size(1400, 1000));
      final agent = _HistoryAgent();
      await tester.runAsync(agent.prepare);
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.pump();

      expect(
        tester.getTopLeft(find.text('First brief')).dy,
        lessThan(tester.getTopLeft(find.text('Old recommendation')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Old recommendation')).dy,
        lessThan(tester.getTopLeft(find.text('Follow-up request')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Follow-up request')).dy,
        lessThan(tester.getTopLeft(find.text('Current recommendation')).dy),
      );

      final oldButton = _button('Old action');
      final currentButton = _button('Current action');
      expect(find.text('Previous response'), findsOneWidget);
      expect(
        tester
            .getSemantics(oldButton)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(
        tester
            .getSemantics(currentButton)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        Focus.of(tester.element(find.text('Old action'))).canRequestFocus,
        isFalse,
      );
      expect(
        Focus.of(tester.element(find.text('Current action'))).canRequestFocus,
        isTrue,
      );

      await tester.tap(oldButton, warnIfMissed: false);
      await tester.pump();
      expect(agent.requests, 0);
      await tester.tap(currentButton);
      await tester.pumpAndSettle();
      expect(agent.requests, 1);
      expect(find.text('Old recommendation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'pending and failed turns keep history visible and controls inert',
    (tester) async {
      _setViewport(tester, const Size(1400, 1000));
      final agent = _HistoryAgent();
      await tester.runAsync(agent.prepare);
      agent.setState(pending: 'pending');
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.pump();

      expect(find.text('Old recommendation'), findsOneWidget);
      expect(find.text('Current recommendation'), findsOneWidget);
      expect(find.text('Pending recommendation'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Pending recommendation')).dy,
        greaterThan(tester.getTopLeft(find.text('Current recommendation')).dy),
      );
      for (final label in ['Old action', 'Current action', 'Pending action']) {
        final button = _button(label);
        expect(
          tester
              .getSemantics(button)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
        );
        expect(
          Focus.of(tester.element(find.text(label))).canRequestFocus,
          isFalse,
        );
        await tester.tap(button, warnIfMissed: false);
      }
      expect(agent.requests, 0);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      agent.setState(error: 'Try again');
      await tester.pumpAndSettle();
      expect(find.text('Pending recommendation'), findsNothing);
      expect(find.text('Old recommendation'), findsOneWidget);
      expect(find.text('Current recommendation'), findsOneWidget);
      expect(
        tester
            .getSemantics(_button('Current action'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );

      agent.setState();
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(_button('Current action'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        tester
            .getSemantics(_button('Old action'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'pending growth follows the bottom and preserves history reading position',
    (tester) async {
      _setViewport(tester, const Size(1400, 800));
      final agent = _HistoryAgent();
      await tester.runAsync(agent.prepare);
      agent.history.insertAll(2, [
        for (var index = 0; index < 12; index++)
          CommerceUserMessage(
            id: 'earlier-$index',
            text: 'Earlier request $index\nOccasion details\nStyle preferences',
          ),
      ]);
      agent.setState(pending: 'pending');
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const ValueKey('primary-pane-scroll')),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      final previousExtent = scroll.maxScrollExtent;
      await tester.runAsync(() => agent.growPending(12));
      await tester.pumpAndSettle();
      expect(scroll.maxScrollExtent, greaterThan(previousExtent));
      expect(scroll.pixels, closeTo(scroll.maxScrollExtent, 1));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.runAsync(() => agent.growPending(24));
      await tester.pumpAndSettle();
      expect(scroll.pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text history keeps composer and draft through resize', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final agent = _HistoryAgent();
    await tester.runAsync(agent.prepare);
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.pumpAndSettle();

    final composer = find.byKey(const ValueKey('stylist-composer'));
    await tester.enterText(composer, 'Keep my draft');
    await tester.pumpAndSettle();
    final fieldBounds = tester.getRect(composer);
    expect(fieldBounds.top, greaterThanOrEqualTo(0));
    expect(fieldBounds.bottom, lessThanOrEqualTo(844));
    await tester.ensureVisible(find.text('Current action'));
    await tester.pumpAndSettle();
    expect(find.text('Old recommendation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1800, 1000);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(composer).controller?.text,
      'Keep my draft',
    );
    expect(tester.takeException(), isNull);
  });

  for (final compact in [false, true]) {
    for (final reducedMotion in [false, true]) {
      testWidgets(
        'renderer-only growth follows the end without model calls, compact=$compact reduceMotion=$reducedMotion',
        (tester) async {
          _setViewport(
            tester,
            compact ? const Size(466, 678) : const Size(951, 669),
          );
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reducedMotion);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final agent = _HistoryAgent();
          await tester.runAsync(agent.prepare);
          agent.history.insertAll(2, [
            for (var i = 0; i < 12; i++)
              CommerceUserMessage(
                id: 'older-$i',
                text: 'Earlier request $i\nDetails\nPreferences',
              ),
          ]);
          agent.setState(pending: 'pending');
          await tester.pumpWidget(ReferenceApp(agent: agent));
          await tester.pumpAndSettle();
          final viewport = find.byKey(
            ValueKey(compact ? 'compact-pane-scroll' : 'primary-pane-scroll'),
          );
          final scroll = tester
              .state<ScrollableState>(
                find
                    .descendant(of: viewport, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          scroll.jumpTo(scroll.maxScrollExtent);
          await tester.pumpAndSettle();
          final before = scroll.pixels;

          // GenUI binds this data update directly; the agent never notifies.
          await tester.runAsync(() => agent.growPendingData(18));
          await tester.pump();
          expect(scroll.maxScrollExtent, greaterThan(before));
          if (reducedMotion) {
            expect(scroll.pixels, closeTo(scroll.maxScrollExtent, 1));
          } else {
            await tester.pump(const Duration(milliseconds: 16));
            await tester.pump(const Duration(milliseconds: 60));
            expect(scroll.pixels, greaterThan(before));
            expect(scroll.pixels, lessThan(scroll.maxScrollExtent));
          }
          // A second renderer update arrives while the first scroll is active.
          await tester.runAsync(() => agent.growPendingData(35));
          await tester.pumpAndSettle();
          expect(scroll.pixels, closeTo(scroll.maxScrollExtent, 1));

          await tester.drag(viewport, const Offset(0, 220));
          await tester.pumpAndSettle();
          final reading = scroll.pixels;
          expect(scroll.extentAfter, greaterThan(48));
          await tester.runAsync(() => agent.growPendingData(45));
          await tester.pumpAndSettle();
          expect(scroll.pixels, closeTo(reading, 1));

          final surfaceState = tester.state(find.byType(Surface).last);
          await tester.runAsync(
            () => agent.growPending(50, notifyAgent: false),
          );
          await tester.pump();
          expect(tester.state(find.byType(Surface).last), same(surfaceState));
          final opacity = tester
              .widget<Opacity>(
                find
                    .ancestor(
                      of: find.byType(Surface).last,
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity;
          // Renderer updates must not replay an already visible reply.
          expect(opacity, 1);
          await tester.pumpAndSettle();
          expect(scroll.pixels, closeTo(reading, 1));
          expect(agent.requests, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Finder _button(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell));

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _HistoryAgent extends CommerceAgent {
  _HistoryAgent() {
    controller = SurfaceController(catalogs: [buildCommerceCatalog()]);
    transport = A2uiTransportAdapter(onSend: (_) async => requests++);
    conversation = Conversation(controller: controller, transport: transport);
  }

  @override
  late final SurfaceController controller;
  late final A2uiTransportAdapter transport;
  @override
  late final Conversation conversation;
  int requests = 0;
  String? _pending;
  String? _error;

  @override
  bool get hasStarted => true;
  @override
  bool get hasDressingRoomSurface => false;
  @override
  DemoJourney? get activeJourney => DemoJourney.paris;
  @override
  String? get latestInlineSurfaceId => 'current';
  @override
  String? get pendingInlineSurfaceId => _pending;
  @override
  String? get connectionError => _error;
  @override
  List<CommerceConversationEntry> get conversationEntries => history;

  final history = <CommerceConversationEntry>[
    CommerceUserMessage(id: 'first', text: 'First brief'),
    CommerceSurfaceEntry(surfaceId: 'old'),
    CommerceUserMessage(id: 'second', text: 'Follow-up request'),
    CommerceSurfaceEntry(surfaceId: 'current'),
  ];

  Future<void> growPending(int lines, {bool notifyAgent = true}) async {
    transport.addMessage(
      core.UpdateComponentsMessage(
        surfaceId: 'pending',
        components: [
          {
            'id': 'text',
            'component': 'Text',
            'text':
                'Pending recommendation\n${List.filled(lines, 'Validated product details').join('\n')}',
          },
        ],
      ),
    );
    if (notifyAgent) {
      emit(
        state.copyWith(
          conversationEntries: List.of(history),
          surfaceRevision: state.surfaceRevision + 1,
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> growPendingData(int lines) async {
    transport.addMessage(
      core.A2uiMessage.fromJson({
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': 'pending',
          'value': {
            'live':
                'Pending recommendation\n${List.filled(lines, 'Validated product details').join('\n')}',
          },
        },
      }),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> prepare() async {
    for (final (id, label) in [
      ('old', 'Old'),
      ('current', 'Current'),
      ('pending', 'Pending'),
    ]) {
      transport.addMessage(
        core.CreateSurfaceMessage(surfaceId: id, catalogId: commerceCatalogId),
      );
      transport.addMessage(
        core.UpdateComponentsMessage(
          surfaceId: id,
          components: [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['text', 'action'],
            },
            {
              'id': 'text',
              'component': 'Text',
              'text': id == 'pending'
                  ? {'path': '/live'}
                  : '$label recommendation',
            },
            {
              'id': 'action',
              'component': 'PrimaryButton',
              'label': '$label action',
              'action': {
                'event': {'name': 'select_product'},
              },
            },
          ],
        ),
      );
      if (id == 'pending') {
        transport.addMessage(
          core.A2uiMessage.fromJson({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': id,
              'value': {'live': '$label recommendation'},
            },
          }),
        );
      }
    }
    await Future<void>.delayed(Duration.zero);
  }

  void setState({String? pending, String? error}) {
    _pending = pending;
    _error = error;
    emit(
      state.copyWith(
        conversationEntries: List.of(history),
        pendingInlineSurfaceId: pending,
        connectionError: error,
      ),
    );
  }

  @override
  Future<void> startJourney(DemoJourney journey) async {}

  @override
  void dispose() {
    conversation.dispose();
    controller.dispose();
    transport.dispose();
    super.dispose();
  }
}
