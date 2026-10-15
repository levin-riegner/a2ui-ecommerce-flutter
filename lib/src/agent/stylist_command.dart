import 'stylist_input_error.dart';
import 'stylist_schemas.dart';

/// Wire names remain stable while host code handles a closed command set.
enum StylistCommandKind {
  resumeSession('resume_session'),
  openSavedLooks('open_saved_looks'),
  saveLook('save_look'),
  restoreLook('restore_look'),
  deleteLook('delete_look'),
  resetLook('reset_look'),
  openBag('open_bag'),
  closeBag('close_bag'),
  addLookToBag('add_look_to_bag'),
  changeBagQuantity('change_bag_quantity'),
  removeBagItem('remove_bag_item'),
  restoreBagItem('restore_bag_item'),
  undoBagChanges('undo_bag_changes'),
  editPreferences('edit_preferences'),
  updatePreferences('update_preferences'),
  setColours('set_colours'),
  setBrandPreferences('set_brand_preferences'),
  compareProducts('compare_products'),
  refreshCityContext('refresh_city_context'),
  findOptions('find_options'),
  updateBudget('update_budget'),
  selectProduct('select_product'),
  removeProduct('remove_product'),
  adjustPiece('adjust_piece'),
  openProductDetails('open_product_details'),
  setFitSize('set_fit_size'),
  chooseProductColour('choose_product_colour'),
  setProductOptions('set_product_options'),
  previewDemoCheckout('preview_demo_checkout'),
  confirmDemoCheckout('confirm_demo_checkout'),
  openDemoReceipt('open_demo_receipt');

  const StylistCommandKind(this.wireName);
  final String wireName;
}

/// Validated command payload. Creation always passes the shared wire schema.
class StylistCommand {
  StylistCommand._(this.kind, Map<String, Object?> context)
    : context = _freezeContext(context) as Map<String, Object?>;
  final StylistCommandKind kind;
  final Map<String, Object?> context;
  String? get productId => context['productId'] as String?;
  String? get lookId => context['lookId'] as String?;
  int? get quantity => context['quantity'] as int?;
  Map<String, Object?> toJson() => {'name': kind.wireName, 'context': context};

  static Future<StylistCommand> decode(Object? raw) async {
    if (raw is! Map || raw['name'] is! String || raw['context'] is! Map) {
      throw const StylistInputError(
        code: StylistInputErrorCode.unsupportedAction,
        message: 'Choose an available outfit action.',
      );
    }
    final kind = StylistCommandKind.values
        .where((k) => k.wireName == raw['name'])
        .firstOrNull;
    if (kind == null) {
      throw const StylistInputError(
        code: StylistInputErrorCode.unsupportedAction,
        message: 'This action is not available in the local catalog yet. You can continue editing your outfit.',
      );
    }
    final context = Map<String, Object?>.from(raw['context'] as Map);
    if (context['category'] is String) {
      context['category'] = (context['category'] as String)
          .trim()
          .toLowerCase();
    }
    final normalized = {
      'name': kind.wireName,
      'context': _freezeContext(context),
    };
    if ((await stylistCommandSchema.validate(normalized)).isNotEmpty) {
      throw const StylistInputError(
        code: StylistInputErrorCode.invalidBrief,
        message: 'Choose valid outfit action values and try again.',
      );
    }
    return StylistCommand._(kind, context);
  }
}

class StylistTurnInput {
  const StylistTurnInput({this.message = '', this.command});
  final String message;
  final StylistCommand? command;
  Map<String, dynamic> toJson() => {
    if (message.isNotEmpty) 'message': message,
    if (command != null) 'action': command!.toJson(),
  };
  static Future<StylistTurnInput> decode(Map<String, dynamic> input) async {
    final command = input['action'] == null
        ? null
        : await StylistCommand.decode(input['action']);
    if ((await stylistTurnSchema.validate({
      ...input,
      if (command != null) 'action': command.toJson(),
    })).isNotEmpty) {
      throw const FormatException('Invalid stylist turn');
    }
    final message = input['message'] as String? ?? '';
    if (message.isEmpty && command == null) {
      throw const FormatException('A message or action is required');
    }
    return StylistTurnInput(message: message, command: command);
  }
}

Object? _freezeContext(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final e in value.entries) e.key as String: _freezeContext(e.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeContext));
  }
  return value;
}
