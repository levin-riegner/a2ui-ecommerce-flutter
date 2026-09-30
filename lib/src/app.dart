import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'agent/commerce_agent.dart';
import 'agent/remote_agent.dart';
import 'data/models.dart';
import 'theme.dart';

const _basicComponentGalleryNames = <String>[
  'Button',
  'Card',
  'CheckBox',
  'Column',
  'ChoicePicker',
  'DateTimeInput',
  'Divider',
  'Icon',
  'List',
  'Modal',
  'Row',
  'Slider',
  'Tabs',
  'Text',
  'TextField',
];

class ReferenceApp extends StatefulWidget {
  const ReferenceApp({
    super.key,
    this.agent,
    this.serviceUrl = const String.fromEnvironment('AGENT_SERVICE_URL'),
  });

  /// Injection for tests and component previews. The app disposes this agent.
  final CommerceAgent? agent;
  final String serviceUrl;

  @override
  State<ReferenceApp> createState() => _ReferenceAppState();
}

class _ReferenceAppState extends State<ReferenceApp> {
  late final CommerceAgent? agent;

  @override
  void initState() {
    super.initState();
    final origin = Uri.tryParse(widget.serviceUrl.trim());
    final validOrigin =
        origin != null &&
        (origin.scheme == 'http' || origin.scheme == 'https') &&
        origin.host.isNotEmpty &&
        origin.userInfo.isEmpty &&
        !origin.hasQuery &&
        !origin.hasFragment;
    agent = widget.agent ?? (validOrigin ? RemoteAgent(origin) : null);
  }

  @override
  void dispose() {
    agent?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2UI Flutter Commerce',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _AppHome(agent: agent),
    );
  }
}

class _AppHome extends StatefulWidget {
  const _AppHome({required this.agent});

  final CommerceAgent? agent;

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  bool showGallery = false;
  bool showStartScreen = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    return AnimatedBuilder(
      animation: agent ?? const AlwaysStoppedAnimation(0),
      builder: (context, _) {
        if (showGallery) {
          return _ComponentGallery(
            onBack: () => setState(() => showGallery = false),
          );
        }
        if (agent == null ||
            showStartScreen ||
            !agent.hasStarted ||
            agent.activeJourney == null) {
          return _StartScreen(
            onSelect: agent == null
                ? null
                : (journey) {
                    setState(() => showStartScreen = false);
                    return agent.startJourney(journey);
                  },
            isBusy: agent?.isBusy ?? false,
            onOpenGallery: () => setState(() => showGallery = true),
          );
        }
        return _ResponsiveShell(
          agent: agent,
          onNewJourney: () => setState(() => showStartScreen = true),
        );
      },
    );
  }
}

class _StartScreen extends StatelessWidget {
  const _StartScreen({
    required this.onSelect,
    required this.onOpenGallery,
    this.isBusy = false,
  });

  final Future<void> Function(DemoJourney journey)? onSelect;
  final VoidCallback onOpenGallery;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandLockup(showMark: true),
                const SizedBox(height: 40),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 680;
                    return Flex(
                      direction: compact ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: compact ? 0 : 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Build the look\naround the moment.',
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      height: 1.04,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Tell your stylist the occasion. An agent searches the catalog and helps you build a look.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: const Color(0xff71717a),
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 28),
                              if (onSelect == null) ...[
                                const _ConnectionNotice(
                                  message: 'Connect the stylist service to start a journey.',
                                ),
                                const SizedBox(height: 18),
                              ],
                              Text(
                                'Choose a journey',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final journey in DemoJourney.values)
                                    ActionChip(
                                      label: Text(journey.title),
                                      onPressed: onSelect == null || isBusy
                                          ? null
                                          : () => onSelect!(journey),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: onOpenGallery,
                                icon: const Icon(Icons.grid_view_outlined),
                                label: const Text('Explore component catalog'),
                              ),
                            ],
                          ),
                        ),
                        if (!compact) const SizedBox(width: 80),
                        Expanded(
                          flex: compact ? 0 : 4,
                          child: Padding(
                            padding: EdgeInsets.only(top: compact ? 36 : 0),
                            child: const _MosaicPreview(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 44),
                const _SafetyNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({this.showMark = false});

  final bool showMark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showMark) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xff18181b),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          'ALDER',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(letterSpacing: 2.2, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Text(
          'GENUINE STYLIST',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: const Color(0xff71717a), letterSpacing: 1.1),
        ),
      ],
    );
  }
}

