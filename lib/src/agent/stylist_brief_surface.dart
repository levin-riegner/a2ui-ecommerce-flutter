/// Host-owned controls for missing outfit facts. Choices stay in the surface
/// data model until the person submits the brief in one explicit action.
class StylistBriefSurface {
  const StylistBriefSurface({required this.data, required this.components});

  final Map<String, Object?> data;
  final List<Map<String, Object?>> components;
}

StylistBriefSurface renderStylistBriefSurface({
  required String reply,
  required Map<String, Object?> clarification,
}) {
  final missing =
      (clarification['missingFields'] as List?)
          ?.map((field) => field.toString())
          .toSet() ??
      const <String>{};
  final dressCode = clarification['dressCode']?.toString() ?? '';
  final season = clarification['season']?.toString() ?? '';
  final budget = (clarification['budget'] as num?)?.toDouble();
  final styles = [
    'casual',
    'smart-casual',
    'business',
    'cocktail',
    'black-tie',
    'outdoorsy',
    if (dressCode.isNotEmpty &&
        !const [
          'casual',
          'smart-casual',
          'business',
          'cocktail',
          'black-tie',
          'outdoorsy',
        ].contains(dressCode))
      dressCode,
  ];
  final displayBudget = budget ?? 750.0;
  final data = <String, Object?>{
    'message': reply,
    'dressCode': dressCode,
    'season': season,
    // The suggested slider value only becomes a host fact on Find options.
    'budget': displayBudget,
  };
  final components = <Map<String, Object?>>[
    {
      'id': 'root',
      'component': 'Column',
      'align': 'stretch',
      'children': [
        'message',
        if (missing.contains('dressCode')) ...['style-label', 'style-options'],
        if (missing.contains('season')) ...['season-label', 'season-options'],
        if (missing.contains('budget')) 'brief-budget',
        'find-options',
      ],
    },
    {
      'id': 'message',
      'component': 'StylistMessage',
      'text': {'path': '/message'},
    },
    if (missing.contains('dressCode')) ...[
      {
        'id': 'style-label',
        'component': 'Eyebrow',
        'text': 'How formal or relaxed?',
      },
      {
        'id': 'style-options',
        'component': 'ChoiceGroup',
        'options': styles,
        'selected': {'path': '/dressCode'},
        'selectionPath': '/dressCode',
      },
    ],
    if (missing.contains('season')) ...[
      {'id': 'season-label', 'component': 'Eyebrow', 'text': 'Season'},
      {
        'id': 'season-options',
        'component': 'ChoiceGroup',
        'options': ['spring', 'summer', 'autumn', 'winter'],
        'selected': {'path': '/season'},
        'selectionPath': '/season',
      },
    ],
    if (missing.contains('budget'))
      {
        'id': 'brief-budget',
        'component': 'BudgetSlider',
        'value': {'path': '/budget'},
        'min': displayBudget < 50 ? displayBudget : 50,
        'max': displayBudget > 2500 ? displayBudget : 2500,
      },
    {
      'id': 'find-options',
      'component': 'PrimaryButton',
      'label': 'Find options',
      'action': {
        'event': {
          'name': 'find_options',
          'context': {
            'dressCode': {'path': '/dressCode'},
            'season': {'path': '/season'},
            'budget': {'path': '/budget'},
          },
        },
      },
    },
  ];
  return StylistBriefSurface(data: data, components: components);
}
