// Run with: fvm flutter test tool/export_reference_previews.dart
// Captures only the disconnected start screen and original project artwork.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/catalog/occasion_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _output = 'docs/verification/reference-architecture-2026-10-15';

void main() {
  testWidgets('export current disconnected start with real bundled fonts', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final (family, asset) in [
        ('Inter', 'assets/fonts/inter/Inter-Variable.ttf'),
        ('Jost', 'assets/fonts/jost/Jost-Variable.ttf'),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final captures = <Map<String, Object?>>[];

    for (final size in [const Size(466, 800), const Size(951, 669)]) {
      tester.view.physicalSize = size;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const ReferenceApp()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Connect your model'), findsWidgets);
      expect(find.byType(OccasionArtwork), findsWidgets);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final filename = 'start-${size.width.toInt()}x${size.height.toInt()}.png';
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(bytes, isNotNull);
        final directory = Directory(_output)..createSync(recursive: true);
        File('${directory.path}/$filename').writeAsBytesSync(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        image.dispose();
      });
      captures.add({
        'file': filename,
        'logicalSize': {'width': size.width, 'height': size.height},
        'pixelRatio': 1,
        'fonts': ['Inter', 'Jost'],
        'state': 'disconnected start; no provider configured or called',
        'artworkTiles': find.byType(OccasionArtwork).evaluate().length,
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
    File('$_output/captures.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(captures)}\n',
    );
  });
}
