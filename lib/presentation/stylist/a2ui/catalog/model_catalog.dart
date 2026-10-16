import 'package:genui/genui.dart';

import '../../../../data/stylist/model/model_ui_catalog.dart';
import '../../../../data/stylist/model/stylist_schemas.dart';

/// Export registrations, including their action properties, rather than maintain
/// parallel model schemas. Root composition gives this and the original catalog
/// to the runtime and renderer respectively.
ModelUiCatalog buildModelUiCatalog(Catalog catalog) {
  final capabilities = catalog.toCapabilitiesJson();
  final schemas = capabilities['components']! as Map;
  return ModelUiCatalog(
    catalogId: capabilities['catalogId']! as String,
    entries: [
      for (final entry in schemas.entries)
        ModelUiCatalogEntry(
          name: entry.key as String,
          schema: Map<String, Object?>.from(entry.value as Map),
          guidance: _guidance(entry.key as String),
          availability: _availability(entry.key as String),
        ),
    ],
    instructions: catalog.systemPromptFragments,
    actionSchema: stylistCommandSchema.jsonSchema(),
  );
}

const _selectable = {
  'ProductCard':
      'Individual recommendation cards for one to five searched products.',
  'ThisOrThat': 'Side-by-side comparison of exactly two searched products.',
  'PicksStrip': 'Compact browsable shortlist of one to five searched products.',
  'AlternativePiece':
      'One replacement for a currently selected piece during adjustment.',
};
const _hostControlled = {
  'StylistSection':
      'Group the host-approved reply and recommendation children.',
  'StylistMessage':
      'Explain the current styling step using approved reply text.',
  'Eyebrow': 'Label a recommendation or form section with a short heading.',
  'DressingRoom':
      'Keep selected pieces, authoritative spend and outfit progress visible.',
  'QuickAdjust': 'Offer validated changes to a currently selected piece.',
  'ColourPicker':
      'Edit catalog-backed colour preferences or local variant selection.',
  'BrandPreferences':
      'Collect preferences among brands actually present in the catalog.',
  'ChoiceChip':
      'Offer a structured host action or edit a bound preference draft.',
  'PrimaryButton':
      'Submit an explicit host command after the person chooses it.',
  'DateTimeInput': 'Edit validated trip dates before preference submission.',
  'Look': 'Display a completed selection from authoritative product IDs.',
  'LookSummary': 'Explain completion and host-calculated outfit totals.',
  'AddToBagButton':
      'Let the person add an eligible completed look to the local demo bag.',
  'FitSize': 'Collect required local demo size or fit options for a product.',
  'TypicalWeather': 'Display fetched, attributed destination weather facts.',
  'SavedLooksRail':
      'Browse locally saved looks with host restore and delete actions.',
  'BagPreview': 'Display local bag quantities and host-calculated money.',
  'DeliveryEstimate': 'Explain the fictional local demo delivery scenario.',
  'FitNotes': 'Present local demo sizing or simulated receipt notes.',
  'Toast':
      'Show the outcome of a host action and its guarded undo when available.',
  'BudgetSlider':
      'Edit a proposed whole-outfit budget before explicit submission.',
  'ChoiceGroup': 'Group bound host intake choices such as season or style.',
  'RecommendationSkeleton': 'Show a temporary non-actionable loading state.',
  'RecommendationPreview':
      'Show the host provisional recommendation state before commit.',
  'PieceSlot':
      'Represent one host-planned outfit category and its current selection.',
};
ModelUiAvailability _availability(String name) => _selectable.containsKey(name)
    ? ModelUiAvailability.modelSelectable
    : _hostControlled.containsKey(name)
    ? ModelUiAvailability.hostControlled
    : ModelUiAvailability.referenceOnly;

String _guidance(String name) =>
    _selectable[name] ??
    (_hostControlled.containsKey(name)
        ? '${_hostControlled[name]} The host controls eligibility, bindings and actions.'
        : '$name is registered and demonstrated in the component gallery. Live model composition does not currently accept it.');