class _MosaicPreview extends StatelessWidget {
  const _MosaicPreview();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.05,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            ColoredBox(color: Color(0xffd7d1c4)),
            ColoredBox(color: Color(0xffe6e0d7)),
            ColoredBox(color: Color(0xff9c8779)),
            ColoredBox(color: Color(0xffbab0a1)),
            ColoredBox(color: Color(0xff2a2a2e)),
            ColoredBox(color: Color(0xffc3b29b)),
            ColoredBox(color: Color(0xffe3d9c9)),
            ColoredBox(color: Color(0xff77706a)),
            ColoredBox(color: Color(0xfff0ece5)),
          ],
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff4f4f5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your stylist uses a fictional catalog with bundled product photographs. An agent connection is required for every journey.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentGallery extends StatelessWidget {
  const _ComponentGallery({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      const _BrandLockup(),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Catalog components',
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A visual index of the commerce vocabulary available to A2UI surfaces. Each custom item has a schema, a Flutter builder, and a fixture-backed interaction path.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: const Color(0xff71717a), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '9 commerce components · 15 GenUI basic components',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tileWidth = constraints.maxWidth < 680
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 2;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _GalleryTile(
                            width: tileWidth,
                            name: 'StylistMessage',
                            description:
                                'Warm guidance with a clear next step.',
                            preview: const _GalleryMessagePreview(),
                          ),
                          _GalleryTile(
                            width: tileWidth,
                            name: 'Eyebrow',
                            description: 'Compact uppercase grouping label.',
                            preview: const _GalleryEyebrowPreview(),
                          ),
                          _GalleryTile(
                            width: tileWidth,
                            name: 'ChoiceChip',
                            description:
                                'Structured single-choice interaction.',
                            preview: const _GalleryChipPreview(),
                          ),
                          _GalleryTile(
                            width: tileWidth,
                            name: 'ChoiceGroup',
                            description: 'Wrapping responsive choice set.',
                            preview: const _GalleryChoiceGroupPreview(),
                          ),
                          _GalleryTile(
                            width: tileWidth,
                            name: 'BudgetSlider',
                            description:
                                'Bounded value updated in the data model.',
                            preview: const _GallerySliderPreview(),
                          ),
                          _GalleryTile(
                            width: tileWidth,
                            name: 'PrimaryButton',
                            description:
                                'Explicit event for a journey transition.',
                            preview: const _GalleryButtonPreview(),
                          ),
                          _GalleryTile(
                            width: tileWidth,
                            name: 'ProductCard',
                            description: 'Recommendation with reason and selection action.',
                            preview: const _GalleryProductPreview(),
                          ),
                          _GalleryTile(
                            width: tileWidth,
                            name: 'PieceSlot',
                            description:
                                'Empty, next, and filled dressing-room states.',
                            preview: const _GalleryPiecePreview(),
                          ),
                          _GalleryTile(
                            width: tileWidth,
                            name: 'DressingRoom',
                            description:
                                'Persistent surface for the evolving look.',
                            preview: const _GalleryDressingPreview(),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'GenUI basic components',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'These primitives are available from the base catalog and can be composed before adding a custom schema.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xff71717a), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in _basicComponentGalleryNames)
                        Chip(
                          avatar: const Icon(Icons.widgets_outlined, size: 16),
                          label: Text(name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Basic components remain available through the GenUI catalog. Add a custom item only when a schema and reusable interaction are clearer than composing existing primitives.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xff71717a), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.width,
    required this.name,
    required this.description,
    required this.preview,
  });

  final double width;
  final String name;
  final String description;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe4e4e7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: const Color(0xff71717a)),
            ),
            const SizedBox(height: 16),
            preview,
          ],
        ),
      ),
    );
  }
}

