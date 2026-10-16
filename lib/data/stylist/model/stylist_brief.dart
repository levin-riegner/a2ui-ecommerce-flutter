import '../../catalog/model/models.dart';
import '../../catalog/model/money.dart';
import 'stylist_constraints.dart';

enum BriefFactSource { user, model, suggestion, inferred }

/// Remembered occasion facts, independent of the model's conversation history.
///
/// Search requires the same two clarifiers as the original PoC: the kind of
/// dressing and a whole-outfit budget. Free-form dress codes remain valid.
class StylistBrief {
  const StylistBrief({
    this.gender = '',
    this.occasion = '',
    this.dressCode = '',
    this.season = '',
    this.budget,
    this.palette = '',
    this.notes = '',
    this.tripStart = '',
    this.tripEnd = '',
    this.sources = const {},
    this.constraints = const StylistConstraints(),
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

  /// Requested garment audience, never an inferred identity of the wearer.
  final String gender;
  String get genderLabel => genderStylingLabel(gender);
  StylistConstraints get productConstraints =>
      constraints.withGender(gender, dressCode: dressCode);

  final String occasion;
  final String dressCode;
  final String season;
  final double? budget;
  int? get budgetCents => budget == null ? null : euroCents(budget!);
  final String palette;
  final String notes;
  final String tripStart;
  final String tripEnd;
  final Map<String, BriefFactSource> sources;
  final StylistConstraints constraints;

  StylistBrief withConstraints(
    StylistConstraints value, {
    Map<String, BriefFactSource>? factSources,
  }) => StylistBrief(
    gender: gender,
    occasion: occasion,
    dressCode: dressCode,
    season: season,
    budget: budget,
    palette: palette,
    notes: notes,
    tripStart: tripStart,
    tripEnd: tripEnd,
    sources: factSources ?? sources,
    constraints: value,
  );

  Map<String, Object?> toSnapshot() => {
    'facts': toMap(),
    'sources': {for (final e in sources.entries) e.key: e.value.name},
    'constraints': constraints.toMap(),
  };

  factory StylistBrief.fromSnapshot(Map<String, Object?> snapshot) {
    final facts = snapshot['facts'],
        sources = snapshot['sources'],
        constraints = snapshot['constraints'];
    if (facts is! Map ||
        sources is! Map ||
        constraints is! Map ||
        sources.keys.any((key) => !fields.contains(key)) ||
        sources.values.any(
          (v) => !BriefFactSource.values.any((s) => s.name == v),
        )) {
      throw const FormatException('Saved outfit facts are invalid.');
    }
    return const StylistBrief()
        .merge(Map<String, Object?>.from(facts))
        .withConstraints(
          StylistConstraints.fromMap(Map<String, Object?>.from(constraints)),
          factSources: Map.unmodifiable({
            for (final e in sources.entries)
              e.key as String: BriefFactSource.values.firstWhere(
                (s) => s.name == e.value,
              ),
          }),
        );
  }

  static const fields = {
    'gender',
    'occasion',
    'dressCode',
    'season',
    'budget',
    'palette',
    'notes',
    'tripStart',
    'tripEnd',
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
    if (gender.isNotEmpty) '$gender catalog audience',
    occasion,
    dressCode.replaceAll('-', ' '),
    season,
    palette,
    notes,
  ].where((value) => value.isNotEmpty).join(' ');

  String get planningBrief => planningText;

  String get summary => [
    if (gender.isNotEmpty) genderLabel,
    occasion,
    dressCode.replaceAll('-', ' '),
    season,
    if (budget != null) 'under ${_money(budget!)}',
    if (tripStart.isNotEmpty)
      '$tripStart${tripEnd.isEmpty || tripEnd == tripStart ? '' : '–$tripEnd'}',
    if (tripStart.isEmpty && tripEnd.isNotEmpty) 'ends $tripEnd',
  ].where((value) => value.isNotEmpty).join(' · ');

  Map<String, Object?> toMap() => {
    if (gender.isNotEmpty) 'gender': gender,
    if (occasion.isNotEmpty) 'occasion': occasion,
    if (dressCode.isNotEmpty) 'dressCode': dressCode,
    if (season.isNotEmpty) 'season': season,
    if (budget != null) 'budget': budget,
    if (palette.isNotEmpty) 'palette': palette,
    if (notes.isNotEmpty) 'notes': notes,
    if (tripStart.isNotEmpty) 'tripStart': tripStart,
    if (tripEnd.isNotEmpty) 'tripEnd': tripEnd,
  };

  /// Returns a validated copy. Blanks preserve facts; [clearFields] removes them.
  /// Protected user facts survive model defaults; invalid fields throw.
  StylistBrief merge(
    Map<String, Object?> patch, {
    BriefFactSource source = BriefFactSource.user,
    Set<String> clearFields = const {},
    bool protectUserFacts = false,
    Set<String> authorizedFields = const {},
  }) {
    final next = toMap();
    final nextSources = Map<String, BriefFactSource>.from(sources);
    bool protected(String name) =>
        protectUserFacts &&
        sources[name] == BriefFactSource.user &&
        !authorizedFields.contains(name);
    for (final name in clearFields) {
      if (!fields.contains(name)) {
        throw FormatException('Unknown outfit field: $name');
      }
      if (!protected(name)) {
        next.remove(name);
        nextSources.remove(name);
      }
    }
    for (final entry in patch.entries) {
      if (!fields.contains(entry.key)) {
        throw FormatException('Unknown outfit field: ${entry.key}');
      }
      if (protected(entry.key)) continue;
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
        nextSources['budget'] = source;
        continue;
      }
      if (value is! String) {
        throw FormatException('${entry.key} must be text');
      }
      var text = value.trim();
      if (entry.key == 'tripStart' || entry.key == 'tripEnd') {
        final date = DateTime.tryParse(text);
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
            date == null ||
            date.toIso8601String().substring(0, 10) != text) {
          throw const FormatException('Enter a valid trip date as YYYY-MM-DD.');
        }
      } else if (entry.key == 'gender') {
        text = text.toLowerCase();
        if (!const {'male', 'female', 'male, female'}.contains(text)) {
          throw const FormatException(
            'Gender must be male, female or male, female',
          );
        }
      } else if (entry.key == 'dressCode') {
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
      nextSources[entry.key] = source;
      next[entry.key] = text.length > maximum
          ? text.substring(0, maximum)
          : text;
    }
    if (next['tripStart'] is String &&
        next['tripEnd'] is String &&
        (next['tripEnd'] as String).compareTo(next['tripStart'] as String) <
            0) {
      throw const FormatException(
        'The trip end date must be on or after its start date.',
      );
    }
    return StylistBrief(
      gender: next['gender'] as String? ?? '',
      occasion: next['occasion'] as String? ?? '',
      dressCode: next['dressCode'] as String? ?? '',
      season: next['season'] as String? ?? '',
      budget: next['budget'] as double?,
      palette: next['palette'] as String? ?? '',
      notes: next['notes'] as String? ?? '',
      tripStart: next['tripStart'] as String? ?? '',
      tripEnd: next['tripEnd'] as String? ?? '',
      sources: Map.unmodifiable(nextSources),
      constraints: constraints,
    );
  }

  /// Records obvious facts from typed words; richer preferences use save_outfit.
  /// Budget extraction is shared with the runtime so UI and admission agree.
  StylistBrief recordMessage(
    String message, {
    double? budget,
    Iterable<String> knownBrands = const [],
  }) {
    final text = message.trim();
    final patch = <String, Object?>{
      'budget': ?(budget ?? parseBriefBudget(text)),
      'gender': ?parseBriefGender(text),
    };
    final clear = <String>{};
    if (RegExp(
      r'\b(?:clear|forget|reset|remove) (?:my |the )?trip dates\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      clear.addAll({'tripStart', 'tripEnd'});
    } else {
      final dates = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').allMatches(text).toList();
      if (dates.length == 2 &&
          RegExp(r'\b(?:to|through|until)\b')
              .hasMatch(text.substring(dates.first.end, dates.last.start))) {
        patch['tripStart'] = dates.first.group(0);
        patch['tripEnd'] = dates.last.group(0);
      } else if (dates.length == 1 &&
          RegExp(
            r'\b(?:trip|travel|from|on|visit|visiting)\b',
            caseSensitive: false,
          ).hasMatch(text)) {
        if (RegExp(
          r'\b(?:ends?|until|return(?:ing)?|back)\b',
          caseSensitive: false,
        ).hasMatch(text.substring(0, dates.single.start))) {
          patch['tripEnd'] = dates.single.group(0);
        } else {
          patch['tripStart'] = dates.single.group(0);
          clear.add('tripEnd');
        }
      }
    }
    for (final name in [
      'gender',
      'notes',
      'palette',
      'season',
      'occasion',
      'dressCode',
    ]) {
      final label = name == 'dressCode'
          ? r'(?:dress code|style)'
          : name == 'gender'
          ? r'(?:gender|audience)'
          : name;
      if (RegExp(
        '\\b(?:clear|forget|reset|remove) (?:my |the )?$label\\b',
        caseSensitive: false,
      ).hasMatch(text)) {
        clear.add(name);
      }
    }
    final occasionCorrection = RegExp(
      r"^(?:actually[, ]+|instead[, ]+|change (?:the |my )?occasion to )(?:(?:it(?: is|'s)?|this is) (?:for )?)?(.+)",
      caseSensitive: false,
    ).firstMatch(text);
    final correctedOccasion = occasionCorrection == null
        ? null
        : _occasionFromMessage(occasionCorrection.group(1)!);
    final statedOccasion = RegExp(
      r'\b(?:for my|attending|going to|occasion(?: is|:))\s+([^.!?;]+)',
      caseSensitive: false,
    ).firstMatch(text);
    var inferredOccasion = false;
    if (correctedOccasion != null &&
        RegExp(
          r'\b(?:wedding|dinner|interview|party|lunch|holiday|trip|meeting|date|concert|festival)\b',
          caseSensitive: false,
        ).hasMatch(correctedOccasion)) {
      patch['occasion'] = correctedOccasion;
    } else if (occasion.isEmpty &&
        statedOccasion != null &&
        !_negatedBefore(text, statedOccasion.start)) {
      patch['occasion'] = _occasionFromMessage(statedOccasion.group(1)!);
    } else if (occasion.isEmpty &&
        RegExp(
          r'\b(?:wedding|dinner|interview|party|lunch|holiday|trip|meeting|date|concert|festival|work|weekend|day|walk)\b',
          caseSensitive: false,
        ).allMatches(text).any((match) => !_negatedBefore(text, match.start))) {
      patch['occasion'] = _occasionFromMessage(text);
      inferredOccasion = true;
    }
    final style = _explicitStyle(text, inferCategory: dressCode.isEmpty);
    if (style != null) patch['dressCode'] = style;
    final mentionedSeasons =
        RegExp(r'\b(spring|summer|autumn|winter)\b', caseSensitive: false)
            .allMatches(text)
            .where((match) => !_negatedBefore(text, match.start))
            .map((match) => match.group(1)!.toLowerCase())
            .toSet();
    if (mentionedSeasons.length == 1) {
      patch['season'] = mentionedSeasons.single;
    }
    var updated = merge(patch, clearFields: clear);
    if (inferredOccasion && updated.occasion.isNotEmpty) {
      updated = updated.merge({
        'occasion': updated.occasion,
      }, source: BriefFactSource.inferred);
    }
    return StylistBrief(
      gender: updated.gender,
      occasion: updated.occasion,
      dressCode: updated.dressCode,
      season: updated.season,
      budget: updated.budget,
      palette: updated.palette,
      notes: updated.notes,
      tripStart: updated.tripStart,
      tripEnd: updated.tripEnd,
      sources: updated.sources,
      constraints: constraints.recordMessage(text, knownBrands: knownBrands),
    );
  }

  /// Explicit accepted facts mentioned this turn, including repeated values.
  /// Inferred occasion text is excluded from factual acknowledgments.
  Map<String, Object?> acceptedFactsFromMessage(String message) {
    final extracted = StylistBrief(
      dressCode: dressCode,
      occasion: occasion,
    ).recordMessage(message);
    final current = toMap();
    return {
      for (final entry in extracted.toMap().entries)
        if (extracted.sources[entry.key] == BriefFactSource.user &&
            current[entry.key] == entry.value)
          entry.key: entry.value,
    };
  }

  /// Changed authoritative fields; absent values represent explicit clearing.
  Map<String, Object?> changedFactsSince(StylistBrief previous) {
    final before = previous.toMap();
    final after = toMap();
    return {
      for (final field in fields)
        if (before[field] != after[field]) field: after[field],
    };
  }
}

String _money(double amount) => formatEuros(amount, omitZeroCents: true);

double _budget(Object? value) {
  double? amount;
  if (value is num) {
    amount = value.toDouble();
  } else if (value is String) {
    final raw = value
        .trim()
        .replaceAll(RegExp(r'€|\b(?:EUR|euros?)\b', caseSensitive: false), '')
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
  return eurosFromCents(euroCents(amount));
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
  final matches = <({int start, int end, String style})>[];
  for (final entry in {
    'black-tie': r'\bblack[ -]?tie\b',
    'white-tie': r'\bwhite[ -]?tie\b',
    'cocktail': r'\bcocktail\b',
    'outdoorsy': r'\b(?:outdoorsy|outdoor|hiking|walking|trail)\b',
    'smart-casual': r'\b(?:smart[ -]?casual|smart|polished)\b',
    'business': r'\b(?:business|professional)\b',
    'formal': r'\bformal\b',
    'casual': r'\b(?:casual|relaxed)\b',
    if (inferCategory)
      'dress': r'\b(?:dress(?:es)?|one[ -]pieces?|coveralls?|jumpsuits?)\b',
    if (inferCategory) 'separates': r'\b(?:tops?|shirts?|knits?|blouses?|trousers?|pants?|shorts?|skirts?)\b',
    if (inferCategory) 'layered': r'\b(?:layers?|jackets?|coats?|outerwear)\b',
  }.entries) {
    for (final match in RegExp(
      entry.value,
      caseSensitive: false,
    ).allMatches(message)) {
      if (!_negatedBefore(message, match.start)) {
        matches.add((start: match.start, end: match.end, style: entry.key));
      }
    }
  }
  // Prefer the last positive correction and the full phrase over its suffix.
  matches.removeWhere(
    (match) => matches.any(
      (other) => other.start < match.start && other.end >= match.end,
    ),
  );
  matches.sort((a, b) => a.start.compareTo(b.start));
  return matches.isEmpty ? null : matches.last.style;
}

bool _negatedBefore(String message, int start) {
  final prefix = message.substring(0, start);
  final clause = prefix
      .split(RegExp(r'[,;.!?]|\b(?:but|instead|and)\b', caseSensitive: false))
      .last;
  return RegExp(
    r"\b(?:no|not|without|avoid|exclude|don['’]?t|do not)\b(?:\s+\w+){0,4}\s*$",
    caseSensitive: false,
  ).hasMatch(clause);
}

/// Detects an explicitly non-EUR budget so the host can ask for a EUR
/// amount. Currency conversion is never inferred from the numeric value.
String? unsupportedBriefBudgetCurrency(String message) {
  final amounts = RegExp(
    r'((?:US|CA|AU)?\$|£|¥|\b(?:USD|GBP|CAD|AUD|JPY|CHF|CNY|INR)\b)\s*[0-9]+(?:[.,][0-9]+)*|[0-9]+(?:[.,][0-9]+)*\s*((?:US|CA|AU)?\$|£|¥|\b(?:USD|GBP|CAD|AUD|JPY|CHF|CNY|INR|dollars?|pounds?|yen)\b)',
    caseSensitive: false,
  );
  for (final match in amounts.allMatches(message)) {
    if (_negatedBefore(message, match.start)) continue;
    final before = message
        .substring(0, match.start)
        .split(RegExp(r'[,;.!?]'))
        .last;
    final after = message.substring(match.end).split(RegExp(r'[,;.!?]')).first;
    final item = RegExp(
      r'\b(?:dress|shoes?|tops?|shirts?|trousers?|pants?|bag|coat|jacket|skirt)\b',
      caseSensitive: false,
    ).hasMatch('$before $after');
    final total = RegExp(
      r'\b(?:whole|entire|total|overall|outfit)\b',
      caseSensitive: false,
    ).hasMatch('$before $after');
    final explicitBudget = RegExp(
      r'\b(?:budget(?: is| of)?|under|up to|spend(?:ing)?|afford|limit)\s*(?:is\s*)?$',
      caseSensitive: false,
    ).hasMatch(before);
    // An item-price quotation does not redefine a settled EUR outfit budget.
    if (item && !total && !explicitBudget) continue;
    return match.group(1) ?? match.group(2);
  }
  return null;
}

/// Extracts a whole-outfit EUR budget only when its scope is reasonably clear.
/// Bare numbers need spend/budget context; conflicting scoped totals are left
/// for clarification rather than silently taking the first item price.
double? parseBriefBudget(String message) {
  if (unsupportedBriefBudgetCurrency(message) != null) return null;
  final amountPattern = RegExp(
    r'(€|\bEUR\s+)?([0-9]+(?:(?:[.,][0-9]+)|(?:[ ]+[0-9]{3}))*)(?:\s*(€|EUR\b|euros?\b))?',
    caseSensitive: false,
  );
  final candidates = <({double amount, int score})>[];
  final amounts = amountPattern.allMatches(message).toList();
  for (var index = 0; index < amounts.length; index++) {
    final match = amounts[index];
    if (_negatedBefore(message, match.start)) continue;
    if (RegExp(r'[$£¥-]\s*$').hasMatch(message.substring(0, match.start)) ||
        RegExp(
          r'^\s*(?:USD|GBP|CAD|AUD|JPY|CHF|CNY|INR|dollars?|pounds?|yen)\b',
          caseSensitive: false,
        ).hasMatch(message.substring(match.end))) {
      continue;
    }
    // Bound each amount's context by its neighbors, so a later outfit total
    // cannot give an earlier item price the same scope.
    final before = message.substring(
      index == 0 ? 0 : amounts[index - 1].end,
      match.start,
    );
    final after = message.substring(
      match.end,
      index + 1 == amounts.length ? message.length : amounts[index + 1].start,
    );
    final localBefore = before.split(RegExp(r'[,;.!?]')).last;
    final localAfter = after.split(RegExp(r'[,;.!?]')).first;
    final currency = match.group(1) != null || match.group(3) != null;
    final totalPattern = RegExp(
      r'\b(?:whole|entire|total|overall)\b|\bfor (?:the |my |an? )?outfit\b',
      caseSensitive: false,
    );
    final total =
        totalPattern.hasMatch(localAfter) ||
        (index == 0 && totalPattern.hasMatch(localBefore)) ||
        RegExp(
          r'\b(?:whole|entire|total|overall)\b',
          caseSensitive: false,
        ).hasMatch(localBefore);
    final budget = RegExp(
      r'\b(?:budget|spend|spending|afford|under|up to|maximum|limit)\b',
      caseSensitive: false,
    ).hasMatch('$localBefore $localAfter');
    final item = RegExp(
      r'\b(?:dress|shoes?|tops?|shirts?|trousers?|pants?|bag|coat|jacket|skirt)\b',
      caseSensitive: false,
    ).hasMatch('$localBefore $localAfter');
    if (!currency && !budget && !total) continue;
    if (item &&
        !total &&
        !RegExp(
          r'\b(?:budget(?: is| of)?|under|up to)\s*$',
          caseSensitive: false,
        ).hasMatch(localBefore)) {
      continue;
    }
    double value;
    try {
      value = match.group(2) == '0' ? 0 : _budget(match.group(2));
    } on FormatException {
      continue;
    }
    candidates.add((
      amount: value,
      score: total
          ? 3
          : budget
          ? 2
          : 1,
    ));
  }
  if (candidates.isEmpty) return null;
  final bestScore = candidates
      .map((candidate) => candidate.score)
      .reduce((a, b) => a > b ? a : b);
  final best = candidates
      .where((candidate) => candidate.score == bestScore)
      .map((candidate) => candidate.amount)
      .toSet();
  return best.length == 1 ? best.single : null;
}

/// Explicit clothing-audience words. Negated mentions are not confirmations.
String? parseBriefGender(String message) {
  final mentions = <({int position, String value})>[];
  for (final entry in genderAudiencePatterns.entries) {
    for (final match in RegExp(
      entry.value,
      caseSensitive: false,
    ).allMatches(message)) {
      if (!_negatedBefore(message, match.start)) {
        mentions.add((position: match.start, value: entry.key));
      }
    }
  }
  if (mentions.isEmpty) return null;
  // A combined label spans its two individual labels; consume that phrase.
  final combined = RegExp(pairedGenderAudiencePattern, caseSensitive: false);
  mentions.removeWhere(
    (mention) =>
        mention.value != 'male, female' &&
        combined
            .allMatches(message)
            .any(
              (match) =>
                  mention.position >= match.start &&
                  mention.position < match.end,
            ),
  );
  if (mentions.isEmpty) return null;
  mentions.sort((a, b) => a.position.compareTo(b.position));
  return mentions.last.value;
}
