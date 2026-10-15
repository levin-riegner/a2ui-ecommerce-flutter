import 'package:flutter/foundation.dart';

import '../data/models.dart';
import 'model_settings.dart';

typedef StylistConnectionFactory = Future<CommerceSession> Function(
  ModelSettings settings,
);

/// UI session state and commands. No renderer, provider, or wire types escape.
/// The app owns and disposes a session after accepting it from the factory.
abstract class CommerceSession extends ChangeNotifier {
  bool get hasStarted;
  DemoJourney? get activeJourney;
  bool get isBusy => false;
  String? get connectionError => null;
  String? get inputError => null;
  String? get connectionNotice => null;
  bool get canRetry => false;
  bool get canStartBrief => false;
  int get bagCount => 0;
  bool get hasLocalLibrary => false;
  Future<void> openBag() async {}
  Future<void> openSavedLooks() async {}
  Future<bool> restartChat() async => true;
  Future<void> retryLastTurn() async {}
  Future<void> startBrief(String message) async {}
  Future<void> startJourney(DemoJourney journey);
  Future<void> sendMessage(String message);
}
