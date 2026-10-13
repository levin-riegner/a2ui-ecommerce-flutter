import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:a2ui_flutter_commerce/src/agent/stub_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_right_components.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:a2ui_flutter_commerce/src/layout/adaptive_pane_layout.dart';
import 'package:a2ui_flutter_commerce/src/layout/duo_layout_adapter.dart';
import 'package:a2ui_flutter_commerce/src/layout/stylist_composer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable/foldable.dart';
import 'package:genui/genui.dart';

import '../tool/duo_simulator_probe.dart' show createDuoFixtureAgent;

const _available = FoldableCapabilities(
  supportLevel: FoldableSupportLevel.available,
  isFoldable: true,
  hingeApiPresent: true,
  regionApiPresent: true,
  angleUnitVerified: false,
  strategy: 'test',
);

FoldableData _data(
  HingeStatus status, {
  List<ReservedRegion> regions = const [],
}) => FoldableData(
  capabilities: _available,
  status: status,
  angleDegrees: status == HingeStatus.closed
      ? 0
      : status == HingeStatus.fullyOpen
      ? 180
      : 90,
  regions: regions,
  displayFeatures: const [],
);

ReservedRegion _division(Rect bounds, {bool active = true}) => ReservedRegion(
  kind: ReservedRegionKind.division,
  bounds: bounds,
  isActive: active,
);
ReservedRegion _camera(Rect bounds, {bool active = true}) => ReservedRegion(
  kind: ReservedRegionKind.occlusion,
  bounds: bounds,
  isActive: active,
);

class _FakeFoldable extends FoldablePlatform {
  _FakeFoldable(this.current);
  FoldableData current;
  final controller = StreamController<FoldableData>.broadcast(sync: true);
  final List<Completer<FoldableData>> pending = [];
  bool deferSnapshots = false;
  bool failSnapshot = false;
  bool failEvents = false;
  int snapshots = 0;
  int eventReads = 0;

  @override
  Future<FoldableData> getSnapshot() {
    snapshots++;
    if (failSnapshot) {
      return Future.error(PlatformException(code: 'temporarily_unavailable'));
    }
    if (deferSnapshots) {
      final completer = Completer<FoldableData>();
      pending.add(completer);
      return completer.future;
    }
    return Future.value(current);
  }

  @override
  Stream<FoldableData> get events {
    eventReads++;
    if (failEvents) throw StateError('Event channel not ready');
    return controller.stream;
  }

  void emit(FoldableData next) {
    current = next;
    controller.add(next);
  }

  Future<void> dispose() => controller.close();
}

class _Observed {
  FoldableData fold = FoldableData.unsupported;
  MediaQueryData layout = const MediaQueryData();
  MediaQueryData ordinary = const MediaQueryData();
}

Widget _probeApp(
  _Observed observed, {
  FoldablePlatform? platform,
  List<DisplayFeature> engineFeatures = const [],
}) => MaterialApp(
  builder: (_, child) => DuoLayoutAdapter(platform: platform, child: child!),
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(displayFeatures: engineFeatures),
        child: Builder(
          builder: (context) {
            observed.fold = DuoLayoutScope.of(context);
            observed.layout = DuoLayoutScope.mediaForLayout(context);
            observed.ordinary = MediaQuery.of(context);
            return Text(observed.fold.status.name);
          },
        ),
      ),
    ),
  ),
);

void _window(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
}