class _GalleryMessagePreview extends StatelessWidget {
  const _GalleryMessagePreview();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Lovely — one more considered piece and the look will come together.',
      style: TextStyle(height: 1.35),
    );
  }
}

class _GalleryEyebrowPreview extends StatelessWidget {
  const _GalleryEyebrowPreview();

  @override
  Widget build(BuildContext context) {
    return Text(
      'SHOES · 3 OPTIONS',
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(letterSpacing: 1.2, color: const Color(0xff71717a)),
    );
  }
}

class _GalleryChipPreview extends StatelessWidget {
  const _GalleryChipPreview();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        const ActionChip(label: Text('Black tie')),
        ActionChip(
          label: const Text('Cocktail'),
          backgroundColor: const Color(0xff18181b),
          labelStyle: const TextStyle(color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _GalleryChoiceGroupPreview extends StatelessWidget {
  const _GalleryChoiceGroupPreview();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in ['Black tie', 'Cocktail', 'Smart elegant'])
          Chip(
            label: Text(option),
            backgroundColor: option == 'Black tie'
                ? const Color(0xff18181b)
                : const Color(0xfff4f4f5),
            labelStyle: TextStyle(
              color: option == 'Black tie'
                  ? Colors.white
                  : const Color(0xff3f3f46),
            ),
          ),
      ],
    );
  }
}

class _GallerySliderPreview extends StatelessWidget {
  const _GallerySliderPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Budget', style: Theme.of(context).textTheme.labelLarge),
            Text('€1,500', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const Slider(value: 0.55, onChanged: null),
      ],
    );
  }
}

class _GalleryButtonPreview extends StatelessWidget {
  const _GalleryButtonPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: () {}, child: const Text('Find options')),
    );
  }
}

class _GalleryProductPreview extends StatelessWidget {
  const _GalleryProductPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffe4e4e7)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xff1c1c1f),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.checkroom_outlined, color: Colors.white70),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most formal',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Demo Pointed Pump',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '€545 · Black satin',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPiecePreview extends StatelessWidget {
  const _GalleryPiecePreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GalleryPieceRow(
          label: 'Dress',
          value: 'Indra Long Dress',
          filled: true,
        ),
        _GalleryPieceRow(
          label: 'A layer over it',
          value: 'Next piece',
          filled: false,
        ),
      ],
    );
  }
}

class _GalleryPieceRow extends StatelessWidget {
  const _GalleryPieceRow({
    required this.label,
    required this.value,
    required this.filled,
  });

  final String label;
  final String value;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            filled ? Icons.check_circle_outline : Icons.add_circle_outline,
            size: 17,
            color: filled ? const Color(0xff18181b) : const Color(0xffa1a1aa),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GalleryDressingPreview extends StatelessWidget {
  const _GalleryDressingPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffafafa),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dressing room', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            'Anniversary dinner in Paris',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const _GalleryPieceRow(label: 'Dress', value: 'Filled', filled: true),
          const _GalleryPieceRow(label: 'Shoes', value: 'Next', filled: false),
        ],
      ),
    );
  }
}

class _ResponsiveShell extends StatelessWidget {
  const _ResponsiveShell({required this.agent, required this.onNewJourney});

  final CommerceAgent agent;
  final VoidCallback onNewJourney;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 951),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      _MobileHeader(onNewJourney: onNewJourney),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  0,
                                ),
                                child: _DressingPanel(
                                  agent: agent,
                                  scrollable: false,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _ChatSurface(agent: agent),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _ChatComposer(
                        agent: agent,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                      ),
                    ],
                  );
                }
                return Row(
                  // The side panels should occupy the full shell height. The
                  // default cross-axis alignment centers their shorter content,
                  // which makes the dressing room appear halfway down the page
                  // on wide web viewports.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ChatPanel(
                        agent: agent,
                        onNewJourney: onNewJourney,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 415, child: _DressingPanel(agent: agent)),
                    SizedBox(
                      width: 60,
                      child: _SideRail(onNewJourney: onNewJourney),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({required this.agent, required this.onNewJourney});

  final CommerceAgent agent;
  final VoidCallback onNewJourney;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: _BrandLockup()),
              IconButton(
                onPressed: onNewJourney,
                icon: const Icon(Icons.close),
                tooltip: 'New journey',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _ChatSurface(agent: agent)),
          const SizedBox(height: 12),
          _ChatComposer(agent: agent),
        ],
      ),
    );
  }
}

