// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get connectionTitle => 'Connect your model';

  @override
  String get connectionPrivacyNotice =>
      'Bring your own API key. Your key stays in memory on this device and is sent directly to your chosen provider. It is not saved.';

  @override
  String get connectionProvider => 'Provider';

  @override
  String get connectionProviderGoogle => 'Google Gemini';

  @override
  String get connectionProviderOpenAi => 'OpenAI';

  @override
  String get connectionProviderAnthropic => 'Anthropic';

  @override
  String get connectionProviderCompatible => 'OpenAI-compatible';

  @override
  String get connectionBaseUrl => 'Provider API base URL';

  @override
  String get connectionBaseUrlHint => 'https://your-provider.example/v1';

  @override
  String get connectionInvalidBaseUrl =>
      'Use HTTPS or a local loopback HTTP address';

  @override
  String get connectionModelId => 'Model ID';

  @override
  String get connectionApiKey => 'API key';

  @override
  String get connectionUsageNotice =>
      'Connecting makes no model request. Starting a journey, chatting, selecting pieces, and retrying use your provider account and may incur charges.';

  @override
  String get connectionSubmit => 'Connect model';

  @override
  String get connectionFailure =>
      'Could not configure your model. Check the provider and model settings.';

  @override
  String get fieldRequired => 'Required';

  @override
  String get composerMessageLabel => 'Message your stylist';

  @override
  String get composerSend => 'Send';

  @override
  String get composerOccasionPlaceholder => 'Tell me about the occasion…';

  @override
  String get composerOccasionLabel => 'Tell me about the occasion';

  @override
  String get composerSendMessage => 'Send message';

  @override
  String get dictationActive => 'Dictation active';

  @override
  String get dictationStop => 'Stop dictation';

  @override
  String get dictationCancel => 'Cancel dictation';

  @override
  String get dictationStart => 'Dictate message';

  @override
  String get dictationListening => 'Listening…';

  @override
  String get dictationUnavailableTooltip => 'Voice input unavailable';

  @override
  String get dictationEnablePermissions =>
      'Enable microphone and speech recognition permissions to dictate. If dictation is unavailable on this device, you can still type.';

  @override
  String get dictationMicrophoneDidNotStart =>
      'The microphone did not start. Please try again or type your message.';

  @override
  String get dictationCouldNotStart =>
      'Dictation could not start. Please try again or type your message.';

  @override
  String get dictationStopped =>
      'Dictation stopped. Your draft is still available.';

  @override
  String get dictationNoSpeech =>
      'No speech detected. Tap the microphone to try again.';

  @override
  String get dictationCheckPermissions =>
      'Check microphone and speech recognition permissions, then try again.';

  @override
  String get dictationCouldNotInitialize =>
      'Speech recognition could not initialize on this device. Please try again or type your message.';

  @override
  String get dictationUnavailable =>
      'Dictation is unavailable right now. Please try again or type your message.';

  @override
  String get budgetWholeOutfit => 'Budget for the whole outfit';

  @override
  String get budgetWholeOutfitEyebrow => 'BUDGET FOR THE WHOLE OUTFIT';

  @override
  String get remove => 'Remove';

  @override
  String get chooseThis => 'Choose this';

  @override
  String get dressingRoomTitle => 'Dressing room';

  @override
  String get choosingNow => 'Choosing now';

  @override
  String get choosingOnLeft => 'Choosing on the left';

  @override
  String get notYet => 'Not yet';

  @override
  String get change => 'Change';

  @override
  String get overBudget => 'Over budget';

  @override
  String get outfitBudget => 'Outfit budget';

  @override
  String get saveLook => 'Save look';

  @override
  String get share => 'Share';

  @override
  String get startOver => 'Start over';

  @override
  String get swap => 'Swap';

  @override
  String get usually => 'Usually';

  @override
  String get noCatalogPieces => 'No catalog pieces selected';

  @override
  String get undo => 'Undo';

  @override
  String get bagEmpty => 'Your bag is empty';

  @override
  String get bagClose => 'Close bag';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get checkOut => 'Check out';

  @override
  String get keepStyling => 'Keep styling';

  @override
  String get occasionMap => 'Occasion map';

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get closeStylist => 'Close stylist';

  @override
  String get inDressingRoom => 'In your dressing room';

  @override
  String get addToDressingRoom => 'Add to dressing room';

  @override
  String get whichDoYouPrefer => 'Which do you prefer?';

  @override
  String get colourQuestion => 'Any colours you’re drawn to? Pick a few.';

  @override
  String get photoUploadQuestion =>
      'Got a photo of you, or a piece you already own?\nI’ll build around it.';

  @override
  String get photoUploadChoose => 'Take a photo or choose from your library';

  @override
  String get yourPhoto => 'YOUR PHOTO';

  @override
  String get photoDescription => 'What I’m seeing';

  @override
  String get useIt => 'Use it';

  @override
  String get replace => 'Replace';

  @override
  String get fitQuestion => 'Your usual size, and how you like it to sit?';

  @override
  String get dressSize => 'DRESS SIZE';

  @override
  String get fitEyebrow => 'FIT';

  @override
  String get occasionTimelineIntro =>
      'Here’s the day as I understand it — tap anything to fix it.';

  @override
  String get editOccasion => 'Edit occasion';

  @override
  String get time => 'Time';

  @override
  String get activity => 'Activity';

  @override
  String get location => 'Location';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get brandQuestion => 'Any brands you love, or would rather I skip?';

  @override
  String get brandLove => 'LOVE';

  @override
  String get brandSkip => 'SKIP';

  @override
  String get addWithPlus => '+ Add';

  @override
  String get addBrand => 'Add a brand';

  @override
  String get brandName => 'Brand name';

  @override
  String get add => 'Add';

  @override
  String get chooseSize => 'Choose size';

  @override
  String get legacyDress => 'A dress';

  @override
  String get legacyLayer => 'A layer over it';

  @override
  String get legacyShoes => 'Shoes';

  @override
  String get legacyBag => 'A bag';

  @override
  String bagSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Bag, $_temp0';
  }

  @override
  String quantitySemantics(int quantity) {
    return 'Quantity $quantity';
  }

  @override
  String categoryPlaceholder(String category) {
    return '$category placeholder';
  }

  @override
  String spentPieceCount(String amount, int count, int total) {
    return '$amount spent · $count of $total';
  }

  @override
  String budgetLeft(String amount) {
    return '$amount left';
  }

  @override
  String addedToBag(int count) {
    return 'Added to your bag · $count items';
  }

  @override
  String addPartialLook(int count, String total) {
    return 'Add the $count piece so far · $total';
  }

  @override
  String addLookToBag(String total) {
    return 'Add the look to your bag · $total';
  }

  @override
  String itemRemoved(String name) {
    return '$name removed';
  }

  @override
  String removeNamedItem(String name) {
    return 'Remove $name';
  }

  @override
  String bagTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Your bag — $_temp0';
  }

  @override
  String chooseItemSize(String name) {
    return 'Choose size · $name';
  }

  @override
  String changeItemSize(String name) {
    return 'Change size · $name';
  }

  @override
  String changeNamedItem(String name) {
    return 'Change $name';
  }

  @override
  String matchingProducts(String name, String count) {
    return '$name · $count matching products';
  }

  @override
  String coloursChosen(int count, String selection) {
    return '$count chosen$selection';
  }

  @override
  String wantItDifferent(String name) {
    return '$name — want it different?';
  }

  @override
  String get restartTitle => 'Back to start?';

  @override
  String get restartDescription =>
      'Your current look, conversation and bag will be cleared. Saved looks will be kept.';

  @override
  String get restartConfirm => 'Back to start';

  @override
  String get occasionExamples => 'HERE ARE SOME EXAMPLES';

  @override
  String get exploreCatalog => 'Explore component catalog';

  @override
  String get disconnectModel => 'Disconnect model';

  @override
  String get connectModelTitle => 'Connect your model';

  @override
  String get occasionTitle => 'Where are you going?';

  @override
  String get occasionDescription =>
      'Tell me the occasion, where it is and roughly what you’d like to spend. I’ll pull the whole look together from what we carry, and you can change anything as we go.';

  @override
  String get occasionField => 'Your occasion';

  @override
  String get startLook => 'Start my look';

  @override
  String get back => 'Back';

  @override
  String get catalogTitle => 'Catalog components';

  @override
  String get catalogDescription =>
      'A visual index of the commerce vocabulary available to A2UI surfaces. Each custom item has a schema, a Flutter builder, and a fixture-backed interaction path.';

  @override
  String get catalogCounts =>
      '9 commerce components · 15 GenUI basic components';

  @override
  String get finalizedComponents => 'Finalized Figma components';

  @override
  String get finalizedScreens => 'Finalized Figma screens';

  @override
  String get basicComponents => 'GenUI basic components';

  @override
  String get basicComponentsDescription =>
      'These primitives are available from the base catalog and can be composed before adding a custom schema.';

  @override
  String get catalogGuidance =>
      'Basic components remain available through the GenUI catalog. Add a custom item only when a schema and reusable interaction are clearer than composing existing primitives.';

  @override
  String get previousResponse => 'Previous response';

  @override
  String get askingStylist => 'Asking your stylist…';

  @override
  String get stylistThinking => 'Your stylist is thinking…';

  @override
  String get updateOutfit => 'Update your outfit';

  @override
  String get stylistUnavailable => 'Stylist unavailable';

  @override
  String get retry => 'Retry';

  @override
  String get newJourney => 'New journey';

  @override
  String get inspectorClose => 'Close inspector';

  @override
  String get inspectorInspect => 'Inspect';

  @override
  String get inspectorExchanges => 'Exchanges';

  @override
  String get inspectorCatalog => 'Catalog';

  @override
  String get inspectorTitle => 'Under the hood';

  @override
  String get inspectorPrivacy =>
      'These are safe structural summaries, not raw HTTP captures. Message text, model prose, prompts, keys and authentication headers are withheld.';

  @override
  String get inspectorAuthority =>
      'The model can choose an eligible recommendation component. The host binds product facts, validates the result and controls prices, basket changes and demo checkout.';

  @override
  String inspectorHistory(int count, int limit) {
    return 'Showing $count of the last $limit events. Newest first; history stays in memory for this connection.';
  }

  @override
  String get inspectorEmpty =>
      'Start a journey or use a basket control to see its path through the app. Host-only actions do not need a model request.';

  @override
  String get inspectorClientInput => 'Client → host';

  @override
  String get inspectorClientExplanation =>
      'A message or control reached the host. Content is withheld; a known action name may be shown.';

  @override
  String get inspectorModelRequest => 'Host → model';

  @override
  String get inspectorRequestExplanation =>
      'Metadata from an actual decoded model request. The provider receives instructions and context; their content is withheld here.';

  @override
  String get inspectorModelResponse => 'Model → host';

  @override
  String get inspectorResponseExplanation =>
      'Metadata from an actual decoded response. Safe component choices and known tool names are shown before host validation; model prose is withheld.';

  @override
  String get inspectorValidation => 'Host validation';

  @override
  String get inspectorValidationExplanation =>
      'The host checks whether the proposed component is eligible. Product, budget and action validation still apply.';

  @override
  String get inspectorModelSelected =>
      'Model-selected recommendation · host-bound surface';

  @override
  String get inspectorHostComposed => 'Host-composed surface';

  @override
  String get inspectorSurfaceExplanation =>
      'A structural summary of the validated A2UI batch published to Flutter. The host supplies facts, bindings and actions. This is not raw model-authored A2UI.';

  @override
  String get inspectorProvider => 'Connected provider';

  @override
  String get inspectorOffline => 'Offline fixture · no provider call';

  @override
  String get inspectorInjected => 'Injected model · test or custom adapter';

  @override
  String inspectorCatalogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registered components',
      one: '1 registered component',
    );
    return '$_temp0';
  }

  @override
  String get inspectorCatalogExplanation =>
      'These schemas come from the same catalog used by the Flutter renderer and sent as model instructions. Availability shows which components the model may choose now, which the host controls, and which are gallery examples.';

  @override
  String get inspectorHostActions => 'Host action contracts';

  @override
  String get inspectorHostActionsExplanation =>
      'Schemas describe validated controls. They do not authorize a model to change your basket or confirm checkout.';

  @override
  String get inspectorSelectable => 'Model selectable';

  @override
  String get inspectorHostControlled => 'Host controlled';

  @override
  String get inspectorReferenceOnly => 'Reference only · gallery';

  @override
  String get inspectorSchema => 'Properties and action bindings';

  @override
  String get inspectorToolResult => 'Host → model tool feedback';

  @override
  String get inspectorToolResultExplanation =>
      'A host tool returned feedback to the model. The tool name and safe counts are shown; its content is withheld.';

  @override
  String inspectorComponentChoice(String component) {
    return 'Component: $component';
  }

  @override
  String inspectorTools(String tools) {
    return 'Tools: $tools';
  }

  @override
  String get inspectorAccepted => 'Accepted';

  @override
  String get inspectorRejected => 'Rejected';

  @override
  String get inspectorTurnFailure => 'Turn not committed';

  @override
  String get inspectorTurnFailureExplanation =>
      'The turn failed before publication. Its safe category distinguishes rejected input, invalid presentation and an unavailable response; exception details are withheld.';
}
