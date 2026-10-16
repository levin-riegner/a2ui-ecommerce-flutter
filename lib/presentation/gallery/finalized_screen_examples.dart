import 'dart:convert';

import 'package:flutter/material.dart';

export '../shared/design_system/views/commerce/occasion_collage.dart'
    show FinalizedOccasionCollage;

/// Executable compositions from the 14 finalized Designs frames. Source copy
/// inconsistencies are retained in sourceIssues, never treated as live data.
class FinalizedScreenExample {
  FinalizedScreenExample._(this._source);
  final Map<String, Object?> _source;
  String get id => _source['id']! as String;
  String get nodeId => _source['nodeId']! as String;
  String get name => _source['name']! as String;
  double get width => (_source['width']! as num).toDouble();
  double get height => (_source['height']! as num).toDouble();
  Size get referenceSize => Size(width, height);
  Map<String, Object?> get data =>
      Map<String, Object?>.from(_source['data']! as Map);
  List<String> get sourceIssues =>
      List<String>.from(_source['sourceIssues']! as List);
  bool get hasOverlay => (_source['overlay']! as List).isNotEmpty;

  List<Map<String, Object?>> _pane(String key, {String rootId = 'root'}) {
    final rows = (_source[key]! as List).cast<Map>();
    return [
      {
        'id': rootId,
        'component': 'Column',
        'align': 'stretch',
        'children': [for (var i = 0; i < rows.length; i++) '$key-$i'],
      },
      for (var i = 0; i < rows.length; i++)
        {'id': '$key-$i', ...Map<String, Object?>.from(rows[i])},
    ];
  }

  /// Pass these flat definitions and [data] to the normal A2UI surface runtime.
  /// The host Duo adapter owns safe areas, scrolling, hinge and pane placement.
  List<Map<String, Object?>> chatComponents() => _pane('chat');
  List<Map<String, Object?>> roomComponents() => _pane('room');
  List<Map<String, Object?>> overlayComponents() => _pane('overlay');

  /// Portable, single-surface composition. Production uses the individual pane
  /// surfaces so the Duo layout adapter can keep its persistent dressing room.
  List<Map<String, Object?>> components({bool portrait = false}) {
    final chat = _pane('chat', rootId: 'chat-pane');
    final room = _pane('room', rootId: 'room-pane');
    return [
      {
        'id': 'root',
        'component': portrait ? 'Column' : 'Row',
        'align': portrait ? 'stretch' : 'start',
        'children': portrait && id != 'start'
            ? ['room-pane', 'chat-pane']
            : ['chat-pane', 'room-pane'],
      },
      for (final definition in [...chat, ...room])
        {
          ...definition,
          if (!portrait &&
              (definition['id'] == 'chat-pane' ||
                  definition['id'] == 'room-pane'))
            'weight': 1,
        },
    ];
  }
}

final finalizedScreenExamples = <FinalizedScreenExample>[
  for (final source in jsonDecode(_screenFixturesJson) as List)
    FinalizedScreenExample._(Map<String, Object?>.from(source as Map)),
];