class _ChatSurface extends StatelessWidget {
  const _ChatSurface({required this.agent});

  final CommerceAgent agent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: agent,
      builder: (context, _) {
        final surfaceId = agent.latestInlineSurfaceId;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (agent.isBusy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          surfaceId == null
                              ? 'Connecting to your stylist…'
                              : 'Your stylist is thinking…',
                        ),
                      ),
                    ],
                  ),
                ),
              if (agent.connectionError != null)
                _ConnectionNotice(
                  message: agent.connectionError!,
                  onRetry: agent.canRetry ? agent.retryLastTurn : null,
                ),
              if (agent.connectionNotice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(agent.connectionNotice!),
                ),
              if (surfaceId != null)
                IgnorePointer(
                  ignoring: agent.isBusy || agent.connectionError != null,
                  child: ExcludeFocus(
                    excluding: agent.isBusy || agent.connectionError != null,
                    child: Surface(
                      key: ValueKey(surfaceId),
                      surfaceContext: agent.controller.contextFor(surfaceId),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.message, this.onRetry});
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff4f4f5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stylist unavailable',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(message),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ChatComposer extends StatefulWidget {
  const _ChatComposer({required this.agent, this.padding = EdgeInsets.zero});

  final CommerceAgent agent;
  final EdgeInsets padding;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  final textController = TextEditingController();

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = textController.text.trim();
    if (text.isEmpty ||
        widget.agent.isBusy ||
        widget.agent.connectionError != null) {
      return;
    }
    textController.clear();
    await widget.agent.conversation.sendRequest(ChatMessage.user(text));
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        !widget.agent.isBusy &&
        widget.agent.connectionError == null &&
        widget.agent.latestInlineSurfaceId != null;
    return Padding(
      padding: widget.padding,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              enabled: canSend,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Tell me about the occasion…',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              maximumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: canSend ? _send : null,
            icon: const Icon(Icons.arrow_upward, size: 22),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}

class _DressingPanel extends StatelessWidget {
  const _DressingPanel({required this.agent, this.scrollable = true});

  final CommerceAgent agent;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final surface = AnimatedBuilder(
      animation: agent,
      builder: (context, _) {
        if (!agent.hasDressingRoomSurface) return const SizedBox.shrink();
        return ExcludeFocus(
          excluding: agent.isBusy || agent.connectionError != null,
          child: IgnorePointer(
            ignoring: agent.isBusy || agent.connectionError != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Surface(
                  surfaceContext: agent.controller.contextFor('dressing-room'),
                ),
                if (agent.hasSelectedProductsSurface) ...[
                  const SizedBox(height: 12),
                  Surface(
                    surfaceContext: agent.controller.contextFor(
                      'selected-products',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (!scrollable) return surface;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      child: surface,
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.onNewJourney});

  final VoidCallback onNewJourney;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 24),
        child: Row(
          children: [
            IconButton(
              onPressed: onNewJourney,
              icon: const Icon(Icons.close, size: 24),
              tooltip: 'New journey',
            ),
            const SizedBox(width: 4),
            const _BrandLockup(),
          ],
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.onNewJourney});

  final VoidCallback onNewJourney;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 10,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xff18181b),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 4),
          RotatedBox(
            quarterTurns: 1,
            child: Text(
              '9:41',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xff18181b),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: onNewJourney,
              icon: const Icon(Icons.close, size: 24),
              tooltip: 'New journey',
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
