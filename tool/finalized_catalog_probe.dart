// Test-only entry point. Renders real A2UI catalog fixtures without a provider.
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:a2ui_flutter_commerce/presentation/gallery/finalized_component_gallery.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/finalized_screen_gallery.dart';
import 'package:a2ui_flutter_commerce/presentation/gallery/finalized_screen_examples.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/layout/duo_layout_adapter.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/theme/app_theme.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:flutter/material.dart';
import 'package:foldable/foldable.dart';

import 'duo_simulator_probe.dart' as duo;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final agent = await duo.createDuoFixtureAgent();
  final key = GlobalKey<FinalizedComponentGalleryState>();
  final errors = <String>[];
  final defaultHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    defaultHandler?.call(details);
  };
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => DuoLayoutAdapter(child: child!),
      home: FinalizedComponentGallery(key: key),
    ),
  );
  developer.registerExtension('ext.catalog.select', (method, parameters) async {
    errors.clear();
    key.currentState!.select(
      parameters['component']!,
      int.parse(parameters['variant'] ?? '0'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'errors': errors}),
    );
  });
  developer.registerExtension('ext.catalog.showApp', (
    method,
    parameters,
  ) async {
    errors.clear();
    runApp(ReferenceApp(agent: agent));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return developer.ServiceExtensionResponse.result(
      jsonEncode({...await duo.captureDuoState(agent), 'errors': errors}),
    );
  });
  developer.registerExtension('ext.catalog.screen', (method, parameters) async {
    errors.clear();
    final index = int.parse(parameters['index'] ?? '0');
    runApp(
      MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DuoLayoutAdapter(child: child!),
        home: FinalizedScreenGallery(
          key: ValueKey(index),
          initialIndex: index,
          showControls: false,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final snapshot = await FoldablePlatform.instance.getSnapshot();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'id': finalizedScreenExamples[index].id,
        'status': snapshot.status.name,
        'angle': snapshot.angleDegrees,
        'size': '${view.physicalSize / view.devicePixelRatio}',
        'errors': errors,
        'textScale': MediaQueryData.fromView(view).textScaler.scale(14) / 14,
      }),
    );
  });
  developer.registerExtension('ext.catalog.productionCapture', (
    method,
    parameters,
  ) async {
    return developer.ServiceExtensionResponse.result(
      jsonEncode({...await duo.captureDuoState(agent), 'errors': errors}),
    );
  });
  developer.registerExtension('ext.catalog.capture', (
    method,
    parameters,
  ) async {
    final snapshot = await FoldablePlatform.instance.getSnapshot();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'status': snapshot.status.name,
        'angle': snapshot.angleDegrees,
        'size': '${view.physicalSize / view.devicePixelRatio}',
        'keyboard': view.viewInsets.bottom / view.devicePixelRatio,
        'textScale':
            MediaQuery.textScalerOf(key.currentContext!).scale(14) / 14,
        'component': key.currentState!.items[key.currentState!.itemIndex].name,
        'variant': key.currentState!.variantIndex,
        'errors': errors,
        'items': [
          for (final item in key.currentState!.items)
            {'name': item.name, 'variants': item.exampleData.length},
        ],
      }),
    );
  });
}
