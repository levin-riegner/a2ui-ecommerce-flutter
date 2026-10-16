import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @connectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your model'**
  String get connectionTitle;

  /// No description provided for @connectionPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Bring your own API key. Your key stays in memory on this device and is sent directly to your chosen provider. It is not saved.'**
  String get connectionPrivacyNotice;

  /// No description provided for @connectionProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get connectionProvider;

  /// No description provided for @connectionProviderGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get connectionProviderGoogle;

  /// No description provided for @connectionProviderOpenAi.
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get connectionProviderOpenAi;

  /// No description provided for @connectionProviderAnthropic.
  ///
  /// In en, this message translates to:
  /// **'Anthropic'**
  String get connectionProviderAnthropic;

  /// No description provided for @connectionProviderCompatible.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible'**
  String get connectionProviderCompatible;

  /// No description provided for @connectionBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Provider API base URL'**
  String get connectionBaseUrl;

  /// No description provided for @connectionBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://your-provider.example/v1'**
  String get connectionBaseUrlHint;

  /// No description provided for @connectionInvalidBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Use HTTPS or a local loopback HTTP address'**
  String get connectionInvalidBaseUrl;

  /// No description provided for @connectionModelId.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get connectionModelId;

  /// No description provided for @connectionApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get connectionApiKey;

  /// No description provided for @connectionUsageNotice.
  ///
  /// In en, this message translates to:
  /// **'Connecting makes no model request. Starting a journey, chatting, selecting pieces, and retrying use your provider account and may incur charges.'**
  String get connectionUsageNotice;

  /// No description provided for @connectionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Connect model'**
  String get connectionSubmit;

  /// No description provided for @connectionFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not configure your model. Check the provider and model settings.'**
  String get connectionFailure;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @composerMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message your stylist'**
  String get composerMessageLabel;

  /// No description provided for @composerSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSend;

  /// No description provided for @composerOccasionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tell me about the occasion…'**
  String get composerOccasionPlaceholder;

  /// No description provided for @composerOccasionLabel.
  ///
  /// In en, this message translates to:
  /// **'Tell me about the occasion'**
  String get composerOccasionLabel;

  /// No description provided for @composerSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get composerSendMessage;

  /// No description provided for @dictationActive.
  ///
  /// In en, this message translates to:
  /// **'Dictation active'**
  String get dictationActive;

  /// No description provided for @dictationStop.
  ///
  /// In en, this message translates to:
  /// **'Stop dictation'**
  String get dictationStop;

  /// No description provided for @dictationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel dictation'**
  String get dictationCancel;

  /// No description provided for @dictationStart.
  ///
  /// In en, this message translates to:
  /// **'Dictate message'**
  String get dictationStart;

  /// No description provided for @dictationListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get dictationListening;

  /// No description provided for @dictationUnavailableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Voice input unavailable'**
  String get dictationUnavailableTooltip;

  /// No description provided for @dictationEnablePermissions.
  ///
  /// In en, this message translates to:
  /// **'Enable microphone and speech recognition permissions to dictate. If dictation is unavailable on this device, you can still type.'**
  String get dictationEnablePermissions;

  /// No description provided for @dictationMicrophoneDidNotStart.
  ///
  /// In en, this message translates to:
  /// **'The microphone did not start. Please try again or type your message.'**
  String get dictationMicrophoneDidNotStart;

  /// No description provided for @dictationCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Dictation could not start. Please try again or type your message.'**
  String get dictationCouldNotStart;

  /// No description provided for @dictationStopped.
  ///
  /// In en, this message translates to:
  /// **'Dictation stopped. Your draft is still available.'**
  String get dictationStopped;

  /// No description provided for @dictationNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech detected. Tap the microphone to try again.'**
  String get dictationNoSpeech;

  /// No description provided for @dictationCheckPermissions.
  ///
  /// In en, this message translates to:
  /// **'Check microphone and speech recognition permissions, then try again.'**
  String get dictationCheckPermissions;

  /// No description provided for @dictationCouldNotInitialize.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition could not initialize on this device. Please try again or type your message.'**
  String get dictationCouldNotInitialize;

  /// No description provided for @dictationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Dictation is unavailable right now. Please try again or type your message.'**
  String get dictationUnavailable;

  /// No description provided for @budgetWholeOutfit.
  ///
  /// In en, this message translates to:
  /// **'Budget for the whole outfit'**
  String get budgetWholeOutfit;

  /// No description provided for @budgetWholeOutfitEyebrow.
  ///
  /// In en, this message translates to:
  /// **'BUDGET FOR THE WHOLE OUTFIT'**
  String get budgetWholeOutfitEyebrow;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @chooseThis.
  ///
  /// In en, this message translates to:
  /// **'Choose this'**
  String get chooseThis;

  /// No description provided for @dressingRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Dressing room'**
  String get dressingRoomTitle;

  /// No description provided for @choosingNow.
  ///
  /// In en, this message translates to:
  /// **'Choosing now'**
  String get choosingNow;

  /// No description provided for @choosingOnLeft.
  ///
  /// In en, this message translates to:
  /// **'Choosing on the left'**
  String get choosingOnLeft;

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notYet;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @overBudget.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get overBudget;

  /// No description provided for @outfitBudget.
  ///
  /// In en, this message translates to:
  /// **'Outfit budget'**
  String get outfitBudget;

  /// No description provided for @saveLook.
  ///
  /// In en, this message translates to:
  /// **'Save look'**
  String get saveLook;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOver;

  /// No description provided for @swap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// No description provided for @usually.
  ///
  /// In en, this message translates to:
  /// **'Usually'**
  String get usually;

  /// No description provided for @noCatalogPieces.
  ///
  /// In en, this message translates to:
  /// **'No catalog pieces selected'**
  String get noCatalogPieces;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @bagEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your bag is empty'**
  String get bagEmpty;

  /// No description provided for @bagClose.
  ///
  /// In en, this message translates to:
  /// **'Close bag'**
  String get bagClose;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @checkOut.
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get checkOut;

  /// No description provided for @keepStyling.
  ///
  /// In en, this message translates to:
  /// **'Keep styling'**
  String get keepStyling;

  /// No description provided for @occasionMap.
  ///
  /// In en, this message translates to:
  /// **'Occasion map'**
  String get occasionMap;

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  /// No description provided for @closeStylist.
  ///
  /// In en, this message translates to:
  /// **'Close stylist'**
  String get closeStylist;

  /// No description provided for @inDressingRoom.
  ///
  /// In en, this message translates to:
  /// **'In your dressing room'**
  String get inDressingRoom;

  /// No description provided for @addToDressingRoom.
  ///
  /// In en, this message translates to:
  /// **'Add to dressing room'**
  String get addToDressingRoom;

  /// No description provided for @whichDoYouPrefer.
  ///
  /// In en, this message translates to:
  /// **'Which do you prefer?'**
  String get whichDoYouPrefer;

  /// No description provided for @colourQuestion.
  ///
  /// In en, this message translates to:
  /// **'Any colours you’re drawn to? Pick a few.'**
  String get colourQuestion;

  /// No description provided for @photoUploadQuestion.
  ///
  /// In en, this message translates to:
  /// **'Got a photo of you, or a piece you already own?\nI’ll build around it.'**
  String get photoUploadQuestion;

  /// No description provided for @photoUploadChoose.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or choose from your library'**
  String get photoUploadChoose;

  /// No description provided for @yourPhoto.
  ///
  /// In en, this message translates to:
  /// **'YOUR PHOTO'**
  String get yourPhoto;

  /// No description provided for @photoDescription.
  ///
  /// In en, this message translates to:
  /// **'What I’m seeing'**
  String get photoDescription;

  /// No description provided for @useIt.
  ///
  /// In en, this message translates to:
  /// **'Use it'**
  String get useIt;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @fitQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your usual size, and how you like it to sit?'**
  String get fitQuestion;

  /// No description provided for @dressSize.
  ///
  /// In en, this message translates to:
  /// **'DRESS SIZE'**
  String get dressSize;

  /// No description provided for @fitEyebrow.
  ///
  /// In en, this message translates to:
  /// **'FIT'**
  String get fitEyebrow;

  /// No description provided for @occasionTimelineIntro.
  ///
  /// In en, this message translates to:
  /// **'Here’s the day as I understand it — tap anything to fix it.'**
  String get occasionTimelineIntro;

  /// No description provided for @editOccasion.
  ///
  /// In en, this message translates to:
  /// **'Edit occasion'**
  String get editOccasion;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @brandQuestion.
  ///
  /// In en, this message translates to:
  /// **'Any brands you love, or would rather I skip?'**
  String get brandQuestion;

  /// No description provided for @brandLove.
  ///
  /// In en, this message translates to:
  /// **'LOVE'**
  String get brandLove;

  /// No description provided for @brandSkip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get brandSkip;

  /// No description provided for @addWithPlus.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get addWithPlus;

  /// No description provided for @addBrand.
  ///
  /// In en, this message translates to:
  /// **'Add a brand'**
  String get addBrand;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'Brand name'**
  String get brandName;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @chooseSize.
  ///
  /// In en, this message translates to:
  /// **'Choose size'**
  String get chooseSize;

  /// No description provided for @legacyDress.
  ///
  /// In en, this message translates to:
  /// **'A dress'**
  String get legacyDress;

  /// No description provided for @legacyLayer.
  ///
  /// In en, this message translates to:
  /// **'A layer over it'**
  String get legacyLayer;

  /// No description provided for @legacyShoes.
  ///
  /// In en, this message translates to:
  /// **'Shoes'**
  String get legacyShoes;

  /// No description provided for @legacyBag.
  ///
  /// In en, this message translates to:
  /// **'A bag'**
  String get legacyBag;

  /// No description provided for @bagSemantics.
  ///
  /// In en, this message translates to:
  /// **'Bag, {count, plural, =1{1 item} other{{count} items}}'**
  String bagSemantics(int count);

  /// No description provided for @quantitySemantics.
  ///
  /// In en, this message translates to:
  /// **'Quantity {quantity}'**
  String quantitySemantics(int quantity);

  /// No description provided for @categoryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'{category} placeholder'**
  String categoryPlaceholder(String category);

  /// No description provided for @spentPieceCount.
  ///
  /// In en, this message translates to:
  /// **'{amount} spent · {count} of {total}'**
  String spentPieceCount(String amount, int count, int total);

  /// No description provided for @budgetLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String budgetLeft(String amount);

  /// No description provided for @addedToBag.
  ///
  /// In en, this message translates to:
  /// **'Added to your bag · {count} items'**
  String addedToBag(int count);

  /// No description provided for @addPartialLook.
  ///
  /// In en, this message translates to:
  /// **'Add the {count} piece so far · {total}'**
  String addPartialLook(int count, String total);

  /// No description provided for @addLookToBag.
  ///
  /// In en, this message translates to:
  /// **'Add the look to your bag · {total}'**
  String addLookToBag(String total);

  /// No description provided for @itemRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String itemRemoved(String name);

  /// No description provided for @removeNamedItem.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeNamedItem(String name);

  /// No description provided for @bagTitle.
  ///
  /// In en, this message translates to:
  /// **'Your bag — {count, plural, =1{1 item} other{{count} items}}'**
  String bagTitle(int count);

  /// No description provided for @chooseItemSize.
  ///
  /// In en, this message translates to:
  /// **'Choose size · {name}'**
  String chooseItemSize(String name);

  /// No description provided for @changeItemSize.
  ///
  /// In en, this message translates to:
  /// **'Change size · {name}'**
  String changeItemSize(String name);

  /// No description provided for @changeNamedItem.
  ///
  /// In en, this message translates to:
  /// **'Change {name}'**
  String changeNamedItem(String name);

  /// No description provided for @matchingProducts.
  ///
  /// In en, this message translates to:
  /// **'{name} · {count} matching products'**
  String matchingProducts(String name, String count);

  /// No description provided for @coloursChosen.
  ///
  /// In en, this message translates to:
  /// **'{count} chosen{selection}'**
  String coloursChosen(int count, String selection);

  /// No description provided for @wantItDifferent.
  ///
  /// In en, this message translates to:
  /// **'{name} — want it different?'**
  String wantItDifferent(String name);

  /// No description provided for @restartTitle.
  ///
  /// In en, this message translates to:
  /// **'Back to start?'**
  String get restartTitle;

  /// No description provided for @restartDescription.
  ///
  /// In en, this message translates to:
  /// **'Your current look and conversation will be cleared. Items in your bag and saved looks will be kept.'**
  String get restartDescription;

  /// No description provided for @restartConfirm.
  ///
  /// In en, this message translates to:
  /// **'Back to start'**
  String get restartConfirm;

  /// No description provided for @occasionExamples.
  ///
  /// In en, this message translates to:
  /// **'HERE ARE SOME EXAMPLES'**
  String get occasionExamples;

  /// No description provided for @exploreCatalog.
  ///
  /// In en, this message translates to:
  /// **'Explore component catalog'**
  String get exploreCatalog;

  /// No description provided for @disconnectModel.
  ///
  /// In en, this message translates to:
  /// **'Disconnect model'**
  String get disconnectModel;

  /// No description provided for @connectModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your model'**
  String get connectModelTitle;

  /// No description provided for @occasionTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get occasionTitle;

  /// No description provided for @occasionDescription.
  ///
  /// In en, this message translates to:
  /// **'Tell me the occasion, where it is and roughly what you’d like to spend. I’ll pull the whole look together from what we carry, and you can change anything as we go.'**
  String get occasionDescription;

  /// No description provided for @occasionField.
  ///
  /// In en, this message translates to:
  /// **'Your occasion'**
  String get occasionField;

  /// No description provided for @startLook.
  ///
  /// In en, this message translates to:
  /// **'Start my look'**
  String get startLook;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @catalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog components'**
  String get catalogTitle;

  /// No description provided for @catalogDescription.
  ///
  /// In en, this message translates to:
  /// **'A visual index of the commerce vocabulary available to A2UI surfaces. Each custom item has a schema, a Flutter builder, and a fixture-backed interaction path.'**
  String get catalogDescription;

  /// No description provided for @catalogCounts.
  ///
  /// In en, this message translates to:
  /// **'9 commerce components · 15 GenUI basic components'**
  String get catalogCounts;

  /// No description provided for @finalizedComponents.
  ///
  /// In en, this message translates to:
  /// **'Finalized Figma components'**
  String get finalizedComponents;

  /// No description provided for @finalizedScreens.
  ///
  /// In en, this message translates to:
  /// **'Finalized Figma screens'**
  String get finalizedScreens;

  /// No description provided for @basicComponents.
  ///
  /// In en, this message translates to:
  /// **'GenUI basic components'**
  String get basicComponents;

  /// No description provided for @basicComponentsDescription.
  ///
  /// In en, this message translates to:
  /// **'These primitives are available from the base catalog and can be composed before adding a custom schema.'**
  String get basicComponentsDescription;

  /// No description provided for @catalogGuidance.
  ///
  /// In en, this message translates to:
  /// **'Basic components remain available through the GenUI catalog. Add a custom item only when a schema and reusable interaction are clearer than composing existing primitives.'**
  String get catalogGuidance;

  /// No description provided for @previousResponse.
  ///
  /// In en, this message translates to:
  /// **'Previous response'**
  String get previousResponse;

  /// No description provided for @askingStylist.
  ///
  /// In en, this message translates to:
  /// **'Asking your stylist…'**
  String get askingStylist;

  /// No description provided for @stylistThinking.
  ///
  /// In en, this message translates to:
  /// **'Your stylist is thinking…'**
  String get stylistThinking;

  /// No description provided for @updateOutfit.
  ///
  /// In en, this message translates to:
  /// **'Update your outfit'**
  String get updateOutfit;

  /// No description provided for @stylistUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stylist unavailable'**
  String get stylistUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @newJourney.
  ///
  /// In en, this message translates to:
  /// **'New journey'**
  String get newJourney;

  /// No description provided for @inspectorClose.
  ///
  /// In en, this message translates to:
  /// **'Close inspector'**
  String get inspectorClose;

  /// No description provided for @inspectorInspect.
  ///
  /// In en, this message translates to:
  /// **'Inspect'**
  String get inspectorInspect;

  /// No description provided for @inspectorExchanges.
  ///
  /// In en, this message translates to:
  /// **'Exchanges'**
  String get inspectorExchanges;

  /// No description provided for @inspectorCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get inspectorCatalog;

  /// No description provided for @inspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Under the hood'**
  String get inspectorTitle;

  /// No description provided for @inspectorPrivacy.
  ///
  /// In en, this message translates to:
  /// **'These are safe structural summaries, not raw HTTP captures. Message text, model prose, prompts, keys and authentication headers are withheld.'**
  String get inspectorPrivacy;

  /// No description provided for @inspectorAuthority.
  ///
  /// In en, this message translates to:
  /// **'The model can choose an eligible recommendation component. The host binds product facts, validates the result and controls prices, basket changes and demo checkout.'**
  String get inspectorAuthority;

  /// No description provided for @inspectorHistory.
  ///
  /// In en, this message translates to:
  /// **'Showing {count} of the last {limit} events. Newest first; history stays in memory for this connection.'**
  String inspectorHistory(int count, int limit);

  /// No description provided for @inspectorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start a journey or use a basket control to see its path through the app. Host-only actions do not need a model request.'**
  String get inspectorEmpty;

  /// No description provided for @inspectorClientInput.
  ///
  /// In en, this message translates to:
  /// **'Client → host'**
  String get inspectorClientInput;

  /// No description provided for @inspectorClientExplanation.
  ///
  /// In en, this message translates to:
  /// **'A message or control reached the host. Content is withheld; a known action name may be shown.'**
  String get inspectorClientExplanation;

  /// No description provided for @inspectorModelRequest.
  ///
  /// In en, this message translates to:
  /// **'Host → model'**
  String get inspectorModelRequest;

  /// No description provided for @inspectorRequestExplanation.
  ///
  /// In en, this message translates to:
  /// **'Metadata from an actual decoded model request. The provider receives instructions and context; their content is withheld here.'**
  String get inspectorRequestExplanation;

  /// No description provided for @inspectorModelResponse.
  ///
  /// In en, this message translates to:
  /// **'Model → host'**
  String get inspectorModelResponse;

  /// No description provided for @inspectorResponseExplanation.
  ///
  /// In en, this message translates to:
  /// **'Metadata from an actual decoded response. Safe component choices and known tool names are shown before host validation; model prose is withheld.'**
  String get inspectorResponseExplanation;

  /// No description provided for @inspectorValidation.
  ///
  /// In en, this message translates to:
  /// **'Host validation'**
  String get inspectorValidation;

  /// No description provided for @inspectorValidationExplanation.
  ///
  /// In en, this message translates to:
  /// **'The host checks whether the proposed component is eligible. Product, budget and action validation still apply.'**
  String get inspectorValidationExplanation;

  /// No description provided for @inspectorModelSelected.
  ///
  /// In en, this message translates to:
  /// **'Model-selected recommendation · host-bound surface'**
  String get inspectorModelSelected;

  /// No description provided for @inspectorHostComposed.
  ///
  /// In en, this message translates to:
  /// **'Host-composed surface'**
  String get inspectorHostComposed;

  /// No description provided for @inspectorSurfaceExplanation.
  ///
  /// In en, this message translates to:
  /// **'A structural summary of the validated A2UI batch published to Flutter. The host supplies facts, bindings and actions. This is not raw model-authored A2UI.'**
  String get inspectorSurfaceExplanation;

  /// No description provided for @inspectorProvider.
  ///
  /// In en, this message translates to:
  /// **'Connected provider'**
  String get inspectorProvider;

  /// No description provided for @inspectorOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline fixture · no provider call'**
  String get inspectorOffline;

  /// No description provided for @inspectorInjected.
  ///
  /// In en, this message translates to:
  /// **'Injected model · test or custom adapter'**
  String get inspectorInjected;

  /// No description provided for @inspectorCatalogCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 registered component} other{{count} registered components}}'**
  String inspectorCatalogCount(int count);

  /// No description provided for @inspectorCatalogExplanation.
  ///
  /// In en, this message translates to:
  /// **'These schemas come from the same catalog used by the Flutter renderer and sent as model instructions. Availability shows which components the model may choose now, which the host controls, and which are gallery examples.'**
  String get inspectorCatalogExplanation;

  /// No description provided for @inspectorHostActions.
  ///
  /// In en, this message translates to:
  /// **'Host action contracts'**
  String get inspectorHostActions;

  /// No description provided for @inspectorHostActionsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Schemas describe validated controls. They do not authorize a model to change your basket or confirm checkout.'**
  String get inspectorHostActionsExplanation;

  /// No description provided for @inspectorSelectable.
  ///
  /// In en, this message translates to:
  /// **'Model selectable'**
  String get inspectorSelectable;

  /// No description provided for @inspectorHostControlled.
  ///
  /// In en, this message translates to:
  /// **'Host controlled'**
  String get inspectorHostControlled;

  /// No description provided for @inspectorReferenceOnly.
  ///
  /// In en, this message translates to:
  /// **'Reference only · gallery'**
  String get inspectorReferenceOnly;

  /// No description provided for @inspectorSchema.
  ///
  /// In en, this message translates to:
  /// **'Properties and action bindings'**
  String get inspectorSchema;

  /// No description provided for @inspectorToolResult.
  ///
  /// In en, this message translates to:
  /// **'Host → model tool feedback'**
  String get inspectorToolResult;

  /// No description provided for @inspectorToolResultExplanation.
  ///
  /// In en, this message translates to:
  /// **'A host tool returned feedback to the model. The tool name and safe counts are shown; its content is withheld.'**
  String get inspectorToolResultExplanation;

  /// No description provided for @inspectorComponentChoice.
  ///
  /// In en, this message translates to:
  /// **'Component: {component}'**
  String inspectorComponentChoice(String component);

  /// No description provided for @inspectorTools.
  ///
  /// In en, this message translates to:
  /// **'Tools: {tools}'**
  String inspectorTools(String tools);

  /// No description provided for @inspectorAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get inspectorAccepted;

  /// No description provided for @inspectorRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get inspectorRejected;

  /// No description provided for @inspectorTurnFailure.
  ///
  /// In en, this message translates to:
  /// **'Turn not committed'**
  String get inspectorTurnFailure;

  /// No description provided for @inspectorTurnFailureExplanation.
  ///
  /// In en, this message translates to:
  /// **'The turn failed before publication. Its safe category distinguishes rejected input, invalid presentation and an unavailable response; exception details are withheld.'**
  String get inspectorTurnFailureExplanation;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
