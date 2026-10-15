import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import '../data/models.dart';
import 'conversation_entry.dart';

/// The host contract for the stylist and test fixture agents.
abstract class CommerceAgent extends ChangeNotifier {
  bool get hasStarted;
  DemoJourney? get activeJourney;
  String? get latestInlineSurfaceId;
  List<CommerceConversationEntry> get conversationEntries {
    final surfaceId = latestInlineSurfaceId;
    return [if (surfaceId != null) CommerceSurfaceEntry(surfaceId: surfaceId)];
  }

  String? get pendingInlineSurfaceId => null;
  bool get hasDressingRoomSurface => hasStarted;
  bool get isBusy => false;
  String? get connectionError => null;

  /// A rejected instruction that can be corrected through ordinary input.
  String? get inputError => null;
  String? get connectionNotice => null;
  bool get canRetry => false;
  bool get canStartBrief => false;
  int get bagCount => 0;
  bool get hasLocalLibrary => false;
  Future<void> openBag() async {}
  Future<void> retryLastTurn() async {}
  Future<void> startBrief(String message) async {}
  SurfaceController get controller;
  Conversation get conversation;

  Future<void> startJourney(DemoJourney journey);
}
