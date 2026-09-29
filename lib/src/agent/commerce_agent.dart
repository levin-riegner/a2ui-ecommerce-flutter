import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import '../data/models.dart';

/// The small host contract shared by the offline fixture and remote stylist.
abstract class CommerceAgent extends ChangeNotifier {
  bool get hasStarted;
  DemoJourney? get activeJourney;
  String? get latestInlineSurfaceId;
  bool get hasSelectedProductsSurface;
  SurfaceController get controller;
  Conversation get conversation;

  Future<void> startJourney(DemoJourney journey);
}
