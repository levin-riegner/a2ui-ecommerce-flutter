import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

/// Recorded host wire messages shared by contract and renderer regression tests.
List<Map<String, dynamic>> readProtocolFixture(String name) => (jsonDecode(
  File('test/fixtures/protocol/$name.json').readAsStringSync(),
) as List).map((message) => Map<String, dynamic>.from(message as Map)).toList();

class ProtocolFixtureHarness {
  ProtocolFixtureHarness() {
    controller = SurfaceController(catalogs: [buildCommerceCatalog()]);
    transport = A2uiTransportAdapter(
      onSend: (message) async => sent.add(message),
    );
    conversation = Conversation(controller: controller, transport: transport);
  }

  late final SurfaceController controller;
  late final A2uiTransportAdapter transport;
  late final Conversation conversation;
  final List<ChatMessage> sent = [];

  void publish(String name) {
    for (final message in readProtocolFixture(name)) {
      transport.addMessage(core.A2uiMessage.fromJson(message));
    }
  }

  Map<String, dynamic> get submittedAction => Map<String, dynamic>.from(
    (jsonDecode(sent.single.parts.uiInteractionParts.single.interaction)
            as Map)['action']
        as Map,
  );

  Widget view(List<String> ids) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (final id in ids)
              Surface(
                key: ValueKey(id),
                surfaceContext: controller.contextFor(id),
              ),
          ],
        ),
      ),
    ),
  );

  void dispose() {
    conversation.dispose();
    controller.dispose();
  }
}