const _screenFixturesJson = r'''
[
  {
    "id": "start",
    "nodeId": "175:2285",
    "name": "01 — Start",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 1500,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "Text",
        "text": "Where are you going?",
        "variant": "h2"
      },
      {
        "component": "StylistMessage",
        "text": "Tell me the occasion, where it is and roughly what you’d like to spend. I’ll pull the whole look together from what we carry, and you can change anything as we go."
      },
      {
        "component": "Eyebrow",
        "text": "Here are some examples"
      },
      {
        "component": "Suggestion",
        "text": "A summer wedding in Lisbon in late June — outdoor ceremony, cocktail dress code, around €1,200 for the whole outfit",
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      },
      {
        "component": "Suggestion",
        "text": "Anniversary dinner at a smart restaurant in Paris in October, black tie optional, about €1,500",
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      },
      {
        "component": "Suggestion",
        "text": "First day at a creative agency in Berlin in September. Smart casual, nothing corporate, under €800",
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "OccasionCollage"
      }
    ],
    "overlay": [],
    "sourceIssues": []
  },
  {
    "id": "brief",
    "nodeId": "175:3772",
    "name": "02 — Brief",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 1500,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "UserMessage",
        "text": "Anniversary dinner at a smart restaurant in Paris in October, black tie optional, about €1,500"
      },
      {
        "component": "StylistMessage",
        "text": "Perfect — an anniversary in Paris in October. I’d go elegant, with the option to take it all the way to black tie. Three quick things and I’ll pull options for you."
      },
      {
        "component": "ChoiceChip",
        "label": "Black tie",
        "selected": true,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Black tie"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Cocktail",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Cocktail"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Smart Elegant",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Smart Elegant"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Spring",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Spring"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Summer",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Summer"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Autumn",
        "selected": true,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Autumn"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Winter",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Winter"
            }
          }
        }
      },
      {
        "component": "BudgetSlider",
        "value": {
          "path": "/budget"
        },
        "min": 0,
        "max": 3750
      },
      {
        "component": "PrimaryButton",
        "label": "Find options",
        "action": {
          "event": {
            "name": "find_options",
            "context": {
              "budget": {
                "path": "/budget"
              },
              "dressCode": {
                "path": "/dressCode"
              },
              "season": {
                "path": "/season"
              }
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "16° / 10°",
        "rain": "Rain 4 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/paris-autumn.png",
        "photoB": "assets/images/finalized_left/restaurant.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "Anniversary dinner in Paris · black tie optional · under €1,500",
        "spent": "€0 spent · 0 of 4",
        "left": "€1,500 left",
        "progress": 0.0,
        "slots": [
          {
            "category": "dress",
            "label": "A dress",
            "name": "",
            "meta": "Choosing now",
            "state": "Next",
            "swatch": "#181818"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          }
        ]
      }
    ],
    "overlay": [],
    "sourceIssues": []
  },
  {
    "id": "picks",
    "nodeId": "186:4485",
    "name": "03 — Picks",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 1500,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "Lovely — the Zimmermann is in your dressing room and leaves you €626. Shoes next: I’d keep them refined and let the dress do the talking."
      },
      {
        "component": "Eyebrow",
        "text": "Shoes · black tie · under €626"
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Satin Pointed Pump",
        "price": "€545",
        "brandLine": "Manolo Blahnik · Black · Satin · 70mm",
        "tag": "Most formal",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "paris-shoes-1"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Leather Kitten Heel",
        "price": "€295",
        "brandLine": "Aeyde · Black · Leather · 55mm",
        "tag": "Easiest",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-kitten-heel"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Suede Low-Top Sneaker",
        "price": "€349",
        "brandLine": "Common Projects · Off-white · Suede",
        "tag": "Relaxed",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-sneaker"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "16° / 10°",
        "rain": "Rain 4 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/paris-autumn.png",
        "photoB": "assets/images/finalized_left/restaurant.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "Anniversary dinner in Paris · black tie optional · under €1,500",
        "spent": "€874 spent · 1 of 4",
        "left": "€626 left",
        "progress": 0.5826666666666667,
        "slots": [
          {
            "category": "dress",
            "label": "A dress",
            "name": "Indra Long Dress",
            "meta": "Zimmermann · €874",
            "state": "Filled",
            "swatch": "#b8a98e"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "",
            "meta": "Choosing now",
            "state": "Next",
            "swatch": "#181818"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Partial",
        "pieceCount": 1,
        "total": "€874",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-picks"
            }
          }
        }
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source budget meter says €0 spent / €1,500 left although selected dress costs €874. Fixture computes €874 spent / €626 left from selected pieces."
    ]
  },
  {
    "id": "portrait_picks",
    "nodeId": "204:7733",
    "name": "04 — Picks (inner display, portrait)",
    "width": 669,
    "height": 951,
    "data": {
      "budget": 1500,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "Lovely — the Zimmermann is in your dressing room and leaves you €626. Shoes next: I’d keep them refined and let the dress do the talking."
      },
      {
        "component": "Eyebrow",
        "text": "Anniversary dinner in Paris · black tie optional · under €1,500"
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Satin Pointed Pump",
        "price": "€545",
        "brandLine": "Manolo Blahnik · Black · Satin · 70mm",
        "tag": "Most formal",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "paris-shoes-1"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Leather Kitten Heel",
        "price": "€295",
        "brandLine": "Aeyde · Black · Leather · 55mm",
        "tag": "Easiest",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-kitten-heel"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Suede Low-Top Sneaker",
        "price": "€349",
        "brandLine": "Common Projects · Off-white · Suede",
        "tag": "Relaxed",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-sneaker"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "16° / 10°",
        "rain": "Rain 4 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/paris-autumn.png",
        "photoB": "assets/images/finalized_left/restaurant.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "Anniversary dinner in Paris · black tie optional · under €1,500",
        "spent": "€874 spent · 1 of 4",
        "left": "€626 left",
        "progress": 0.5826666666666667,
        "slots": [
          {
            "category": "dress",
            "label": "A dress",
            "name": "Indra Long Dress",
            "meta": "Zimmermann · €874",
            "state": "Filled",
            "swatch": "#b8a98e"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "",
            "meta": "Choosing now",
            "state": "Next",
            "swatch": "#181818"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Partial",
        "pieceCount": 1,
        "total": "€874",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-portrait_picks"
            }
          }
        }
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source budget meter says €0 spent / €1,500 left although selected dress costs €874. Fixture computes €874 spent / €626 left from selected pieces."
    ]
  },
  {
    "id": "berlin_brief",
    "nodeId": "203:4824",
    "name": "B1 — Brief • Berlin first day",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 800,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "UserMessage",
        "text": "First day at a creative agency in Berlin in September. Smart casual, nothing corporate, under €800"
      },
      {
        "component": "StylistMessage",
        "text": "Nice — first days are about looking like yourself, just a notch sharper. Tell me how you want to come across and what you usually wear, and I’ll build around that."
      },
      {
        "component": "ChoiceChip",
        "label": "Polished",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Polished"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Relaxed",
        "selected": true,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Relaxed"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "A bit bold",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "A bit bold"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Trousers + Shirt",
        "selected": true,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Trousers + Shirt"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Denim",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Denim"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "A dress",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "A dress"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Yes",
        "selected": true,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Yes"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "No",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "No"
            }
          }
        }
      },
      {
        "component": "BudgetSlider",
        "value": {
          "path": "/budget"
        },
        "min": 0,
        "max": 3750
      },
      {
        "component": "PrimaryButton",
        "label": "Build the look",
        "action": {
          "event": {
            "name": "find_options",
            "context": {
              "budget": {
                "path": "/budget"
              },
              "dressCode": {
                "path": "/dressCode"
              },
              "season": {
                "path": "/season"
              }
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "12° / 19°",
        "rain": "Rain 3 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "First day · Berlin · September · smart casual, relaxed · under €800",
        "spent": "€0 spent · 0 of 4",
        "left": "€800 left",
        "progress": 0.0,
        "slots": [
          {
            "category": "bottom",
            "label": "Trousers",
            "name": "",
            "meta": "Choosing now",
            "state": "Next",
            "swatch": "#181818"
          },
          {
            "category": "top",
            "label": "Top",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          }
        ]
      }
    ],
    "overlay": [],
    "sourceIssues": []
  },
  {
    "id": "berlin_tops",
    "nodeId": "203:5085",
    "name": "B2 — Picks • Tops",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 800,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "Good trouser — it’s in your dressing room. Now a top. Nothing stiff: I’d go for a knit or a soft shirt you can push the sleeves up on."
      },
      {
        "component": "Eyebrow",
        "text": "Tops • Relaxed • Under €510"
      },
      {
        "component": "ProductCard",
        "category": "top",
        "name": "Merino Crew Knit",
        "price": "€180",
        "brandLine": "COS · Charcoal · Merino",
        "tag": "Easiest",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-berlin-knit"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "top",
        "name": "Washed Cotton Shirt",
        "price": "€145",
        "brandLine": "Sunspel · Off-white · Cotton",
        "tag": "Sharpest",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-berlin-shirt"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "top",
        "name": "Striped Boat-Neck Tee",
        "price": "€95",
        "brandLine": "Armor Lux · Navy stripe · Cotton",
        "tag": "A bit bold",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-berlin-tee"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "12° / 19°",
        "rain": "Rain 3 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "First day · Berlin · September · smart casual, relaxed · under €800",
        "spent": "€290 spent · 1 of 4",
        "left": "€510 left",
        "progress": 0.3625,
        "slots": [
          {
            "category": "bottom",
            "label": "Trousers",
            "name": "Pleated Wool Trouser",
            "meta": "Uniqlo U · €290",
            "state": "Filled",
            "swatch": "#666666"
          },
          {
            "category": "top",
            "label": "Top",
            "name": "",
            "meta": "Choosing now",
            "state": "Next",
            "swatch": "#181818"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Partial",
        "pieceCount": 1,
        "total": "€290",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-berlin_tops"
            }
          }
        }
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source cards retain shoe product names and final card category Shoes while showing top prices/brands. Executable fixture uses corrected top names already present in Berlin Complete source, preserving product identity and category."
    ]
  },
  {
    "id": "berlin_complete",
    "nodeId": "203:5384",
    "name": "B3 — Complete look",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 800,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "Good trouser — it’s in your dressing room. Now a top. Nothing stiff: I’d go for a knit or a soft shirt you can push the sleeves up on."
      },
      {
        "component": "Eyebrow",
        "text": "Tops • Relaxed • Under €510"
      },
      {
        "component": "ProductCard",
        "category": "top",
        "name": "Merino Crew Knit",
        "price": "€180",
        "brandLine": "COS · Charcoal · Merino",
        "tag": "Easiest",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-berlin-knit"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "top",
        "name": "Washed Cotton Shirt",
        "price": "€145",
        "brandLine": "Sunspel · Off-white · Cotton",
        "tag": "Sharpest",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-berlin-shirt"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "top",
        "name": "Striped Boat-Neck Tee",
        "price": "€95",
        "brandLine": "Armor Lux · Navy stripe · Cotton",
        "tag": "A bit bold",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-berlin-tee"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "12° / 19°",
        "rain": "Rain 3 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "First day · Berlin · September · smart casual, relaxed · under €800",
        "spent": "€775 spent · 4 of 4",
        "left": "€25 left",
        "progress": 0.96875,
        "slots": [
          {
            "category": "bottom",
            "label": "Trousers",
            "name": "Pleated Wool Trouser",
            "meta": "Uniqlo U · €290",
            "state": "Filled",
            "swatch": "#666666"
          },
          {
            "category": "top",
            "label": "Top",
            "name": "Merino Crew Knit",
            "meta": "COS · €180",
            "state": "Filled",
            "swatch": "#555555"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "Unlined Cotton Blazer",
            "meta": "Arket · €190",
            "state": "Filled",
            "swatch": "#444444"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "Leather Derby",
            "meta": "Grenson · €115",
            "state": "Filled",
            "swatch": "#222222"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Default",
        "pieceCount": 4,
        "total": "€775",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-berlin_complete"
            }
          }
        }
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source selected top is named Washed Cotton Shirt but priced/branded as COS €180 knit. Fixture uses Merino Crew Knit (from source recommendation) to preserve item identity and €775 total."
    ]
  },
  {
    "id": "cotswolds_brief",
    "nodeId": "203:5644",
    "name": "C1 — Brief · Cotswolds weekend",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 800,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "UserMessage",
        "text": "First day at a creative agency in Berlin in September. Smart casual, nothing corporate, under €800"
      },
      {
        "component": "StylistMessage",
        "text": "Nice — first days are about looking like yourself, just a notch sharper. Tell me how you want to come across and what you usually wear, and I’ll build around that."
      },
      {
        "component": "ChoiceChip",
        "label": "An hour or two",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "An hour or two"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Half days",
        "selected": true,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Half days"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "All day",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "All day"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Yes, a pub",
        "selected": true,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Yes, a pub"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Something nicer",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Something nicer"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Just walking",
        "selected": false,
        "action": {
          "event": {
            "name": "set_brief_choice",
            "context": {
              "value": "Just walking"
            }
          }
        }
      },
      {
        "component": "TypicalWeather",
        "title": "Design example",
        "days": [
          {
            "label": "Fri",
            "value": "9°",
            "detail": "Rain"
          },
          {
            "label": "Sat",
            "value": "7°",
            "detail": "Showers"
          },
          {
            "label": "Sun",
            "value": "8°",
            "detail": "Cloudy"
          }
        ],
        "disclaimer": "Figma example data; not a live forecast"
      },
      {
        "component": "PrimaryButton",
        "label": "Start with the coat",
        "action": {
          "event": {
            "name": "find_options",
            "context": {
              "budget": {
                "path": "/budget"
              },
              "dressCode": {
                "path": "/dressCode"
              },
              "season": {
                "path": "/season"
              }
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "12° / 19°",
        "rain": "Rain 3 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "First day · Berlin · September · smart casual, relaxed · under €800",
        "spent": "€0 spent · 0 of 4",
        "left": "€800 left",
        "progress": 0.0,
        "slots": [
          {
            "category": "bottom",
            "label": "Trousers",
            "name": "",
            "meta": "Choosing now",
            "state": "Next",
            "swatch": "#181818"
          },
          {
            "category": "top",
            "label": "Top",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          }
        ]
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "The finalized Cotswolds Brief frame still contains Berlin user message, narrative, rack brief, copied Berlin photographs and €800 budget. Fixture preserves source text as a review issue; it is not a validated Cotswolds flow."
    ]
  },
  {
    "id": "cotswolds_boots",
    "nodeId": "203:5999",
    "name": "C2 — Picks · boots",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 800,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "Good — the waxed jacket’s on your rack and will shrug off the rain. Boots next: waterproof, and something you can walk half a day in."
      },
      {
        "component": "Eyebrow",
        "text": "Boots · waterproof · under €575"
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Leather Country Boot",
        "price": "€180",
        "brandLine": "Blundstone · Brown · Waterproof leather",
        "tag": "Easiest",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-country-boot"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Lace-Up Walking Boot",
        "price": "€145",
        "brandLine": "Grenson · Brown · Gore-Tex",
        "tag": "Best for all day",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-walking-boot"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Tall Rubber Boot",
        "price": "€95",
        "brandLine": "Le Chameau · Green · Rubber",
        "tag": "Wettest days",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-rubber-boot"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "12° / 19°",
        "rain": "Rain 3 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "First day · Berlin · September · smart casual, relaxed · under €800",
        "spent": "€0 spent · 0 of 4",
        "left": "€800 left",
        "progress": 0.0,
        "slots": [
          {
            "category": "bottom",
            "label": "Trousers",
            "name": "",
            "meta": "Choosing now",
            "state": "Next",
            "swatch": "#181818"
          },
          {
            "category": "top",
            "label": "Top",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          }
        ]
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source boots conversation says waxed jacket €325 while rack still contains Berlin items/spending. No fake Cotswolds outfit is synthesized in this fixture."
    ]
  },
  {
    "id": "cotswolds_complete",
    "nodeId": "204:6453",
    "name": "C3 — Complete look",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 800,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "That’s you sorted — €860, everything waterproof or wool, and it packs into one bag. Swap anything from your dressing room, or add it all from there when you’re ready."
      },
      {
        "component": "Eyebrow",
        "text": "Anything to change?"
      },
      {
        "component": "ChoiceChip",
        "label": "Add a second knit",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Add a second knit"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Lighter jacket",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Lighter jacket"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Under €800 ",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Under €800 "
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "12° / 19°",
        "rain": "Rain 3 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "First day · Berlin · September · smart casual, relaxed · under €800",
        "spent": "€775 spent · 4 of 4",
        "left": "€25 left",
        "progress": 0.96875,
        "slots": [
          {
            "category": "bottom",
            "label": "Trousers",
            "name": "Pleated Wool Trouser",
            "meta": "Uniqlo U · €290",
            "state": "Filled",
            "swatch": "#666666"
          },
          {
            "category": "top",
            "label": "Top",
            "name": "Merino Crew Knit",
            "meta": "COS · €180",
            "state": "Filled",
            "swatch": "#555555"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "Unlined Cotton Blazer",
            "meta": "Arket · €190",
            "state": "Filled",
            "swatch": "#444444"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "Leather Derby",
            "meta": "Grenson · €115",
            "state": "Filled",
            "swatch": "#222222"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Default",
        "pieceCount": 4,
        "total": "€775",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-cotswolds_complete"
            }
          }
        }
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source Cotswolds Complete claims €860 and €40 left but rack items are copied from Berlin; source product sum differs. Fixture uses coherent copied Berlin rack (€775 of €800) and flags it for domain-content review, rather than inventing missing Cotswolds pieces."
    ]
  },
  {
    "id": "complete",
    "nodeId": "204:6664",
    "name": "A4 — Complete look",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 1500,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "That’s the look — €1,489, €11 under. Elegant enough for black tie, and the kitten heel means you can walk from the hotel. Tap Change on any piece in your dressing room, or add the lot from there when you’re happy."
      },
      {
        "component": "Eyebrow",
        "text": "Anything to change?"
      },
      {
        "component": "ChoiceChip",
        "label": "Swap the shoes",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Swap the shoes"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Dressier bag",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Dressier bag"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "A bolder colour",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "A bolder colour"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "16° / 10°",
        "rain": "Rain 4 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "Anniversary dinner in Paris · black tie optional · under €1,500",
        "spent": "€1,489 spent · 4 of 4",
        "left": "€11 left",
        "progress": 0.9926666666666667,
        "slots": [
          {
            "category": "dress",
            "label": "A dress",
            "name": "Indra Long Dress",
            "meta": "Zimmermann · €874",
            "state": "Filled",
            "swatch": "#b8a98e"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "Leather Kitten Heel",
            "meta": "Aeyde · €295",
            "state": "Filled",
            "swatch": "#202020"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "Wool Wrap Scarf",
            "meta": "Arket · €190",
            "state": "Filled",
            "swatch": "#654142"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "Le Petit Bambino",
            "meta": "Mango · €130",
            "state": "Filled",
            "swatch": "#ed3a35"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Default",
        "pieceCount": 4,
        "total": "€1,489",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-complete"
            }
          }
        }
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source complete rack reuses copied Berlin/Cotswolds names while bag modal prices total €1,489. Fixture uses canonical four-piece €1,489 outfit; literal source copy remains in manifest. Source photos show Berlin despite Paris brief."
    ]
  },
  {
    "id": "added_bag",
    "nodeId": "204:7212",
    "name": "A4 — Complete look",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 1500,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "That’s the look — €1,489, €11 under. Elegant enough for black tie, and the kitten heel means you can walk from the hotel. Tap Change on any piece in your dressing room, or add the lot from there when you’re happy."
      },
      {
        "component": "Eyebrow",
        "text": "Anything to change?"
      },
      {
        "component": "ChoiceChip",
        "label": "Swap the shoes",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Swap the shoes"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Dressier bag",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Dressier bag"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "A bolder colour",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "A bolder colour"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "16° / 10°",
        "rain": "Rain 4 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "Anniversary dinner in Paris · black tie optional · under €1,500",
        "spent": "€1,489 spent · 4 of 4",
        "left": "€11 left",
        "progress": 0.9926666666666667,
        "slots": [
          {
            "category": "dress",
            "label": "A dress",
            "name": "Indra Long Dress",
            "meta": "Zimmermann · €874",
            "state": "Filled",
            "swatch": "#b8a98e"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "Leather Kitten Heel",
            "meta": "Aeyde · €295",
            "state": "Filled",
            "swatch": "#202020"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "Wool Wrap Scarf",
            "meta": "Arket · €190",
            "state": "Filled",
            "swatch": "#654142"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "Le Petit Bambino",
            "meta": "Mango · €130",
            "state": "Filled",
            "swatch": "#ed3a35"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Added",
        "pieceCount": 4,
        "total": "€1,489",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-added_bag"
            }
          }
        }
      },
      {
        "component": "Toast",
        "message": "4 items added",
        "actionLabel": "View bag",
        "action": {
          "event": {
            "name": "open_bag",
            "context": {}
          }
        }
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source complete rack reuses copied Berlin/Cotswolds names while bag modal prices total €1,489. Fixture uses canonical four-piece €1,489 outfit; literal source copy remains in manifest. Source photos show Berlin despite Paris brief."
    ]
  },
  {
    "id": "bag_preview",
    "nodeId": "204:7457",
    "name": "A4 — Complete look",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 1500,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "That’s the look — €1,489, €11 under. Elegant enough for black tie, and the kitten heel means you can walk from the hotel. Tap Change on any piece in your dressing room, or add the lot from there when you’re happy."
      },
      {
        "component": "Eyebrow",
        "text": "Anything to change?"
      },
      {
        "component": "ChoiceChip",
        "label": "Swap the shoes",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Swap the shoes"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "Dressier bag",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "Dressier bag"
            }
          }
        }
      },
      {
        "component": "ChoiceChip",
        "label": "A bolder colour",
        "selected": false,
        "action": {
          "event": {
            "name": "adjust_piece",
            "context": {
              "adjustment": "A bolder colour"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "16° / 10°",
        "rain": "Rain 4 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/berlin-landmark.png",
        "photoB": "assets/images/finalized_left/creative-studio.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "Anniversary dinner in Paris · black tie optional · under €1,500",
        "spent": "€1,489 spent · 4 of 4",
        "left": "€11 left",
        "progress": 0.9926666666666667,
        "slots": [
          {
            "category": "dress",
            "label": "A dress",
            "name": "Indra Long Dress",
            "meta": "Zimmermann · €874",
            "state": "Filled",
            "swatch": "#b8a98e"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "Leather Kitten Heel",
            "meta": "Aeyde · €295",
            "state": "Filled",
            "swatch": "#202020"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "Wool Wrap Scarf",
            "meta": "Arket · €190",
            "state": "Filled",
            "swatch": "#654142"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "Le Petit Bambino",
            "meta": "Mango · €130",
            "state": "Filled",
            "swatch": "#ed3a35"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Added",
        "pieceCount": 4,
        "total": "€1,489",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-bag_preview"
            }
          }
        }
      },
      {
        "component": "Toast",
        "message": "4 items added",
        "actionLabel": "View bag",
        "action": {
          "event": {
            "name": "open_bag",
            "context": {}
          }
        }
      }
    ],
    "overlay": [
      {
        "component": "BagPreview",
        "items": [
          {
            "id": "paris-dress-1",
            "category": "dress",
            "name": "Indra Long Dress",
            "meta": "Zimmermann · €874",
            "swatch": "#b8a98e",
            "unitPrice": 874,
            "quantity": 1,
            "size": "38"
          },
          {
            "id": "design-kitten-heel",
            "category": "shoes",
            "name": "Leather Kitten Heel",
            "meta": "Aeyde · €295",
            "swatch": "#202020",
            "unitPrice": 295,
            "quantity": 1,
            "size": "39"
          },
          {
            "id": "design-wrap",
            "category": "layer",
            "name": "Wool Wrap Scarf",
            "meta": "Arket · €190",
            "swatch": "#654142",
            "unitPrice": 190,
            "quantity": 1,
            "size": "One size"
          },
          {
            "id": "design-bag",
            "category": "bag",
            "name": "Le Petit Bambino",
            "meta": "Mango · €130",
            "swatch": "#ed3a35",
            "unitPrice": 130,
            "quantity": 1,
            "size": "One size"
          }
        ],
        "closeAction": {
          "event": {
            "name": "close_bag",
            "context": {}
          }
        },
        "quantityAction": {
          "event": {
            "name": "set_bag_quantity",
            "context": {}
          }
        },
        "removeAction": {
          "event": {
            "name": "remove_bag_product",
            "context": {}
          }
        },
        "restoreAction": {
          "event": {
            "name": "restore_bag_product",
            "context": {}
          }
        },
        "checkoutAction": {
          "event": {
            "name": "checkout_bag",
            "context": {}
          }
        }
      }
    ],
    "sourceIssues": [
      "Source complete rack reuses copied Berlin/Cotswolds names while bag modal prices total €1,489. Fixture uses canonical four-piece €1,489 outfit; literal source copy remains in manifest. Source photos show Berlin despite Paris brief."
    ]
  },
  {
    "id": "partially_folded",
    "nodeId": "205:7997",
    "name": "Partially folded",
    "width": 951,
    "height": 669,
    "data": {
      "budget": 1500,
      "dressCode": "black-tie",
      "season": "autumn",
      "draft": "",
      "selectedSize": "38"
    },
    "chat": [
      {
        "component": "Text",
        "text": "ALDER",
        "variant": "caption"
      },
      {
        "component": "StylistMessage",
        "text": "Lovely — the Zimmermann is in your dressing room and leaves you €626. Shoes next: I’d keep them refined and let the dress do the talking."
      },
      {
        "component": "Eyebrow",
        "text": "Shoes · black tie · under €626"
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Satin Pointed Pump",
        "price": "€545",
        "brandLine": "Manolo Blahnik · Black · Satin · 70mm",
        "tag": "Most formal",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "paris-shoes-1"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Leather Kitten Heel",
        "price": "€295",
        "brandLine": "Aeyde · Black · Leather · 55mm",
        "tag": "Easiest",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-kitten-heel"
            }
          }
        }
      },
      {
        "component": "ProductCard",
        "category": "shoes",
        "name": "Suede Low-Top Sneaker",
        "price": "€349",
        "brandLine": "Common Projects · Off-white · Suede",
        "tag": "Relaxed",
        "swatch": "#e4e4e7",
        "action": {
          "event": {
            "name": "select_product",
            "context": {
              "productId": "design-sneaker"
            }
          }
        }
      },
      {
        "component": "ChatInput",
        "value": {
          "path": "/draft"
        },
        "action": {
          "event": {
            "name": "send_message",
            "context": {}
          }
        }
      }
    ],
    "room": [
      {
        "component": "ContextStrip",
        "location": "Known",
        "venue": "Paris 8e",
        "temperatures": "16° / 10°",
        "rain": "Rain 4 in 10",
        "mapAction": {
          "event": {
            "name": "expand_map",
            "context": {}
          }
        },
        "weatherAction": {
          "event": {
            "name": "expand_weather",
            "context": {}
          }
        },
        "photoA": "assets/images/finalized_left/paris-autumn.png",
        "photoB": "assets/images/finalized_left/restaurant.png"
      },
      {
        "component": "DressingRoom",
        "title": "Dressing room",
        "brief": "Anniversary dinner in Paris · black tie optional · under €1,500",
        "spent": "€874 spent · 1 of 4",
        "left": "€626 left",
        "progress": 0.5826666666666667,
        "slots": [
          {
            "category": "dress",
            "label": "A dress",
            "name": "Indra Long Dress",
            "meta": "Zimmermann · €874",
            "state": "Filled",
            "swatch": "#b8a98e"
          },
          {
            "category": "shoes",
            "label": "Shoes",
            "name": "",
            "meta": "Choosing now",
            "state": "Next",
            "swatch": "#181818"
          },
          {
            "category": "layer",
            "label": "A layer over it",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          },
          {
            "category": "bag",
            "label": "A bag",
            "name": "",
            "meta": "Not yet",
            "state": "Empty",
            "swatch": "#181818"
          }
        ]
      },
      {
        "component": "AddToBagButton",
        "state": "Partial",
        "pieceCount": 1,
        "total": "€874",
        "action": {
          "event": {
            "name": "add_look_to_bag",
            "context": {
              "lookId": "design-partially_folded"
            }
          }
        }
      }
    ],
    "overlay": [],
    "sourceIssues": [
      "Source budget meter says €0 spent / €1,500 left although selected dress costs €874. Fixture computes €874 spent / €626 left from selected pieces."
    ]
  }
]
''';
