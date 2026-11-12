import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Scrolls the pet care tab strip toward earlier sections without selecting a tab.
  ///
  /// In en, this message translates to:
  /// **'Previous tabs'**
  String get previousTabs;

  /// Scrolls the pet care tab strip to reveal further sections without selecting a tab.
  ///
  /// In en, this message translates to:
  /// **'More tabs'**
  String get moreTabs;

  /// Settings page app bar title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section for local notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Opens reminder preferences from Settings.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// Description of the reminder preferences destination.
  ///
  /// In en, this message translates to:
  /// **'Medication doses and planned vaccinations'**
  String get remindersDescription;

  /// Section heading for theme choices.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// Theme choice that follows device brightness.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Light theme choice.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme choice.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Explains the System theme choice.
  ///
  /// In en, this message translates to:
  /// **'Follow device settings'**
  String get followDeviceSettings;

  /// Section heading for application language choices.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Language choice that follows supported system languages.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// Explains the System application language choice.
  ///
  /// In en, this message translates to:
  /// **'Follow device language'**
  String get followDeviceLanguage;

  /// Turkish language autonym; stays Turkish in every translation.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// English language autonym; stays English in every translation.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Screen reader label while preferences are being read.
  ///
  /// In en, this message translates to:
  /// **'Loading settings'**
  String get loadingSettings;

  /// Screen reader label while a preference is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving settings'**
  String get savingSettings;

  /// Retries an operation that failed.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Theme storage read failed; a Retry action is available.
  ///
  /// In en, this message translates to:
  /// **'Failed to load theme preference'**
  String get themeLoadFailed;

  /// Language storage read failed; a Retry action is available.
  ///
  /// In en, this message translates to:
  /// **'Failed to load language preference'**
  String get languageLoadFailed;

  /// Both theme and language storage reads failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings'**
  String get settingsLoadFailed;

  /// Theme storage write failed; the previous theme is retained.
  ///
  /// In en, this message translates to:
  /// **'Failed to save theme preference'**
  String get themeSaveFailed;

  /// Language storage write failed; the previous language is retained.
  ///
  /// In en, this message translates to:
  /// **'Failed to save language preference'**
  String get languageSaveFailed;

  /// Settings section with the privacy policy, source code and license links.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// Opens the privacy policy web page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// Opens the app's public source repository in the browser.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// Subtitle of the Source code link.
  ///
  /// In en, this message translates to:
  /// **'Open source under the GNU GPL v3 or later'**
  String get sourceCodeDescription;

  /// Opens the license notices of Patilog and its bundled packages.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// Copyright and license line on the open-source licenses page; keep the name unchanged.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Berke Can Koç\nLicensed under the GNU GPL v3 or later.\nProvided without any warranty.'**
  String get appLegalese;

  /// No browser could open an About link; a Copy link action is offered.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get linkOpenFailed;

  /// Copies the link that could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// Confirms that the link was copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// Cancels an operation or closes a confirmation without changing data.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Edits a review section.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Returns to the previous form step.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Validates a section and returns to Review.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Advances to the next form step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// Saves an edited record.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// Visible label while a record is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// Placeholder for an optional value that was not supplied.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// Heading above a recoverable load error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// Hides input without submitting the form.
  ///
  /// In en, this message translates to:
  /// **'Hide keyboard'**
  String get hideKeyboard;

  /// Returns to Review after a failed save.
  ///
  /// In en, this message translates to:
  /// **'Review changes'**
  String get reviewChanges;

  /// Current form position, total number of steps and step title.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total} · {title}'**
  String formStep(int current, int total, String title);

  /// Screen reader label for the positional progress bar.
  ///
  /// In en, this message translates to:
  /// **'Current form step'**
  String get currentFormStep;

  /// Date picker button; preserve the supplied field label's casing.
  ///
  /// In en, this message translates to:
  /// **'{field}: choose date'**
  String chooseDateField(String field);

  /// Clears only the indicated optional date.
  ///
  /// In en, this message translates to:
  /// **'{field}: clear date'**
  String clearDateField(String field);

  /// Pet directory title and home shortcut tooltip.
  ///
  /// In en, this message translates to:
  /// **'My pets'**
  String get myPets;

  /// Pet profile tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Veterinary visit navigation label.
  ///
  /// In en, this message translates to:
  /// **'Vet visits'**
  String get vetVisits;

  /// Short bottom navigation label. The full destination title and tooltip use vetVisits.
  ///
  /// In en, this message translates to:
  /// **'Vet visits'**
  String get vetVisitsNavigation;

  /// Vaccination navigation label.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get vaccinations;

  /// Medication navigation label.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications;

  /// Measurement history navigation label.
  ///
  /// In en, this message translates to:
  /// **'Weight history'**
  String get weightHistory;

  /// Label for a clinic's name.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get clinic;

  /// Label for a veterinarian's name.
  ///
  /// In en, this message translates to:
  /// **'Veterinarian'**
  String get veterinarian;

  /// Pet profile app bar fallback title.
  ///
  /// In en, this message translates to:
  /// **'Pet profile'**
  String get petProfile;

  /// Heading of the pet's basic profile information.
  ///
  /// In en, this message translates to:
  /// **'Profile details'**
  String get profileDetails;

  /// Opens the populated pet form.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Pet delete icon tooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete pet'**
  String get deletePet;

  /// Confirmation title before deleting a pet and its care history.
  ///
  /// In en, this message translates to:
  /// **'Delete pet?'**
  String get deletePetTitle;

  /// Deletion scope; user-supplied name is shown unchanged without generating suffixes.
  ///
  /// In en, this message translates to:
  /// **'{name}’s profile, photo, weight history, vet visits, vaccinations, medications and dose records will be removed. This cannot be undone.'**
  String deletePetMessage(String name);

  /// Confirms permanent record deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// Requests fresh confirmation before retrying deletion.
  ///
  /// In en, this message translates to:
  /// **'Retry deletion'**
  String get retryDeletion;

  /// Retries refreshing the loaded profile.
  ///
  /// In en, this message translates to:
  /// **'Retry profile'**
  String get retryProfile;

  /// The requested pet no longer exists.
  ///
  /// In en, this message translates to:
  /// **'Pet not found'**
  String get petNotFound;

  /// Pet profile load failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to get pet'**
  String get petLoadFailed;

  /// Pet directory load failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to get pets'**
  String get petsLoadFailed;

  /// Failed pet creation; draft is retained.
  ///
  /// In en, this message translates to:
  /// **'Failed to create pet'**
  String get petCreateFailed;

  /// Failed pet update; draft is retained.
  ///
  /// In en, this message translates to:
  /// **'Failed to update pet'**
  String get petUpdateFailed;

  /// Pet deletion failed; profile is retained.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete pet'**
  String get petDeleteFailed;

  /// Failed profile refresh; loaded content is retained.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh pet'**
  String get petRefreshFailed;

  /// Selected photo could not be copied into app storage.
  ///
  /// In en, this message translates to:
  /// **'Failed to save new image'**
  String get photoSaveFailed;

  /// Creates a pet or opens its creation form.
  ///
  /// In en, this message translates to:
  /// **'Add pet'**
  String get addPet;

  /// Title of the existing pet form.
  ///
  /// In en, this message translates to:
  /// **'Edit pet'**
  String get editPet;

  /// Form step containing basic pet information.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get petStep;

  /// Final form step, before submitting.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// Review heading before saving a pet.
  ///
  /// In en, this message translates to:
  /// **'Review pet'**
  String get reviewPet;

  /// Section for pet name, species, sex and breed.
  ///
  /// In en, this message translates to:
  /// **'Basic details'**
  String get basicDetails;

  /// Pet name input and review label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get petName;

  /// Empty pet name validation.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get petNameRequired;

  /// Pet name validation using visible Unicode characters.
  ///
  /// In en, this message translates to:
  /// **'Keep name within {max} characters'**
  String petNameTooLong(int max);

  /// Pet species field label.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get species;

  /// Pet sex field label.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// Pet breed field label.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get breed;

  /// Optional pet breed input.
  ///
  /// In en, this message translates to:
  /// **'Breed (optional)'**
  String get breedOptional;

  /// Pet reproductive status field.
  ///
  /// In en, this message translates to:
  /// **'Reproductive status'**
  String get reproductiveStatus;

  /// Pet birth date label.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get birthDate;

  /// Optional pet birth date input.
  ///
  /// In en, this message translates to:
  /// **'Birth date (optional)'**
  String get birthDateOptional;

  /// Latest recorded pet weight.
  ///
  /// In en, this message translates to:
  /// **'Current weight'**
  String get currentWeight;

  /// Optional initial or updated pet weight in kg.
  ///
  /// In en, this message translates to:
  /// **'Weight (optional)'**
  String get weightOptional;

  /// Weight input cannot be parsed as a finite number.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid weight'**
  String get weightInvalid;

  /// Weight must be positive.
  ///
  /// In en, this message translates to:
  /// **'Weight must be greater than 0'**
  String get weightPositive;

  /// Weight fractional precision validation.
  ///
  /// In en, this message translates to:
  /// **'Use up to {max} decimal places'**
  String weightPrecision(int max);

  /// Section for pet identification.
  ///
  /// In en, this message translates to:
  /// **'Identification'**
  String get identification;

  /// Pet microchip identifier label.
  ///
  /// In en, this message translates to:
  /// **'Microchip ID'**
  String get microchipId;

  /// Optional pet microchip input.
  ///
  /// In en, this message translates to:
  /// **'Microchip ID (optional)'**
  String get microchipIdOptional;

  /// Expandable optional information on pet form Review.
  ///
  /// In en, this message translates to:
  /// **'Health & identification (optional)'**
  String get healthIdentificationOptional;

  /// Screen reader name for an empty pet photo button.
  ///
  /// In en, this message translates to:
  /// **'Add pet photo'**
  String get addPetPhoto;

  /// Screen reader name for an existing pet photo button.
  ///
  /// In en, this message translates to:
  /// **'Change pet photo'**
  String get changePetPhoto;

  /// Pet photo selection action.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// Replaces the selected pet photo.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// Removes a selected pet photo from the draft.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// Photo permission failure with an actionable recovery explanation.
  ///
  /// In en, this message translates to:
  /// **'Photo access was denied. Allow access in Settings and try again.'**
  String get photoAccessDenied;

  /// Recoverable photo picker failure; cancellation is silent.
  ///
  /// In en, this message translates to:
  /// **'Could not select a photo. Please try again.'**
  String get photoSelectFailed;

  /// Confirmation title when leaving a dirty form.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// Explains that leaving discards the current form draft.
  ///
  /// In en, this message translates to:
  /// **'Your changes have not been saved. Leave without saving?'**
  String get discardChangesMessage;

  /// Keeps the unsaved form open.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// Discards unsaved draft changes.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// Dog species label.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get speciesDog;

  /// Cat species label.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get speciesCat;

  /// Bird species label.
  ///
  /// In en, this message translates to:
  /// **'Bird'**
  String get speciesBird;

  /// Other pet species label.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get speciesOther;

  /// Male pet sex label.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// Female pet sex label.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// Explicit unknown value, distinct from an empty optional field.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Pet has not been sterilized.
  ///
  /// In en, this message translates to:
  /// **'Intact'**
  String get reproductiveIntact;

  /// Pet has been sterilized.
  ///
  /// In en, this message translates to:
  /// **'Sterilized'**
  String get reproductiveSterilized;

  /// Empty pet directory heading.
  ///
  /// In en, this message translates to:
  /// **'No pets yet'**
  String get noPetsYet;

  /// Empty pet directory explanation.
  ///
  /// In en, this message translates to:
  /// **'Add your first pet to start tracking health and care.'**
  String get petsEmptyDescription;

  /// Welcome heading in the pet directory when no profiles have been added.
  ///
  /// In en, this message translates to:
  /// **'Your pets’ care in one place'**
  String get petWelcomeTitle;

  /// Explains the app's purpose in the empty pet directory.
  ///
  /// In en, this message translates to:
  /// **'Track health records, meals, and weight.'**
  String get petWelcomeDescription;

  /// Explains account-free, local storage in the empty pet directory; does not promise encryption or cloud backup.
  ///
  /// In en, this message translates to:
  /// **'No account needed. Records are stored on this device.'**
  String get petWelcomePrivacy;

  /// Pet creation action across destinations when no profiles have been added.
  ///
  /// In en, this message translates to:
  /// **'Add your first pet'**
  String get addFirstPet;

  /// Pet directory introduction shown only when pets exist.
  ///
  /// In en, this message translates to:
  /// **'Choose a pet to view its profile and care overview.'**
  String get choosePetOverview;

  /// Creates a veterinary visit.
  ///
  /// In en, this message translates to:
  /// **'Add visit'**
  String get addVisit;

  /// Creates a vaccination record or plan.
  ///
  /// In en, this message translates to:
  /// **'Add vaccination'**
  String get addVaccination;

  /// Creates a medication and its first schedule.
  ///
  /// In en, this message translates to:
  /// **'Add medication'**
  String get addMedication;

  /// Chooses the owner before creating a care record.
  ///
  /// In en, this message translates to:
  /// **'Choose a pet'**
  String get choosePet;

  /// Closes a selection sheet without choosing a record.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Screen reader label while saved-name suggestions are loading.
  ///
  /// In en, this message translates to:
  /// **'Loading suggestions'**
  String get loadingSuggestions;

  /// weight_entry_form_page.dart: labelText: 'Weight'
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// weight_entry_form_page.dart: widget.entry == null ? 'Save' : 'Save changes'
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// weight_entry_form_page.dart: title: 'Measurement'
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get measurement;

  /// weight_history_page.dart: title: 'Delete measurement?'
  ///
  /// In en, this message translates to:
  /// **'Delete measurement?'**
  String get deleteMeasurementTitle;

  /// weight_history_page.dart: semanticsLabel: 'Updating measurements'
  ///
  /// In en, this message translates to:
  /// **'Updating measurements'**
  String get updatingMeasurements;

  /// weight_history_page.dart: tooltip: 'Add measurement'
  ///
  /// In en, this message translates to:
  /// **'Add measurement'**
  String get addMeasurement;

  /// weight_history_page.dart: ('No measurements yet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'No measurements yet'**
  String get noMeasurements;

  /// weight_history_page.dart: ('Add a weight measurement to start the history.', textAlign: TextAlign.center)
  ///
  /// In en, this message translates to:
  /// **'Add a weight measurement to start the history.'**
  String get measurementsEmpty;

  /// weight_history_page.dart: ('Latest weight', style: theme.textTheme.titleMedium)
  ///
  /// In en, this message translates to:
  /// **'Latest weight'**
  String get latestWeight;

  /// Heading above the pet's weight history chart.
  ///
  /// In en, this message translates to:
  /// **'Weight trend'**
  String get weightTrend;

  /// No description provided for @weightChartOneMonth.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get weightChartOneMonth;

  /// No description provided for @weightChartThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get weightChartThreeMonths;

  /// No description provided for @weightChartSixMonths.
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get weightChartSixMonths;

  /// Compact month range on weight chart controls. The full month wording is supplied separately for tooltips and accessibility.
  ///
  /// In en, this message translates to:
  /// **'{months} mo'**
  String weightChartMonthsShort(int months);

  /// No description provided for @weightChartAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get weightChartAll;

  /// No description provided for @weightChartEmpty.
  ///
  /// In en, this message translates to:
  /// **'No measurements in this period.'**
  String get weightChartEmpty;

  /// No description provided for @weightChartShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all history'**
  String get weightChartShowAll;

  /// Difference between the last and first plotted daily measurements; no health judgement is implied.
  ///
  /// In en, this message translates to:
  /// **'Change in this period: {change} kg'**
  String weightChartChange(String change);

  /// No description provided for @weightChartSinglePoint.
  ///
  /// In en, this message translates to:
  /// **'One day recorded. Add a measurement on another day to see the trend.'**
  String get weightChartSinglePoint;

  /// No description provided for @weightChartDailyHint.
  ///
  /// In en, this message translates to:
  /// **'Latest measurement per day. Touch a point for its date and weight.'**
  String get weightChartDailyHint;

  /// No description provided for @weightChartSemantics.
  ///
  /// In en, this message translates to:
  /// **'Weight by date in kilograms. Exact measurements are listed below.'**
  String get weightChartSemantics;

  /// weight_history_page.dart: title: 'Measurements'
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurements;

  /// weight_history_page.dart: ('Newest first. Select a measurement to edit it.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
  ///
  /// In en, this message translates to:
  /// **'Newest first. Select a measurement to edit it.'**
  String get measurementsOrderHint;

  /// weight_history_page.dart: semanticsLabel: 'Deleting measurement'
  ///
  /// In en, this message translates to:
  /// **'Deleting measurement'**
  String get deletingMeasurement;

  /// weight_entry_form_page.dart: return 'Weight is required';
  ///
  /// In en, this message translates to:
  /// **'Weight is required'**
  String get weightRequired;

  /// weight_entry_form_page.dart: return 'Enter a weight greater than zero';
  ///
  /// In en, this message translates to:
  /// **'Enter a weight greater than zero'**
  String get weightGreaterThanZero;

  /// weight_entry_form_page.dart: return 'Use up to 3 decimal places';
  ///
  /// In en, this message translates to:
  /// **'Use up to 3 decimal places'**
  String get weightThreeDecimals;

  /// weight_entry_form_page.dart: labelText: 'Measurement date'
  ///
  /// In en, this message translates to:
  /// **'Measurement date'**
  String get measurementDate;

  /// weight_entry_form_page.dart: widget.entry == null ? 'Add measurement' : 'Edit measurement'
  ///
  /// In en, this message translates to:
  /// **'Edit measurement'**
  String get editMeasurement;

  /// weight_entry_form_page.dart: ('Review measurement', style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'Review measurement'**
  String get reviewMeasurement;

  /// confirm_vet_visit_deletion.dart: title: 'Delete visit?'
  ///
  /// In en, this message translates to:
  /// **'Delete visit?'**
  String get deleteVisitTitle;

  /// vet_visit_form_page.dart: labelText: 'Reason for visit'
  ///
  /// In en, this message translates to:
  /// **'Reason for visit'**
  String get visitReason;

  /// vet_visit_form_page.dart: label: 'Visit reason'
  ///
  /// In en, this message translates to:
  /// **'Visit reason'**
  String get visitReasonSummary;

  /// vet_visit_form_page.dart: return 'Enter a reason for the visit';
  ///
  /// In en, this message translates to:
  /// **'Enter a reason for the visit'**
  String get visitReasonRequired;

  /// vet_visit_form_page.dart: reason.characters.length > 100 ? 'Keep reason within 100 characters' : null
  ///
  /// In en, this message translates to:
  /// **'Keep reason within 100 characters'**
  String get visitReasonLimit;

  /// vet_visit_form_page.dart: labelText: 'Visit date'
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get visitDate;

  /// vet_visit_form_page.dart: ('Dates of any linked vaccinations will also change.', style: Theme.of(context).textTheme.bodySmall)
  ///
  /// In en, this message translates to:
  /// **'Dates of any linked vaccinations will also change.'**
  String get linkedVaccinationDateNotice;

  /// vet_visit_form_page.dart: ('Review visit', style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'Review visit'**
  String get reviewVisit;

  /// vet_visit_form_page.dart: title: 'Visit details'
  ///
  /// In en, this message translates to:
  /// **'Visit details'**
  String get visitDetails;

  /// vet_visit_form_page.dart: title: 'Clinic & veterinarian (optional)'
  ///
  /// In en, this message translates to:
  /// **'Clinic & veterinarian (optional)'**
  String get clinicalOptional;

  /// vet_visit_form_page.dart: label: 'Clinic (optional)'
  ///
  /// In en, this message translates to:
  /// **'Clinic (optional)'**
  String get clinicOptional;

  /// vet_visit_form_page.dart: label: 'Veterinarian (optional)'
  ///
  /// In en, this message translates to:
  /// **'Veterinarian (optional)'**
  String get veterinarianOptional;

  /// vet_visit_form_page.dart: ('Retry suggestions')
  ///
  /// In en, this message translates to:
  /// **'Retry suggestions'**
  String get retrySuggestions;

  /// vet_visit_form_page.dart: title: 'Medical notes (optional)'
  ///
  /// In en, this message translates to:
  /// **'Medical notes (optional)'**
  String get medicalNotesOptional;

  /// vet_visit_form_page.dart: labelText: 'Diagnosis (optional)'
  ///
  /// In en, this message translates to:
  /// **'Diagnosis (optional)'**
  String get diagnosisOptional;

  /// vet_visit_form_page.dart: labelText: 'Notes (optional)'
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// vaccination_form_page.dart: (value?.characters.length ?? 0) > 200 ? 'Keep notes within 200 characters' : null
  ///
  /// In en, this message translates to:
  /// **'Keep notes within 200 characters'**
  String get notesLimit200;

  /// vet_visit_form_page.dart: title: 'Cost (optional)'
  ///
  /// In en, this message translates to:
  /// **'Cost (optional)'**
  String get costOptional;

  /// vet_visit_form_page.dart: labelText: 'Amount (optional)'
  ///
  /// In en, this message translates to:
  /// **'Amount (optional)'**
  String get amountOptional;

  /// vet_visit_form_page.dart: value == null || value.trim().isEmpty || parseVetVisitCost(value) != null ? null : 'Enter a valid amount with up to 2 decimal places'
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount with up to 2 decimal places'**
  String get costInvalid;

  /// vet_visit_form_page.dart: labelText: 'Currency'
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// vet_visit_form_page.dart: widget.visit == null ? 'Add visit' : 'Edit visit'
  ///
  /// In en, this message translates to:
  /// **'Edit visit'**
  String get editVisit;

  /// vet_visit_form_page.dart: title: 'Visit'
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visit;

  /// vet_visit_detail_page.dart: title: 'Vet visit'
  ///
  /// In en, this message translates to:
  /// **'Vet visit'**
  String get vetVisit;

  /// vet_visit_detail_page.dart: deleting ? 'Deleting visit' : 'Refreshing visit'
  ///
  /// In en, this message translates to:
  /// **'Deleting visit'**
  String get deletingVisit;

  /// vet_visit_detail_page.dart: deleting ? 'Deleting visit' : 'Refreshing visit'
  ///
  /// In en, this message translates to:
  /// **'Refreshing visit'**
  String get refreshingVisit;

  /// vet_visit_detail_page.dart: tooltip: 'Delete visit'
  ///
  /// In en, this message translates to:
  /// **'Delete visit'**
  String get deleteVisit;

  /// vet_visit_detail_page.dart: title: 'Clinic & veterinarian'
  ///
  /// In en, this message translates to:
  /// **'Clinic & veterinarian'**
  String get clinical;

  /// vet_visit_detail_page.dart: title: 'Medical notes'
  ///
  /// In en, this message translates to:
  /// **'Medical notes'**
  String get medicalNotes;

  /// vet_visit_detail_page.dart: label: 'Diagnosis'
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosis;

  /// vet_visit_detail_page.dart: label: 'Notes'
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// vet_visit_detail_page.dart: title: 'Cost'
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get cost;

  /// vet_visit_detail_page.dart: label: 'Amount'
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// vet_visit_list_page.dart: semanticsLabel: 'Updating visits'
  ///
  /// In en, this message translates to:
  /// **'Updating visits'**
  String get updatingVisits;

  /// vet_visit_list_page.dart: ('No visits yet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get noVisits;

  /// vet_visit_list_page.dart: ('Add a completed visit to keep the details together.', textAlign: TextAlign.center)
  ///
  /// In en, this message translates to:
  /// **'Add a completed visit to keep the details together.'**
  String get visitsEmpty;

  /// visit_vaccinations_section.dart: title: 'Linked vaccinations'
  ///
  /// In en, this message translates to:
  /// **'Linked vaccinations'**
  String get linkedVaccinations;

  /// visit_vaccinations_section.dart: retryLabel: 'Retry vaccinations'
  ///
  /// In en, this message translates to:
  /// **'Retry vaccinations'**
  String get retryVaccinations;

  /// visit_vaccinations_section.dart: ('No vaccinations linked to this visit.')
  ///
  /// In en, this message translates to:
  /// **'No vaccinations linked to this visit.'**
  String get noLinkedVaccinations;

  /// visit_vaccinations_section.dart: semanticsLabel: 'Loading linked vaccinations'
  ///
  /// In en, this message translates to:
  /// **'Loading linked vaccinations'**
  String get loadingLinkedVaccinations;

  /// confirm_vaccination_deletion.dart: title: 'Delete vaccination?'
  ///
  /// In en, this message translates to:
  /// **'Delete vaccination?'**
  String get deleteVaccinationTitle;

  /// vaccination_form_page.dart: labelText: 'Vet visit (optional)'
  ///
  /// In en, this message translates to:
  /// **'Vet visit (optional)'**
  String get vetVisitOptional;

  /// vaccination_form_page.dart: ('No linked visit', maxLines: 1, overflow: TextOverflow.ellipsis)
  ///
  /// In en, this message translates to:
  /// **'No linked visit'**
  String get noLinkedVisit;

  /// vaccination_form_page.dart: ('Linked visit unavailable', maxLines: 1, overflow: TextOverflow.ellipsis)
  ///
  /// In en, this message translates to:
  /// **'Linked visit unavailable'**
  String get linkedVisitUnavailable;

  /// vaccination_form_page.dart: semanticsLabel: 'Loading visits'
  ///
  /// In en, this message translates to:
  /// **'Loading visits'**
  String get loadingVisits;

  /// vaccination_form_page.dart: ('Retry visits')
  ///
  /// In en, this message translates to:
  /// **'Retry visits'**
  String get retryVisits;

  /// vaccination_form_page.dart: label: 'Vaccine name'
  ///
  /// In en, this message translates to:
  /// **'Vaccine name'**
  String get vaccineName;

  /// vaccination_form_page.dart: return 'Enter a vaccine name';
  ///
  /// In en, this message translates to:
  /// **'Enter a vaccine name'**
  String get vaccineNameRequired;

  /// vaccination_form_page.dart: text.characters.length > 50 ? 'Keep vaccine name within 50 characters' : null
  ///
  /// In en, this message translates to:
  /// **'Keep vaccine name within 50 characters'**
  String get vaccineNameLimit;

  /// vaccination_form_page.dart: labelText: 'Status'
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// vaccination_form_page.dart: ('Administered')
  ///
  /// In en, this message translates to:
  /// **'Administered'**
  String get administered;

  /// vaccination_form_page.dart: ('Planned')
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get planned;

  /// vaccination_form_page.dart: return 'Choose today or a future date';
  ///
  /// In en, this message translates to:
  /// **'Choose today or a future date'**
  String get dateTodayOrFuture;

  /// vaccination_form_page.dart: return 'Choose today or an earlier date';
  ///
  /// In en, this message translates to:
  /// **'Choose today or an earlier date'**
  String get dateTodayOrPast;

  /// vaccination_form_page.dart: _status == VaccinationStatus.planned ? 'Planned date' : 'Administration date'
  ///
  /// In en, this message translates to:
  /// **'Planned date'**
  String get plannedDate;

  /// vaccination_form_page.dart: _status == VaccinationStatus.planned ? 'Planned date' : 'Administration date'
  ///
  /// In en, this message translates to:
  /// **'Administration date'**
  String get administrationDate;

  /// vaccination_form_page.dart: ('Date from linked vet visit', style: Theme.of(context).textTheme.bodySmall)
  ///
  /// In en, this message translates to:
  /// **'Date from linked vet visit'**
  String get dateFromLinkedVisit;

  /// vaccination_form_page.dart: ('Review vaccination', style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'Review vaccination'**
  String get reviewVaccination;

  /// vaccination_form_page.dart: title: 'Vaccine details'
  ///
  /// In en, this message translates to:
  /// **'Vaccine details'**
  String get vaccineDetails;

  /// vaccination_form_page.dart: title: 'Next dose (optional)'
  ///
  /// In en, this message translates to:
  /// **'Next dose (optional)'**
  String get nextDoseOptional;

  /// vaccination_form_page.dart: ('Optionally create a separate plan for the next dose.')
  ///
  /// In en, this message translates to:
  /// **'Optionally create a separate plan for the next dose.'**
  String get separateNextDoseHint;

  /// vaccination_form_page.dart: return 'Choose a date after the administration date';
  ///
  /// In en, this message translates to:
  /// **'Choose a date after the administration date'**
  String get dateAfterAdministration;

  /// vaccination_form_page.dart: labelText: 'Next dose date (optional)'
  ///
  /// In en, this message translates to:
  /// **'Next dose date (optional)'**
  String get nextDoseDateOptional;

  /// vaccination_form_page.dart: ('Reminders are managed in Settings → Notifications.', key: const Key('vaccination-reminder-guidance'), style: Theme.of(context).textTheme.bodySmall?.
  ///
  /// In en, this message translates to:
  /// **'Reminders are managed in Settings → Notifications.'**
  String get remindersSettingsGuidance;

  /// vaccination_form_page.dart: widget.recordAdministration ? 'Record administration' : widget.vaccination == null ? 'Add vaccination' : 'Edit vaccination'
  ///
  /// In en, this message translates to:
  /// **'Record administration'**
  String get recordAdministration;

  /// vaccination_form_page.dart: widget.vaccination == null ? 'Add vaccination' : 'Edit vaccination'
  ///
  /// In en, this message translates to:
  /// **'Edit vaccination'**
  String get editVaccination;

  /// vaccination_form_page.dart: title: 'Vaccination'
  ///
  /// In en, this message translates to:
  /// **'Vaccination'**
  String get vaccination;

  /// vaccination_detail_page.dart: label: 'Vaccine'
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get vaccine;

  /// vaccination_detail_page.dart: deleting ? 'Deleting vaccination' : 'Refreshing vaccination'
  ///
  /// In en, this message translates to:
  /// **'Deleting vaccination'**
  String get deletingVaccination;

  /// vaccination_detail_page.dart: deleting ? 'Deleting vaccination' : 'Refreshing vaccination'
  ///
  /// In en, this message translates to:
  /// **'Refreshing vaccination'**
  String get refreshingVaccination;

  /// vaccination_detail_page.dart: tooltip: 'Delete vaccination'
  ///
  /// In en, this message translates to:
  /// **'Delete vaccination'**
  String get deleteVaccination;

  /// vaccination_list_page.dart: ('No vaccinations yet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'No vaccinations yet'**
  String get noVaccinations;

  /// vaccination_list_page.dart: ('Record an administered vaccine or plan an upcoming dose.', textAlign: TextAlign.center)
  ///
  /// In en, this message translates to:
  /// **'Record an administered vaccine or plan an upcoming dose.'**
  String get vaccinationsEmpty;

  /// vaccination_list_page.dart: (context, 'History', Icons.history, history, state)
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// vaccination_list_page.dart: semanticsLabel: 'Updating vaccinations'
  ///
  /// In en, this message translates to:
  /// **'Updating vaccinations'**
  String get updatingVaccinations;

  /// linked_vet_visit_section.dart: title: 'Linked vet visit'
  ///
  /// In en, this message translates to:
  /// **'Linked vet visit'**
  String get linkedVetVisit;

  /// linked_vet_visit_section.dart: retryLabel: 'Retry visit'
  ///
  /// In en, this message translates to:
  /// **'Retry visit'**
  String get retryVisit;

  /// linked_vet_visit_section.dart: openLabel: 'Open vet visit'
  ///
  /// In en, this message translates to:
  /// **'Open vet visit'**
  String get openVetVisit;

  /// linked_vet_visit_section.dart: semanticsLabel: 'Loading linked vet visit'
  ///
  /// In en, this message translates to:
  /// **'Loading linked vet visit'**
  String get loadingLinkedVisit;

  /// vaccination_status_badge.dart: overdue ? 'Overdue' : date == today ? 'Due today' : 'Upcoming'
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// vaccination_status_badge.dart: date == today ? 'Due today' : 'Upcoming'
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// vaccination_status_badge.dart: date == today ? 'Due today' : 'Upcoming'
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// medication_actions.dart: title = 'Delete medication?'
  ///
  /// In en, this message translates to:
  /// **'Delete medication?'**
  String get deleteMedicationTitle;

  /// medication_actions.dart: title = 'Cancel scheduled changes?'
  ///
  /// In en, this message translates to:
  /// **'Cancel scheduled changes?'**
  String get cancelScheduledChangesTitle;

  /// medication_actions.dart: title = 'Clear dose record?'
  ///
  /// In en, this message translates to:
  /// **'Clear dose record?'**
  String get clearDoseRecordTitle;

  /// medication_actions.dart: message = 'This dose will return to No record. The scheduled dose stays in the plan.'
  ///
  /// In en, this message translates to:
  /// **'This dose will return to No record. The scheduled dose stays in the plan.'**
  String get clearDoseRecordMessage;

  /// medication_actions.dart: action is ClearMedicationDoseAction ? 'Clear record' : 'Cancel changes'
  ///
  /// In en, this message translates to:
  /// **'Clear record'**
  String get clearRecord;

  /// medication_actions.dart: action is ClearMedicationDoseAction ? 'Clear record' : 'Cancel changes'
  ///
  /// In en, this message translates to:
  /// **'Cancel changes'**
  String get cancelChanges;

  /// medication_display.dart: period.intervalDays == 1 ? 'Daily' : 'Every ${period.intervalDays} days'
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// medication_detail_page.dart: end == null ? 'No end date' : DateUtils.isSameDay(period.startDate, end) ? 'One day' : 'Until ${dates.formatShortDate(end)}'
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEndDate;

  /// medication_list_page.dart: tooltip: 'Previous day'
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// medication_list_page.dart: DateUtils.isSameDay(date, cubit.now()) ? 'Today' : MaterialLocalizations.of(context).formatMediumDate(date)
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// medication_list_page.dart: tooltip: 'Next day'
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// medication_list_page.dart: ('Back to today')
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get backToToday;

  /// medication_list_page.dart: retryLabel: 'Retry dose records'
  ///
  /// In en, this message translates to:
  /// **'Retry dose records'**
  String get retryDoseRecords;

  /// medication_list_page.dart: ('No doses scheduled', 'There are no scheduled doses for this day.', action: 'View medications', onAction: () => setState(() => _tab = 1))
  ///
  /// In en, this message translates to:
  /// **'No doses scheduled'**
  String get noDoses;

  /// medication_list_page.dart: ('No doses scheduled', 'There are no scheduled doses for this day.', action: 'View medications', onAction: () => setState(() => _tab = 1))
  ///
  /// In en, this message translates to:
  /// **'There are no scheduled doses for this day.'**
  String get noDosesForDay;

  /// medication_list_page.dart: action: 'View medications'
  ///
  /// In en, this message translates to:
  /// **'View medications'**
  String get viewMedications;

  /// medication_list_page.dart: MedicationStatus.active => 'Active'
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// medication_list_page.dart: semanticsLabel: 'Updating medications'
  ///
  /// In en, this message translates to:
  /// **'Updating medications'**
  String get updatingMedications;

  /// medication_list_page.dart: loaded.failedAction != null ? 'Retry action' : 'Retry'
  ///
  /// In en, this message translates to:
  /// **'Retry action'**
  String get retryAction;

  /// medication_list_page.dart: ['Doses', 'Medications']
  ///
  /// In en, this message translates to:
  /// **'Doses'**
  String get doses;

  /// medication_list_page.dart: ('No medications yet', 'Add a medication and its schedule to start dose tracking.')
  ///
  /// In en, this message translates to:
  /// **'No medications yet'**
  String get noMedications;

  /// medication_list_page.dart: ('No medications yet', 'Add a medication and its schedule to start dose tracking.')
  ///
  /// In en, this message translates to:
  /// **'Add a medication and its schedule to start dose tracking.'**
  String get medicationsEmpty;

  /// medication_detail_page.dart: ('Open this section again to refresh the visit.')
  ///
  /// In en, this message translates to:
  /// **'Open this section again to refresh the visit.'**
  String get reopenVisitSection;

  /// medication_detail_page.dart: label: 'Dosage instructions'
  ///
  /// In en, this message translates to:
  /// **'Dosage instructions'**
  String get dosageInstructions;

  /// medication_detail_page.dart: DateUtils.isSameDay(period.startDate, end) ? 'One day' : 'Until ${dates.formatShortDate(end)}'
  ///
  /// In en, this message translates to:
  /// **'One day'**
  String get oneDay;

  /// medication_detail_page.dart: ('Edit change')
  ///
  /// In en, this message translates to:
  /// **'Edit change'**
  String get editChange;

  /// medication_detail_page.dart: ('Cancel change')
  ///
  /// In en, this message translates to:
  /// **'Cancel change'**
  String get cancelChange;

  /// medication_detail_page.dart: title: 'Schedule'
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// medication_detail_page.dart: ('Edit details')
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get editDetails;

  /// medication_detail_page.dart: MedicationStatus.completed => 'Completed'
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// medication_detail_page.dart: ('Edit medication')
  ///
  /// In en, this message translates to:
  /// **'Edit medication'**
  String get editMedication;

  /// medication_detail_page.dart: ('Schedule doses again')
  ///
  /// In en, this message translates to:
  /// **'Schedule doses again'**
  String get scheduleAgain;

  /// medication_detail_page.dart: ('Clinic & notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))
  ///
  /// In en, this message translates to:
  /// **'Clinic & notes'**
  String get clinicAndNotes;

  /// medication_detail_page.dart: _showCalendar ? 'Hide dose calendar' : 'Dose calendar'
  ///
  /// In en, this message translates to:
  /// **'Hide dose calendar'**
  String get hideDoseCalendar;

  /// medication_detail_page.dart: _showCalendar ? 'Hide dose calendar' : 'Dose calendar'
  ///
  /// In en, this message translates to:
  /// **'Dose calendar'**
  String get doseCalendar;

  /// medication_detail_page.dart: title: 'Previous schedules'
  ///
  /// In en, this message translates to:
  /// **'Previous schedules'**
  String get previousSchedules;

  /// medication_detail_page.dart: title: 'Medication'
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get medication;

  /// medication_detail_page.dart: tooltip: 'Delete medication'
  ///
  /// In en, this message translates to:
  /// **'Delete medication'**
  String get deleteMedication;

  /// medication_form_page.dart: (text ?? '').trim().isEmpty ? 'Enter a medication name.' : _limit(text, 50)
  ///
  /// In en, this message translates to:
  /// **'Enter a medication name.'**
  String get medicationNameRequired;

  /// medication_form_page.dart: return 'Use HH:mm, from 00:00 to 23:59.';
  ///
  /// In en, this message translates to:
  /// **'Use HH:mm, from 00:00 to 23:59.'**
  String get doseTimeInvalid;

  /// medication_form_page.dart: _times.where((time) => parseDoseTime(time.text) == minute).length > 1 ? 'Each time must be different.' : null
  ///
  /// In en, this message translates to:
  /// **'Each time must be different.'**
  String get uniqueDoseTimes;

  /// medication_form_page.dart: _times.isEmpty ? 'Add at least one dose time.' : _end != null && calendarDayNumber(_end!) < calendarDayNumber(_saveStart) ? 'End date must be on or af
  ///
  /// In en, this message translates to:
  /// **'Add at least one dose time.'**
  String get doseTimeRequired;

  /// medication_form_page.dart: _end != null && calendarDayNumber(_end!) < calendarDayNumber(_saveStart) ? 'End date must be on or after the start date.' : null
  ///
  /// In en, this message translates to:
  /// **'End date must be on or after the start date.'**
  String get periodEndInvalid;

  /// medication_form_page.dart: ('Which medication?', style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'Which medication?'**
  String get whichMedication;

  /// medication_form_page.dart: label: 'Medication name'
  ///
  /// In en, this message translates to:
  /// **'Medication name'**
  String get medicationName;

  /// medication_form_page.dart: (_dosage, 'Dosage instructions (optional)', hintText: 'e.g. half a tablet', validator: (value) => _limit(value, 100), readOnly: _historical)
  ///
  /// In en, this message translates to:
  /// **'Dosage instructions (optional)'**
  String get dosageInstructionsOptional;

  /// medication_form_page.dart: hintText: 'e.g. half a tablet'
  ///
  /// In en, this message translates to:
  /// **'e.g. half a tablet'**
  String get dosageExample;

  /// medication_form_page.dart: ('When are the doses?', style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'When are the doses?'**
  String get doseScheduleQuestion;

  /// medication_form_page.dart: ('This previous schedule is read-only. You can still correct its clinic information and notes.')
  ///
  /// In en, this message translates to:
  /// **'This previous schedule is read-only. You can still correct its clinic information and notes.'**
  String get previousScheduleReadOnly;

  /// medication_form_page.dart: ('Schedule changes start tomorrow or later. Earlier dose records stay unchanged.')
  ///
  /// In en, this message translates to:
  /// **'Schedule changes start tomorrow or later. Earlier dose records stay unchanged.'**
  String get newScheduleEffectiveHint;

  /// medication_form_page.dart: _locked && !_historical || widget.newSchedule ? 'Changes start' : 'Start date'
  ///
  /// In en, this message translates to:
  /// **'Changes start'**
  String get changesStart;

  /// medication_form_page.dart: _locked && !_historical || widget.newSchedule ? 'Changes start' : 'Start date'
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// medication_form_page.dart: labelText: 'Frequency'
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// medication_form_page.dart: ('Every N days')
  ///
  /// In en, this message translates to:
  /// **'Every N days'**
  String get everyNDays;

  /// medication_form_page.dart: (_interval, 'Days between doses', keyboardType: TextInputType.number, readOnly: _historical, validator: (value) => (int.tryParse(value ?? '') ?? 0) <
  ///
  /// In en, this message translates to:
  /// **'Days between doses'**
  String get daysBetweenDoses;

  /// medication_form_page.dart: (int.tryParse(value ?? '') ?? 0) < 1 ? 'Enter at least 1 day.' : null
  ///
  /// In en, this message translates to:
  /// **'Enter at least 1 day.'**
  String get intervalRequired;

  /// medication_form_page.dart: labelText: 'Dose time'
  ///
  /// In en, this message translates to:
  /// **'Dose time'**
  String get doseTime;

  /// medication_form_page.dart: hintText: 'HH:mm'
  ///
  /// In en, this message translates to:
  /// **'HH:mm'**
  String get timeFormatHint;

  /// medication_form_page.dart: ('Add another time')
  ///
  /// In en, this message translates to:
  /// **'Add another time'**
  String get addAnotherTime;

  /// medication_form_page.dart: labelText: 'End date (optional)'
  ///
  /// In en, this message translates to:
  /// **'End date (optional)'**
  String get endDateOptional;

  /// medication_form_page.dart: ('Review medication', style: Theme.of(context).textTheme.titleLarge)
  ///
  /// In en, this message translates to:
  /// **'Review medication'**
  String get reviewMedication;

  /// medication_form_page.dart: ('Earlier dose records stay unchanged.')
  ///
  /// In en, this message translates to:
  /// **'Earlier dose records stay unchanged.'**
  String get preserveEarlierDoseRecords;

  /// medication_form_page.dart: title: 'Clinic & notes (optional)'
  ///
  /// In en, this message translates to:
  /// **'Clinic & notes (optional)'**
  String get clinicalNotesOptional;

  /// medication_form_page.dart: widget.newSchedule ? 'Schedule doses' : _editing ? 'Edit medication' : 'Add medication'
  ///
  /// In en, this message translates to:
  /// **'Schedule doses'**
  String get scheduleDoses;

  /// medication_form_page.dart: retryLabel: 'Retry dose history'
  ///
  /// In en, this message translates to:
  /// **'Retry dose history'**
  String get retryDoseHistory;

  /// medication_form_page.dart: semanticsLabel: 'Checking dose history'
  ///
  /// In en, this message translates to:
  /// **'Checking dose history'**
  String get checkingDoseHistory;

  /// medication_doses.dart: loading ? 'Loading dose record…' : 'Dose record unavailable'
  ///
  /// In en, this message translates to:
  /// **'Loading dose record…'**
  String get loadingDoseRecord;

  /// medication_doses.dart: loading ? 'Loading dose record…' : 'Dose record unavailable'
  ///
  /// In en, this message translates to:
  /// **'Dose record unavailable'**
  String get doseRecordUnavailable;

  /// medication_doses.dart: ('Scheduled')
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// medication_doses.dart: log.status == MedicationDoseStatus.given ? 'Given at ${formatDoseTime(log.givenAt!.toLocal().hour * 60 + log.givenAt!.toLocal().minute)} · Edit' : 'Sk
  ///
  /// In en, this message translates to:
  /// **'Skipped · Edit'**
  String get skippedEdit;

  /// medication_doses.dart: ('Skip')
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipDose;

  /// medication_doses.dart: ('Given')
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get doseGiven;

  /// medication_doses.dart: ('No record')
  ///
  /// In en, this message translates to:
  /// **'No record'**
  String get noDoseRecord;

  /// medication_doses.dart: ('Record dose')
  ///
  /// In en, this message translates to:
  /// **'Record dose'**
  String get recordDose;

  /// medication_doses.dart: message: 'Your dose record changes have not been saved.'
  ///
  /// In en, this message translates to:
  /// **'Your dose record changes have not been saved.'**
  String get unsavedDoseRecord;

  /// medication_doses.dart: widget.dose.log == null ? 'Record dose' : 'Edit dose record'
  ///
  /// In en, this message translates to:
  /// **'Edit dose record'**
  String get editDoseRecord;

  /// medication_doses.dart: ('Skipped')
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get doseSkipped;

  /// medication_doses.dart: labelText: 'Given at'
  ///
  /// In en, this message translates to:
  /// **'Given at'**
  String get givenAt;

  /// medication_doses.dart: hintText: 'HH:mm · 24-hour'
  ///
  /// In en, this message translates to:
  /// **'HH:mm · 24-hour'**
  String get time24Hint;

  /// medication_doses.dart: DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60).isAfter(widget.editor.now()) ? 'Given time cannot be in the future.' : null
  ///
  /// In en, this message translates to:
  /// **'Given time cannot be in the future.'**
  String get givenTimeFuture;

  /// medication_doses.dart: ('This dose is not available for changes. Close and refresh the selected day.')
  ///
  /// In en, this message translates to:
  /// **'This dose is not available for changes. Close and refresh the selected day.'**
  String get doseNoLongerAvailable;

  /// medication_dose_calendar.dart: (Icons.hourglass_empty, 'Dose records unavailable')
  ///
  /// In en, this message translates to:
  /// **'Dose records unavailable'**
  String get doseRecordsUnavailable;

  /// medication_dose_calendar.dart: tooltip: 'Previous month'
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// medication_dose_calendar.dart: tooltip: 'Next month'
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// medication_dose_calendar.dart: ('Go to today')
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get goToToday;

  /// medication_dose_calendar.dart: semanticsLabel: 'Loading month records'
  ///
  /// In en, this message translates to:
  /// **'Loading month records'**
  String get loadingMonthRecords;

  /// medication_dose_calendar.dart: retryLabel: 'Retry calendar'
  ///
  /// In en, this message translates to:
  /// **'Retry calendar'**
  String get retryCalendar;

  /// medication_dose_calendar.dart: ('No doses scheduled for this day.')
  ///
  /// In en, this message translates to:
  /// **'No doses scheduled for this day.'**
  String get noCalendarDayDoses;

  /// visit_medications_section.dart: title: 'Linked medications'
  ///
  /// In en, this message translates to:
  /// **'Linked medications'**
  String get linkedMedications;

  /// visit_medications_section.dart: retryLabel: 'Retry medications'
  ///
  /// In en, this message translates to:
  /// **'Retry medications'**
  String get retryMedications;

  /// visit_medications_section.dart: ('No medications linked to this visit.')
  ///
  /// In en, this message translates to:
  /// **'No medications linked to this visit.'**
  String get noLinkedMedications;

  /// all_pets_care_page.dart: DeleteGlobalVetVisit() => 'Delete vet visit?'
  ///
  /// In en, this message translates to:
  /// **'Delete vet visit?'**
  String get deleteVetVisitTitle;

  /// all_pets_care_page.dart: ('All pets')
  ///
  /// In en, this message translates to:
  /// **'All pets'**
  String get allPets;

  /// all_pets_care_page.dart: message: 'There are no scheduled doses for this day. View Medications to manage schedules.'
  ///
  /// In en, this message translates to:
  /// **'There are no scheduled doses for this day. View Medications to manage schedules.'**
  String get allPetsNoDayDoses;

  /// all_pets_care_page.dart: title: 'No vet visits yet'
  ///
  /// In en, this message translates to:
  /// **'No vet visits yet'**
  String get noVetVisits;

  /// all_pets_care_page.dart: message: 'Keep a record of checkups and treatment for your pets.'
  ///
  /// In en, this message translates to:
  /// **'Keep a record of checkups and treatment for your pets.'**
  String get allVisitsEmpty;

  /// all_pets_care_page.dart: retryLabel: 'Retry pets'
  ///
  /// In en, this message translates to:
  /// **'Retry pets'**
  String get retryPets;

  /// all_pets_care_page.dart: state.failedAction is GlobalDoseAction ? 'Retry dose record' : 'Retry deletion'
  ///
  /// In en, this message translates to:
  /// **'Retry dose record'**
  String get retryDoseRecord;

  /// all_pets_care_page.dart: semanticsLabel: 'Updating care records'
  ///
  /// In en, this message translates to:
  /// **'Updating care records'**
  String get updatingCareRecords;

  /// care_record_card.dart: pet?.name ?? 'Pet unavailable'
  ///
  /// In en, this message translates to:
  /// **'Pet unavailable'**
  String get petUnavailable;

  /// care_record_card.dart: semanticsLabel: 'Deleting record'
  ///
  /// In en, this message translates to:
  /// **'Deleting record'**
  String get deletingRecord;

  /// notification_settings_page.dart: semanticsLabel: 'Updating reminders'
  ///
  /// In en, this message translates to:
  /// **'Updating reminders'**
  String get updatingReminders;

  /// notification_settings_page.dart: state.saveError != null ? 'Retry save' : 'Retry'
  ///
  /// In en, this message translates to:
  /// **'Retry save'**
  String get retrySave;

  /// notification_settings_page.dart: ('Choose which reminders this device sends. Times follow the device’s local time.')
  ///
  /// In en, this message translates to:
  /// **'Choose which reminders this device sends. Times follow the device’s local time.'**
  String get remindersDeviceHint;

  /// notification_settings_page.dart: title: 'Medication reminders'
  ///
  /// In en, this message translates to:
  /// **'Medication reminders'**
  String get medicationReminders;

  /// notification_settings_page.dart: subtitle: 'At scheduled dose times.'
  ///
  /// In en, this message translates to:
  /// **'At scheduled dose times.'**
  String get medicationReminderHint;

  /// notification_settings_page.dart: title: 'Vaccination reminders'
  ///
  /// In en, this message translates to:
  /// **'Vaccination reminders'**
  String get vaccinationReminders;

  /// notification_settings_page.dart: subtitle: 'On selected days.'
  ///
  /// In en, this message translates to:
  /// **'On selected days.'**
  String get vaccinationReminderHint;

  /// notification_settings_page.dart: title: 'Vaccination schedule'
  ///
  /// In en, this message translates to:
  /// **'Vaccination schedule'**
  String get vaccinationSchedule;

  /// notification_settings_page.dart: ('Days & time')
  ///
  /// In en, this message translates to:
  /// **'Days & time'**
  String get daysAndTime;

  /// notification_settings_page.dart: state.issue == null ? 'Loading schedule…' : 'Schedule unavailable'
  ///
  /// In en, this message translates to:
  /// **'Loading schedule…'**
  String get loadingSchedule;

  /// notification_settings_page.dart: state.issue == null ? 'Loading schedule…' : 'Schedule unavailable'
  ///
  /// In en, this message translates to:
  /// **'Schedule unavailable'**
  String get scheduleUnavailable;

  /// notification_settings_page.dart: ('These days and time apply to all planned vaccinations.')
  ///
  /// In en, this message translates to:
  /// **'These days and time apply to all planned vaccinations.'**
  String get sharedVaccinationScheduleHint;

  /// notification_settings_page.dart: blocked ? 'Notifications are blocked' : 'Precise timing is off'
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked'**
  String get notificationsBlocked;

  /// notification_settings_page.dart: blocked ? 'Notifications are blocked' : 'Precise timing is off'
  ///
  /// In en, this message translates to:
  /// **'Precise timing is off'**
  String get preciseRemindersOff;

  /// notification_settings_page.dart: blocked ? 'Allow notifications on this device to receive reminders.' : 'Medication reminders use normal scheduling and may arrive late.'
  ///
  /// In en, this message translates to:
  /// **'Allow notifications on this device to receive reminders.'**
  String get allowNotificationsHint;

  /// notification_settings_page.dart: blocked ? 'Allow notifications on this device to receive reminders.' : 'Medication reminders use normal scheduling and may arrive late.'
  ///
  /// In en, this message translates to:
  /// **'Meal and medication reminders may arrive late without precise timing.'**
  String get inexactRemindersHint;

  /// notification_settings_page.dart: blocked ? 'Allow notifications' : 'Allow precise reminders'
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get allowNotifications;

  /// notification_settings_page.dart: blocked ? 'Allow notifications' : 'Allow precise reminders'
  ///
  /// In en, this message translates to:
  /// **'Allow precise reminders'**
  String get allowPreciseReminders;

  /// notification_settings_page.dart: ('Open device settings')
  ///
  /// In en, this message translates to:
  /// **'Open device settings'**
  String get openDeviceSettings;

  /// notification_settings_page.dart: title: 'Upcoming reminders'
  ///
  /// In en, this message translates to:
  /// **'Upcoming reminders'**
  String get upcomingReminders;

  /// notification_settings_page.dart: state.isBusy ? 'Updating reminders…' : state.plan!.reminders.isEmpty ? 'No upcoming reminders. Add a planned vaccination or a medication schedule.' :
  ///
  /// In en, this message translates to:
  /// **'Updating reminders…'**
  String get updatingRemindersEllipsis;

  /// notification_settings_page.dart: state.plan!.reminders.isEmpty ? 'No upcoming reminders. Add a planned vaccination or a medication schedule.' : 'Next: ${MaterialLocalizations.of(conte
  ///
  /// In en, this message translates to:
  /// **'No upcoming reminders. Add a vaccination, medication schedule or daily feeding plan.'**
  String get noUpcomingReminders;

  /// notification_settings_page.dart: ('Open the app regularly to prepare later reminders.')
  ///
  /// In en, this message translates to:
  /// **'Open the app regularly to prepare later reminders.'**
  String get reminderQueueRefreshHint;

  /// notification_settings_page.dart: message: 'Leave without updating the reminder schedule?'
  ///
  /// In en, this message translates to:
  /// **'Leave without updating the reminder schedule?'**
  String get discardReminderSchedule;

  /// reminder_schedule_fields.dart: ('Remind me', style: Theme.of(context).textTheme.titleMedium)
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMe;

  /// reminder_schedule_fields.dart: ('Choose up to 3 reminder days.')
  ///
  /// In en, this message translates to:
  /// **'Choose up to 3 reminder days.'**
  String get reminderDayLimitHint;

  /// reminder_schedule_fields.dart: _days.isEmpty ? 'Select at least one day' : _days.length > VaccinationReminderSchedule.maxReminderDays ? 'Choose up to 3 reminder days' : null
  ///
  /// In en, this message translates to:
  /// **'Select at least one day'**
  String get reminderDayRequired;

  /// reminder_schedule_fields.dart: _days.length > VaccinationReminderSchedule.maxReminderDays ? 'Choose up to 3 reminder days' : null
  ///
  /// In en, this message translates to:
  /// **'Choose up to 3 reminder days'**
  String get reminderDayLimit;

  /// reminder_schedule_fields.dart: day == 0 ? 'Vaccination day' : '$day ${day == 1 ? 'day' : 'days'} before'
  ///
  /// In en, this message translates to:
  /// **'Vaccination day'**
  String get vaccinationDay;

  /// reminder_schedule_fields.dart: labelText: 'Reminder time'
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// reminder_schedule_fields.dart: helperText: '24-hour time on this device.'
  ///
  /// In en, this message translates to:
  /// **'24-hour time on this device.'**
  String get time24DeviceHint;

  /// reminder_schedule_fields.dart: _minute != null ? null : 'Use 00:00–23:59'
  ///
  /// In en, this message translates to:
  /// **'Use 00:00–23:59'**
  String get timeRangeInvalid;

  /// notification_navigation.dart: ('Finish the current form or action to open this reminder.')
  ///
  /// In en, this message translates to:
  /// **'Finish the current form or action to open this reminder.'**
  String get finishFormToOpenReminder;

  /// No description provided for @healthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health records'**
  String get healthRecords;

  /// No description provided for @deleteMeasurementForPetMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove the {weight} kg measurement from {date} for {petName}?'**
  String deleteMeasurementForPetMessage(
    String weight,
    String date,
    String petName,
  );

  /// Care UI: deleteMeasurementMessage. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove the {weight} kg measurement from {date}?'**
  String deleteMeasurementMessage(String weight, String date);

  /// Care UI: deleteMeasurementTooltip. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Delete {weight} kg measurement from {date}'**
  String deleteMeasurementTooltip(String weight, String date);

  /// Care UI: deleteVisitMessage. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove “{reason}” from {date}? Linked medications and their dose records will be kept without this visit link. This cannot be undone.'**
  String deleteVisitMessage(String reason, String date);

  /// Care UI: deleteVaccinationMessage. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove “{name}” from {date}? Any separately planned doses will remain. This cannot be undone.'**
  String deleteVaccinationMessage(String name, String date);

  /// Care UI: deleteVisitTooltip. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Delete visit from {date}: {reason}'**
  String deleteVisitTooltip(String date, String reason);

  /// Care UI: deleteVaccinationTooltip. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} from {date}'**
  String deleteVaccinationTooltip(String name, String date);

  /// Care UI: openVaccination. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Open vaccination: {name}'**
  String openVaccination(String name);

  /// Care UI: diagnosisLimit. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Keep diagnosis within {max} characters'**
  String diagnosisLimit(int max);

  /// Care UI: notesLimit. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Keep notes within {max} characters'**
  String notesLimit(int max);

  /// Care UI: maxCharacters. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Use {max, plural, one{{max} character or fewer.} other{{max} characters or fewer.}}'**
  String maxCharacters(int max);

  /// Care UI: deleteMedicationMessage. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}, all its schedules and dose records?'**
  String deleteMedicationMessage(String name);

  /// Care UI: cancelScheduleResumeMessage. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove these unstarted changes? The previous schedule may continue until its end date or the next change.'**
  String get cancelScheduleResumeMessage;

  /// Care UI: cancelScheduleKeepHistoryMessage. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove these unstarted changes? Earlier dose records will be kept.'**
  String get cancelScheduleKeepHistoryMessage;

  /// Care UI: medicationEveryDays. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Every {days} day} other{Every {days} days}}'**
  String medicationEveryDays(int days);

  /// Care UI: medicationScheduleSummary. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{frequency} · {times}'**
  String medicationScheduleSummary(String frequency, String times);

  /// Care UI: dateRange. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String dateRange(String start, String end);

  /// Care UI: doseCount. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} dose} other{{count} doses}}'**
  String doseCount(int count);

  /// Care UI: doseCountRecorded. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} dose} other{{count} doses}} · {recorded} recorded'**
  String doseCountRecorded(int count, int recorded);

  /// Care UI: startsOn. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String startsOn(String date);

  /// Care UI: endedOn. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String endedOn(String date);

  /// Care UI: scheduleChangeSummary. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'From {date}: {schedule}'**
  String scheduleChangeSummary(String date, String schedule);

  /// Care UI: untilDate. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String untilDate(String date);

  /// Care UI: removeDoseTime. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove {time} dose time'**
  String removeDoseTime(String time);

  /// Care UI: editScheduledChangesNotice. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Editing scheduled changes from {date}. Current usage stays unchanged until then.'**
  String editScheduledChangesNotice(String date);

  /// Care UI: changesFromDate. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Changes from {date}'**
  String changesFromDate(String date);

  /// Care UI: fromDate. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String fromDate(String date);

  /// Care UI: givenAtEdit. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Given at {time} · Edit'**
  String givenAtEdit(String time);

  /// Care UI: doseWithNameAndTime. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{name} · {time} dose'**
  String doseWithNameAndTime(String name, String time);

  /// Care UI: scheduledDoseCount. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{count} scheduled'**
  String scheduledDoseCount(int count);

  /// Care UI: givenDoseCount. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{count} given'**
  String givenDoseCount(int count);

  /// Care UI: skippedDoseCount. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String skippedDoseCount(int count);

  /// Care UI: missingDoseCount. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{count} with no record'**
  String missingDoseCount(int count);

  /// Care UI: calendarDayDescription. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{date}. {status}'**
  String calendarDayDescription(String date, String status);

  /// Care UI: noScheduledDoses. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'No scheduled doses'**
  String get noScheduledDoses;

  /// Care UI: openMedication. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Open medication: {name}'**
  String openMedication(String name);

  /// Care UI: deleteGlobalVisitMessage. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove this visit for {name}? Linked vaccinations and medication schedules will be kept without this link.'**
  String deleteGlobalVisitMessage(String name);

  /// Care UI: deleteGlobalVaccinationMessage. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove this vaccination for {name}? This cannot be undone.'**
  String deleteGlobalVaccinationMessage(String name);

  /// Care UI: deleteNamedRecord. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String deleteNamedRecord(String name);

  /// Care UI: todayWithDate. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String todayWithDate(String date);

  /// Care UI: nextReminder. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Next: {date}, {time}'**
  String nextReminder(String date, String time);

  /// Care UI: queuedReminderSummary. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} reminder queued through {date}.} other{{count} reminders queued through {date}.}}'**
  String queuedReminderSummary(int count, String date);

  /// Care UI: reminderDaysBefore. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{{days} day before} other{{days} days before}}'**
  String reminderDaysBefore(int days);

  /// Care UI: reminderScheduleSummary. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'{days} · {time}'**
  String reminderScheduleSummary(String days, String time);

  /// Care UI: recordAdministrationTitle. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Record administration'**
  String get recordAdministrationTitle;

  /// Care UI: weightLoadFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to load weight history'**
  String get weightLoadFailed;

  /// Care UI: measurementCreateFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to create measurement'**
  String get measurementCreateFailed;

  /// Care UI: measurementUpdateFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to update measurement'**
  String get measurementUpdateFailed;

  /// Care UI: measurementDeleteFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete measurement'**
  String get measurementDeleteFailed;

  /// Care UI: measurementNotFound. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Measurement not found'**
  String get measurementNotFound;

  /// Care UI: visitsLoadFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to load vet visits'**
  String get visitsLoadFailed;

  /// Care UI: visitLoadFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to load vet visit'**
  String get visitLoadFailed;

  /// Care UI: visitNotFound. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Vet visit not found'**
  String get visitNotFound;

  /// Care UI: visitCreateFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to create vet visit'**
  String get visitCreateFailed;

  /// Care UI: visitUpdateFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to update vet visit'**
  String get visitUpdateFailed;

  /// Care UI: visitDeleteFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete vet visit'**
  String get visitDeleteFailed;

  /// Care UI: suggestionsLoadFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to load suggestions'**
  String get suggestionsLoadFailed;

  /// Care UI: vaccinationsLoadFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to load vaccinations'**
  String get vaccinationsLoadFailed;

  /// Care UI: vaccinationLoadFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to load vaccination'**
  String get vaccinationLoadFailed;

  /// Care UI: vaccinationNotFound. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Vaccination not found'**
  String get vaccinationNotFound;

  /// Care UI: vaccinationCreateFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to create vaccination'**
  String get vaccinationCreateFailed;

  /// Care UI: vaccinationUpdateFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to update vaccination'**
  String get vaccinationUpdateFailed;

  /// Care UI: vaccinationDeleteFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete vaccination'**
  String get vaccinationDeleteFailed;

  /// Care UI: medicationsLoadFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to load medications'**
  String get medicationsLoadFailed;

  /// Care UI: medicationNotFound. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Medication record not found'**
  String get medicationNotFound;

  /// Care UI: medicationSaveFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to save medication'**
  String get medicationSaveFailed;

  /// Care UI: medicationDeleteFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete medication'**
  String get medicationDeleteFailed;

  /// Care UI: scheduleDeleteFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel scheduled changes'**
  String get scheduleDeleteFailed;

  /// Care UI: doseLoadFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dose records'**
  String get doseLoadFailed;

  /// Care UI: doseSaveFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to save dose record'**
  String get doseSaveFailed;

  /// Care UI: doseClearFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear dose record'**
  String get doseClearFailed;

  /// Care UI: periodCheckFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to check dose history'**
  String get periodCheckFailed;

  /// Care UI: petNamesRefreshFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Pet names could not be refreshed.'**
  String get petNamesRefreshFailed;

  /// Care UI: remindersInitializeFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize reminders'**
  String get remindersInitializeFailed;

  /// Care UI: remindersSyncFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to update reminders'**
  String get remindersSyncFailed;

  /// Care UI: notificationPermissionFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to request notification permission'**
  String get notificationPermissionFailed;

  /// Care UI: exactPermissionFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to request precise reminder permission'**
  String get exactPermissionFailed;

  /// Care UI: deviceSettingsFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to open device settings'**
  String get deviceSettingsFailed;

  /// Care UI: reminderSettingsSaveFailed. User content and formatted values are passed unchanged.
  ///
  /// In en, this message translates to:
  /// **'Failed to save reminder settings'**
  String get reminderSettingsSaveFailed;

  /// A dose result panel could not save or clear a result. The draft is retained.
  ///
  /// In en, this message translates to:
  /// **'Failed to update dose record'**
  String get doseUpdateFailed;

  /// A reminder points to a removed record or a dose that is no longer scheduled. Opening does not record a dose.
  ///
  /// In en, this message translates to:
  /// **'This reminder’s record is no longer available.'**
  String get reminderTargetUnavailable;

  /// Reminder title. Pet and clinical record names are user content, never translated.
  ///
  /// In en, this message translates to:
  /// **'{petName} · {recordName}'**
  String notificationTitle(String petName, String recordName);

  /// Medication reminder with a local 24-hour scheduled time.
  ///
  /// In en, this message translates to:
  /// **'Scheduled dose · {time}'**
  String notificationDoseBody(String time);

  /// Medication reminder with user-entered instructions, preserved verbatim.
  ///
  /// In en, this message translates to:
  /// **'{time} · {instructions}'**
  String notificationDoseInstructions(String time, String instructions);

  /// Vaccination reminder. The due calendar day is formatted using the effective regional locale.
  ///
  /// In en, this message translates to:
  /// **'Vaccination planned for {date}.'**
  String notificationVaccinationBody(String date);

  /// Android medication notification channel description in system settings.
  ///
  /// In en, this message translates to:
  /// **'Scheduled medication doses'**
  String get medicationChannelDescription;

  /// Android vaccination notification channel description in system settings.
  ///
  /// In en, this message translates to:
  /// **'Planned vaccination reminders'**
  String get vaccinationChannelDescription;

  /// A reminder target could not be loaded; Retry is available.
  ///
  /// In en, this message translates to:
  /// **'Failed to open reminder'**
  String get reminderOpenFailed;

  /// No description provided for @feeding.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get feeding;

  /// No description provided for @addFeeding.
  ///
  /// In en, this message translates to:
  /// **'Log feeding'**
  String get addFeeding;

  /// No description provided for @editFeeding.
  ///
  /// In en, this message translates to:
  /// **'Edit feeding'**
  String get editFeeding;

  /// No description provided for @feedingRecord.
  ///
  /// In en, this message translates to:
  /// **'Feeding record'**
  String get feedingRecord;

  /// No description provided for @feedingPlan.
  ///
  /// In en, this message translates to:
  /// **'Daily plan'**
  String get feedingPlan;

  /// No description provided for @dailyMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get dailyMeals;

  /// No description provided for @feedingTrend.
  ///
  /// In en, this message translates to:
  /// **'Daily food offered'**
  String get feedingTrend;

  /// No description provided for @foodOptional.
  ///
  /// In en, this message translates to:
  /// **'Food name (optional)'**
  String get foodOptional;

  /// No description provided for @foodNameLimit.
  ///
  /// In en, this message translates to:
  /// **'Keep the food name within 50 characters'**
  String get foodNameLimit;

  /// No description provided for @feedingAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a gram amount greater than zero'**
  String get feedingAmountInvalid;

  /// No description provided for @feedingPrecision.
  ///
  /// In en, this message translates to:
  /// **'Use at most one decimal place'**
  String get feedingPrecision;

  /// No description provided for @feedingNoMeals.
  ///
  /// In en, this message translates to:
  /// **'No meals planned'**
  String get feedingNoMeals;

  /// No description provided for @feedingNoMealsDescription.
  ///
  /// In en, this message translates to:
  /// **'Log food whenever you offer it, or set up a daily plan.'**
  String get feedingNoMealsDescription;

  /// No description provided for @feedingNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No feeding records'**
  String get feedingNoRecords;

  /// No description provided for @feedingNoRecordsDescription.
  ///
  /// In en, this message translates to:
  /// **'Recorded food amounts will appear here.'**
  String get feedingNoRecordsDescription;

  /// No description provided for @feedingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load feeding records'**
  String get feedingLoadFailed;

  /// No description provided for @feedingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save feeding record'**
  String get feedingSaveFailed;

  /// No description provided for @feedingDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete feeding record'**
  String get feedingDeleteFailed;

  /// No description provided for @feedingPlanSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save feeding plan'**
  String get feedingPlanSaveFailed;

  /// No description provided for @feedingPlanCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel feeding plan'**
  String get feedingPlanCancelFailed;

  /// No description provided for @feedingRecordNotFound.
  ///
  /// In en, this message translates to:
  /// **'This feeding record is no longer available.'**
  String get feedingRecordNotFound;

  /// No description provided for @feedingPlanNotFound.
  ///
  /// In en, this message translates to:
  /// **'This feeding plan is no longer available.'**
  String get feedingPlanNotFound;

  /// No description provided for @feedingDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete feeding record?'**
  String get feedingDeleteTitle;

  /// No description provided for @feedingDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the recorded amount. A linked meal will return to No record.'**
  String get feedingDeleteMessage;

  /// No description provided for @feedingCancelPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel scheduled plan?'**
  String get feedingCancelPlanTitle;

  /// No description provided for @feedingCancelPlanMessage.
  ///
  /// In en, this message translates to:
  /// **'The previous plan may continue until its end date. Recorded feedings stay unchanged.'**
  String get feedingCancelPlanMessage;

  /// No description provided for @feedingCancelFirstPlanMessage.
  ///
  /// In en, this message translates to:
  /// **'These meals will be removed from the plan. Recorded feedings stay unchanged.'**
  String get feedingCancelFirstPlanMessage;

  /// No description provided for @feedingFirstPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Your first plan can start today or later.'**
  String get feedingFirstPlanHint;

  /// No description provided for @feedingChangesHint.
  ///
  /// In en, this message translates to:
  /// **'Changes start tomorrow or later. Earlier feeding records stay unchanged.'**
  String get feedingChangesHint;

  /// No description provided for @feedingPlanEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'A plan is optional. Add meal times and amounts for quicker daily tracking.'**
  String get feedingPlanEmptyMessage;

  /// No description provided for @createFeedingPlan.
  ///
  /// In en, this message translates to:
  /// **'Create plan'**
  String get createFeedingPlan;

  /// No description provided for @editFeedingPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get editFeedingPlan;

  /// No description provided for @endFeedingPlan.
  ///
  /// In en, this message translates to:
  /// **'Set end date'**
  String get endFeedingPlan;

  /// No description provided for @feedingPlanEndHint.
  ///
  /// In en, this message translates to:
  /// **'This plan has started. Keep its meals unchanged and choose an end date.'**
  String get feedingPlanEndHint;

  /// No description provided for @feedingGiven.
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get feedingGiven;

  /// No description provided for @feedingChartSelectPet.
  ///
  /// In en, this message translates to:
  /// **'Select a pet above to see its daily feeding chart.'**
  String get feedingChartSelectPet;

  /// No description provided for @addMeal.
  ///
  /// In en, this message translates to:
  /// **'Add meal'**
  String get addMeal;

  /// No description provided for @feedingDuplicateTime.
  ///
  /// In en, this message translates to:
  /// **'Each meal needs a different time'**
  String get feedingDuplicateTime;

  /// No description provided for @feedingEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End date cannot be before the start date'**
  String get feedingEndBeforeStart;

  /// No description provided for @feedingMealTime.
  ///
  /// In en, this message translates to:
  /// **'Meal time'**
  String get feedingMealTime;

  /// No description provided for @feedingDate.
  ///
  /// In en, this message translates to:
  /// **'Feeding date'**
  String get feedingDate;

  /// No description provided for @feedingTime.
  ///
  /// In en, this message translates to:
  /// **'Feeding time'**
  String get feedingTime;

  /// No description provided for @feedingNotes.
  ///
  /// In en, this message translates to:
  /// **'Food & notes (optional)'**
  String get feedingNotes;

  /// No description provided for @feedingPlanLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading plan…'**
  String get feedingPlanLoading;

  /// No description provided for @feedingPlanReview.
  ///
  /// In en, this message translates to:
  /// **'Review the meal times and amounts before saving.'**
  String get feedingPlanReview;

  /// No description provided for @feedingRecordReview.
  ///
  /// In en, this message translates to:
  /// **'Review the amount and actual feeding time.'**
  String get feedingRecordReview;

  /// No description provided for @feedingPlanDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid start date'**
  String get feedingPlanDateRequired;

  /// No description provided for @feedingChartHint.
  ///
  /// In en, this message translates to:
  /// **'Amounts offered, not amounts eaten. Days without a record have no bar.'**
  String get feedingChartHint;

  /// Feeding UI; user text and formatted values remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'{amount} g'**
  String feedingGrams(String amount);

  /// No description provided for @recordMeal.
  ///
  /// In en, this message translates to:
  /// **'Record meal'**
  String get recordMeal;

  /// Feeding UI; user text and formatted values remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Meal {number}'**
  String feedingMealNumber(int number);

  /// Feeding UI; user text and formatted values remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Remove meal {number}'**
  String removeFeedingMeal(int number);

  /// Feeding UI; user text and formatted values remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String feedingDays(int count);

  /// No description provided for @feedingPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get feedingPlans;

  /// No description provided for @feedingAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get feedingAmount;

  /// No description provided for @feedingEditEndDate.
  ///
  /// In en, this message translates to:
  /// **'Edit end date'**
  String get feedingEditEndDate;

  /// No description provided for @feedingExtraRecords.
  ///
  /// In en, this message translates to:
  /// **'Other feedings'**
  String get feedingExtraRecords;

  /// No description provided for @feedingRecordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} record} other{{count} records}}'**
  String feedingRecordsCount(int count);

  /// No description provided for @feedingReminders.
  ///
  /// In en, this message translates to:
  /// **'Feeding reminders'**
  String get feedingReminders;

  /// No description provided for @feedingReminderHint.
  ///
  /// In en, this message translates to:
  /// **'At the meal times in each daily plan.'**
  String get feedingReminderHint;

  /// No description provided for @feedingChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Scheduled feeding times'**
  String get feedingChannelDescription;

  /// No description provided for @notificationFeedingBody.
  ///
  /// In en, this message translates to:
  /// **'Offer {amount} g at {time}.'**
  String notificationFeedingBody(String amount, String time);

  /// No description provided for @notificationFeedingFoodBody.
  ///
  /// In en, this message translates to:
  /// **'Offer {amount} g of {food} at {time}.'**
  String notificationFeedingFoodBody(String amount, String food, String time);

  /// Feeding UI; user text and formatted values remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'{date} · {amount} g'**
  String feedingEntrySummary(String date, String amount);
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
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
