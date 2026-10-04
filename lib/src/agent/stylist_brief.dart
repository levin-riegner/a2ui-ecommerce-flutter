import '../data/models.dart';

/// Remembered occasion facts, independent of the model's conversation history.
///
/// Search requires the same two clarifiers as the original PoC: the kind of
/// dressing and a whole-outfit budget. Free-form dress codes remain valid.
class StylistBrief {
  const StylistBrief({
    this.occasion = '',
    this.dressCode = '',
    this.season = '',
    this.budget,
    this.palette = '',
    this.notes = '',
  });

  factory StylistBrief.fromJourney(DemoJourney journey) => StylistBrief(
    occasion: journey.title,
    dressCode: switch (journey) {
      DemoJourney.paris => 'black-tie',
      DemoJourney.berlin || DemoJourney.lisbon => 'smart-casual',
      DemoJourney.cotswolds => 'casual',
    },
    season: journey.season.toLowerCase(),
    budget: journey.budget,
  );

  final String occasion;
  final String dressCode;
  final String season;
  final double? budget;
  final String palette;
  final String notes;

  static const fields = {
    'occasion',
    'dressCode',
    'season',
    'budget',
    'palette',
    'notes',
  };
  static const seasons = {'spring', 'summer', 'autumn', 'winter'};

  List<String> get missingFields => [
    if (dressCode.isEmpty) 'dressCode',
    if (budget == null) 'budget',
  ];

  List<String> get missing => missingFields;
  bool get canSearch => missingFields.isEmpty;

  /// Current facts only: replacing winter with summer does not retain winter.
  String get planningText => [
    occasion,
    dressCode.replaceAll('-', ' '),
    season,
    palette,
    notes,
  ].where((value) => value.isNotEmpty).join(' ');

  String get planningBrief => planningText;

  String get summary => [
    occasion,
    dressCode.replaceAll('-', ' '),
    season,
    if (budget != null) 'under ${_money(budget!)}',
  ].where((value) => value.isNotEmpty).join(' · ');

  Map<String, Object?> toMap() => {
    if (occasion.isNotEmpty) 'occasion': occasion,
    if (dressCode.isNotEmpty) 'dressCode': dressCode,
    if (season.isNotEmpty) 'season': season,
    if (budget != null) 'budget': budget,
    if (palette.isNotEmpty) 'palette': palette,
    if (notes.isNotEmpty) 'notes': notes,
  };

  /// Applies one validated save or editor submission without mutating this brief.
  ///
  /// Blank values leave existing facts intact. Invalid fields fail explicitly,
  /// so a model or editor can correct them instead of silently losing an answer.
  StylistBrief merge(Map<String, Object?> patch) {
    final next = toMap();
    for (final entry in patch.entries) {
      if (!fields.contains(entry.key)) {
        throw FormatException('Unknown outfit field: ${entry.key}');
      }
      var value = entry.value;
      if (value is List) {
        if (value.length != 1) {
          throw FormatException('${entry.key} needs one value');
        }
        value = value.single;
      }
      if (value == null || (value is String && value.trim().isEmpty)) {
        continue;
      }
      if (entry.key == 'budget') {
        next['budget'] = _budget(value);
        continue;
      }
      if (value is! String) {
        throw FormatException('${entry.key} must be text');
      }
      var text = value.trim();
      if (entry.key == 'dressCode') {
        text = text.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      } else if (entry.key == 'season') {
        text = text.toLowerCase();
        if (!seasons.contains(text)) {
          throw const FormatException(
            'Season must be spring, summer, autumn or winter',
          );
        }
      }
      final maximum = entry.key == 'dressCode' ? 60 : 400;
      next[entry.key] = text.length > maximum
          ? text.substring(0, maximum)
          : text;
    }
    return StylistBrief(
      occasion: next['occasion'] as String? ?? '',
      dressCode: next['dressCode'] as String? ?? '',
      season: next['season'] as String? ?? '',
      budget: next['budget'] as double?,
      palette: next['palette'] as String? ?? '',
      notes: next['notes'] as String? ?? '',
    );
  }

