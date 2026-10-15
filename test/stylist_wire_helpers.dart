import 'package:a2ui_flutter_commerce/src/agent/stylist_presenter.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_result.dart';

/// Wire assertions explicitly opt into the A2UI presenter. Domain assertions
/// continue to inspect the runtime's renderer-independent result directly.
Map<String, dynamic> presentedStylistTurn(Map result) =>
    result is StylistTurnResult
    ? presentStylistResult(result)
    : Map<String, dynamic>.from(result);
