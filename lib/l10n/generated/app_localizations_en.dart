// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersDescription =>
      'Medication doses and planned vaccinations';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get followDeviceSettings => 'Follow device settings';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get followDeviceLanguage => 'Follow device language';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get loadingSettings => 'Loading settings';

  @override
  String get savingSettings => 'Saving settings';

  @override
  String get retry => 'Retry';

  @override
  String get themeLoadFailed => 'Failed to load theme preference';

  @override
  String get languageLoadFailed => 'Failed to load language preference';

  @override
  String get settingsLoadFailed => 'Failed to load settings';

  @override
  String get themeSaveFailed => 'Failed to save theme preference';

  @override
  String get languageSaveFailed => 'Failed to save language preference';

  @override
  String get cancel => 'Cancel';

  @override
  String get edit => 'Edit';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get continueAction => 'Continue';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get saving => 'Saving…';

  @override
  String get notProvided => 'Not provided';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get hideKeyboard => 'Hide keyboard';

  @override
  String get reviewChanges => 'Review changes';

  @override
  String formStep(int current, int total, String title) {
    return 'Step $current of $total · $title';
  }

  @override
  String get currentFormStep => 'Current form step';

  @override
  String chooseDateField(String field) {
    return '$field: choose date';
  }

  @override
  String clearDateField(String field) {
    return '$field: clear date';
  }

  @override
  String get myPets => 'My pets';

  @override
  String get profile => 'Profile';

  @override
  String get vetVisits => 'Vet visits';

  @override
  String get vetVisitsNavigation => 'Vet visits';

  @override
  String get vaccinations => 'Vaccinations';

  @override
  String get medications => 'Medications';

  @override
  String get weightHistory => 'Weight history';

  @override
  String get clinic => 'Clinic';

  @override
  String get veterinarian => 'Veterinarian';

  @override
  String get petProfile => 'Pet profile';

  @override
  String get profileDetails => 'Profile details';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get deletePet => 'Delete pet';

  @override
  String get deletePetTitle => 'Delete pet?';

  @override
  String deletePetMessage(String name) {
    return '$name’s profile, photo, weight history, vet visits, vaccinations, medications and dose records will be removed. This cannot be undone.';
  }

  @override
  String get deleteAction => 'Delete';

  @override
  String get retryDeletion => 'Retry deletion';

  @override
  String get retryProfile => 'Retry profile';

  @override
  String get petNotFound => 'Pet not found';

  @override
  String get petLoadFailed => 'Failed to get pet';

  @override
  String get petsLoadFailed => 'Failed to get pets';

  @override
  String get petCreateFailed => 'Failed to create pet';

  @override
  String get petUpdateFailed => 'Failed to update pet';

  @override
  String get petDeleteFailed => 'Failed to delete pet';

  @override
  String get petRefreshFailed => 'Failed to refresh pet';

  @override
  String get photoSaveFailed => 'Failed to save new image';

  @override
  String get addPet => 'Add pet';

  @override
  String get editPet => 'Edit pet';

  @override
  String get petStep => 'Pet';

  @override
  String get review => 'Review';

  @override
  String get reviewPet => 'Review pet';

  @override
  String get basicDetails => 'Basic details';

  @override
  String get petName => 'Name';

  @override
  String get petNameRequired => 'Name is required';

  @override
  String petNameTooLong(int max) {
    return 'Keep name within $max characters';
  }

  @override
  String get species => 'Species';

  @override
  String get sex => 'Sex';

  @override
  String get breed => 'Breed';

  @override
  String get breedOptional => 'Breed (optional)';

  @override
  String get reproductiveStatus => 'Reproductive status';

  @override
  String get birthDate => 'Birth date';

  @override
  String get birthDateOptional => 'Birth date (optional)';

  @override
  String get currentWeight => 'Current weight';

  @override
  String get weightOptional => 'Weight (optional)';

  @override
  String get weightInvalid => 'Enter a valid weight';

  @override
  String get weightPositive => 'Weight must be greater than 0';

  @override
  String weightPrecision(int max) {
    return 'Use up to $max decimal places';
  }

  @override
  String get identification => 'Identification';

  @override
  String get microchipId => 'Microchip ID';

  @override
  String get microchipIdOptional => 'Microchip ID (optional)';

  @override
  String get healthIdentificationOptional =>
      'Health & identification (optional)';

  @override
  String get addPetPhoto => 'Add pet photo';

  @override
  String get changePetPhoto => 'Change pet photo';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get photoAccessDenied =>
      'Photo access was denied. Allow access in Settings and try again.';

  @override
  String get photoSelectFailed => 'Could not select a photo. Please try again.';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage =>
      'Your changes have not been saved. Leave without saving?';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get speciesDog => 'Dog';

  @override
  String get speciesCat => 'Cat';

  @override
  String get speciesBird => 'Bird';

  @override
  String get speciesOther => 'Other';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get unknown => 'Unknown';

  @override
  String get reproductiveIntact => 'Intact';

  @override
  String get reproductiveSterilized => 'Sterilized';

  @override
  String get noPetsYet => 'No pets yet';

  @override
  String get petsEmptyDescription =>
      'Add your first pet to start tracking health and care.';

  @override
  String get choosePetOverview =>
      'Choose a pet to view its profile and care overview.';

  @override
  String get addVisit => 'Add visit';

  @override
  String get addVaccination => 'Add vaccination';

  @override
  String get addMedication => 'Add medication';

  @override
  String get choosePet => 'Choose a pet';

  @override
  String get close => 'Close';

  @override
  String get loadingSuggestions => 'Loading suggestions';

  @override
  String get weight => 'Weight';

  @override
  String get save => 'Save';

  @override
  String get measurement => 'Measurement';

  @override
  String get deleteMeasurementTitle => 'Delete measurement?';

  @override
  String get updatingMeasurements => 'Updating measurements';

  @override
  String get addMeasurement => 'Add measurement';

  @override
  String get noMeasurements => 'No measurements yet';

  @override
  String get measurementsEmpty =>
      'Add a weight measurement to start the history.';

  @override
  String get latestWeight => 'Latest weight';

  @override
  String get measurements => 'Measurements';

  @override
  String get measurementsOrderHint =>
      'Newest first. Select a measurement to edit it.';

  @override
  String get deletingMeasurement => 'Deleting measurement';

  @override
  String get weightRequired => 'Weight is required';

  @override
  String get weightGreaterThanZero => 'Enter a weight greater than zero';

  @override
  String get weightThreeDecimals => 'Use up to 3 decimal places';

  @override
  String get measurementDate => 'Measurement date';

  @override
  String get editMeasurement => 'Edit measurement';

  @override
  String get reviewMeasurement => 'Review measurement';

  @override
  String get deleteVisitTitle => 'Delete visit?';

  @override
  String get visitReason => 'Reason for visit';

  @override
  String get visitReasonSummary => 'Visit reason';

  @override
  String get visitReasonRequired => 'Enter a reason for the visit';

  @override
  String get visitReasonLimit => 'Keep reason within 100 characters';

  @override
  String get visitDate => 'Visit date';

  @override
  String get linkedVaccinationDateNotice =>
      'Dates of any linked vaccinations will also change.';

  @override
  String get reviewVisit => 'Review visit';

  @override
  String get visitDetails => 'Visit details';

  @override
  String get clinicalOptional => 'Clinic & veterinarian (optional)';

  @override
  String get clinicOptional => 'Clinic (optional)';

  @override
  String get veterinarianOptional => 'Veterinarian (optional)';

  @override
  String get retrySuggestions => 'Retry suggestions';

  @override
  String get medicalNotesOptional => 'Medical notes (optional)';

  @override
  String get diagnosisOptional => 'Diagnosis (optional)';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get notesLimit200 => 'Keep notes within 200 characters';

  @override
  String get costOptional => 'Cost (optional)';

  @override
  String get amountOptional => 'Amount (optional)';

  @override
  String get costInvalid => 'Enter a valid amount with up to 2 decimal places';

  @override
  String get currency => 'Currency';

  @override
  String get editVisit => 'Edit visit';

  @override
  String get visit => 'Visit';

  @override
  String get vetVisit => 'Vet visit';

  @override
  String get deletingVisit => 'Deleting visit';

  @override
  String get refreshingVisit => 'Refreshing visit';

  @override
  String get deleteVisit => 'Delete visit';

  @override
  String get clinical => 'Clinic & veterinarian';

  @override
  String get medicalNotes => 'Medical notes';

  @override
  String get diagnosis => 'Diagnosis';

  @override
  String get notes => 'Notes';

  @override
  String get cost => 'Cost';

  @override
  String get amount => 'Amount';

  @override
  String get updatingVisits => 'Updating visits';

  @override
  String get noVisits => 'No visits yet';

  @override
  String get visitsEmpty =>
      'Add a completed visit to keep the details together.';

  @override
  String get linkedVaccinations => 'Linked vaccinations';

  @override
  String get retryVaccinations => 'Retry vaccinations';

  @override
  String get noLinkedVaccinations => 'No vaccinations linked to this visit.';

  @override
  String get loadingLinkedVaccinations => 'Loading linked vaccinations';

  @override
  String get deleteVaccinationTitle => 'Delete vaccination?';

  @override
  String get vetVisitOptional => 'Vet visit (optional)';

  @override
  String get noLinkedVisit => 'No linked visit';

  @override
  String get linkedVisitUnavailable => 'Linked visit unavailable';

  @override
  String get loadingVisits => 'Loading visits';

  @override
  String get retryVisits => 'Retry visits';

  @override
  String get vaccineName => 'Vaccine name';

  @override
  String get vaccineNameRequired => 'Enter a vaccine name';

  @override
  String get vaccineNameLimit => 'Keep vaccine name within 50 characters';

  @override
  String get status => 'Status';

  @override
  String get administered => 'Administered';

  @override
  String get planned => 'Planned';

  @override
  String get dateTodayOrFuture => 'Choose today or a future date';

  @override
  String get dateTodayOrPast => 'Choose today or an earlier date';

  @override
  String get plannedDate => 'Planned date';

  @override
  String get administrationDate => 'Administration date';

  @override
  String get dateFromLinkedVisit => 'Date from linked vet visit';

  @override
  String get reviewVaccination => 'Review vaccination';

  @override
  String get vaccineDetails => 'Vaccine details';

  @override
  String get nextDoseOptional => 'Next dose (optional)';

  @override
  String get separateNextDoseHint =>
      'Optionally create a separate plan for the next dose.';

  @override
  String get dateAfterAdministration =>
      'Choose a date after the administration date';

  @override
  String get nextDoseDateOptional => 'Next dose date (optional)';

  @override
  String get remindersSettingsGuidance =>
      'Reminders are managed in Settings → Notifications.';

  @override
  String get recordAdministration => 'Record administration';

  @override
  String get editVaccination => 'Edit vaccination';

  @override
  String get vaccination => 'Vaccination';

  @override
  String get vaccine => 'Vaccine';

  @override
  String get deletingVaccination => 'Deleting vaccination';

  @override
  String get refreshingVaccination => 'Refreshing vaccination';

  @override
  String get deleteVaccination => 'Delete vaccination';

  @override
  String get noVaccinations => 'No vaccinations yet';

  @override
  String get vaccinationsEmpty =>
      'Record an administered vaccine or plan an upcoming dose.';

  @override
  String get history => 'History';

  @override
  String get updatingVaccinations => 'Updating vaccinations';

  @override
  String get linkedVetVisit => 'Linked vet visit';

  @override
  String get retryVisit => 'Retry visit';

  @override
  String get openVetVisit => 'Open vet visit';

  @override
  String get loadingLinkedVisit => 'Loading linked vet visit';

  @override
  String get overdue => 'Overdue';

  @override
  String get dueToday => 'Due today';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get deleteMedicationTitle => 'Delete medication?';

  @override
  String get cancelScheduledChangesTitle => 'Cancel scheduled changes?';

  @override
  String get clearDoseRecordTitle => 'Clear dose record?';

  @override
  String get clearDoseRecordMessage =>
      'This dose will return to No record. The scheduled dose stays in the plan.';

  @override
  String get clearRecord => 'Clear record';

  @override
  String get cancelChanges => 'Cancel changes';

  @override
  String get daily => 'Daily';

  @override
  String get noEndDate => 'No end date';

  @override
  String get previousDay => 'Previous day';

  @override
  String get today => 'Today';

  @override
  String get nextDay => 'Next day';

  @override
  String get backToToday => 'Back to today';

  @override
  String get retryDoseRecords => 'Retry dose records';

  @override
  String get noDoses => 'No doses scheduled';

  @override
  String get noDosesForDay => 'There are no scheduled doses for this day.';

  @override
  String get viewMedications => 'View medications';

  @override
  String get active => 'Active';

  @override
  String get updatingMedications => 'Updating medications';

  @override
  String get retryAction => 'Retry action';

  @override
  String get doses => 'Doses';

  @override
  String get noMedications => 'No medications yet';

  @override
  String get medicationsEmpty =>
      'Add a medication and its schedule to start dose tracking.';

  @override
  String get reopenVisitSection =>
      'Open this section again to refresh the visit.';

  @override
  String get dosageInstructions => 'Dosage instructions';

  @override
  String get oneDay => 'One day';

  @override
  String get editChange => 'Edit change';

  @override
  String get cancelChange => 'Cancel change';

  @override
  String get schedule => 'Schedule';

  @override
  String get editDetails => 'Edit details';

  @override
  String get completed => 'Completed';

  @override
  String get editMedication => 'Edit medication';

  @override
  String get scheduleAgain => 'Schedule doses again';

  @override
  String get clinicAndNotes => 'Clinic & notes';

  @override
  String get hideDoseCalendar => 'Hide dose calendar';

  @override
  String get doseCalendar => 'Dose calendar';

  @override
  String get previousSchedules => 'Previous schedules';

  @override
  String get medication => 'Medication';

  @override
  String get deleteMedication => 'Delete medication';

  @override
  String get medicationNameRequired => 'Enter a medication name.';

  @override
  String get doseTimeInvalid => 'Use HH:mm, from 00:00 to 23:59.';

  @override
  String get uniqueDoseTimes => 'Each time must be different.';

  @override
  String get doseTimeRequired => 'Add at least one dose time.';

  @override
  String get periodEndInvalid => 'End date must be on or after the start date.';

  @override
  String get whichMedication => 'Which medication?';

  @override
  String get medicationName => 'Medication name';

  @override
  String get dosageInstructionsOptional => 'Dosage instructions (optional)';

  @override
  String get dosageExample => 'e.g. half a tablet';

  @override
  String get doseScheduleQuestion => 'When are the doses?';

  @override
  String get previousScheduleReadOnly =>
      'This previous schedule is read-only. You can still correct its clinic information and notes.';

  @override
  String get newScheduleEffectiveHint =>
      'Schedule changes start tomorrow or later. Earlier dose records stay unchanged.';

  @override
  String get changesStart => 'Changes start';

  @override
  String get startDate => 'Start date';

  @override
  String get frequency => 'Frequency';

  @override
  String get everyNDays => 'Every N days';

  @override
  String get daysBetweenDoses => 'Days between doses';

  @override
  String get intervalRequired => 'Enter at least 1 day.';

  @override
  String get doseTime => 'Dose time';

  @override
  String get timeFormatHint => 'HH:mm';

  @override
  String get addAnotherTime => 'Add another time';

  @override
  String get endDateOptional => 'End date (optional)';

  @override
  String get reviewMedication => 'Review medication';

  @override
  String get preserveEarlierDoseRecords =>
      'Earlier dose records stay unchanged.';

  @override
  String get clinicalNotesOptional => 'Clinic & notes (optional)';

  @override
  String get scheduleDoses => 'Schedule doses';

  @override
  String get retryDoseHistory => 'Retry dose history';

  @override
  String get checkingDoseHistory => 'Checking dose history';

  @override
  String get loadingDoseRecord => 'Loading dose record…';

  @override
  String get doseRecordUnavailable => 'Dose record unavailable';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get skippedEdit => 'Skipped · Edit';

  @override
  String get skipDose => 'Skip';

  @override
  String get doseGiven => 'Given';

  @override
  String get noDoseRecord => 'No record';

  @override
  String get recordDose => 'Record dose';

  @override
  String get unsavedDoseRecord =>
      'Your dose record changes have not been saved.';

  @override
  String get editDoseRecord => 'Edit dose record';

  @override
  String get doseSkipped => 'Skipped';

  @override
  String get givenAt => 'Given at';

  @override
  String get time24Hint => 'HH:mm · 24-hour';

  @override
  String get givenTimeFuture => 'Given time cannot be in the future.';

  @override
  String get doseNoLongerAvailable =>
      'This dose is not available for changes. Close and refresh the selected day.';

  @override
  String get doseRecordsUnavailable => 'Dose records unavailable';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get goToToday => 'Go to today';

  @override
  String get loadingMonthRecords => 'Loading month records';

  @override
  String get retryCalendar => 'Retry calendar';

  @override
  String get noCalendarDayDoses => 'No doses scheduled for this day.';

  @override
  String get linkedMedications => 'Linked medications';

  @override
  String get retryMedications => 'Retry medications';

  @override
  String get noLinkedMedications => 'No medications linked to this visit.';

  @override
  String get deleteVetVisitTitle => 'Delete vet visit?';

  @override
  String get allPets => 'All pets';

  @override
  String get allPetsNoDayDoses =>
      'There are no scheduled doses for this day. View Medications to manage schedules.';

  @override
  String get noVetVisits => 'No vet visits yet';

  @override
  String get allVisitsEmpty =>
      'Keep a record of checkups and treatment for your pets.';

  @override
  String get retryPets => 'Retry pets';

  @override
  String get retryDoseRecord => 'Retry dose record';

  @override
  String get updatingCareRecords => 'Updating care records';

  @override
  String get petUnavailable => 'Pet unavailable';

  @override
  String get deletingRecord => 'Deleting record';

  @override
  String get updatingReminders => 'Updating reminders';

  @override
  String get retrySave => 'Retry save';

  @override
  String get remindersDeviceHint =>
      'Choose which reminders this device sends. Times follow the device’s local time.';

  @override
  String get medicationReminders => 'Medication reminders';

  @override
  String get medicationReminderHint => 'At scheduled dose times.';

  @override
  String get vaccinationReminders => 'Vaccination reminders';

  @override
  String get vaccinationReminderHint => 'On selected days.';

  @override
  String get vaccinationSchedule => 'Vaccination schedule';

  @override
  String get daysAndTime => 'Days & time';

  @override
  String get loadingSchedule => 'Loading schedule…';

  @override
  String get scheduleUnavailable => 'Schedule unavailable';

  @override
  String get sharedVaccinationScheduleHint =>
      'These days and time apply to all planned vaccinations.';

  @override
  String get notificationsBlocked => 'Notifications are blocked';

  @override
  String get preciseRemindersOff => 'Precise timing is off';

  @override
  String get allowNotificationsHint =>
      'Allow notifications on this device to receive reminders.';

  @override
  String get inexactRemindersHint =>
      'Medication reminders use normal scheduling and may arrive late.';

  @override
  String get allowNotifications => 'Allow notifications';

  @override
  String get allowPreciseReminders => 'Allow precise reminders';

  @override
  String get openDeviceSettings => 'Open device settings';

  @override
  String get upcomingReminders => 'Upcoming reminders';

  @override
  String get updatingRemindersEllipsis => 'Updating reminders…';

  @override
  String get noUpcomingReminders =>
      'No upcoming reminders. Add a planned vaccination or a medication schedule.';

  @override
  String get reminderQueueRefreshHint =>
      'Open the app regularly to prepare later reminders.';

  @override
  String get discardReminderSchedule =>
      'Leave without updating the reminder schedule?';

  @override
  String get remindMe => 'Remind me';

  @override
  String get reminderDayLimitHint => 'Choose up to 3 reminder days.';

  @override
  String get reminderDayRequired => 'Select at least one day';

  @override
  String get reminderDayLimit => 'Choose up to 3 reminder days';

  @override
  String get vaccinationDay => 'Vaccination day';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get time24DeviceHint => '24-hour time on this device.';

  @override
  String get timeRangeInvalid => 'Use 00:00–23:59';

  @override
  String get finishFormToOpenReminder =>
      'Finish the current form or action to open this reminder.';

  @override
  String deleteMeasurementMessage(String weight, String date) {
    return 'Remove the $weight kg measurement from $date?';
  }

  @override
  String deleteMeasurementTooltip(String weight, String date) {
    return 'Delete $weight kg measurement from $date';
  }

  @override
  String deleteVisitMessage(String reason, String date) {
    return 'Remove “$reason” from $date? Linked medications and their dose records will be kept without this visit link. This cannot be undone.';
  }

  @override
  String deleteVaccinationMessage(String name, String date) {
    return 'Remove “$name” from $date? Any separately planned doses will remain. This cannot be undone.';
  }

  @override
  String deleteVisitTooltip(String date, String reason) {
    return 'Delete visit from $date: $reason';
  }

  @override
  String deleteVaccinationTooltip(String name, String date) {
    return 'Delete $name from $date';
  }

  @override
  String openVaccination(String name) {
    return 'Open vaccination: $name';
  }

  @override
  String diagnosisLimit(int max) {
    return 'Keep diagnosis within $max characters';
  }

  @override
  String notesLimit(int max) {
    return 'Keep notes within $max characters';
  }

  @override
  String maxCharacters(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters or fewer.',
      one: '$max character or fewer.',
    );
    return 'Use $_temp0';
  }

  @override
  String deleteMedicationMessage(String name) {
    return 'Delete $name, all its schedules and dose records?';
  }

  @override
  String get cancelScheduleResumeMessage =>
      'Remove these unstarted changes? The previous schedule may continue until its end date or the next change.';

  @override
  String get cancelScheduleKeepHistoryMessage =>
      'Remove these unstarted changes? Earlier dose records will be kept.';

  @override
  String medicationEveryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Every $days days',
      one: 'Every $days day',
    );
    return '$_temp0';
  }

  @override
  String medicationScheduleSummary(String frequency, String times) {
    return '$frequency · $times';
  }

  @override
  String dateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String doseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses',
      one: '$count dose',
    );
    return '$_temp0';
  }

  @override
  String doseCountRecorded(int count, int recorded) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses',
      one: '$count dose',
    );
    return '$_temp0 · $recorded recorded';
  }

  @override
  String startsOn(String date) {
    return 'Starts $date';
  }

  @override
  String endedOn(String date) {
    return 'Ended $date';
  }

  @override
  String scheduleChangeSummary(String date, String schedule) {
    return 'From $date: $schedule';
  }

  @override
  String untilDate(String date) {
    return 'Until $date';
  }

  @override
  String removeDoseTime(String time) {
    return 'Remove $time dose time';
  }

  @override
  String editScheduledChangesNotice(String date) {
    return 'Editing scheduled changes from $date. Current usage stays unchanged until then.';
  }

  @override
  String changesFromDate(String date) {
    return 'Changes from $date';
  }

  @override
  String fromDate(String date) {
    return 'From $date';
  }

  @override
  String givenAtEdit(String time) {
    return 'Given at $time · Edit';
  }

  @override
  String doseWithNameAndTime(String name, String time) {
    return '$name · $time dose';
  }

  @override
  String scheduledDoseCount(int count) {
    return '$count scheduled';
  }

  @override
  String givenDoseCount(int count) {
    return '$count given';
  }

  @override
  String skippedDoseCount(int count) {
    return '$count skipped';
  }

  @override
  String missingDoseCount(int count) {
    return '$count with no record';
  }

  @override
  String calendarDayDescription(String date, String status) {
    return '$date. $status';
  }

  @override
  String get noScheduledDoses => 'No scheduled doses';

  @override
  String openMedication(String name) {
    return 'Open medication: $name';
  }

  @override
  String deleteGlobalVisitMessage(String name) {
    return 'Remove this visit for $name? Linked vaccinations and medication schedules will be kept without this link.';
  }

  @override
  String deleteGlobalVaccinationMessage(String name) {
    return 'Remove this vaccination for $name? This cannot be undone.';
  }

  @override
  String deleteNamedRecord(String name) {
    return 'Delete $name';
  }

  @override
  String todayWithDate(String date) {
    return 'Today · $date';
  }

  @override
  String nextReminder(String date, String time) {
    return 'Next: $date, $time';
  }

  @override
  String queuedReminderSummary(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders queued through $date.',
      one: '$count reminder queued through $date.',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: '$days day before',
    );
    return '$_temp0';
  }

  @override
  String reminderScheduleSummary(String days, String time) {
    return '$days · $time';
  }

  @override
  String get recordAdministrationTitle => 'Record administration';

  @override
  String get weightLoadFailed => 'Failed to load weight history';

  @override
  String get measurementCreateFailed => 'Failed to create measurement';

  @override
  String get measurementUpdateFailed => 'Failed to update measurement';

  @override
  String get measurementDeleteFailed => 'Failed to delete measurement';

  @override
  String get measurementNotFound => 'Measurement not found';

  @override
  String get visitsLoadFailed => 'Failed to load vet visits';

  @override
  String get visitLoadFailed => 'Failed to load vet visit';

  @override
  String get visitNotFound => 'Vet visit not found';

  @override
  String get visitCreateFailed => 'Failed to create vet visit';

  @override
  String get visitUpdateFailed => 'Failed to update vet visit';

  @override
  String get visitDeleteFailed => 'Failed to delete vet visit';

  @override
  String get suggestionsLoadFailed => 'Failed to load suggestions';

  @override
  String get vaccinationsLoadFailed => 'Failed to load vaccinations';

  @override
  String get vaccinationLoadFailed => 'Failed to load vaccination';

  @override
  String get vaccinationNotFound => 'Vaccination not found';

  @override
  String get vaccinationCreateFailed => 'Failed to create vaccination';

  @override
  String get vaccinationUpdateFailed => 'Failed to update vaccination';

  @override
  String get vaccinationDeleteFailed => 'Failed to delete vaccination';

  @override
  String get medicationsLoadFailed => 'Failed to load medications';

  @override
  String get medicationNotFound => 'Medication record not found';

  @override
  String get medicationSaveFailed => 'Failed to save medication';

  @override
  String get medicationDeleteFailed => 'Failed to delete medication';

  @override
  String get scheduleDeleteFailed => 'Failed to cancel scheduled changes';

  @override
  String get doseLoadFailed => 'Failed to load dose records';

  @override
  String get doseSaveFailed => 'Failed to save dose record';

  @override
  String get doseClearFailed => 'Failed to clear dose record';

  @override
  String get periodCheckFailed => 'Failed to check dose history';

  @override
  String get petNamesRefreshFailed => 'Pet names could not be refreshed.';

  @override
  String get remindersInitializeFailed => 'Failed to initialize reminders';

  @override
  String get remindersSyncFailed => 'Failed to update reminders';

  @override
  String get notificationPermissionFailed =>
      'Failed to request notification permission';

  @override
  String get exactPermissionFailed =>
      'Failed to request precise reminder permission';

  @override
  String get deviceSettingsFailed => 'Failed to open device settings';

  @override
  String get reminderSettingsSaveFailed => 'Failed to save reminder settings';

  @override
  String get doseUpdateFailed => 'Failed to update dose record';

  @override
  String get reminderTargetUnavailable =>
      'This reminder’s record is no longer available.';

  @override
  String get reminderOpenFailed => 'Failed to open reminder';
}
