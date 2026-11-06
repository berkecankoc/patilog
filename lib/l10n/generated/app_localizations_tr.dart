// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get previousTabs => 'Önceki sekmeler';

  @override
  String get moreTabs => 'Diğer sekmeler';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get notificationsTitle => 'Bildirimler';

  @override
  String get remindersTitle => 'Hatırlatmalar';

  @override
  String get remindersDescription => 'İlaç dozları ve planlanan aşılar';

  @override
  String get appearanceTitle => 'Görünüm';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get followDeviceSettings => 'Cihaz ayarlarını izle';

  @override
  String get languageTitle => 'Dil';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get followDeviceLanguage => 'Cihaz dilini izle';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get loadingSettings => 'Ayarlar yükleniyor';

  @override
  String get savingSettings => 'Ayarlar kaydediliyor';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get themeLoadFailed => 'Tema tercihi yüklenemedi';

  @override
  String get languageLoadFailed => 'Dil tercihi yüklenemedi';

  @override
  String get settingsLoadFailed => 'Ayarlar yüklenemedi';

  @override
  String get themeSaveFailed => 'Tema tercihi kaydedilemedi';

  @override
  String get languageSaveFailed => 'Dil tercihi kaydedilemedi';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get edit => 'Düzenle';

  @override
  String get back => 'Geri';

  @override
  String get done => 'Tamam';

  @override
  String get continueAction => 'Devam et';

  @override
  String get saveChanges => 'Değişiklikleri kaydet';

  @override
  String get saving => 'Kaydediliyor…';

  @override
  String get notProvided => 'Belirtilmedi';

  @override
  String get somethingWentWrong => 'Bir sorun oluştu';

  @override
  String get hideKeyboard => 'Klavyeyi gizle';

  @override
  String get reviewChanges => 'Değişiklikleri gözden geçir';

  @override
  String formStep(int current, int total, String title) {
    return 'Adım $current/$total · $title';
  }

  @override
  String get currentFormStep => 'Geçerli form adımı';

  @override
  String chooseDateField(String field) {
    return '$field: tarih seç';
  }

  @override
  String clearDateField(String field) {
    return '$field: tarihi temizle';
  }

  @override
  String get myPets => 'Dostlarım';

  @override
  String get profile => 'Profil';

  @override
  String get vetVisits => 'Veteriner ziyaretleri';

  @override
  String get vetVisitsNavigation => 'Ziyaretler';

  @override
  String get vaccinations => 'Aşılar';

  @override
  String get medications => 'İlaçlar';

  @override
  String get weightHistory => 'Kilo geçmişi';

  @override
  String get clinic => 'Klinik';

  @override
  String get veterinarian => 'Veteriner hekim';

  @override
  String get petProfile => 'Dost profili';

  @override
  String get profileDetails => 'Profil bilgileri';

  @override
  String get editProfile => 'Profili düzenle';

  @override
  String get deletePet => 'Profili sil';

  @override
  String get deletePetTitle => 'Profil silinsin mi?';

  @override
  String deletePetMessage(String name) {
    return '$name adlı dostunuzun profili, fotoğrafı, kilo geçmişi, veteriner ziyaretleri, aşıları, ilaçları ve doz kayıtları silinecek. Bu işlem geri alınamaz.';
  }

  @override
  String get deleteAction => 'Sil';

  @override
  String get retryDeletion => 'Silmeyi tekrar dene';

  @override
  String get retryProfile => 'Profili tekrar yükle';

  @override
  String get petNotFound => 'Dost bulunamadı';

  @override
  String get petLoadFailed => 'Dost bilgileri yüklenemedi';

  @override
  String get petsLoadFailed => 'Dostlarınız yüklenemedi';

  @override
  String get petCreateFailed => 'Dost eklenemedi';

  @override
  String get petUpdateFailed => 'Dost bilgileri güncellenemedi';

  @override
  String get petDeleteFailed => 'Profil silinemedi';

  @override
  String get petRefreshFailed => 'Dost bilgileri yenilenemedi';

  @override
  String get photoSaveFailed => 'Fotoğraf kaydedilemedi';

  @override
  String get addPet => 'Dost ekle';

  @override
  String get editPet => 'Profili düzenle';

  @override
  String get petStep => 'Dostunuz';

  @override
  String get review => 'Gözden geçir';

  @override
  String get reviewPet => 'Dost bilgilerini gözden geçir';

  @override
  String get basicDetails => 'Temel bilgiler';

  @override
  String get petName => 'Ad';

  @override
  String get petNameRequired => 'Ad girin';

  @override
  String petNameTooLong(int max) {
    return 'Ad en fazla $max karakter olabilir';
  }

  @override
  String get species => 'Tür';

  @override
  String get sex => 'Cinsiyet';

  @override
  String get breed => 'Irk';

  @override
  String get breedOptional => 'Irk (isteğe bağlı)';

  @override
  String get reproductiveStatus => 'Kısırlaştırma durumu';

  @override
  String get birthDate => 'Doğum tarihi';

  @override
  String get birthDateOptional => 'Doğum tarihi (isteğe bağlı)';

  @override
  String get currentWeight => 'Güncel kilo';

  @override
  String get weightOptional => 'Kilo (isteğe bağlı)';

  @override
  String get weightInvalid => 'Geçerli bir kilo girin';

  @override
  String get weightPositive => 'Kilo 0’dan büyük olmalı';

  @override
  String weightPrecision(int max) {
    return 'En fazla $max ondalık basamak kullanın';
  }

  @override
  String get identification => 'Kimlik bilgileri';

  @override
  String get microchipId => 'Mikroçip numarası';

  @override
  String get microchipIdOptional => 'Mikroçip numarası (isteğe bağlı)';

  @override
  String get healthIdentificationOptional =>
      'Sağlık ve kimlik bilgileri (isteğe bağlı)';

  @override
  String get addPetPhoto => 'Dost fotoğrafı ekle';

  @override
  String get changePetPhoto => 'Dost fotoğrafını değiştir';

  @override
  String get addPhoto => 'Fotoğraf ekle';

  @override
  String get changePhoto => 'Fotoğrafı değiştir';

  @override
  String get removePhoto => 'Fotoğrafı kaldır';

  @override
  String get photoAccessDenied =>
      'Fotoğraf erişimi reddedildi. Ayarlardan izin verip tekrar deneyin.';

  @override
  String get photoSelectFailed => 'Fotoğraf seçilemedi. Tekrar deneyin.';

  @override
  String get discardChangesTitle => 'Değişikliklerden vazgeçilsin mi?';

  @override
  String get discardChangesMessage =>
      'Değişiklikler kaydedilmedi. Kaydetmeden çıkılsın mı?';

  @override
  String get keepEditing => 'Düzenlemeye devam et';

  @override
  String get discardChanges => 'Değişikliklerden vazgeç';

  @override
  String get speciesDog => 'Köpek';

  @override
  String get speciesCat => 'Kedi';

  @override
  String get speciesBird => 'Kuş';

  @override
  String get speciesOther => 'Diğer';

  @override
  String get sexMale => 'Erkek';

  @override
  String get sexFemale => 'Dişi';

  @override
  String get unknown => 'Bilinmiyor';

  @override
  String get reproductiveIntact => 'Kısırlaştırılmamış';

  @override
  String get reproductiveSterilized => 'Kısırlaştırılmış';

  @override
  String get noPetsYet => 'Henüz dost eklenmedi';

  @override
  String get petsEmptyDescription =>
      'Sağlık ve bakım takibine başlamak için ilk dostunuzu ekleyin.';

  @override
  String get petWelcomeTitle => 'Dostlarınızın bakımı bir arada';

  @override
  String get petWelcomeDescription =>
      'Sağlık kayıtlarını, öğünlerini ve kilosunu takip edin.';

  @override
  String get petWelcomePrivacy =>
      'Hesap oluşturmanız gerekmez. Kayıtlarınız bu cihazda saklanır.';

  @override
  String get addFirstPet => 'İlk dostunu ekle';

  @override
  String get choosePetOverview =>
      'Profilini ve bakım kayıtlarını görmek için bir dost seçin.';

  @override
  String get addVisit => 'Ziyaret ekle';

  @override
  String get addVaccination => 'Aşı ekle';

  @override
  String get addMedication => 'İlaç ekle';

  @override
  String get choosePet => 'Dost seçin';

  @override
  String get close => 'Kapat';

  @override
  String get loadingSuggestions => 'Öneriler yükleniyor';

  @override
  String get weight => 'Kilo';

  @override
  String get save => 'Kaydet';

  @override
  String get measurement => 'Ölçüm';

  @override
  String get deleteMeasurementTitle => 'Ölçüm silinsin mi?';

  @override
  String get updatingMeasurements => 'Ölçümler güncelleniyor';

  @override
  String get addMeasurement => 'Ölçüm ekle';

  @override
  String get noMeasurements => 'Henüz ölçüm yok';

  @override
  String get measurementsEmpty =>
      'Geçmişi oluşturmak için bir kilo ölçümü ekleyin.';

  @override
  String get latestWeight => 'Son kilo';

  @override
  String get weightTrend => 'Kilo değişimi';

  @override
  String get weightChartOneMonth => '1 ay';

  @override
  String get weightChartThreeMonths => '3 ay';

  @override
  String get weightChartSixMonths => '6 ay';

  @override
  String weightChartMonthsShort(int months) {
    return '$months ay';
  }

  @override
  String get weightChartAll => 'Tümü';

  @override
  String get weightChartEmpty => 'Bu dönemde ölçüm yok.';

  @override
  String get weightChartShowAll => 'Tüm geçmişi göster';

  @override
  String weightChartChange(String change) {
    return 'Bu dönemdeki değişim: $change kg';
  }

  @override
  String get weightChartSinglePoint =>
      'Bir güne ait ölçüm var. Değişimi görmek için başka bir güne ölçüm ekleyin.';

  @override
  String get weightChartDailyHint =>
      'Her günün son ölçümü gösterilir. Tarih ve kilo için bir noktaya dokunun.';

  @override
  String get weightChartSemantics =>
      'Tarihe göre kilogram cinsinden kilo grafiği. Ölçümler aşağıda listelenmiştir.';

  @override
  String get measurements => 'Ölçümler';

  @override
  String get measurementsOrderHint =>
      'En yeni ölçüm üstte. Düzenlemek için bir ölçüm seçin.';

  @override
  String get deletingMeasurement => 'Ölçüm siliniyor';

  @override
  String get weightRequired => 'Kilo girin';

  @override
  String get weightGreaterThanZero => '0’dan büyük bir kilo girin';

  @override
  String get weightThreeDecimals => 'En fazla 3 ondalık basamak kullanın';

  @override
  String get measurementDate => 'Ölçüm tarihi';

  @override
  String get editMeasurement => 'Ölçümü düzenle';

  @override
  String get reviewMeasurement => 'Ölçümü gözden geçir';

  @override
  String get deleteVisitTitle => 'Ziyaret silinsin mi?';

  @override
  String get visitReason => 'Ziyaret nedeni';

  @override
  String get visitReasonSummary => 'Ziyaret nedeni';

  @override
  String get visitReasonRequired => 'Ziyaret nedenini girin';

  @override
  String get visitReasonLimit =>
      'Ziyaret nedeni en fazla 100 karakter olabilir';

  @override
  String get visitDate => 'Ziyaret tarihi';

  @override
  String get linkedVaccinationDateNotice =>
      'Bağlı aşıların tarihleri de güncellenecek.';

  @override
  String get reviewVisit => 'Ziyareti gözden geçir';

  @override
  String get visitDetails => 'Ziyaret bilgileri';

  @override
  String get clinicalOptional => 'Klinik ve hekim (isteğe bağlı)';

  @override
  String get clinicOptional => 'Klinik (isteğe bağlı)';

  @override
  String get veterinarianOptional => 'Veteriner hekim (isteğe bağlı)';

  @override
  String get retrySuggestions => 'Önerileri tekrar yükle';

  @override
  String get medicalNotesOptional => 'Tıbbi notlar (isteğe bağlı)';

  @override
  String get diagnosisOptional => 'Tanı (isteğe bağlı)';

  @override
  String get notesOptional => 'Notlar (isteğe bağlı)';

  @override
  String get notesLimit200 => 'Notlar en fazla 200 karakter olabilir';

  @override
  String get costOptional => 'Ücret (isteğe bağlı)';

  @override
  String get amountOptional => 'Tutar (isteğe bağlı)';

  @override
  String get costInvalid =>
      'En fazla 2 ondalık basamaklı geçerli bir tutar girin';

  @override
  String get currency => 'Para birimi';

  @override
  String get editVisit => 'Ziyareti düzenle';

  @override
  String get visit => 'Ziyaret';

  @override
  String get vetVisit => 'Veteriner ziyareti';

  @override
  String get deletingVisit => 'Ziyaret siliniyor';

  @override
  String get refreshingVisit => 'Ziyaret yenileniyor';

  @override
  String get deleteVisit => 'Ziyareti sil';

  @override
  String get clinical => 'Klinik ve hekim';

  @override
  String get medicalNotes => 'Tıbbi notlar';

  @override
  String get diagnosis => 'Tanı';

  @override
  String get notes => 'Notlar';

  @override
  String get cost => 'Ücret';

  @override
  String get amount => 'Tutar';

  @override
  String get updatingVisits => 'Ziyaretler güncelleniyor';

  @override
  String get noVisits => 'Henüz ziyaret yok';

  @override
  String get visitsEmpty =>
      'Gerçekleşmiş bir ziyaret ekleyerek bilgilerini bir arada tutun.';

  @override
  String get linkedVaccinations => 'Bağlı aşılar';

  @override
  String get retryVaccinations => 'Aşıları tekrar yükle';

  @override
  String get noLinkedVaccinations => 'Bu ziyarete bağlı aşı yok.';

  @override
  String get loadingLinkedVaccinations => 'Bağlı aşılar yükleniyor';

  @override
  String get deleteVaccinationTitle => 'Aşı silinsin mi?';

  @override
  String get vetVisitOptional => 'Veteriner ziyareti (isteğe bağlı)';

  @override
  String get noLinkedVisit => 'Bağlı ziyaret yok';

  @override
  String get linkedVisitUnavailable => 'Bağlı ziyarete ulaşılamıyor';

  @override
  String get loadingVisits => 'Ziyaretler yükleniyor';

  @override
  String get retryVisits => 'Ziyaretleri tekrar yükle';

  @override
  String get vaccineName => 'Aşı adı';

  @override
  String get vaccineNameRequired => 'Aşı adını girin';

  @override
  String get vaccineNameLimit => 'Aşı adı en fazla 50 karakter olabilir';

  @override
  String get status => 'Durum';

  @override
  String get administered => 'Uygulandı';

  @override
  String get planned => 'Planlandı';

  @override
  String get dateTodayOrFuture => 'Bugünü veya sonraki bir tarihi seçin';

  @override
  String get dateTodayOrPast => 'Bugünü veya önceki bir tarihi seçin';

  @override
  String get plannedDate => 'Planlanan tarih';

  @override
  String get administrationDate => 'Uygulama tarihi';

  @override
  String get dateFromLinkedVisit => 'Tarih bağlı veteriner ziyaretinden alınır';

  @override
  String get reviewVaccination => 'Aşıyı gözden geçir';

  @override
  String get vaccineDetails => 'Aşı bilgileri';

  @override
  String get nextDoseOptional => 'Sonraki doz (isteğe bağlı)';

  @override
  String get separateNextDoseHint =>
      'İsterseniz sonraki doz için ayrı bir plan oluşturun.';

  @override
  String get dateAfterAdministration =>
      'Uygulama tarihinden sonraki bir tarihi seçin';

  @override
  String get nextDoseDateOptional => 'Sonraki doz tarihi (isteğe bağlı)';

  @override
  String get remindersSettingsGuidance =>
      'Hatırlatmaları Ayarlar → Bildirimler bölümünden yönetebilirsiniz.';

  @override
  String get recordAdministration => 'Uygulanan aşıyı kaydet';

  @override
  String get editVaccination => 'Aşıyı düzenle';

  @override
  String get vaccination => 'Aşı';

  @override
  String get vaccine => 'Aşı';

  @override
  String get deletingVaccination => 'Aşı siliniyor';

  @override
  String get refreshingVaccination => 'Aşı yenileniyor';

  @override
  String get deleteVaccination => 'Aşıyı sil';

  @override
  String get noVaccinations => 'Henüz aşı yok';

  @override
  String get vaccinationsEmpty =>
      'Uygulanan bir aşıyı kaydedin veya sonraki dozu planlayın.';

  @override
  String get history => 'Geçmiş';

  @override
  String get updatingVaccinations => 'Aşılar güncelleniyor';

  @override
  String get linkedVetVisit => 'Bağlı veteriner ziyareti';

  @override
  String get retryVisit => 'Ziyareti tekrar yükle';

  @override
  String get openVetVisit => 'Veteriner ziyaretini aç';

  @override
  String get loadingLinkedVisit => 'Bağlı veteriner ziyareti yükleniyor';

  @override
  String get overdue => 'Gecikmiş';

  @override
  String get dueToday => 'Bugün';

  @override
  String get upcoming => 'Yaklaşan';

  @override
  String get deleteMedicationTitle => 'İlaç silinsin mi?';

  @override
  String get cancelScheduledChangesTitle =>
      'Planlanan değişiklikler iptal edilsin mi?';

  @override
  String get clearDoseRecordTitle => 'Doz kaydı temizlensin mi?';

  @override
  String get clearDoseRecordMessage =>
      'Dozun durumu Kayıt yok olacak. Planlanan doz silinmeyecek.';

  @override
  String get clearRecord => 'Kaydı temizle';

  @override
  String get cancelChanges => 'Değişiklikleri iptal et';

  @override
  String get daily => 'Her gün';

  @override
  String get noEndDate => 'Bitiş tarihi yok';

  @override
  String get previousDay => 'Önceki gün';

  @override
  String get today => 'Bugün';

  @override
  String get nextDay => 'Sonraki gün';

  @override
  String get backToToday => 'Bugüne dön';

  @override
  String get retryDoseRecords => 'Doz kayıtlarını tekrar yükle';

  @override
  String get noDoses => 'Planlanan doz yok';

  @override
  String get noDosesForDay => 'Bu gün için planlanan doz yok.';

  @override
  String get viewMedications => 'İlaçları görüntüle';

  @override
  String get active => 'Aktif';

  @override
  String get updatingMedications => 'İlaçlar güncelleniyor';

  @override
  String get retryAction => 'İşlemi tekrar dene';

  @override
  String get doses => 'Dozlar';

  @override
  String get noMedications => 'Henüz ilaç yok';

  @override
  String get medicationsEmpty =>
      'Doz takibine başlamak için bir ilaç ve kullanım planı ekleyin.';

  @override
  String get reopenVisitSection =>
      'Ziyareti yenilemek için bu bölümü yeniden açın.';

  @override
  String get dosageInstructions => 'Doz talimatı';

  @override
  String get oneDay => 'Tek gün';

  @override
  String get editChange => 'Değişikliği düzenle';

  @override
  String get cancelChange => 'Değişikliği iptal et';

  @override
  String get schedule => 'Kullanım planı';

  @override
  String get editDetails => 'Bilgileri düzenle';

  @override
  String get completed => 'Tamamlandı';

  @override
  String get editMedication => 'İlacı düzenle';

  @override
  String get scheduleAgain => 'Dozları yeniden planla';

  @override
  String get clinicAndNotes => 'Klinik ve notlar';

  @override
  String get hideDoseCalendar => 'Doz takvimini gizle';

  @override
  String get doseCalendar => 'Doz takvimi';

  @override
  String get previousSchedules => 'Önceki planlar';

  @override
  String get medication => 'İlaç';

  @override
  String get deleteMedication => 'İlacı sil';

  @override
  String get medicationNameRequired => 'İlaç adını girin.';

  @override
  String get doseTimeInvalid => '00:00–23:59 arasında bir saat girin.';

  @override
  String get uniqueDoseTimes => 'Her saat farklı olmalı.';

  @override
  String get doseTimeRequired => 'En az bir doz saati ekleyin.';

  @override
  String get periodEndInvalid => 'Bitiş tarihi başlangıçtan önce olamaz.';

  @override
  String get whichMedication => 'Hangi ilaç?';

  @override
  String get medicationName => 'İlaç adı';

  @override
  String get dosageInstructionsOptional => 'Doz talimatı (isteğe bağlı)';

  @override
  String get dosageExample => 'ör. yarım tablet';

  @override
  String get doseScheduleQuestion => 'Dozlar ne zaman?';

  @override
  String get previousScheduleReadOnly =>
      'Bu eski plan değiştirilemez. Klinik bilgilerini ve notları düzeltebilirsiniz.';

  @override
  String get newScheduleEffectiveHint =>
      'Plan değişiklikleri en erken yarın başlar. Önceki doz kayıtları korunur.';

  @override
  String get changesStart => 'Değişiklik başlangıcı';

  @override
  String get startDate => 'Başlangıç tarihi';

  @override
  String get frequency => 'Sıklık';

  @override
  String get everyNDays => 'N günde bir';

  @override
  String get daysBetweenDoses => 'Dozlar arasındaki gün sayısı';

  @override
  String get intervalRequired => 'En az 1 gün girin.';

  @override
  String get doseTime => 'Doz saati';

  @override
  String get timeFormatHint => 'SS:dd';

  @override
  String get addAnotherTime => 'Başka saat ekle';

  @override
  String get endDateOptional => 'Bitiş tarihi (isteğe bağlı)';

  @override
  String get reviewMedication => 'İlacı gözden geçir';

  @override
  String get preserveEarlierDoseRecords => 'Önceki doz kayıtları korunur.';

  @override
  String get clinicalNotesOptional => 'Klinik ve notlar (isteğe bağlı)';

  @override
  String get scheduleDoses => 'Dozları planla';

  @override
  String get retryDoseHistory => 'Doz geçmişini tekrar yükle';

  @override
  String get checkingDoseHistory => 'Doz geçmişi kontrol ediliyor';

  @override
  String get loadingDoseRecord => 'Doz kaydı yükleniyor…';

  @override
  String get doseRecordUnavailable => 'Doz kaydına ulaşılamıyor';

  @override
  String get scheduled => 'Planlandı';

  @override
  String get skippedEdit => 'Atlandı · Düzenle';

  @override
  String get skipDose => 'Atla';

  @override
  String get doseGiven => 'Verildi';

  @override
  String get noDoseRecord => 'Kayıt yok';

  @override
  String get recordDose => 'Dozu kaydet';

  @override
  String get unsavedDoseRecord => 'Doz kaydındaki değişiklikler kaydedilmedi.';

  @override
  String get editDoseRecord => 'Doz kaydını düzenle';

  @override
  String get doseSkipped => 'Atlandı';

  @override
  String get givenAt => 'Verildiği saat';

  @override
  String get time24Hint => 'SS:dd · 24 saat';

  @override
  String get givenTimeFuture => 'Verilme saati gelecekte olamaz.';

  @override
  String get doseNoLongerAvailable =>
      'Bu doz artık değiştirilemiyor. Paneli kapatıp seçili günü yenileyin.';

  @override
  String get doseRecordsUnavailable => 'Doz kayıtlarına ulaşılamıyor';

  @override
  String get previousMonth => 'Önceki ay';

  @override
  String get nextMonth => 'Sonraki ay';

  @override
  String get goToToday => 'Bugüne git';

  @override
  String get loadingMonthRecords => 'Ayın kayıtları yükleniyor';

  @override
  String get retryCalendar => 'Takvimi tekrar yükle';

  @override
  String get noCalendarDayDoses => 'Bu gün için planlanan doz yok.';

  @override
  String get linkedMedications => 'Bağlı ilaçlar';

  @override
  String get retryMedications => 'İlaçları tekrar yükle';

  @override
  String get noLinkedMedications => 'Bu ziyarete bağlı ilaç yok.';

  @override
  String get deleteVetVisitTitle => 'Veteriner ziyareti silinsin mi?';

  @override
  String get allPets => 'Tüm dostlarım';

  @override
  String get allPetsNoDayDoses =>
      'Bu gün için planlanan doz yok. Planları yönetmek için İlaçlar bölümünü açın.';

  @override
  String get noVetVisits => 'Henüz veteriner ziyareti yok';

  @override
  String get allVisitsEmpty =>
      'Dostlarınızın muayene ve tedavilerini kaydedin.';

  @override
  String get retryPets => 'Dostlarını tekrar yükle';

  @override
  String get retryDoseRecord => 'Doz kaydını tekrar dene';

  @override
  String get updatingCareRecords => 'Bakım kayıtları güncelleniyor';

  @override
  String get petUnavailable => 'Dost bilgilerine ulaşılamıyor';

  @override
  String get deletingRecord => 'Kayıt siliniyor';

  @override
  String get updatingReminders => 'Hatırlatmalar güncelleniyor';

  @override
  String get retrySave => 'Kaydetmeyi tekrar dene';

  @override
  String get remindersDeviceHint =>
      'Bu cihazın hangi hatırlatmaları göndereceğini seçin. Saatler cihazın yerel saatine göredir.';

  @override
  String get medicationReminders => 'İlaç hatırlatmaları';

  @override
  String get medicationReminderHint => 'Planlanan doz saatlerinde.';

  @override
  String get vaccinationReminders => 'Aşı hatırlatmaları';

  @override
  String get vaccinationReminderHint => 'Seçilen günlerde.';

  @override
  String get vaccinationSchedule => 'Aşı hatırlatma planı';

  @override
  String get daysAndTime => 'Günler ve saat';

  @override
  String get loadingSchedule => 'Plan yükleniyor…';

  @override
  String get scheduleUnavailable => 'Plana ulaşılamıyor';

  @override
  String get sharedVaccinationScheduleHint =>
      'Bu günler ve saat, planlanan tüm aşılar için geçerlidir.';

  @override
  String get notificationsBlocked => 'Bildirimlere izin verilmiyor';

  @override
  String get preciseRemindersOff => 'Tam saatinde hatırlatma kapalı';

  @override
  String get allowNotificationsHint =>
      'Hatırlatmaları almak için bu cihazda bildirimlere izin verin.';

  @override
  String get inexactRemindersHint =>
      'Kesin zamanlama kapalıyken öğün ve ilaç hatırlatmaları gecikebilir.';

  @override
  String get allowNotifications => 'Bildirimlere izin ver';

  @override
  String get allowPreciseReminders => 'Tam saatinde hatırlatmaya izin ver';

  @override
  String get openDeviceSettings => 'Cihaz ayarlarını aç';

  @override
  String get upcomingReminders => 'Yaklaşan hatırlatmalar';

  @override
  String get updatingRemindersEllipsis => 'Hatırlatmalar güncelleniyor…';

  @override
  String get noUpcomingReminders =>
      'Yaklaşan hatırlatma yok. Aşı, ilaç kullanım planı veya günlük beslenme planı ekle.';

  @override
  String get reminderQueueRefreshHint =>
      'Sonraki hatırlatmaların hazırlanması için uygulamayı düzenli açın.';

  @override
  String get discardReminderSchedule =>
      'Hatırlatma planını güncellemeden çıkılsın mı?';

  @override
  String get remindMe => 'Bana hatırlat';

  @override
  String get reminderDayLimitHint => 'En fazla 3 hatırlatma günü seçin.';

  @override
  String get reminderDayRequired => 'En az bir gün seçin';

  @override
  String get reminderDayLimit => 'En fazla 3 hatırlatma günü seçin';

  @override
  String get vaccinationDay => 'Aşı günü';

  @override
  String get reminderTime => 'Hatırlatma saati';

  @override
  String get time24DeviceHint => 'Bu cihazda 24 saat biçimi kullanılır.';

  @override
  String get timeRangeInvalid => '00:00–23:59 arasında bir saat girin';

  @override
  String get finishFormToOpenReminder =>
      'Bu hatırlatmayı açmak için açık formu veya işlemi tamamlayın.';

  @override
  String get healthRecords => 'Sağlık kayıtları';

  @override
  String deleteMeasurementForPetMessage(
    String weight,
    String date,
    String petName,
  ) {
    return '$petName için $date tarihli $weight kg ölçümü silinsin mi?';
  }

  @override
  String deleteMeasurementMessage(String weight, String date) {
    return '$date tarihindeki $weight kg ölçümü silinsin mi?';
  }

  @override
  String deleteMeasurementTooltip(String weight, String date) {
    return '$date tarihindeki $weight kg ölçümü sil';
  }

  @override
  String deleteVisitMessage(String reason, String date) {
    return '$date tarihindeki “$reason” ziyareti silinsin mi? Bağlı ilaçlar ve doz kayıtları, ziyaret bağlantısı kaldırılarak korunacak. Bu işlem geri alınamaz.';
  }

  @override
  String deleteVaccinationMessage(String name, String date) {
    return '$date tarihindeki “$name” aşısı silinsin mi? Ayrı planlanan dozlar korunacak. Bu işlem geri alınamaz.';
  }

  @override
  String deleteVisitTooltip(String date, String reason) {
    return '$date tarihindeki ziyareti sil: $reason';
  }

  @override
  String deleteVaccinationTooltip(String name, String date) {
    return '$date tarihindeki $name aşısını sil';
  }

  @override
  String openVaccination(String name) {
    return 'Aşıyı aç: $name';
  }

  @override
  String diagnosisLimit(int max) {
    return 'Tanı en fazla $max karakter olabilir';
  }

  @override
  String notesLimit(int max) {
    return 'Notlar en fazla $max karakter olabilir';
  }

  @override
  String maxCharacters(int max) {
    return 'En fazla $max karakter kullanın.';
  }

  @override
  String deleteMedicationMessage(String name) {
    return '$name adlı ilaç, tüm kullanım planları ve doz kayıtları silinsin mi?';
  }

  @override
  String get cancelScheduleResumeMessage =>
      'Henüz başlamamış bu değişiklikler kaldırılsın mı? Önceki plan, bitiş tarihine veya sonraki değişikliğe kadar devam edebilir.';

  @override
  String get cancelScheduleKeepHistoryMessage =>
      'Henüz başlamamış bu değişiklikler kaldırılsın mı? Önceki doz kayıtları korunacak.';

  @override
  String medicationEveryDays(int days) {
    return '$days günde bir';
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
    return '$count doz';
  }

  @override
  String doseCountRecorded(int count, int recorded) {
    return '$count doz · $recorded kayıtlı';
  }

  @override
  String startsOn(String date) {
    return 'Başlangıç: $date';
  }

  @override
  String endedOn(String date) {
    return 'Bitiş: $date';
  }

  @override
  String scheduleChangeSummary(String date, String schedule) {
    return '$date itibarıyla: $schedule';
  }

  @override
  String untilDate(String date) {
    return 'Bitiş: $date';
  }

  @override
  String removeDoseTime(String time) {
    return '$time doz saatini kaldır';
  }

  @override
  String editScheduledChangesNotice(String date) {
    return '$date tarihinde başlayacak değişiklikleri düzenliyorsunuz. O zamana kadar mevcut kullanım değişmez.';
  }

  @override
  String changesFromDate(String date) {
    return 'Değişiklik başlangıcı: $date';
  }

  @override
  String fromDate(String date) {
    return 'Başlangıç: $date';
  }

  @override
  String givenAtEdit(String time) {
    return 'Verildi: $time · Düzenle';
  }

  @override
  String doseWithNameAndTime(String name, String time) {
    return '$name · $time dozu';
  }

  @override
  String scheduledDoseCount(int count) {
    return '$count planlanan doz';
  }

  @override
  String givenDoseCount(int count) {
    return '$count verildi';
  }

  @override
  String skippedDoseCount(int count) {
    return '$count atlandı';
  }

  @override
  String missingDoseCount(int count) {
    return '$count kayıt yok';
  }

  @override
  String calendarDayDescription(String date, String status) {
    return '$date. $status';
  }

  @override
  String get noScheduledDoses => 'Planlanan doz yok';

  @override
  String openMedication(String name) {
    return 'İlacı aç: $name';
  }

  @override
  String deleteGlobalVisitMessage(String name) {
    return '$name için bu ziyaret silinsin mi? Bağlı aşılar ve ilaç planları, ziyaret bağlantısı kaldırılarak korunacak.';
  }

  @override
  String deleteGlobalVaccinationMessage(String name) {
    return '$name için bu aşı silinsin mi? Bu işlem geri alınamaz.';
  }

  @override
  String deleteNamedRecord(String name) {
    return 'Kaydı sil: $name';
  }

  @override
  String todayWithDate(String date) {
    return 'Bugün · $date';
  }

  @override
  String nextReminder(String date, String time) {
    return 'Sıradaki: $date, $time';
  }

  @override
  String queuedReminderSummary(int count, String date) {
    return '$date tarihine kadar $count hatırlatma hazır.';
  }

  @override
  String reminderDaysBefore(int days) {
    return '$days gün önce';
  }

  @override
  String reminderScheduleSummary(String days, String time) {
    return '$days · $time';
  }

  @override
  String get recordAdministrationTitle => 'Uygulanan aşı';

  @override
  String get weightLoadFailed => 'Kilo geçmişi yüklenemedi';

  @override
  String get measurementCreateFailed => 'Ölçüm eklenemedi';

  @override
  String get measurementUpdateFailed => 'Ölçüm güncellenemedi';

  @override
  String get measurementDeleteFailed => 'Ölçüm silinemedi';

  @override
  String get measurementNotFound => 'Ölçüm bulunamadı';

  @override
  String get visitsLoadFailed => 'Veteriner ziyaretleri yüklenemedi';

  @override
  String get visitLoadFailed => 'Veteriner ziyareti yüklenemedi';

  @override
  String get visitNotFound => 'Veteriner ziyareti bulunamadı';

  @override
  String get visitCreateFailed => 'Veteriner ziyareti eklenemedi';

  @override
  String get visitUpdateFailed => 'Veteriner ziyareti güncellenemedi';

  @override
  String get visitDeleteFailed => 'Veteriner ziyareti silinemedi';

  @override
  String get suggestionsLoadFailed => 'Öneriler yüklenemedi';

  @override
  String get vaccinationsLoadFailed => 'Aşılar yüklenemedi';

  @override
  String get vaccinationLoadFailed => 'Aşı bilgileri yüklenemedi';

  @override
  String get vaccinationNotFound => 'Aşı bulunamadı';

  @override
  String get vaccinationCreateFailed => 'Aşı eklenemedi';

  @override
  String get vaccinationUpdateFailed => 'Aşı güncellenemedi';

  @override
  String get vaccinationDeleteFailed => 'Aşı silinemedi';

  @override
  String get medicationsLoadFailed => 'İlaçlar yüklenemedi';

  @override
  String get medicationNotFound => 'İlaç kaydı bulunamadı';

  @override
  String get medicationSaveFailed => 'İlaç kaydedilemedi';

  @override
  String get medicationDeleteFailed => 'İlaç silinemedi';

  @override
  String get scheduleDeleteFailed => 'Planlanan değişiklikler iptal edilemedi';

  @override
  String get doseLoadFailed => 'Doz kayıtları yüklenemedi';

  @override
  String get doseSaveFailed => 'Doz kaydı kaydedilemedi';

  @override
  String get doseClearFailed => 'Doz kaydı temizlenemedi';

  @override
  String get periodCheckFailed => 'Doz geçmişi kontrol edilemedi';

  @override
  String get petNamesRefreshFailed => 'Dostlarınızın adları yenilenemedi.';

  @override
  String get remindersInitializeFailed => 'Hatırlatmalar başlatılamadı';

  @override
  String get remindersSyncFailed => 'Hatırlatmalar güncellenemedi';

  @override
  String get notificationPermissionFailed => 'Bildirim izni istenemedi';

  @override
  String get exactPermissionFailed => 'Tam saatinde hatırlatma izni istenemedi';

  @override
  String get deviceSettingsFailed => 'Cihaz ayarları açılamadı';

  @override
  String get reminderSettingsSaveFailed => 'Hatırlatma ayarları kaydedilemedi';

  @override
  String get doseUpdateFailed => 'Doz kaydı güncellenemedi';

  @override
  String get reminderTargetUnavailable =>
      'Bu hatırlatmanın kaydına artık ulaşılamıyor.';

  @override
  String notificationTitle(String petName, String recordName) {
    return '$petName · $recordName';
  }

  @override
  String notificationDoseBody(String time) {
    return 'Planlanan doz · $time';
  }

  @override
  String notificationDoseInstructions(String time, String instructions) {
    return '$time · $instructions';
  }

  @override
  String notificationVaccinationBody(String date) {
    return 'Aşı tarihi: $date.';
  }

  @override
  String get medicationChannelDescription => 'Planlanan ilaç dozları';

  @override
  String get vaccinationChannelDescription =>
      'Planlanan aşılar için hatırlatmalar';

  @override
  String get reminderOpenFailed => 'Hatırlatma açılamadı';

  @override
  String get feeding => 'Beslenme';

  @override
  String get addFeeding => 'Mama kaydet';

  @override
  String get editFeeding => 'Beslenme kaydını düzenle';

  @override
  String get feedingRecord => 'Beslenme kaydı';

  @override
  String get feedingPlan => 'Günlük plan';

  @override
  String get dailyMeals => 'Öğünler';

  @override
  String get feedingTrend => 'Günlük verilen mama';

  @override
  String get foodOptional => 'Mama adı (isteğe bağlı)';

  @override
  String get foodNameLimit => 'Mama adı en fazla 50 karakter olabilir';

  @override
  String get feedingAmountInvalid => 'Sıfırdan büyük bir gram miktarı gir';

  @override
  String get feedingPrecision => 'En fazla bir ondalık basamak kullan';

  @override
  String get feedingNoMeals => 'Planlanmış öğün yok';

  @override
  String get feedingNoMealsDescription =>
      'Mama verdiğinde kaydet veya bir günlük plan oluştur.';

  @override
  String get feedingNoRecords => 'Beslenme kaydı yok';

  @override
  String get feedingNoRecordsDescription =>
      'Kaydettiğin mama miktarları burada görünecek.';

  @override
  String get feedingLoadFailed => 'Beslenme kayıtları yüklenemedi';

  @override
  String get feedingSaveFailed => 'Beslenme kaydı kaydedilemedi';

  @override
  String get feedingDeleteFailed => 'Beslenme kaydı silinemedi';

  @override
  String get feedingPlanSaveFailed => 'Beslenme planı kaydedilemedi';

  @override
  String get feedingPlanCancelFailed => 'Beslenme planı iptal edilemedi';

  @override
  String get feedingRecordNotFound => 'Bu beslenme kaydına artık ulaşılamıyor.';

  @override
  String get feedingPlanNotFound => 'Bu beslenme planına artık ulaşılamıyor.';

  @override
  String get feedingDeleteTitle => 'Beslenme kaydı silinsin mi?';

  @override
  String get feedingDeleteMessage =>
      'Kaydedilen miktar silinecek. Bağlı bir öğün varsa yeniden kayıtsız görünecek.';

  @override
  String get feedingCancelPlanTitle => 'Planlanan beslenme iptal edilsin mi?';

  @override
  String get feedingCancelPlanMessage =>
      'Önceki plan kendi bitiş tarihine kadar devam edebilir. Beslenme kayıtları değişmez.';

  @override
  String get feedingCancelFirstPlanMessage =>
      'Bu öğünler plandan kaldırılacak. Beslenme kayıtları değişmez.';

  @override
  String get feedingFirstPlanHint =>
      'İlk planın bugün veya sonrasında başlayabilir.';

  @override
  String get feedingChangesHint =>
      'Değişiklikler en erken yarın başlar. Önceki beslenme kayıtları değişmez.';

  @override
  String get feedingPlanEmptyMessage =>
      'Plan oluşturmak isteğe bağlı. Daha hızlı takip için öğün saatlerini ve miktarlarını ekle.';

  @override
  String get createFeedingPlan => 'Plan oluştur';

  @override
  String get editFeedingPlan => 'Planı düzenle';

  @override
  String get endFeedingPlan => 'Bitiş tarihi belirle';

  @override
  String get feedingPlanEndHint =>
      'Bu plan başladı. Öğünler değişmeden kalır; bitiş tarihini düzenleyebilirsin.';

  @override
  String get feedingGiven => 'Verildi';

  @override
  String get feedingChartSelectPet =>
      'Günlük beslenme grafiği için yukarıdan bir dost seç.';

  @override
  String get addMeal => 'Öğün ekle';

  @override
  String get feedingDuplicateTime => 'Her öğünün saati farklı olmalı';

  @override
  String get feedingEndBeforeStart => 'Bitiş tarihi başlangıçtan önce olamaz';

  @override
  String get feedingMealTime => 'Öğün saati';

  @override
  String get feedingDate => 'Mama verilme tarihi';

  @override
  String get feedingTime => 'Mama verilme saati';

  @override
  String get feedingNotes => 'Mama ve notlar (isteğe bağlı)';

  @override
  String get feedingPlanLoading => 'Plan yükleniyor…';

  @override
  String get feedingPlanReview =>
      'Kaydetmeden önce öğün saatlerini ve miktarlarını kontrol et.';

  @override
  String get feedingRecordReview =>
      'Miktarı ve mama verilme zamanını kontrol et.';

  @override
  String get feedingPlanDateRequired => 'Geçerli bir başlangıç tarihi seç';

  @override
  String get feedingChartHint =>
      'Yenen değil, verilen miktarlar gösterilir. Kayıtsız günlerde çubuk görünmez.';

  @override
  String feedingGrams(String amount) {
    return '$amount g';
  }

  @override
  String get recordMeal => 'Öğün kaydet';

  @override
  String feedingMealNumber(int number) {
    return 'Öğün $number';
  }

  @override
  String removeFeedingMeal(int number) {
    return 'Öğün $number öğesini kaldır';
  }

  @override
  String feedingDays(int count) {
    return '$count gün';
  }

  @override
  String get feedingPlans => 'Planlar';

  @override
  String get feedingAmount => 'Miktar';

  @override
  String get feedingEditEndDate => 'Bitiş tarihini düzenle';

  @override
  String get feedingExtraRecords => 'Diğer beslenme kayıtları';

  @override
  String feedingRecordsCount(int count) {
    return '$count kayıt';
  }

  @override
  String get feedingReminders => 'Beslenme hatırlatmaları';

  @override
  String get feedingReminderHint => 'Günlük plandaki öğün saatlerinde.';

  @override
  String get feedingChannelDescription => 'Planlanan öğün saatleri';

  @override
  String notificationFeedingBody(String amount, String time) {
    return '$time saatinde $amount g mama ver.';
  }

  @override
  String notificationFeedingFoodBody(String amount, String food, String time) {
    return '$time saatinde $amount g $food ver.';
  }

  @override
  String feedingEntrySummary(String date, String amount) {
    return '$date · $amount g';
  }
}
