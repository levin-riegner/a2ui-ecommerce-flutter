import 'package:a2ui_flutter_commerce/data/stylist/model/commerce_trace.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/model_ui_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/commerce_inspector.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_inspector_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ModelUiCatalog catalog() => ModelUiCatalog(
  catalogId: 'test-catalog',
  entries: [
    ModelUiCatalogEntry(
      name: 'ProductCard',
      schema: {
        'type': 'object',
        'properties': {
          'productId': {'type': 'string'},
        },
      },
      guidance: 'Show an individual recommendation.',
      availability: ModelUiAvailability.modelSelectable,
    ),
  ],
  instructions: const [],
  actionSchema: const {'type': 'object'},
);

Future<void> drain(CommerceInspectorBloc bloc) async {
  await Future<void>.delayed(Duration.zero);
}

Future<void> selectView(WidgetTester tester, String label) async {
  await tester.tap(
    find.byKey(
      ValueKey(
        label == 'Inspect'
            ? 'commerce-inspect-button'
            : 'commerce-inspector-close',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new inspector does not inherit another pane scroll position', (
    tester,
  ) async {
    final bloc = CommerceInspectorBloc(catalog: catalog());
    addTearDown(bloc.close);
    for (var i = 0; i < 20; i++) {
      bloc.record(CommerceTraceEntry.clientInput(messageLength: i));
    }
    Widget pane(String key) => MaterialApp(
      home: Scaffold(
        body: CommerceInspector(key: ValueKey(key), bloc: bloc),
      ),
    );
    await tester.pumpWidget(pane('room'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    await tester.pumpWidget(pane('basket'));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      0,
    );
    expect(find.text('Under the hood').hitTestable(), findsOneWidget);
  });
  test(
    'inspector bounds immutable history and toggles independently',
    () async {
      final bloc = CommerceInspectorBloc(catalog: catalog());
      addTearDown(bloc.close);
      for (var index = 0; index < 105; index++) {
        bloc.record(CommerceTraceEntry.clientInput(messageLength: index));
      }
      bloc.setInspecting(true);
      await drain(bloc);
      expect(bloc.state.inspecting, isTrue);
      expect(bloc.state.entries, hasLength(CommerceInspectorBloc.historyLimit));
      expect(bloc.state.entries.first.details['messageCharacters'], 5);
      expect(bloc.state.entries.last.details['messageCharacters'], 104);
      expect(() => bloc.state.entries.clear(), throwsUnsupportedError);
      expect(
        () => bloc.state.entries.first.details.clear(),
        throwsUnsupportedError,
      );
      bloc.setInspecting(false);
      await drain(bloc);
      expect(bloc.state.inspecting, isFalse);
      expect(bloc.state.entries, hasLength(100));
    },
  );

  testWidgets('distinguishes decoded fixture response from host A2UI', (
    tester,
  ) async {
    final bloc = CommerceInspectorBloc(catalog: catalog());
    addTearDown(bloc.close);
    bloc.record(
      CommerceTraceEntry.modelResponse(
        source: CommerceModelSource.offline,
        textLength: 42,
        tools: ['present_products'],
        finishReason: 'stop',
        component: 'ProductCard',
        productCount: 2,
      ),
    );
    bloc.record(
      CommerceTraceEntry.surfaceCommit(
        components: ['ProductCard'],
        registeredComponents: ['ProductCard'],
        messageCount: 3,
        bagCount: 0,
        modelSelected: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommerceInspector(bloc: bloc)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Model-selected recommendation · host-bound surface'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Model → host'), 200);
    expect(find.text('Offline fixture · no provider call'), findsOneWidget);
    await tester.tap(find.text('Model → host'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"textContent": "withheld"'), findsOneWidget);
    expect(find.textContaining('"component": "ProductCard"'), findsOneWidget);
  });

  for (final bounded in [true, false]) {
    testWidgets(
      'toggle retains experience state with bounded height $bounded',
      (tester) async {
        final bloc = CommerceInspectorBloc(catalog: catalog());
        addTearDown(bloc.close);
        var disposals = 0;
        final experience = _CounterExperience(onDispose: () => disposals++);
        final pane = CommerceInspectionPane(bloc: bloc, experience: experience);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: bounded ? pane : SingleChildScrollView(child: pane),
            ),
          ),
        );
        await tester.tap(find.text('Count 0'));
        await tester.pump();
        await selectView(tester, 'Inspect');
        await tester.pumpAndSettle();
        expect(bloc.state.inspecting, isTrue);
        expect(disposals, 0);
        expect(find.text('Count 1').hitTestable(), findsNothing);
        expect(find.text('Under the hood'), findsOneWidget);
        await selectView(tester, 'Experience');
        await tester.pumpAndSettle();
        expect(find.text('Count 1'), findsOneWidget);
        expect(disposals, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('pane sheet preserves original experience bounds and scroll', (
    tester,
  ) async {
    final bloc = CommerceInspectorBloc(catalog: catalog());
    final scroll = ScrollController();
    addTearDown(bloc.close);
    addTearDown(scroll.dispose);
    const boundsKey = ValueKey('experience-bounds');
    Widget experience() => SizedBox.expand(
      key: boundsKey,
      child: ListView(
        key: const ValueKey('experience-list'),
        controller: scroll,
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 80, child: Text('Product $i')),
        ],
      ),
    );
    Widget frame(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 420, height: 500, child: child)),
      ),
    );
    await tester.pumpWidget(frame(experience()));
    final originalBounds = tester.getRect(find.byKey(boundsKey));
    await tester.pumpWidget(
      frame(CommerceInspectionPane(bloc: bloc, experience: experience())),
    );
    expect(tester.getRect(find.byKey(boundsKey)), originalBounds);
    expect(find.text('Inspect'), findsNothing);
    final buttonBounds = tester.getRect(
      find.byKey(const ValueKey('commerce-inspect-button')),
    );
    expect(buttonBounds.height, inInclusiveRange(44, 48));
    expect(buttonBounds.width, buttonBounds.height);
    expect(find.byTooltip('Inspect'), findsOneWidget);
    expect(buttonBounds.right, originalBounds.right - 8);
    expect(buttonBounds.top, originalBounds.top + 16);
    await tester.drag(
      find.byKey(const ValueKey('experience-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    final offset = scroll.offset;
    expect(offset, greaterThan(0));
    await selectView(tester, 'Inspect');
    expect(
      tester.getRect(find.byKey(const ValueKey('commerce-inspector-sheet'))),
      originalBounds,
    );
    await selectView(tester, 'Experience');
    expect(scroll.offset, offset);
    expect(tester.getRect(find.byKey(boundsKey)), originalBounds);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact inspector sheet fills the screen and dismisses with back',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bloc = CommerceInspectorBloc(catalog: catalog());
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 250,
                child: CommerceInspectionPane(
                  bloc: bloc,
                  fullScreen: true,
                  experience: const Center(child: Text('Retained room')),
                ),
              ),
            ),
          ),
        ),
      );
      await selectView(tester, 'Inspect');
      expect(
        tester.getRect(find.byKey(const ValueKey('commerce-inspector-sheet'))),
        const Rect.fromLTWH(0, 0, 390, 844),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commerce-inspector-sheet')),
        findsNothing,
      );
      expect(bloc.state.inspecting, isFalse);
      expect(find.text('Retained room').hitTestable(), findsOneWidget);
      await selectView(tester, 'Inspect');
      final sheet = tester.getRect(
        find.byKey(const ValueKey('commerce-inspector-sheet')),
      );
      await tester.flingFrom(
        sheet.topCenter + const Offset(0, 12),
        const Offset(0, 500),
        1200,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('commerce-inspector-sheet')),
        findsNothing,
      );
      expect(bloc.state.inspecting, isFalse);
    },
  );

  testWidgets('hidden experience cannot receive focus and retains its draft', (
    tester,
  ) async {
    final bloc = CommerceInspectorBloc(catalog: catalog());
    final focus = FocusNode();
    final draft = TextEditingController();
    addTearDown(bloc.close);
    addTearDown(focus.dispose);
    addTearDown(draft.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommerceInspectionPane(
            bloc: bloc,
            experience: Center(
              child: TextField(focusNode: focus, controller: draft),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    expect(focus.hasFocus, isTrue);

    await selectView(tester, 'Inspect');
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(focus.canRequestFocus, isFalse);
    expect(draft.text, 'Keep this draft');

    await selectView(tester, 'Experience');
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.canRequestFocus, isTrue);
    expect(focus.hasFocus, isTrue);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all actual catalog registrations are available without a model',
    (tester) async {
      final source = buildCommerceCatalog();
      final manifest = buildModelUiCatalog(source);
      final bloc = CommerceInspectorBloc(catalog: manifest);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommerceInspector(bloc: bloc)),
        ),
      );
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(manifest.entries, hasLength(60));
      expect(find.text('60 registered components'), findsOneWidget);
      expect(find.text('Host action contracts'), findsOneWidget);
      final lastName = manifest.entries.last.name;
      await tester.scrollUntilVisible(
        find.text(lastName),
        300,
        maxScrolls: 60,
        scrollable: find
            .descendant(
              of: find.byKey(
                const PageStorageKey('commerce-inspector-catalog'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(lastName), findsOneWidget);
      await tester.tap(find.text(lastName));
      await tester.pumpAndSettle();
      expect(find.text('Properties and action bindings'), findsOneWidget);
      await tester.tap(find.text('Exchanges'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('small viewport and large text keep inspect controls usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bloc = CommerceInspectorBloc(catalog: catalog());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: CommerceInspectionPane(
            bloc: bloc,
            experience: const Center(child: Text('Live experience')),
          ),
        ),
      ),
    );
    await selectView(tester, 'Inspect');
    await tester.pumpAndSettle();
    expect(find.text('Under the hood'), findsOneWidget);
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();
    expect(find.text('1 registered component'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CounterExperience extends StatefulWidget {
  const _CounterExperience({required this.onDispose});

  final VoidCallback onDispose;

  @override
  State<_CounterExperience> createState() => _CounterExperienceState();
}

class _CounterExperienceState extends State<_CounterExperience> {
  int _count = 0;

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('Count $_count'),
    ),
  );
}