void main() {
  testWidgets(
    'cover keeps one content column and preserves draft across poses',
    (tester) async {
      _window(tester, const Size(466, 678));
      tester.view.padding = const FakeViewPadding(right: 84, bottom: 34);
      addTearDown(tester.view.resetPadding);
      final previous = FoldablePlatform.instance;
      final fake = _FakeFoldable(
        _data(
          HingeStatus.closed,
          regions: [_camera(const Rect.fromLTWH(382, 0, 84, 170))],
        ),
      );
      FoldablePlatform.instance = fake;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() async {
        FoldablePlatform.instance = previous;
        debugDefaultTargetPlatformOverride = null;
        await fake.dispose();
      });
      await tester.pumpWidget(
        ReferenceApp(agent: GenkitAgent(StylistRuntime(products: []))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('occasion-mosaic')), findsNothing);
      expect(
        tester.getRect(find.text('Where are you going?')).right,
        lessThanOrEqualTo(382),
      );
      final scroll = find.byKey(const ValueKey('compact-pane-scroll'));
      expect(tester.getRect(scroll).right, 382);
      final card = find.byType(InkWell).first;
      expect(tester.getRect(card).right, 374);
      expect(tester.getRect(find.byType(Divider)).right, 374);
      final composer = find.byType(StylistComposer);
      expect(tester.getRect(composer).right, 374);
      // The native 34-point home-indicator inset wins over the cover's 8-point
      // preferred clearance, keeping the complete input above the safe edge.
      expect(tester.getRect(composer).bottom, 678 - 34);
      await tester.enterText(find.byType(TextField), 'Keep this occasion');
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.text('Keep this occasion'), findsOneWidget);
      expect(tester.getRect(composer).bottom, lessThanOrEqualTo(378));
      tester.view.resetViewInsets();
      tester.view.physicalSize = const Size(951, 669);
      fake.emit(_data(HingeStatus.fullyOpen));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('occasion-mosaic')), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(tester.getRect(find.text('Where are you going?')).left, 32);
      expect(
        tester.getRect(find.byKey(const ValueKey('alder-header'))).height,
        80,
      );
      expect(tester.getRect(card).width, 400);
      expect(tester.getRect(card).left, 32);
      expect(tester.getRect(composer).height, 52);
      expect(tester.getRect(composer).bottom, 669 - 34);
      expect(
        tester.getSize(find.byKey(const ValueKey('stylist-submit-circle'))),
        const Size(36, 36),
      );
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editable),
      );
      tester.view.physicalSize = const Size(466, 678);
      fake.emit(
        _data(
          HingeStatus.closed,
          regions: [_camera(const Rect.fromLTWH(382, 0, 84, 170))],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('occasion-mosaic')), findsNothing);
      expect(find.text('Keep this occasion'), findsOneWidget);
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(scroll).right, 382);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'snapshot and event updates recover after snapshot and stream errors',
    (tester) async {
      final fake = _FakeFoldable(_data(HingeStatus.fullyOpen));
      addTearDown(fake.dispose);
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: fake));
      await tester.pumpAndSettle();
      expect(observed.fold.status, HingeStatus.fullyOpen);
      expect(fake.controller.hasListener, isTrue);
      fake.emit(_data(HingeStatus.partiallyOpen));
      await tester.pump();
      expect(observed.fold.status, HingeStatus.partiallyOpen);
      fake.controller.addError(StateError('transient native event error'));
      await tester.pump();
      expect(observed.fold, FoldableData.unsupported);
      fake.emit(_data(HingeStatus.closed));
      await tester.pump();
      expect(observed.fold.status, HingeStatus.closed);
      fake.failSnapshot = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(observed.fold, FoldableData.unsupported);
      fake.failSnapshot = false;
      fake.current = _data(HingeStatus.fullyOpen);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(observed.fold.status, HingeStatus.fullyOpen);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('live event during a slow startup snapshot is not lost', (
    tester,
  ) async {
    final fake = _FakeFoldable(_data(HingeStatus.closed))
      ..deferSnapshots = true;
    addTearDown(fake.dispose);
    final observed = _Observed();
    await tester.pumpWidget(_probeApp(observed, platform: fake));
    expect(fake.pending, hasLength(1));
    fake.emit(_data(HingeStatus.partiallyOpen));
    await tester.pump();
    fake.pending.single.complete(_data(HingeStatus.closed));
    await tester.pumpAndSettle();
    expect(observed.fold.status, HingeStatus.partiallyOpen);
  });

  testWidgets(
    'event activation can recover on resume after initial channel failure',
    (tester) async {
      final fake = _FakeFoldable(_data(HingeStatus.fullyOpen))
        ..failEvents = true;
      addTearDown(fake.dispose);
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: fake));
      await tester.pumpAndSettle();
      expect(fake.controller.hasListener, isFalse);
      fake.failEvents = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(fake.controller.hasListener, isTrue);
      fake.emit(_data(HingeStatus.partiallyOpen));
      await tester.pumpAndSettle();
      expect(observed.fold.status, HingeStatus.partiallyOpen);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scope consumers receive angle and capability changes within the same posture',
    (tester) async {
      final fake = _FakeFoldable(_data(HingeStatus.partiallyOpen));
      addTearDown(fake.dispose);
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: fake));
      await tester.pumpAndSettle();
      expect(observed.fold.angleDegrees, 90);
      expect(observed.fold.isFoldable, isTrue);
      fake.emit(fake.current.copyWith(angleDegrees: 45));
      await tester.pumpAndSettle();
      expect(observed.fold.status, HingeStatus.partiallyOpen);
      expect(observed.fold.angleDegrees, 45);
      fake.emit(
        fake.current.copyWith(capabilities: FoldableCapabilities.unsupported),
      );
      await tester.pumpAndSettle();
      expect(observed.fold.status, HingeStatus.partiallyOpen);
      expect(observed.fold.isFoldable, isFalse);
      expect(observed.fold.capabilities, FoldableCapabilities.unsupported);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('later events win over an in-flight older snapshot', (
    tester,
  ) async {
    final fake = _FakeFoldable(_data(HingeStatus.fullyOpen));
    addTearDown(fake.dispose);
    final observed = _Observed();
    await tester.pumpWidget(_probeApp(observed, platform: fake));
    await tester.pumpAndSettle();
    fake.deferSnapshots = true;
    tester.binding.handleMetricsChanged();
    expect(fake.pending, hasLength(1));
    fake.emit(_data(HingeStatus.closed));
    await tester.pump();
    fake.pending.single.complete(_data(HingeStatus.partiallyOpen));
    await tester.pumpAndSettle();
    expect(observed.fold.status, HingeStatus.closed);
  });

  for (final newestFirst in [true, false]) {
    testWidgets(
      'concurrent snapshots preserve latest request when newest completes ${newestFirst ? 'first' : 'last'}',
      (tester) async {
        final fake = _FakeFoldable(_data(HingeStatus.closed));
        addTearDown(fake.dispose);
        final observed = _Observed();
        await tester.pumpWidget(_probeApp(observed, platform: fake));
        await tester.pumpAndSettle();
        fake.deferSnapshots = true;
        tester.binding.handleMetricsChanged();
        tester.binding.handleMetricsChanged();
        expect(fake.pending, hasLength(2));
        if (newestFirst) {
          fake.pending.last.complete(_data(HingeStatus.fullyOpen));
          await tester.pump();
          fake.pending.first.complete(_data(HingeStatus.partiallyOpen));
        } else {
          fake.pending.first.complete(_data(HingeStatus.partiallyOpen));
          await tester.pump();
          fake.pending.last.complete(_data(HingeStatus.fullyOpen));
        }
        await tester.pumpAndSettle();
        expect(observed.fold.status, HingeStatus.fullyOpen);
      },
    );
  }

  testWidgets(
    'platform replacement cancels old events and ignores its pending snapshots',
    (tester) async {
      final old = _FakeFoldable(_data(HingeStatus.closed));
      final next = _FakeFoldable(_data(HingeStatus.fullyOpen));
      addTearDown(old.dispose);
      addTearDown(next.dispose);
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: old));
      await tester.pumpAndSettle();
      old.deferSnapshots = true;
      tester.binding.handleMetricsChanged();
      await tester.pumpWidget(_probeApp(observed, platform: next));
      await tester.pumpAndSettle();
      expect(old.controller.hasListener, isFalse);
      expect(next.controller.hasListener, isTrue);
      old.pending.single.complete(_data(HingeStatus.partiallyOpen));
      old.emit(_data(HingeStatus.closed));
      await tester.pumpAndSettle();
      expect(observed.fold.status, HingeStatus.fullyOpen);
    },
  );

  testWidgets(
    'missing initial snapshot still permits later live event recovery',
    (tester) async {
      final fake = _FakeFoldable(_data(HingeStatus.fullyOpen))
        ..failSnapshot = true;
      addTearDown(fake.dispose);
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: fake));
      await tester.pumpAndSettle();
      expect(observed.fold, FoldableData.unsupported);
      expect(fake.controller.hasListener, isTrue);
      fake.emit(_data(HingeStatus.partiallyOpen));
      await tester.pumpAndSettle();
      expect(observed.fold.status, HingeStatus.partiallyOpen);
      expect(tester.takeException(), isNull);
    },
  );

  final division = _division(const Rect.fromLTWH(455, 0, 40, 669));
  for (final status in [
    HingeStatus.closed,
    HingeStatus.partiallyOpen,
    HingeStatus.fullyOpen,
  ]) {
    testWidgets('reserved division is only active during ${status.name}', (
      tester,
    ) async {
      final fake = _FakeFoldable(_data(status, regions: [division]));
      addTearDown(fake.dispose);
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: fake));
      await tester.pumpAndSettle();
      final features = observed.layout.displayFeatures;
      if (status == HingeStatus.partiallyOpen) {
        expect(features.single.type, DisplayFeatureType.fold);
        expect(features.single.state, DisplayFeatureState.postureHalfOpened);
        expect(features.single.bounds, division.bounds);
      } else {
        expect(features, isEmpty);
      }
      expect(observed.ordinary.displayFeatures, isEmpty);
    });
  }

  testWidgets(
    'zero, negative, inactive, unknown, and nonfinite reserved regions are ignored',
    (tester) async {
      final fake = _FakeFoldable(
        _data(
          HingeStatus.partiallyOpen,
          regions: [
            _division(const Rect.fromLTWH(300, 0, 0, 669)),
            _division(const Rect.fromLTWH(300, 0, -10, 669)),
            _division(const Rect.fromLTWH(300, 0, 20, 669), active: false),
            _division(const Rect.fromLTWH(double.nan, 0, 20, 669)),
            _division(const Rect.fromLTWH(300, 0, double.infinity, 669)),
            _camera(const Rect.fromLTWH(10, 10, 0, 20)),
            _camera(const Rect.fromLTWH(10, 10, 20, 20), active: false),
            const ReservedRegion(
              kind: ReservedRegionKind.unknown,
              bounds: Rect.fromLTWH(10, 10, 20, 20),
              isActive: true,
            ),
          ],
        ),
      );
      addTearDown(fake.dispose);
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: fake));
      await tester.pumpAndSettle();
      expect(observed.layout.displayFeatures, isEmpty);
      expect(observed.layout.padding, EdgeInsets.zero);
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in <Rect, EdgeInsets>{
    const Rect.fromLTWH(20, 300, 30, 60): const EdgeInsets.only(left: 50),
    const Rect.fromLTWH(300, 20, 60, 30): const EdgeInsets.only(top: 50),
    const Rect.fromLTWH(620, 300, 30, 60): const EdgeInsets.only(right: 49),
    const Rect.fromLTWH(300, 902, 60, 30): const EdgeInsets.only(bottom: 49),
  }.entries) {
    testWidgets('interior camera ${entry.key} reserves nearest viewport edge', (
      tester,
    ) async {
      _window(tester, const Size(669, 951));
      final fake = _FakeFoldable(
        _data(HingeStatus.fullyOpen, regions: [_camera(entry.key)]),
      );
      addTearDown(fake.dispose);
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: fake));
      await tester.pumpAndSettle();
      expect(observed.layout.padding, entry.value);
      expect(
        observed.layout.displayFeatures.single.type,
        DisplayFeatureType.cutout,
      );
      expect(observed.ordinary.padding, EdgeInsets.zero);
    });
  }

  testWidgets('engine display features take precedence over plugin geometry', (
    tester,
  ) async {
    const engine = DisplayFeature(
      bounds: Rect.fromLTWH(350, 0, 20, 669),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureHalfOpened,
    );
    final fake = _FakeFoldable(
      _data(HingeStatus.partiallyOpen, regions: [division]),
    );
    addTearDown(fake.dispose);
    final observed = _Observed();
    await tester.pumpWidget(
      _probeApp(observed, platform: fake, engineFeatures: [engine]),
    );
    await tester.pumpAndSettle();
    expect(observed.layout.displayFeatures, [engine]);
    expect(observed.ordinary.displayFeatures, [engine]);
  });

  testWidgets(
    'method and event channels decode native posture snapshots into local scope',
    (tester) async {
      final platform = MethodChannelFoldable();
      final messenger = tester.binding.defaultBinaryMessenger;
      var queries = 0;
      var listens = 0;
      final wire = <String, Object?>{
        'supportLevel': 'available',
        'isFoldable': true,
        'hingeApiPresent': true,
        'regionApiPresent': true,
        'angleUnitVerified': false,
        'strategy': 'test-native',
        'status': 'fullyOpen',
        'angleDegrees': 180,
        'horizontalSizeClass': 'regular',
        'verticalSizeClass': 'regular',
        'regions': <Object?>[],
      };
      messenger.setMockMethodCallHandler(
        const MethodChannel(kFoldableMethodChannel),
        (call) async {
          expect(call.method, 'getSnapshot');
          queries++;
          return wire;
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel(kFoldableEventChannel),
        (call) async {
          if (call.method == 'listen') listens++;
          return null;
        },
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel(kFoldableMethodChannel),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel(kFoldableEventChannel),
          null,
        );
      });
      final observed = _Observed();
      await tester.pumpWidget(_probeApp(observed, platform: platform));
      await tester.pumpAndSettle();
      expect(queries, greaterThanOrEqualTo(1));
      expect(listens, 1);
      expect(observed.fold.status, HingeStatus.fullyOpen);
      tester.binding.channelBuffers.push(
        kFoldableEventChannel,
        const StandardMethodCodec().encodeSuccessEnvelope({
          ...wire,
          'status': 'partiallyOpen',
          'angleDegrees': 90,
          'regions': [
            {
              'kind': 'division',
              'left': 455,
              'top': 0,
              'width': 40,
              'height': 669,
              'active': true,
            },
          ],
        }),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(observed.fold.status, HingeStatus.partiallyOpen);
      expect(observed.fold.angleDegrees, 90);
      expect(observed.layout.displayFeatures.single.bounds, division.bounds);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real native event activation error is retried by cancelling and resubscribing on resume',
    (tester) async {
      final platform = MethodChannelFoldable();
      final messenger = tester.binding.defaultBinaryMessenger;
      final errors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      var listens = 0;
      var cancels = 0;
      final nativeCalls = <String>[];
      final wire = <String, Object?>{
        'supportLevel': 'available',
        'isFoldable': true,
        'hingeApiPresent': true,
        'regionApiPresent': true,
        'angleUnitVerified': false,
        'strategy': 'test-native',
        'status': 'fullyOpen',
        'angleDegrees': 180,
        'regions': <Object?>[],
      };
      FlutterError.onError = (details) {
        final error = details.exception;
        if (error is PlatformException &&
            error.code == 'activation_unavailable') {
          errors.add(details);
        } else {
          previousErrorHandler?.call(details);
        }
      };
      messenger.setMockMethodCallHandler(
        const MethodChannel(kFoldableMethodChannel),
        (call) async => wire,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel(kFoldableEventChannel),
        (call) async {
          nativeCalls.add(call.method);
          if (call.method == 'listen') {
            listens++;
            if (listens == 1) {
              throw PlatformException(code: 'activation_unavailable');
            }
          }
          if (call.method == 'cancel') cancels++;
          return null;
        },
      );
      try {
        final observed = _Observed();
        await tester.pumpWidget(_probeApp(observed, platform: platform));
        await tester.pumpAndSettle();
        expect(errors, hasLength(1));
        expect(
          errors.single.context.toString(),
          contains('activating platform stream'),
        );
        expect(listens, 1);
        expect(observed.fold.status, HingeStatus.fullyOpen);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(cancels, 1);
        expect(listens, 2);
        expect(nativeCalls, ['listen', 'cancel', 'listen']);
        tester.binding.channelBuffers.push(
          kFoldableEventChannel,
          const StandardMethodCodec().encodeSuccessEnvelope({
            ...wire,
            'status': 'partiallyOpen',
            'angleDegrees': 75,
            'regions': [
              {
                'kind': 'division',
                'left': 455,
                'top': 0,
                'width': 40,
                'height': 669,
                'active': true,
              },
            ],
          }),
          (_) {},
        );
        await tester.pumpAndSettle();
        expect(observed.fold.status, HingeStatus.partiallyOpen);
        expect(observed.fold.angleDegrees, 75);
        expect(
          observed.layout.displayFeatures.single.state,
          DisplayFeatureState.postureHalfOpened,
        );
        expect(errors, hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        FlutterError.onError = previousErrorHandler;
        messenger.setMockMethodCallHandler(
          const MethodChannel(kFoldableMethodChannel),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel(kFoldableEventChannel),
          null,
        );
      }
    },
  );

  for (final recovery in ['resume', 'metrics']) {
    testWidgets(
      'real native stream closed after an unavailable startup snapshot recovers on $recovery',
      (tester) async {
        _window(tester, const Size(951, 669));
        final platform = MethodChannelFoldable();
        final globalPlatform = FoldablePlatform.instance;
        final messenger = tester.binding.defaultBinaryMessenger;
        var available = false;
        var listens = 0;
        final wire = <String, Object?>{
          'supportLevel': 'available',
          'isFoldable': true,
          'hingeApiPresent': true,
          'regionApiPresent': true,
          'angleUnitVerified': false,
          'strategy': 'test-native',
          'status': 'fullyOpen',
          'angleDegrees': 180,
          'regions': <Object?>[],
        };
        messenger.setMockMethodCallHandler(
          const MethodChannel(kFoldableMethodChannel),
          (call) async {
            if (!available) {
              throw PlatformException(code: 'temporarily_unavailable');
            }
            return wire;
          },
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel(kFoldableEventChannel),
          (call) async {
            if (call.method == 'listen') listens++;
            return null;
          },
        );
        try {
          final observed = _Observed();
          await tester.pumpWidget(_probeApp(observed, platform: platform));
          await tester.pumpAndSettle();
          expect(observed.fold, FoldableData.unsupported);
          expect(listens, 0);
          // The real plugin has now completed and cached its Dart stream.
          // A later snapshot alone is insufficient: native events must resume.
          available = true;
          if (recovery == 'resume') {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          } else {
            tester.binding.handleMetricsChanged();
          }
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          expect(observed.fold.status, HingeStatus.fullyOpen);
          expect(listens, 1);
          expect(FoldablePlatform.instance, same(globalPlatform));
          // There is deliberately no metrics or lifecycle notification here.
          // An event-only hinge change proves that the native listener is live.
          tester.binding.channelBuffers.push(
            kFoldableEventChannel,
            const StandardMethodCodec().encodeSuccessEnvelope({
              ...wire,
              'status': 'partiallyOpen',
              'angleDegrees': 75,
              'regions': [
                {
                  'kind': 'division',
                  'left': 455,
                  'top': 0,
                  'width': 40,
                  'height': 669,
                  'active': true,
                },
              ],
            }),
            (_) {},
          );
          await tester.pumpAndSettle();
          expect(observed.fold.status, HingeStatus.partiallyOpen);
          expect(observed.fold.angleDegrees, 75);
          expect(
            observed.layout.displayFeatures.single.bounds,
            const Rect.fromLTWH(455, 0, 40, 669),
          );
          expect(FoldablePlatform.instance, same(globalPlatform));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          messenger.setMockMethodCallHandler(
            const MethodChannel(kFoldableMethodChannel),
            null,
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel(kFoldableEventChannel),
            null,
          );
        }
      },
    );
  }

  testWidgets(
    'camera behind the keyboard reserves no visible-body space and composer stays reachable',
    (tester) async {
      _window(tester, const Size(669, 951));
      final fake = _FakeFoldable(
        _data(
          HingeStatus.fullyOpen,
          regions: [_camera(const Rect.fromLTWH(300, 600, 60, 30))],
        ),
      );
      addTearDown(fake.dispose);
      final controller = TextEditingController(
        text: 'Keep this camera-safe draft',
      );
      addTearDown(controller.dispose);
      MediaQueryData? layoutMedia;
      Size? body;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              DuoLayoutAdapter(platform: fake, child: child!),
          home: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                body = constraints.biggest;
                layoutMedia = DuoLayoutScope.mediaForLayout(
                  context,
                  viewportSize: body,
                );
                return AdaptivePaneLayout(
                  primary: const Text('Conversation'),
                  secondary: const Text('Selected outfit'),
                  header: const Text('Stylist'),
                  footer: TextField(
                    key: const ValueKey('camera-composer'),
                    controller: controller,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(body, const Size(669, 951));
      expect(layoutMedia!.padding.bottom, 351);
      await tester.tap(find.byKey(const ValueKey('camera-composer')));
      final before = tester.state<EditableTextState>(find.byType(EditableText));
      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      await tester.pumpAndSettle();
      expect(body, const Size(669, 451));
      expect(layoutMedia!.padding, EdgeInsets.zero);
      final composer = tester.getRect(
        find.byKey(const ValueKey('camera-composer')),
      );
      expect(composer.bottom, lessThanOrEqualTo(451));
      expect(composer.top, greaterThanOrEqualTo(0));
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(before),
      );
      expect(before.widget.focusNode.hasFocus, isTrue);
      expect(controller.text, 'Keep this camera-safe draft');
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(layoutMedia!.padding.bottom, 351);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual stylist preserves draft, focus, session and selected outfit through cover/inner/posture/keyboard transitions',
    (tester) async {
      _window(tester, const Size(466, 678));
      final fake = _FakeFoldable(_data(HingeStatus.closed));
      final previous = FoldablePlatform.instance;
      FoldablePlatform.instance = fake;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        FoldablePlatform.instance = previous;
        debugDefaultTargetPlatformOverride = null;
      });
      addTearDown(fake.dispose);
      try {
        final agent = StubAgent();
        await tester.runAsync(() => agent.startJourney(DemoJourney.paris));
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Find options'));
        await tester.tap(find.text('Find options'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add to dressing room').first);
        await tester.tap(find.text('Add to dressing room').first);
        await tester.pumpAndSettle();
        final session = agent.conversation;
        final surfaceId = agent.latestInlineSurfaceId;
        final room = agent.controller.contextFor('dressing-room').dataModel;
        final before = jsonEncode(room.getValue<Object?>(DataPath('/')));
        expect(before, contains('Demo Pointed Pump'));
        await tester.enterText(
          find.byKey(const ValueKey('stylist-composer')),
          'Keep the knit, make the shoes blue',
        );
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        final controller = editable.widget.controller;
        expect(editable.widget.focusNode.hasFocus, isTrue);
        for (final transition in [
          (const Size(669, 951), HingeStatus.fullyOpen, 0.0),
          (const Size(951, 669), HingeStatus.fullyOpen, 0.0),
          (const Size(951, 669), HingeStatus.partiallyOpen, 0.0),
          (const Size(669, 951), HingeStatus.partiallyOpen, 0.0),
          (const Size(466, 678), HingeStatus.closed, 240.0),
          (const Size(951, 669), HingeStatus.fullyOpen, 220.0),
          (const Size(466, 678), HingeStatus.closed, 0.0),
        ]) {
          final size = transition.$1;
          final status = transition.$2;
          fake.current = _data(
            status,
            regions: status == HingeStatus.partiallyOpen
                ? [
                    _division(
                      size.width > size.height
                          ? Rect.fromLTWH(455, 0, 40, size.height)
                          : Rect.fromLTWH(0, 455, size.width, 40),
                    ),
                  ]
                : [],
          );
          tester.view.physicalSize = size;
          tester.view.viewInsets = FakeViewPadding(bottom: transition.$3);
          fake.emit(fake.current);
          await tester.pumpAndSettle();
          final after = tester.state<EditableTextState>(
            find.byType(EditableText),
          );
          expect(after, same(editable));
          expect(after.widget.controller, same(controller));
          expect(controller.text, 'Keep the knit, make the shoes blue');
          expect(after.widget.focusNode.hasFocus, isTrue);
          expect(agent.conversation, same(session));
          expect(agent.latestInlineSurfaceId, surfaceId);
          expect(jsonEncode(room.getValue<Object?>(DataPath('/'))), before);
          final composer = tester.getRect(
            find.byKey(const ValueKey('stylist-composer')),
          );
          expect(
            composer.bottom,
            lessThanOrEqualTo(size.height - transition.$3),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $status keyboard=${transition.$3}',
          );
        }
        expect(fake.snapshots, greaterThan(1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
        FoldablePlatform.instance = previous;
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  for (final size in [const Size(466, 678), const Size(669, 951)]) {
    testWidgets('actual compact dressing room condenses at $size', (
      tester,
    ) async {
      _window(tester, size);
      final fake = _FakeFoldable(_data(HingeStatus.closed));
      final previous = FoldablePlatform.instance;
      FoldablePlatform.instance = fake;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final agent = (await tester.runAsync(() async {
        final font = FontLoader('Jost')
          ..addFont(rootBundle.load('assets/fonts/jost/Jost-Variable.ttf'));
        await font.load();
        return createDuoFixtureAgent();
      }))!;
      try {
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.pumpAndSettle();
        final room = find.byKey(const ValueKey('finalized-dressing-room'));
        final decoration =
            tester.widget<Container>(room).decoration as BoxDecoration;
        expect(decoration.color, Colors.black);
        expect(tester.getSize(room).height, lessThan(350));
        expect(
          tester
              .widgetList<FinalizedPieceSlot>(find.byType(FinalizedPieceSlot))
              .every((slot) => slot.compactHorizontal),
          isTrue,
        );
        final selected = agent.controller.contextFor('dressing-room').dataModel;
        final before = jsonEncode(selected.getValue<Object?>(DataPath('/')));
        final session = agent.conversation;
        tester.view.physicalSize = const Size(951, 669);
        fake.emit(_data(HingeStatus.fullyOpen));
        await tester.pumpAndSettle();
        expect(tester.getSize(room).height, greaterThan(350));
        tester.view.physicalSize = size;
        fake.emit(_data(HingeStatus.closed));
        await tester.pumpAndSettle();
        expect(tester.getSize(room).height, lessThan(350));
        expect(agent.conversation, same(session));
        expect(jsonEncode(selected.getValue<Object?>(DataPath('/'))), before);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        FoldablePlatform.instance = previous;
        await tester.pumpWidget(const SizedBox.shrink());
        await fake.dispose();
      }
    });
  }
  testWidgets(
    'only the black dressing room remains stable between Open and Book',
    (tester) async {
      _window(tester, const Size(951, 669));
      final fake = _FakeFoldable(
        _data(
          HingeStatus.fullyOpen,
          regions: [_camera(const Rect.fromLTRB(867, 0, 951, 120))],
        ),
      );
      final previous = FoldablePlatform.instance;
      FoldablePlatform.instance = fake;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        FoldablePlatform.instance = previous;
        debugDefaultTargetPlatformOverride = null;
      });
      addTearDown(fake.dispose);
      await tester.runAsync(() async {
        final font = FontLoader('Jost')
          ..addFont(rootBundle.load('assets/fonts/jost/Jost-Variable.ttf'));
        await font.load();
      });
      final agent = (await tester.runAsync(createDuoFixtureAgent))!;
      try {
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.pumpAndSettle();
        final room = find.byKey(const ValueKey('finalized-dressing-room'));
        expect(find.textContaining('Selected pieces'), findsNothing);
        expect(find.text('Remove'), findsNothing);
        final resize = find.byKey(const ValueKey('dressing-room-resize'));
        final top = tester.getTopLeft(room).dy;
        final height = tester.getSize(resize).height;
        expect(top, lessThan(669 - 34));
        final session = agent.conversation;
        final before = jsonEncode(
          agent.controller
              .contextFor('dressing-room')
              .dataModel
              .getValue<Object?>(DataPath('/')),
        );
        for (final status in [
          HingeStatus.partiallyOpen,
          HingeStatus.fullyOpen,
        ]) {
          fake.emit(
            _data(
              status,
              regions: [
                _camera(const Rect.fromLTRB(867, 0, 951, 120)),
                if (status == HingeStatus.partiallyOpen)
                  _division(const Rect.fromLTWH(455.5, 0, 40, 669)),
              ],
            ),
          );
          await tester.pump();
          expect(tester.getTopLeft(room).dy, closeTo(top, .01));
          await tester.pump(const Duration(milliseconds: 160));
          expect(tester.getTopLeft(room).dy, closeTo(top, .01));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(room).dy, closeTo(top, .01));
          expect(tester.getSize(resize).height, closeTo(height, .01));
          expect(agent.conversation, same(session));
          expect(
            jsonEncode(
              agent.controller
                  .contextFor('dressing-room')
                  .dataModel
                  .getValue<Object?>(DataPath('/')),
            ),
            before,
          );
          expect(tester.takeException(), isNull);
        }
        // Content exceeding the pane minimum animates and remains scrollable.
        agent.controller
            .contextFor('dressing-room')
            .dataModel
            .update(
              DataPath('/brief'),
              List.filled(
                8,
                'Berlin first day with a much longer description of the occasion, '
                'layering preferences, weather and the planned evening activities.',
              ).join(' '),
            );
        await tester.pump();
        await tester.pump();
        expect(tester.getTopLeft(room).dy, closeTo(top, .01));
        await tester.pump(const Duration(milliseconds: 80));
        final intermediateHeight = tester.getSize(resize).height;
        expect(intermediateHeight, greaterThan(height));
        await tester.pumpAndSettle();
        expect(tester.getSize(resize).height, greaterThan(intermediateHeight));
        expect(tester.getTopLeft(room).dy, closeTo(top, .01));
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        FoldablePlatform.instance = previous;
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  for (final entry in <Size, bool>{
    const Size(466, 678): false,
    const Size(669, 951): false,
    const Size(951, 669): true,
  }.entries) {
    testWidgets(
      'native scope respects exact Duo view ${entry.key} and layout mode',
      (tester) async {
        _window(tester, entry.key);
        final fake = _FakeFoldable(
          _data(entry.value ? HingeStatus.fullyOpen : HingeStatus.closed),
        );
        addTearDown(fake.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) =>
                DuoLayoutAdapter(platform: fake, child: child!),
            home: const Scaffold(
              body: AdaptivePaneLayout(
                primary: Text('conversation'),
                secondary: Text('outfit'),
                header: Text('header'),
                footer: Text('composer'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey(entry.value ? 'split-pane-layout' : 'compact-pane-layout'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