  /// Records obvious facts from typed words; richer preferences use save_outfit.
  /// The runtime passes its already parsed monetary amount to avoid two parsers.
  StylistBrief recordMessage(String message, {double? budget}) {
    final text = message.trim();
    final patch = <String, Object?>{'budget': ?budget};
    if (occasion.isEmpty &&
        RegExp(r'[a-z]', caseSensitive: false).hasMatch(
          text.replaceAll(RegExp(r'\bEUR\b', caseSensitive: false), ''),
        )) {
      patch['occasion'] = _occasionFromMessage(text);
    }
    final style = _explicitStyle(text, inferCategory: dressCode.isEmpty);
    if (style != null) patch['dressCode'] = style;
    final mentionedSeasons = RegExp(
      r'\b(spring|summer|autumn|winter)\b',
      caseSensitive: false,
    ).allMatches(text).map((match) => match.group(1)!.toLowerCase()).toSet();
    if (mentionedSeasons.length == 1) {
      patch['season'] = mentionedSeasons.single;
    }
    return merge(patch);
  }
}

String _money(double amount) =>
    '€${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';

double _budget(Object? value) {
  double? amount;
  if (value is num) {
    amount = value.toDouble();
  } else if (value is String) {
    final raw = value
        .trim()
        .replaceAll(RegExp(r'€|\bEUR\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s'), '');
    if (RegExp(r'^\d+(?:[.,]\d+)*$').hasMatch(raw)) {
      final decimal = RegExp(r'[.,](\d{1,2})$').firstMatch(raw);
      final digits = decimal == null
          ? raw.replaceAll(RegExp(r'[.,]'), '')
          : '${raw.substring(0, decimal.start).replaceAll(RegExp(r'[.,]'), '')}.${decimal.group(1)}';
      amount = double.tryParse(digits);
    }
  }
  if (amount == null || !amount.isFinite || amount <= 0) {
    throw const FormatException('Budget must be a positive amount in EUR');
  }
  return (amount * 100).roundToDouble() / 100;
}

String _occasionFromMessage(String message) => message
    .replaceAll(
      RegExp(
        r'(?:under|budget(?:\s+of)?)?\s*(?:€|EUR)\s*[0-9][0-9.,\s]*|[0-9][0-9.,\s]*\s*(?:€|EUR\b)',
        caseSensitive: false,
      ),
      '',
    )
    .replaceAll(
      RegExp(
        r'\b(?:spring|summer|autumn|winter|black[ -]?tie|white[ -]?tie|cocktail|smart[ -]?casual|smart|polished|business|professional|formal|casual|relaxed|outdoorsy)\b',
        caseSensitive: false,
      ),
      '',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String? _explicitStyle(String message, {required bool inferCategory}) {
  for (final entry in {
    'black-tie': r'\bblack[ -]?tie\b',
    'white-tie': r'\bwhite[ -]?tie\b',
    'cocktail': r'\bcocktail\b',
    'outdoorsy': r'\b(?:outdoorsy|outdoor|hiking|walking|trail)\b',
    'smart-casual': r'\b(?:smart[ -]?casual|smart|polished)\b',
    'business': r'\b(?:business|professional)\b',
    'formal': r'\bformal\b',
    'casual': r'\b(?:casual|relaxed)\b',
    if (inferCategory) 'dress': r'\bdress(?:es)?\b',
    if (inferCategory) 'separates': r'\b(?:tops?|shirts?|knits?|blouses?|trousers?|pants?|shorts?|skirts?)\b',
    if (inferCategory) 'layered': r'\b(?:layers?|jackets?|coats?|outerwear)\b',
  }.entries) {
    if (RegExp(entry.value, caseSensitive: false).hasMatch(message)) {
      return entry.key;
    }
  }
  return null;
}
