/// A diagnostic vocabulary, deliberately unable to carry prompts or credentials.
/// Only structural counts and closed, known identifiers cross this boundary.
enum CommerceTraceKind {
  clientInput,
  modelRequest,
  modelResponse,
  toolResult,
  validation,
  surfaceCommit,
  turnFailure,
}

enum CommerceModelSource { provider, injected, offline }

enum CommerceTurnFailure { inputRejected, presentationRejected, unavailable }

class CommerceTraceEntry {
  CommerceTraceEntry._(this.kind, Map<String, Object?> details)
    : details = Map.unmodifiable(details);

  factory CommerceTraceEntry.turnFailure(CommerceTurnFailure failure) =>
      CommerceTraceEntry._(CommerceTraceKind.turnFailure, {
        'reason': failure.name,
        'committed': false,
      });

  factory CommerceTraceEntry.clientInput({
    required int messageLength,
    String? action,
  }) => CommerceTraceEntry._(CommerceTraceKind.clientInput, {
    'messageCharacters': messageLength,
    'messageContent': 'withheld',
    if (action != null) 'action': _known(action, _actions),
  });

  factory CommerceTraceEntry.modelRequest({
    required CommerceModelSource source,
    required int requestNumber,
    required int messageCount,
    required int catalogComponents,
    required Iterable<String> tools,
  }) => CommerceTraceEntry._(CommerceTraceKind.modelRequest, {
    'source': source.name,
    'requestNumber': requestNumber,
    'messageCount': messageCount,
    'catalogComponents': catalogComponents,
    'tools': List.unmodifiable(
      tools.take(16).map((name) => _known(name, _tools)),
    ),
    'promptContent': 'withheld',
  });

  factory CommerceTraceEntry.modelResponse({
    required CommerceModelSource source,
    required int textLength,
    required Iterable<String> tools,
    String? finishReason,
    String? component,
    int? productCount,
  }) => CommerceTraceEntry._(CommerceTraceKind.modelResponse, {
    'source': source.name,
    'finishReason': _known(finishReason, {
      'stop',
      'length',
      'blocked',
      'other',
    }),
    'textCharacters': textLength,
    'textContent': 'withheld',
    'tools': List.unmodifiable(
      tools.take(16).map((name) => _known(name, _tools)),
    ),
    if (component != null) 'component': _known(component, modelComponents),
    'productCount': ?productCount,
  });

  factory CommerceTraceEntry.toolResult({
    required String tool,
    required bool accepted,
    int? productCount,
  }) => CommerceTraceEntry._(CommerceTraceKind.toolResult, {
    'tool': _known(tool, _tools),
    'accepted': accepted,
    'productCount': ?productCount,
    'content': 'withheld',
    'origin': 'hostTool',
  });

  factory CommerceTraceEntry.validation({
    required bool accepted,
    String? component,
  }) => CommerceTraceEntry._(CommerceTraceKind.validation, {
    'accepted': accepted,
    if (component != null) 'component': _known(component, modelComponents),
  });

  /// A summary of the validated host batch, never a purported raw model payload.
  factory CommerceTraceEntry.surfaceCommit({
    required Iterable<String> components,
    required Iterable<String> registeredComponents,
    required int messageCount,
    required int bagCount,
    required bool modelSelected,
  }) => CommerceTraceEntry._(CommerceTraceKind.surfaceCommit, {
    'origin': 'hostComposed',
    'recommendationChoice': modelSelected ? 'modelSelected' : 'hostSelected',
    'messageCount': messageCount,
    'bagCount': bagCount,
    'components': List.unmodifiable(
      components.toSet().map(
        (name) => _known(name, registeredComponents.toSet()),
      ),
    ),
    'dynamicContent': 'withheld',
    'representation': 'structuralSummary',
  });

  final CommerceTraceKind kind;
  final Map<String, Object?> details;

  static const modelComponents = {
    'ProductCard',
    'ThisOrThat',
    'PicksStrip',
    'AlternativePiece',
  };

  static String _known(String? value, Set<String> allowed) =>
      allowed.contains(value) ? value! : 'unrecognized';

  static const _tools = {
    'respond_to_question',
    'search_products',
    'present_products',
    'save_outfit',
    'add_to_outfit',
    'remove_from_outfit',
    'apply_outfit_changes',
  };

  static const _actions = {
    'resume_session',
    'open_saved_looks',
    'save_look',
    'reset_look',
    'open_bag',
    'close_bag',
    'add_look_to_bag',
    'undo_bag_changes',
    'edit_preferences',
    'compare_products',
    'refresh_city_context',
    'select_product',
    'remove_product',
    'remove_bag_item',
    'restore_look',
    'delete_look',
    'change_bag_quantity',
    'restore_bag_item',
    'preview_demo_checkout',
    'open_demo_receipt',
    'confirm_demo_checkout',
    'open_product_details',
    'set_fit_size',
    'choose_product_colour',
    'set_product_options',
    'adjust_piece',
    'find_options',
    'update_budget',
    'update_preferences',
    'set_colours',
    'set_brand_preferences',
  };
}
