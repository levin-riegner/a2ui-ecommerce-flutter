import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import '../data/models.dart';

/// The host contract for the stylist and test fixture agents.
abstract class CommerceAgent extends ChangeNotifier {
  bool get hasStarted;
  DemoJourney? get activeJourney;
  String? get latestInlineSurfaceId;
  bool get hasSelectedProductsSurface;
  bool get hasDressingRoomSurface => hasStarted;
  bool get isBusy => false;
  String? get connectionError => null;
  String? get connectionNotice => null;
  bool get canRetry => false;
  Future<void> retryLastTurn() async {}
  SurfaceController get controller;
  Conversation get conversation;

  Future<void> startJourney(DemoJourney journey);
}
