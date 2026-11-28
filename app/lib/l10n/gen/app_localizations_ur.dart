// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String aboutMinutes(Object n) {
    return 'تقریباً $n منٹ';
  }

  @override
  String get aboutYou => 'آپ کے بارے میں';

  @override
  String get accountTitle => 'اکاؤنٹ ہولڈر کا نام';

  @override
  String get add => 'شامل کریں';

  @override
  String get addAService => 'سروس شامل کریں';

  @override
  String get addAddress => 'پتہ شامل کریں';

  @override
  String get addContact => 'رابطہ شامل کریں';

  @override
  String get addPackage => 'پیکج شامل کریں';

  @override
  String get addPhoto => 'تصویر شامل کریں';

  @override
  String get addServicesToSeeJobs =>
      'متعلقہ کام دیکھنے کے لیے اپنی خدمات شامل کریں۔';

  @override
  String get addTimeOff => 'چھٹیاں شامل کریں';

  @override
  String get address => 'پتہ';

  @override
  String get addressAfterBooking => 'بکنگ کے بعد مکمل پتہ بتا دیا جائے گا۔';

  @override
  String get addressDefaultBadge => 'پہلے سے منتخب';

  @override
  String get addressDeleted => 'پتہ حذف ہو گیا۔';

  @override
  String get addressHelper => 'صرف وہی کاریگر دیکھ سکے گا جسے آپ بک کریں گے';

  @override
  String get addressSaved => 'پتہ محفوظ ہو گیا۔';

  @override
  String get agree => 'راضی ہوں';

  @override
  String agreeToAmount(Object amount) {
    return '$amount پر راضی';
  }

  @override
  String get agreeToHint => 'اس کے بعد گاہک آپ کو بک کرنے کی تصدیق کرے گا۔';

  @override
  String agreeToQ(Object price) {
    return '$price پر راضی ہیں؟';
  }

  @override
  String get agreedPrice => 'طے شدہ قیمت';

  @override
  String get all => 'سب';

  @override
  String get allBusyHint =>
      'اس دن کوئی موزوں ورکر فارغ نہیں۔ آپ پھر بھی کام پوسٹ کر سکتے ہیں، یا دوسرا دن چنیں۔';

  @override
  String get allServices => 'سب';

  @override
  String get allServicesOffered => 'آپ پہلے ہی تمام خدمات پیش کر رہے ہیں۔';

  @override
  String amountDue(Object amount) {
    return 'واجب الادا رقم: $amount';
  }

  @override
  String get anyWorkerNearby => 'قریب کا کوئی بھی فارغ ورکر';

  @override
  String get appName => 'کام ناؤ';

  @override
  String appVersion(Object version) {
    return 'کام ناؤ $version';
  }

  @override
  String get applyPromo => 'لاگو کریں';

  @override
  String get areaHint => 'مثلاً ڈی ایچ اے فیز 5';

  @override
  String areaLine(Object area) {
    return 'علاقہ: $area';
  }

  @override
  String get areaOptional => 'علاقہ (اختیاری)';

  @override
  String get areasHint => 'مثلاً گلبرگ، ماڈل ٹاؤن';

  @override
  String get areasYouCover => 'آپ کے علاقے';

  @override
  String get arriveInMinutes => 'آپ کتنے منٹ میں پہنچ سکتے ہیں';

  @override
  String get askedForYou => 'گاہک نے آپ کو بلایا ہے';

  @override
  String get atLeast5 => 'کم از کم 5 حروف';

  @override
  String get atLeast8 => 'کم از کم 8 حروف';

  @override
  String get availableAnyTime => 'کسی بھی وقت دستیاب';

  @override
  String get availableAnyTimeHelp =>
      'اپنے کام کے دن اور اوقات مقرر کرنے کے لیے بند کریں۔';

  @override
  String get back => 'واپس';

  @override
  String get backToLogin => 'لاگ ان پر واپس جائیں';

  @override
  String get badgeAlwaysOnTime => 'ہمیشہ وقت پر';

  @override
  String get badgeCustomerFavourite => 'گاہکوں کا پسندیدہ';

  @override
  String get badgeExperienced => '5+ سال تجربہ';

  @override
  String get badgeJobs100 => '100+ کام';

  @override
  String get badgeVerified => 'تصدیق شدہ';

  @override
  String get bankTransfer => 'بینک ٹرانسفر';

  @override
  String get baseLocation => 'بنیادی لوکیشن';

  @override
  String get baseLocationHint =>
      'کام اسی جگہ سے فاصلے کے حساب سے ملتے ہیں۔ گاہک اسے کبھی نہیں دیکھتے۔';

  @override
  String get book => 'بک کریں';

  @override
  String get bookAgain => 'دوبارہ بک کریں';

  @override
  String bookAgree(Object price) {
    return 'آپ $price ادا کرنے پر رضامند ہیں۔ باقی تمام پیشکشیں بند ہو جائیں گی۔';
  }

  @override
  String bookAgreeEmergency(Object price, Object fee) {
    return 'آپ $price اور $fee ایمرجنسی فیس ادا کرنے پر رضامند ہیں۔ باقی تمام پیشکشیں بند ہو جائیں گی۔';
  }

  @override
  String bookFor(Object price) {
    return '$price میں بک کریں';
  }

  @override
  String get bookPackage => 'بک کریں';

  @override
  String get bookThisWorker => 'اس ورکر کو بک کریں';

  @override
  String bookWorkerQ(Object name) {
    return '$name کو بک کریں؟';
  }

  @override
  String get booked => 'بک ہو گیا!';

  @override
  String get booking => 'بکنگ';

  @override
  String get bookingCancelled => 'بکنگ منسوخ ہو گئی۔';

  @override
  String bookingNumber(Object id) {
    return 'بکنگ نمبر $id';
  }

  @override
  String bookingNumberPrice(Object id, Object price) {
    return 'بکنگ نمبر $id · $price';
  }

  @override
  String get bookingRemindersHint =>
      'ہر بک کیے گئے کام سے ایک دن پہلے اور ایک گھنٹہ پہلے یاد دہانی';

  @override
  String get bookingRemindersSetting => 'کام کی یاد دہانیاں';

  @override
  String bookingWorkerDirectly(String name) {
    return '$name کی بکنگ';
  }

  @override
  String get bookingWorkerDirectlyHint =>
      'آپ کا کام صرف یہی ورکر دیکھے گا۔ اگر وہ نہ آ سکیں تو آپ اسے سب کو بھیج سکتے ہیں۔';

  @override
  String budget(Object amount) {
    return 'بجٹ: $amount';
  }

  @override
  String budgetLower(Object amount) {
    return 'بجٹ $amount';
  }

  @override
  String get budgetOptional => 'آپ کا بجٹ (اختیاری)';

  @override
  String get cancel => 'منسوخ';

  @override
  String get cancelBooking => 'بکنگ منسوخ کریں';

  @override
  String get cancelBookingQ => 'یہ بکنگ منسوخ کریں؟';

  @override
  String cancelFeeLate(Object amount) {
    return 'ابھی منسوخ کرنے پر $amount لگیں گے، کیونکہ کام جلد شروع ہونے والا ہے۔ یہ رقم کاریگر کو ان کے مختص کیے گئے وقت کے لیے جاتی ہے۔';
  }

  @override
  String cancelFeeOnTheWay(Object amount) {
    return 'کاریگر راستے میں ہے، اس لیے ابھی منسوخ کرنے پر $amount لگیں گے۔ یہ رقم کاریگر کو ان کے سفر کے لیے جاتی ہے۔';
  }

  @override
  String cancelFreeUntil(Object time, Object amount) {
    return '$time تک منسوخی مفت ہے۔ اس کے بعد $amount لگیں گے۔';
  }

  @override
  String get cancelPayout => 'درخواست منسوخ کریں';

  @override
  String get cancelRequest => 'درخواست منسوخ کریں';

  @override
  String get cancelRequestQ => 'یہ درخواست منسوخ کریں؟';

  @override
  String cancelledReason(Object reason) {
    return 'منسوخ: $reason';
  }

  @override
  String get cannotTakeJob => 'میں یہ کام نہیں لے سکتا';

  @override
  String get cannotTakeJobHint =>
      'گاہک کو بتا دیا جائے گا، اور کام قریبی دوسرے ورکرز کو چلا جائے گا۔';

  @override
  String get cannotTakeJobOk => 'چھوڑ دیں';

  @override
  String get cannotTakeJobQ => 'یہ کام چھوڑ دیں؟';

  @override
  String get cantDoThisAnyMore => 'میں اب یہ کام نہیں کر سکتا';

  @override
  String get cashReceivedQ => 'نقد رقم مل گئی؟';

  @override
  String get ccAppIssue => 'ایپ میں مسئلہ';

  @override
  String get ccBehaviour => 'برا رویہ';

  @override
  String get ccDamage => 'سامان کا نقصان';

  @override
  String get ccFraud => 'دھوکہ دہی';

  @override
  String get ccNoShow => 'کاریگر نہیں آیا';

  @override
  String get ccOther => 'کچھ اور';

  @override
  String get ccOvercharging => 'زیادہ پیسے لیے';

  @override
  String get ccPayment => 'ادائیگی کا مسئلہ';

  @override
  String get ccServiceQuality => 'خراب کام';

  @override
  String get change => 'تبدیل کریں';

  @override
  String get changeHowOften => 'کتنی بار، بدلیں';

  @override
  String get changePassword => 'پاس ورڈ تبدیل کریں';

  @override
  String get changePhoto => 'تصویر تبدیل کریں';

  @override
  String get chat => 'چیٹ';

  @override
  String get chooseAService => 'سروس منتخب کریں';

  @override
  String get chooseDaysOff => 'اپنی چھٹی کے دن چنیں';

  @override
  String get chooseNewPassword => 'نیا پاس ورڈ منتخب کریں';

  @override
  String get chooseOneWorkingDay =>
      'کم از کم ایک کام کا دن چنیں، یا \"کسی بھی وقت دستیاب\" آن کریں۔';

  @override
  String get chooseService => 'سروس منتخب کریں۔';

  @override
  String get close => 'بند کریں';

  @override
  String get cnicNumber => 'شناختی کارڈ نمبر';

  @override
  String get cnicPrivate =>
      'شناختی کارڈ کی تصاویر نجی ہیں۔ انہیں صرف کام ناؤ کا عملہ دیکھ سکتا ہے۔';

  @override
  String codeSentTo(String phone) {
    return '$phone پر بھیجا گیا کوڈ درج کریں۔';
  }

  @override
  String comingSoon(Object method) {
    return '$method (جلد آ رہا ہے)';
  }

  @override
  String get commentOptional => 'تبصرہ (اختیاری)';

  @override
  String commissionDue(Object amount) {
    return 'واجب الادا کمیشن: $amount';
  }

  @override
  String get commissionDueHint =>
      'نقد کاموں سے۔ کام ناؤ اس کی ادائیگی کے لیے آپ سے رابطہ کرے گا۔';

  @override
  String commissionKeep(Object percent, Object amount, Object earning) {
    return 'کام ناؤ کمیشن $percent%: $amount۔ آپ کو $earning ملیں گے۔';
  }

  @override
  String commissionLine(Object percent, Object amount, Object date) {
    return '$percent% کمیشن $amount · $date';
  }

  @override
  String commissionPaymentOpen(Object amount) {
    return '$amount کمیشن کی ادائیگی جاری ہے';
  }

  @override
  String get commissionPaymentWindowClosed =>
      'ادائیگی کی ونڈو بند ہو گئی۔ JazzCash یا Easypaisa کی تصدیق کے بعد آپ کا والٹ اپ ڈیٹ ہو جائے گا۔';

  @override
  String commissionPercent(Object percent) {
    return 'کمیشن $percent%';
  }

  @override
  String commissionRateNow(Object percent) {
    return 'آپ کا موجودہ کمیشن ریٹ $percent% ہے۔';
  }

  @override
  String get commissionStandard => 'معیاری کمیشن';

  @override
  String get complete => 'مکمل کریں';

  @override
  String get completeJob => 'کام مکمل کریں';

  @override
  String get completePaymentNewTab =>
      'نئے ٹیب میں ادائیگی مکمل کریں۔ تصدیق ہوتے ہی یہ صفحہ اپ ڈیٹ ہو جائے گا۔';

  @override
  String get completeWithCode => 'گاہک کے کوڈ سے مکمل کریں';

  @override
  String get completedJobs => 'مکمل کام';

  @override
  String get completionCode => 'تکمیل کوڈ';

  @override
  String get completionCodeHint =>
      'یہ کوڈ کاریگر کو صرف تب دیں جب کام آپ کی تسلی کے مطابق مکمل ہو جائے۔';

  @override
  String get confirm => 'تصدیق کریں';

  @override
  String get confirmAction => 'کنفرم کریں';

  @override
  String get confirmBooking => 'بکنگ کی تصدیق کریں';

  @override
  String confirmCashAmount(Object amount) {
    return 'تصدیق کریں کہ آپ کو $amount نقد مل گئے۔';
  }

  @override
  String get confirmJobDone => 'کام مکمل ہونے کی تصدیق کریں';

  @override
  String confirmNumberHint(String phone) {
    return 'ہم $phone پر SMS کے ذریعے 6 ہندسوں کا کوڈ بھیجیں گے۔ اس سے کام ناؤ گاہکوں اور کاریگروں کے لیے محفوظ رہتا ہے۔';
  }

  @override
  String get confirmOncePaid => 'گاہک کی ادائیگی ملنے پر تصدیق کریں۔';

  @override
  String get confirmYourNumber => 'اپنا فون نمبر کنفرم کریں';

  @override
  String get contact => 'رابطہ';

  @override
  String get contactAdded => 'شامل کر دیا گیا۔';

  @override
  String get contactPhoneLabel => 'موبائل نمبر';

  @override
  String get contactRemoved => 'ہٹا دیا گیا۔';

  @override
  String get continueAction => 'جاری رکھیں';

  @override
  String get copyInvite => 'دعوت کاپی کریں';

  @override
  String get copyLink => 'لنک کاپی کریں';

  @override
  String get couldNotGetLocation => 'آپ کی لوکیشن نہیں مل سکی۔';

  @override
  String get couldNotSendLocation => 'آپ کی لوکیشن نہیں بھیجی جا سکی۔';

  @override
  String get counter => 'جوابی قیمت';

  @override
  String get counterOffer => 'جوابی پیشکش';

  @override
  String get counterSent => 'جوابی پیشکش بھیج دی گئی۔';

  @override
  String get createAccount => 'اکاؤنٹ بنائیں';

  @override
  String get createAnAccount => 'نیا اکاؤنٹ بنائیں';

  @override
  String get creditAdmin => 'کام ناؤ کی طرف سے';

  @override
  String creditApplied(Object amount) {
    return 'کریڈٹ: $amount کی رعایت';
  }

  @override
  String creditBalance(Object amount) {
    return 'آپ کا کریڈٹ: $amount';
  }

  @override
  String get creditHistory => 'کریڈٹ کی تاریخ';

  @override
  String get creditReferral => 'دعوت کا انعام';

  @override
  String get creditReturned => 'واپس';

  @override
  String get creditSpent => 'بکنگ پر استعمال';

  @override
  String get creditWelcome => 'خوش آمدید کریڈٹ';

  @override
  String get currentPassword => 'موجودہ پاس ورڈ';

  @override
  String currentPlan(Object name) {
    return 'موجودہ پلان: $name';
  }

  @override
  String currentPrice(Object amount) {
    return 'موجودہ قیمت: $amount';
  }

  @override
  String get customer => 'گاہک';

  @override
  String customerBudget(Object amount) {
    return 'گاہک کا بجٹ: $amount';
  }

  @override
  String get customerCounteredShort => 'گاہک نے جوابی قیمت دی۔ آپ کی باری۔';

  @override
  String get customerCounteredYourMove =>
      'گاہک نے جوابی قیمت دی ہے۔ اب آپ کی باری ہے۔';

  @override
  String get customerNotPaid => 'گاہک نے ابھی ادائیگی نہیں کی۔';

  @override
  String get customerNotThere => 'گاہک موجود نہیں';

  @override
  String get customerNotThereQ => 'رپورٹ کریں کہ گاہک موجود نہیں تھا؟';

  @override
  String get customersPaid => 'گاہکوں نے ادا کیا';

  @override
  String dateRange(String start, String end) {
    return '$start سے $end تک';
  }

  @override
  String get dayOff => 'چھٹی';

  @override
  String daysAgo(Object n) {
    return '$n دن پہلے';
  }

  @override
  String get defaultAddress => 'مستقل پتہ';

  @override
  String get delete => 'حذف کریں';

  @override
  String get deleteAddressQ => 'یہ پتہ حذف کریں؟';

  @override
  String get deletePackageBody => 'اس سے پہلے سے کی گئی بکنگز برقرار رہیں گی۔';

  @override
  String get deletePackageQ => 'یہ پیکج حذف کریں؟';

  @override
  String get deletePhotoBody => 'گاہک اسے مزید نہیں دیکھ سکیں گے۔';

  @override
  String get deletePhotoQ => 'یہ تصویر حذف کریں؟';

  @override
  String get describeProblem => 'مسئلہ بیان کریں';

  @override
  String get details => 'تفصیلات';

  @override
  String get discountNote =>
      'رعایت کام ناؤ دیتا ہے۔ آپ کے ورکر کو پورا حصہ ملتا ہے۔';

  @override
  String distanceKm(Object km) {
    return '$km کلومیٹر';
  }

  @override
  String get docCertificate => 'سرٹیفکیٹ';

  @override
  String get docCnicBack => 'شناختی کارڈ (پیچھے)';

  @override
  String get docCnicFront => 'شناختی کارڈ (سامنے)';

  @override
  String get docOther => 'دیگر';

  @override
  String docUploaded(Object doc) {
    return '$doc اپ لوڈ ہو گیا۔';
  }

  @override
  String get done => 'ٹھیک ہے';

  @override
  String get downloadFailed => 'ڈاؤن لوڈ نہیں ہو سکا۔';

  @override
  String get downloadReceiptPdf => 'PDF ڈاؤن لوڈ کریں';

  @override
  String get downloadStatement => 'اسٹیٹمنٹ ڈاؤن لوڈ کریں (CSV)';

  @override
  String durationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours گھنٹے',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours گھنٹے $minutes منٹ';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes منٹ';
  }

  @override
  String get earnings => 'آمدنی';

  @override
  String get earningsReports => 'کمائی کی رپورٹ';

  @override
  String get earningsReportsHint =>
      'ہفتے یا مہینے کے حساب سے، سروس، نقد اور آن لائن کے لحاظ سے، اور ڈاؤن لوڈ کے لیے اسٹیٹمنٹ';

  @override
  String get edit => 'تبدیل کریں';

  @override
  String get editAddress => 'پتہ بدلیں';

  @override
  String get editCaption => 'عنوان بدلیں';

  @override
  String get editPackage => 'پیکج میں تبدیلی';

  @override
  String get editProfile => 'پروفائل میں ترمیم';

  @override
  String get email => 'ای میل';

  @override
  String get emailOptional => 'ای میل (اختیاری، پاس ورڈ ری سیٹ کے لیے)';

  @override
  String get emergency => 'ایمرجنسی';

  @override
  String get emergencyContacts => 'ہنگامی رابطے';

  @override
  String get emergencyContactsHint =>
      'کام کے دوران ایس او ایس دبانے پر انہیں پیغام جاتا ہے';

  @override
  String emergencyFee(Object fee) {
    return 'ایمرجنسی · فیس $fee';
  }

  @override
  String get emergencyFeeLabel => 'ایمرجنسی فیس';

  @override
  String get emergencyJob => 'ایمرجنسی کام';

  @override
  String emergencySubtitle(Object fee) {
    return 'کاریگروں کو سب سے پہلے دکھایا جائے گا۔ کل رقم میں $fee شامل ہوں گے۔';
  }

  @override
  String endAfterStartFor(String day) {
    return '$day کو ختم ہونے کا وقت شروع ہونے کے وقت کے بعد ہونا چاہیے۔';
  }

  @override
  String get enterAddress => 'پتہ درج کریں';

  @override
  String get enterCnic => 'اپنا شناختی کارڈ نمبر درج کریں';

  @override
  String get enterCompletionCode => 'تکمیل کوڈ درج کریں';

  @override
  String get enterFullName => 'اپنا پورا نام درج کریں';

  @override
  String get enterMinutes => 'منٹ درج کریں';

  @override
  String get enterNumber => 'نمبر درج کریں';

  @override
  String get enterPassword => 'اپنا پاس ورڈ درج کریں';

  @override
  String get enterPhone => 'اپنا فون نمبر درج کریں';

  @override
  String get enterPrice => 'قیمت درج کریں';

  @override
  String get enterTheCode => 'SMS میں آیا کوڈ درج کریں۔';

  @override
  String get enterValidPhone => 'درست فون نمبر درج کریں';

  @override
  String etaMinutes(Object n) {
    return 'تقریباً $n منٹ';
  }

  @override
  String feeCustomerOwed(Object amount) {
    return 'دیر سے منسوخی کی فیس: $amount۔ دوبارہ بک کرنے سے پہلے ادا کریں۔';
  }

  @override
  String feeCustomerPaid(Object amount) {
    return 'دیر سے منسوخی کی $amount فیس ادا ہو گئی۔ شکریہ۔';
  }

  @override
  String get feeOwedHint =>
      'ادا کرنے کے لیے دبائیں۔ ادائیگی کے بعد آپ دوبارہ بک کر سکتے ہیں۔';

  @override
  String feeOwedTitle(Object amount) {
    return 'آپ پر دیر سے منسوخی کی $amount فیس واجب ہے';
  }

  @override
  String get feePayOffice =>
      'آن لائن ادائیگی ابھی دستیاب نہیں۔ KaamNow کے دفتر میں ادا کریں یا سپورٹ سے رابطہ کریں۔';

  @override
  String get feeWaived => 'منسوخی کی فیس معاف کر دی گئی۔';

  @override
  String feeWorkerOwed(Object amount) {
    return 'گاہک کے دیر سے منسوخی کی فیس ادا کرنے پر آپ کو $amount ملیں گے۔';
  }

  @override
  String feeWorkerPaid(Object amount) {
    return 'منسوخی کی $amount فیس آپ کے والیٹ میں شامل ہو گئی۔';
  }

  @override
  String get filterActive => 'جاری';

  @override
  String get finishPayingNewTab =>
      'نئے ٹیب میں ادائیگی مکمل کریں۔ تصدیق ہوتے ہی آپ کا پلان فعال ہو جائے گا۔';

  @override
  String get firstVisit => 'پہلی بار';

  @override
  String get fixedPricePackage => 'مقررہ قیمت والا پیکج';

  @override
  String get fixedPricePackages => 'مقررہ قیمت والے پیکجز';

  @override
  String forgotCodeHint(String phone) {
    return 'اگر $phone کا کام ناؤ اکاؤنٹ ہے تو ہم نے اس پر SMS سے کوڈ بھیج دیا ہے۔';
  }

  @override
  String get forgotEmailOnly =>
      'اگر اس نمبر کے اکاؤنٹ میں ای میل موجود ہے تو ہم نے پاس ورڈ ری سیٹ کرنے کا لنک ای میل کر دیا ہے۔';

  @override
  String get forgotHint =>
      'اپنا فون نمبر درج کریں۔ نیا پاس ورڈ بنانے کے لیے ہم آپ کو SMS سے کوڈ بھیجیں گے۔';

  @override
  String get forgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get forgotTitle => 'پاس ورڈ بھول گئے؟';

  @override
  String get free => 'مفت';

  @override
  String freeWorkersOn(String day) {
    return '$day کو فارغ ورکر';
  }

  @override
  String get freqBiweekly => 'ہر دو ہفتے';

  @override
  String get freqMonthly => 'ہر مہینے';

  @override
  String get freqWeekly => 'ہر ہفتے';

  @override
  String get fromKaamNowJob => 'کام ناؤ کے ایک کام سے';

  @override
  String fromPrice(Object price) {
    return '$price سے شروع';
  }

  @override
  String fromPriceCap(Object price) {
    return '$price سے شروع';
  }

  @override
  String get fullName => 'پورا نام';

  @override
  String get getCompletionCode => 'تکمیل کوڈ حاصل کریں';

  @override
  String get getPaid => 'رقم وصول کریں';

  @override
  String get getVerified => 'پیشکش بھیجنے کے لیے تصدیق کروائیں';

  @override
  String get getVerifiedHint =>
      'شناختی کارڈ کے دونوں رخ اپ لوڈ کریں، اپنی خدمات شامل کریں اور اپنی بنیادی لوکیشن لگائیں۔ کام ناؤ نئے کاریگروں کو پیشکش دینے سے پہلے جانچتا ہے۔';

  @override
  String get helpAndComplaints => 'مدد اور شکایات';

  @override
  String get hireHelp => 'مدد حاصل کرنا';

  @override
  String get homeIntro =>
      'کام بتائیں، قریبی تصدیق شدہ کاریگروں سے قیمتیں لیں، اور جو پسند آئے اسے چنیں۔';

  @override
  String hoursAgo(Object n) {
    return '$n گھنٹے پہلے';
  }

  @override
  String get howLongJob => 'کام میں کتنا وقت لگے گا؟';

  @override
  String get howLongJobHelp =>
      'اندازاً بتائیں۔ ورکر یہ وقت آپ کے لیے خالی رکھیں گے۔';

  @override
  String get howOften => 'کتنی بار؟';

  @override
  String get howToInstall => 'انسٹال کرنے کا طریقہ';

  @override
  String get iWantTo => 'میں چاہتا/چاہتی ہوں';

  @override
  String get iban => 'IBAN';

  @override
  String get imOnMyWay => 'میں راستے میں ہوں';

  @override
  String get install => 'انسٹال کریں';

  @override
  String get installApp => 'ایپ انسٹال کریں';

  @override
  String get installHint =>
      'اسے اپنی ہوم اسکرین پر لگائیں اور ایپ کی طرح کھولیں۔';

  @override
  String get installTitle => 'کام ناؤ انسٹال کریں';

  @override
  String get installedThanks =>
      'کام ناؤ انسٹال ہو گیا۔ آپ اسے اپنی ہوم اسکرین سے کھول سکتے ہیں۔';

  @override
  String get inviteCodeHint =>
      'کسی دوست سے کوڈ ملا ہے؟ آپ کو پہلی بکنگ پر کریڈٹ ملے گا۔';

  @override
  String get inviteCodeOptional => 'دعوتی کوڈ (اختیاری)';

  @override
  String get inviteCopied =>
      'دعوت کاپی ہو گئی۔ اسے واٹس ایپ یا SMS میں پیسٹ کریں۔';

  @override
  String inviteExplain(Object welcome, Object min, Object reward) {
    return 'جو دوست آپ کے کوڈ سے سائن اپ کریں انہیں پہلی بکنگ پر $welcome کی رعایت ملتی ہے۔ جب وہ $min یا اس سے زیادہ کی بکنگ ادا کریں تو آپ کو $reward کا کریڈٹ ملتا ہے۔';
  }

  @override
  String inviteExplainWorker(Object welcome, Object min, Object reward) {
    return 'جو گاہک آپ کے کوڈ سے سائن اپ کریں انہیں پہلی بکنگ پر $welcome کی رعایت ملتی ہے۔ جب وہ $min یا اس سے زیادہ کی بکنگ ادا کریں تو $reward آپ کے والٹ میں شامل ہو جاتے ہیں۔';
  }

  @override
  String get inviteFriends => 'دوستوں کو دعوت دیں';

  @override
  String inviteMessage(Object code, Object amount, Object link) {
    return 'کام ناؤ سے لاہور میں قابلِ اعتماد ورکر بک کریں۔ میرے کوڈ $code سے سائن اپ کریں اور پہلی بکنگ پر $amount کی رعایت پائیں: $link';
  }

  @override
  String invitedCount(int count) {
    return 'شامل ہونے والے دوست: $count';
  }

  @override
  String get iosInstallSteps =>
      'سفاری میں شیئر بٹن دبائیں، پھر “Add to Home Screen” منتخب کریں۔';

  @override
  String get iveArrived => 'میں پہنچ گیا ہوں';

  @override
  String get job => 'کام';

  @override
  String get jobAddress => 'کام کا پتہ';

  @override
  String get jobCompleted => 'کام مکمل ہو گیا۔';

  @override
  String get jobIsBooked => 'یہ کام بک ہو چکا ہے';

  @override
  String get jobLocation => 'کام کی جگہ';

  @override
  String get jobNowRepeats => 'یہ کام اب دہرایا جائے گا۔';

  @override
  String jobNumberPrice(Object id, Object price) {
    return 'کام نمبر $id · $price';
  }

  @override
  String get jobPassedOn => 'ہو گیا۔ کام دوسرے ورکرز کو بھیج دیا گیا۔';

  @override
  String get jobPosted => 'کام پوسٹ ہو گیا۔';

  @override
  String jobPostedNotified(Object n) {
    return 'کام پوسٹ ہو گیا۔ $n قریبی کاریگروں کو اطلاع دی گئی۔';
  }

  @override
  String jobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کام',
      one: '1 کام',
    );
    return '$_temp0';
  }

  @override
  String jobsDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کام مکمل',
    );
    return '$_temp0';
  }

  @override
  String get jobsNearYou => 'آپ کے قریب کام';

  @override
  String get justNow => 'ابھی ابھی';

  @override
  String get kaamnowCommission => 'کام ناؤ کمیشن';

  @override
  String kaamnowReply(Object text) {
    return 'کام ناؤ: $text';
  }

  @override
  String get labelHome => 'گھر';

  @override
  String get labelOther => 'دوسری جگہ';

  @override
  String get labelWork => 'دفتر';

  @override
  String get language => 'زبان';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String lastAttempt(Object status, Object reason) {
    return 'پچھلی کوشش: $status۔ $reason';
  }

  @override
  String lastBooked(String date) {
    return 'آپ کا آخری کام: $date';
  }

  @override
  String leaveRepeatingBody(String name) {
    return '$name کو بتا دیا جائے گا، اور آئندہ کام قریب کے دوسرے ورکرز کو جائے گا۔';
  }

  @override
  String get leaveRepeatingQ => 'یہ کام چھوڑ دیں؟';

  @override
  String get leftRepeating => 'ہو گیا۔ اب آپ کو یہ کام نہیں ملیں گے۔';

  @override
  String get levelHelp => 'KaamNow درجہ: مکمل کام، ریٹنگ اور وقت کی پابندی سے';

  @override
  String get levelNeedsVerification =>
      'اکاؤنٹ کی تصدیق کے بعد درجے شروع ہوتے ہیں۔';

  @override
  String get levelNew => 'نیا';

  @override
  String get levelRising => 'ابھرتا ہوا';

  @override
  String get levelShownHint =>
      'گاہک آپ کا درجہ آپ کی پیشکشوں اور پروفائل پر دیکھتے ہیں۔';

  @override
  String get levelTopRated => 'سب سے بہترین';

  @override
  String get levelTrusted => 'قابلِ اعتماد';

  @override
  String get linkCopied => 'لنک کاپی ہو گیا۔';

  @override
  String get linkExpired => 'یہ لنک ختم ہو چکا ہے یا بند کر دیا گیا ہے۔';

  @override
  String get live => 'لائیو';

  @override
  String get liveTracking => 'لائیو ٹریکنگ';

  @override
  String get loadMore => 'مزید دیکھیں';

  @override
  String get location => 'لوکیشن';

  @override
  String get locationDenied =>
      'لوکیشن کی اجازت نہیں دی گئی۔ آپ پھر بھی نقشے پر پن لگا سکتے ہیں۔';

  @override
  String get locationOff => 'لوکیشن سروس بند ہے۔';

  @override
  String get logIn => 'لاگ اِن';

  @override
  String get logOut => 'لاگ آؤٹ';

  @override
  String get loginWithNewPassword =>
      'اب آپ نئے پاس ورڈ سے لاگ اِن کر سکتے ہیں۔';

  @override
  String get makeDefault => 'پہلے استعمال کریں';

  @override
  String get markAllRead => 'سب پڑھ لیے';

  @override
  String get markCompleteQ => 'کام کو مکمل قرار دیں؟';

  @override
  String get maxAddressesReached =>
      'آپ کے 10 پتے ہیں، جو زیادہ سے زیادہ حد ہے۔';

  @override
  String get maxContactsReached =>
      'آپ کے 3 رابطے ہیں، جو زیادہ سے زیادہ حد ہے۔';

  @override
  String get maxPhotosReached =>
      'آپ کی 12 تصاویر ہیں، جو زیادہ سے زیادہ حد ہے۔ نئی شامل کرنے کے لیے ایک حذف کریں۔';

  @override
  String get messageNotSent => 'پیغام نہیں بھیجا جا سکا۔';

  @override
  String get messageToCustomer => 'گاہک کے لیے پیغام (اختیاری)';

  @override
  String get messagesPrivate =>
      'پیغامات صرف آپ اور اس بکنگ کے دوسرے فرد کے درمیان ہیں۔';

  @override
  String get methodCash => 'نقد';

  @override
  String get methodEasypaisa => 'ایزی پیسہ';

  @override
  String get methodJazzcash => 'جاز کیش';

  @override
  String methodRef(Object method, Object ref) {
    return '$method · حوالہ $ref';
  }

  @override
  String minPayoutHint(Object amount) {
    return 'آپ $amount سے پے آؤٹ مانگ سکتے ہیں۔';
  }

  @override
  String minimumIs(Object amount) {
    return 'کم از کم $amount';
  }

  @override
  String minutesAgo(Object n) {
    return '$n منٹ پہلے';
  }

  @override
  String get moreDetail => 'براہِ کرم کچھ مزید تفصیل دیں (20 سے زیادہ حروف)';

  @override
  String get moveEarlier => 'پہلے کریں';

  @override
  String get moveLater => 'بعد میں کریں';

  @override
  String get myLevel => 'میرا درجہ';

  @override
  String get myLevelHint => 'آپ کا درجہ، بیجز، اور اگلے درجے تک کیسے پہنچیں';

  @override
  String get myPackages => 'میرے پیکجز';

  @override
  String get myPackagesHint =>
      'مقررہ قیمت والے کام جو گاہک فوراً بک کر سکتے ہیں';

  @override
  String get myPortfolio => 'میرے کام کی تصاویر';

  @override
  String get myPortfolioHint => 'گاہکوں کو دکھائیں کہ آپ نے کیا کام کیا ہے';

  @override
  String get myReviews => 'میرے جائزے';

  @override
  String get myReviewsHint => 'دیکھیں گاہکوں نے کیا کہا اور جواب دیں';

  @override
  String get myScheduleSubtitle =>
      'وہ دن اور اوقات جب آپ کام لیتے ہیں، اور چھٹیاں';

  @override
  String get myScheduleTitle => 'میرے کام کے اوقات';

  @override
  String get myTips => 'میری ٹپس';

  @override
  String get myTipsHint => 'گاہکوں کی دی ہوئی ٹپس';

  @override
  String get myWorkerProfile => 'میرا کاریگر پروفائل';

  @override
  String get myWorkers => 'میرے ورکر';

  @override
  String get myWorkersHomeHint => 'پسندیدہ ورکر کو دوبارہ بک کریں';

  @override
  String nFree(int count) {
    return '$count فارغ';
  }

  @override
  String negAccept(Object who, Object amount) {
    return '$who نے $amount پر قبول کیا';
  }

  @override
  String negAgree(Object who, Object amount) {
    return '$who $amount پر راضی ہو گئے';
  }

  @override
  String negCounter(Object who, Object amount) {
    return '$who نے $amount کی جوابی قیمت دی';
  }

  @override
  String negOffer(Object who, Object amount) {
    return '$who نے $amount کی پیشکش کی';
  }

  @override
  String negReject(Object who) {
    return '$who نے مسترد کیا';
  }

  @override
  String negRevise(Object who, Object amount) {
    return '$who نے قیمت بدل کر $amount کر دی';
  }

  @override
  String negWithdraw(Object who) {
    return '$who نے پیشکش واپس لی';
  }

  @override
  String get networkError =>
      'کام ناؤ سے رابطہ نہیں ہو سکا۔ اپنا انٹرنیٹ کنکشن چیک کریں۔';

  @override
  String get newPassword => 'نیا پاس ورڈ';

  @override
  String nextLevelIs(Object level) {
    return '$level بننے کے لیے';
  }

  @override
  String nextVisitOn(String when) {
    return 'اگلی بار: $when';
  }

  @override
  String get no => 'نہیں';

  @override
  String get noActiveBookings => 'کوئی جاری بکنگ نہیں';

  @override
  String get noAlertsYet => 'ابھی کوئی اطلاع نہیں';

  @override
  String get noBadgesYet =>
      'ابھی کوئی بیج نہیں۔ یہ تجربے، گاہکوں کے محفوظ کرنے اور ہمیشہ وقت پر آنے سے ملتے ہیں۔';

  @override
  String get noBookingsCustomerHint =>
      'کاریگر بک کرنے کے لیے اپنی کسی درخواست پر پیشکش قبول کریں۔';

  @override
  String get noBookingsWorkerHint =>
      'جب کوئی گاہک آپ کی پیشکش قبول کرے گا تو کام یہاں نظر آئے گا۔';

  @override
  String get noCancelledBookings => 'کوئی منسوخ بکنگ نہیں';

  @override
  String get noComplaints => 'کوئی شکایت نہیں';

  @override
  String get noComplaintsHint =>
      'اگر کسی کام میں کوئی مسئلہ ہو تو یہاں رپورٹ کریں، کام ناؤ اس کا جائزہ لے گا۔';

  @override
  String get noCompletedBookings => 'کوئی مکمل بکنگ نہیں';

  @override
  String get noCompletedJobs => 'ابھی کوئی کام مکمل نہیں ہوا۔';

  @override
  String get noEmergencyContacts => 'ابھی کوئی ہنگامی رابطہ نہیں';

  @override
  String get noEmergencyContactsHint =>
      'زیادہ سے زیادہ 3 قابل اعتماد لوگ شامل کریں۔ جب آپ کام کے دوران ایس او ایس دبائیں گے تو انہیں کام دیکھنے کے لنک کے ساتھ پیغام جائے گا۔';

  @override
  String get noMessagesYet => 'ابھی کوئی پیغام نہیں';

  @override
  String get noOffers => 'کوئی پیشکش نہیں';

  @override
  String get noOffersHere => 'یہاں کوئی پیشکش نہیں';

  @override
  String get noOffersHereHint => 'آپ کی بھیجی گئی پیشکشیں یہاں نظر آئیں گی۔';

  @override
  String get noOpenJobs => 'اس وقت کوئی کام دستیاب نہیں';

  @override
  String get noOpenJobsHint =>
      'آپ کے علاقے اور خدمات کے نئے کام یہاں نظر آئیں گے، اور آپ کو اطلاع ملے گی۔';

  @override
  String get noPackagesFound => 'یہاں ابھی کوئی پیکج نہیں';

  @override
  String get noPackagesFoundHint =>
      'اس کے بجائے کام پوسٹ کریں، قریبی کاریگر آپ کو پیشکشیں بھیجیں گے۔';

  @override
  String get noPackagesYet => 'ابھی کوئی پیکج نہیں';

  @override
  String get noPortfolioHint =>
      'اپنے کیے ہوئے کاموں کی زیادہ سے زیادہ 12 تصاویر شامل کریں۔ گاہک انہیں آپ کی پروفائل پر دیکھتے ہیں۔ ہر تصویر سے مقام اور کیمرے کی تفصیلات ہٹا دی جاتی ہیں۔';

  @override
  String get noPortfolioYet => 'ابھی کام کی کوئی تصویر نہیں';

  @override
  String get noRepeatingJobs => 'کوئی دہرایا جانے والا کام نہیں';

  @override
  String get noRepeatingJobsCustomer =>
      'کوئی بکنگ کھولیں اور \"یہ کام دہرائیں\" پر ٹیپ کریں تاکہ یہ ہر ہفتے یا مہینے ہو۔';

  @override
  String get noRepeatingJobsWorker =>
      'جب کوئی گاہک آپ کے ساتھ کام دہرائے گا تو یہاں نظر آئے گا۔';

  @override
  String get noRequestsHint =>
      'قریبی کاریگروں سے قیمتیں لینے کے لیے کام پوسٹ کریں۔';

  @override
  String get noRequestsYet => 'ابھی کوئی درخواست نہیں';

  @override
  String get noReviewsYet => 'ابھی کوئی ریویو نہیں۔';

  @override
  String get noSavedAddresses => 'کوئی محفوظ پتہ نہیں';

  @override
  String get noSavedAddressesHint =>
      'گھر، دفتر اور دوسری جگہیں (زیادہ سے زیادہ 10) محفوظ کریں تاکہ کام جلدی اور درست مقام کے ساتھ پوسٹ ہو۔';

  @override
  String get noService => 'کوئی نہیں';

  @override
  String get noServicesYet => 'ابھی کوئی سروس دستیاب نہیں';

  @override
  String get noShowCustomerReported => 'رپورٹ: گاہک موجود نہیں تھا۔';

  @override
  String get noShowNoteLabel => 'کیا ہوا؟ (اختیاری)';

  @override
  String get noShowReported =>
      'رپورٹ ہو گئی۔ بکنگ منسوخ کر دی گئی ہے اور ہماری ٹیم اس کا جائزہ لے گی۔';

  @override
  String noShowWait(String time) {
    return 'آپ $time کے بعد یہ رپورٹ کر سکتے ہیں۔ پہلے فون کر کے دیکھیں۔';
  }

  @override
  String get noShowWorkerReported => 'رپورٹ: ورکر نہیں آیا۔';

  @override
  String get noSlotsLeft => 'اس دن کوئی وقت باقی نہیں۔ دوسرا دن چنیں۔';

  @override
  String get noTimeOff => 'کوئی چھٹی طے نہیں۔';

  @override
  String get noTips =>
      'ابھی کوئی ٹپ نہیں۔ اچھا کام اور خوش اخلاقی سے اکثر ٹپ ملتی ہے۔';

  @override
  String get noWorkersYet => 'ابھی کوئی ورکر نہیں';

  @override
  String get noWorkersYetHint =>
      'جو ورکر پسند آئے اس کے دل کے نشان پر ٹیپ کر کے اسے محفوظ کریں۔ جو ورکر آپ کا کام مکمل کریں وہ بھی یہاں نظر آتے ہیں۔';

  @override
  String get noneFree => 'کوئی فارغ نہیں';

  @override
  String get notNow => 'ابھی نہیں';

  @override
  String get noteOptional => 'نوٹ (اختیاری)';

  @override
  String get numberConfirmed => 'فون نمبر کنفرم ہو گیا۔';

  @override
  String get off => 'بند';

  @override
  String get offerSent => 'پیشکش بھیج دی گئی۔ گاہک کو اطلاع دی جائے گی۔';

  @override
  String get offerServices => 'خدمات پیش کرنا';

  @override
  String offersADay(Object n) {
    return 'روزانہ $n پیشکشیں';
  }

  @override
  String offersBlockedDebt(Object amount) {
    return 'آپ کے ذمے $amount سے زیادہ کمیشن ہے، اس لیے ادائیگی تک آپ آفرز نہیں بھیج سکتے۔';
  }

  @override
  String offersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پیشکشیں',
      one: '1 پیشکش',
    );
    return '$_temp0';
  }

  @override
  String offersHeading(Object n) {
    return 'پیشکشیں ($n)';
  }

  @override
  String offersLeftToday(Object n) {
    return 'آج $n پیشکشیں باقی ہیں';
  }

  @override
  String get ok => 'ٹھیک ہے';

  @override
  String get onlinePaymentSoon =>
      'آن لائن ادائیگی جلد آ رہی ہے۔ اپ گریڈ کے لیے کام ناؤ سپورٹ سے رابطہ کریں۔';

  @override
  String get onlinePaymentUnavailable =>
      'اس ڈیوائس پر ابھی آن لائن ادائیگی دستیاب نہیں۔';

  @override
  String get onlyAvailableGetAlerts =>
      'صرف دستیاب کاریگروں کو نئے کام کی اطلاع ملتی ہے۔';

  @override
  String get onlyIfDone => 'صرف تب تصدیق کریں جب کام ہو چکا ہو۔';

  @override
  String get openAction => 'کھولیں';

  @override
  String get openBooking => 'بکنگ کھولیں';

  @override
  String get osmCredit => '© OpenStreetMap contributors';

  @override
  String get otherDay => 'دوسرا دن';

  @override
  String get packageBooked => 'بک ہو گیا! کاریگر کو اطلاع دے دی گئی ہے۔';

  @override
  String packageBookedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بار بک ہوا',
    );
    return '$_temp0';
  }

  @override
  String get packageChooseAddress => 'پتہ چنیں، یا اپنی لوکیشن استعمال کریں۔';

  @override
  String get packageDeleted => 'پیکج حذف ہو گیا۔';

  @override
  String get packageDescription => 'تفصیل (اختیاری)';

  @override
  String get packageDuration => 'کتنا وقت لگتا ہے';

  @override
  String get packageFixedPriceNote =>
      'گاہک بالکل یہی قیمت ادا کرتے ہیں۔ جو پرزے یا اضافی کام درج نہیں، وہ کام شروع کرنے سے پہلے چیٹ میں طے کریں۔';

  @override
  String packageHiddenByAdmin(Object reason) {
    return 'KaamNow نے چھپا دیا: $reason';
  }

  @override
  String get packageIncludes => 'کیا شامل ہے (ہر لائن میں ایک)';

  @override
  String get packageIncludesHint => 'فلٹر کی دھلائی\nگیس پریشر چیک';

  @override
  String get packageIncludesTooLong => 'ہر لائن 80 حروف سے کم رکھیں۔';

  @override
  String get packageIncludesTooMany => 'زیادہ سے زیادہ 8 چیزیں لکھیں۔';

  @override
  String get packageLive => 'پیکج دوبارہ چالو ہے۔';

  @override
  String get packageNoBidding =>
      'مقررہ قیمت۔ کوئی پیشکش یا مول تول نہیں۔ کام مکمل ہونے کے بعد ادائیگی کریں۔';

  @override
  String get packageNotes => 'کاریگر کے لیے ہدایات (اختیاری)';

  @override
  String get packageNotesHint => 'مثلاً گیٹ کوڈ، اے سی کا برانڈ، منزل';

  @override
  String get packagePaused => 'پیکج روک دیا گیا۔ اب گاہک اسے نہیں دیکھتے۔';

  @override
  String get packagePausedLabel => 'روکا ہوا';

  @override
  String get packagePrice => 'مقررہ قیمت';

  @override
  String get packagePriceLabel => 'پیکج کی قیمت';

  @override
  String get packageSaved => 'پیکج محفوظ ہو گیا۔';

  @override
  String get packageShown => 'گاہکوں کو دکھایا جا رہا ہے';

  @override
  String get packageTitle => 'پیکج کا نام';

  @override
  String get packageTitleHint => 'مثلاً اے سی سروس (1 یونٹ)';

  @override
  String packageTotal(Object amount) {
    return 'کل: $amount';
  }

  @override
  String get packageWhen => 'کب';

  @override
  String get packageWhere => 'کہاں';

  @override
  String get packageWriteAddress => 'پورا پتہ لکھیں (مکان، گلی، بلاک)۔';

  @override
  String get packagesBrowseIntro =>
      'ہر پیکج کی قیمت مقرر ہے۔ ایسا وقت چنیں جب کاریگر فارغ ہو، اور آپ کی بکنگ فوراً پکی ہو جائے گی۔';

  @override
  String get packagesHomeHint =>
      'طے شدہ کام، طے شدہ قیمت پر بک کریں، بغیر مول تول کے';

  @override
  String get packagesIntro =>
      'طے شدہ کام طے شدہ قیمت پر پیش کریں، جیسے \"اے سی سروس، 2,500 روپے\"۔ گاہک آپ کے فارغ وقت پر بغیر مول تول کے بک کرتے ہیں۔';

  @override
  String packagesLimit(int n) {
    return 'آپ زیادہ سے زیادہ $n پیکج رکھ سکتے ہیں۔';
  }

  @override
  String packagesNear(Object place) {
    return 'وہ کاریگر دکھائے جا رہے ہیں جو $place آتے ہیں';
  }

  @override
  String get packagesNeedService =>
      'پہلے اپنی پروفائل میں سروس شامل کریں، پھر اس کے پیکج بنائیں۔';

  @override
  String paidAmount(Object amount) {
    return '$amount ادا ہو گئے';
  }

  @override
  String get password => 'پاس ورڈ';

  @override
  String get passwordChanged => 'پاس ورڈ تبدیل ہو گیا';

  @override
  String get passwordChangedShort => 'پاس ورڈ تبدیل ہو گیا۔';

  @override
  String get passwordsDontMatch => 'دونوں پاس ورڈ ایک جیسے نہیں ہیں';

  @override
  String get pastWork => 'پچھلا کام';

  @override
  String get pauseRepeating => 'روکیں';

  @override
  String get pausedRepeating =>
      'روک دیا گیا۔ دوبارہ شروع کرنے تک کوئی کام نہیں ہوگا۔';

  @override
  String get payCash =>
      'کاریگر کو نقد ادائیگی کریں۔ رقم ملنے پر وہ تصدیق کریں گے۔';

  @override
  String get payCommission => 'کمیشن ادا کریں';

  @override
  String get payCommissionOffice =>
      'دستیاب ہو تو آن لائن ادا کریں، یا کام ناؤ کے دفتر میں جمع کروائیں، وہ اسے درج کر لیں گے۔';

  @override
  String payWith(Object method) {
    return '$method سے ادائیگی کریں';
  }

  @override
  String get payment => 'ادائیگی';

  @override
  String get paymentConfirmed => 'ادائیگی کی تصدیق ہو گئی۔';

  @override
  String get paymentPageFailed =>
      'ادائیگی کا صفحہ نہیں کھل سکا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String paymentPending(Object method, Object amount) {
    return '$amount کی $method ادائیگی زیرِ التوا';
  }

  @override
  String paymentRefunded(Object amount) {
    return 'آپ کی $amount کی ادائیگی واپس کر دی گئی۔';
  }

  @override
  String get paymentWindowClosed =>
      'گیٹ وے کی تصدیق کے بعد یہ صفحہ اپ ڈیٹ ہو جائے گا۔';

  @override
  String get payoutCancelled => 'پے آؤٹ کی درخواست منسوخ ہو گئی۔';

  @override
  String payoutOpen(Object amount) {
    return '$amount کے پے آؤٹ کی درخواست جاری ہے';
  }

  @override
  String payoutOpenHint(Object method, Object account) {
    return '$method $account میں۔ اس میں شامل کام بھیجے جانے یا مسترد ہونے تک آپ کے بیلنس میں شمار نہیں ہوتے۔';
  }

  @override
  String get payoutRequested => 'پے آؤٹ کی درخواست ہو گئی۔ ہم جلد بھیج دیں گے۔';

  @override
  String get payoutTo => 'یہاں بھیجیں';

  @override
  String get periodCustom => 'تاریخیں منتخب کریں';

  @override
  String get periodLastMonth => 'پچھلے مہینے';

  @override
  String periodRange(Object start, Object end) {
    return '$start سے $end تک';
  }

  @override
  String get periodThisMonth => 'اس مہینے';

  @override
  String get periodThisWeek => 'اس ہفتے';

  @override
  String get periodThisYear => 'اس سال';

  @override
  String get phoneNumber => 'فون نمبر';

  @override
  String get photoAdded => 'تصویر شامل ہو گئی۔';

  @override
  String get photoCaptionLabel => 'تصویر میں کیا ہے؟ (اختیاری)';

  @override
  String get photoDeleted => 'تصویر حذف ہو گئی۔';

  @override
  String photoHiddenBy(String reason) {
    return 'کام ناؤ نے چھپا دی: $reason';
  }

  @override
  String get photoServiceLabel => 'خدمت (اختیاری)';

  @override
  String get photoUpdated => 'تصویر اپ ڈیٹ ہو گئی۔';

  @override
  String photosCount(int count, int max) {
    return '$max میں سے $count تصاویر';
  }

  @override
  String get photosOptional => 'تصاویر (اختیاری)';

  @override
  String get pickATime => 'پہلے وقت چنیں۔';

  @override
  String get pinPlaced => 'پن لگ گیا۔ جگہ بدلنے کے لیے نقشے پر ٹیپ کریں۔';

  @override
  String get placeNameHint => 'جیسے امی کا گھر';

  @override
  String get placeNameLabel => 'اس جگہ کا نام';

  @override
  String get planPaymentWindowClosed =>
      'ادائیگی کی تصدیق ہوتے ہی آپ کا پلان فعال ہو جائے گا۔';

  @override
  String get plans => 'پلان';

  @override
  String get postAJob => 'کام پوسٹ کریں';

  @override
  String get postJobGetOffers => 'کام پوسٹ کریں اور پیشکشیں لیں';

  @override
  String get preferredTime => 'پسندیدہ وقت';

  @override
  String pricePerDays(Object price, Object days) {
    return '$price / $days دن';
  }

  @override
  String get profileSaved => 'پروفائل محفوظ ہو گیا۔';

  @override
  String get profileUpdated => 'پروفائل اپ ڈیٹ ہو گیا۔';

  @override
  String promoApplied(Object code, Object amount) {
    return '$code: $amount کی رعایت';
  }

  @override
  String get promoCode => 'پرومو کوڈ';

  @override
  String get pushBlockedHint =>
      'آپ کے براؤزر میں بند ہیں۔ براؤزر کی سیٹنگز میں اس سائٹ کے لیے نوٹیفکیشنز کی اجازت دیں۔';

  @override
  String get pushBlockedHintPhone =>
      'آپ کے فون کی سیٹنگز میں بند ہیں۔ سیٹنگز میں کام ناؤ کے لیے نوٹیفکیشنز کی اجازت دیں۔';

  @override
  String get pushHintCustomer =>
      'کاریگروں کی پیشکش اور بکنگ میں تبدیلی کا فوراً پتا چلے۔';

  @override
  String get pushHintWorker =>
      'قریب نئے کام اور گاہکوں کے جواب کی فوراً اطلاع پائیں۔';

  @override
  String get pushNeedsInstallHint =>
      'آئی فون پر پہلے کام ناؤ انسٹال کریں (شیئر، پھر “Add to Home Screen”)، پھر انسٹال شدہ ایپ میں اسے آن کریں۔';

  @override
  String get pushNotAllowed => 'نوٹیفکیشنز کی اجازت نہیں دی گئی۔';

  @override
  String get pushOffHint => 'بند: اطلاعات صرف ایپ کے اندر نظر آئیں گی۔';

  @override
  String get pushOnHint =>
      'آن: پیشکش، بکنگ اور پیغامات کی اطلاع کام ناؤ بند ہونے پر بھی آئے گی۔';

  @override
  String get pushSetting => 'اس ڈیوائس پر نوٹیفکیشنز';

  @override
  String get pushTitle => 'اس ڈیوائس پر اطلاعات حاصل کریں';

  @override
  String get pushTurnedOn => 'اس ڈیوائس پر نوٹیفکیشنز آن ہو گئیں۔';

  @override
  String get rateThisJob => 'اس کام کو ریٹ کریں';

  @override
  String rateWorker(Object name) {
    return '$name کو ریٹ کریں';
  }

  @override
  String get ratingNew => 'نیا';

  @override
  String get reason => 'وجہ';

  @override
  String reasonLine(Object reason) {
    return 'وجہ: $reason';
  }

  @override
  String get reasonOptional => 'وجہ (اختیاری)';

  @override
  String get receiptBilledTo => 'گاہک';

  @override
  String get receiptBooking => 'بکنگ';

  @override
  String get receiptDate => 'تاریخ';

  @override
  String get receiptDownloaded => 'رسید ڈاؤن لوڈ ہو گئی۔';

  @override
  String get receiptFooter =>
      'یہ رسید کمپیوٹر سے بنی ہے اور اس پر دستخط کی ضرورت نہیں۔';

  @override
  String get receiptJob => 'کام';

  @override
  String get receiptNumber => 'رسید نمبر';

  @override
  String get receiptPaidAfterRefunds => 'واپسی کے بعد ادائیگی';

  @override
  String get receiptPaidBy => 'ادائیگی کا طریقہ';

  @override
  String receiptRefundOn(Object date) {
    return '$date کو رقم واپس';
  }

  @override
  String get receiptRefundedTitle => 'رسید (رقم واپس)';

  @override
  String get receiptService => 'سروس';

  @override
  String receiptTaxNumber(Object number) {
    return 'ٹیکس نمبر: $number';
  }

  @override
  String get receiptTitle => 'رسید';

  @override
  String get receiptTotalPaid => 'کل ادائیگی';

  @override
  String get receiptTransactionId => 'ٹرانزیکشن آئی ڈی';

  @override
  String get receiptWorkDoneBy => 'کام کرنے والا';

  @override
  String get received => 'مل گئے';

  @override
  String get recentJobs => 'حالیہ کام';

  @override
  String get recentVisits => 'حالیہ کام';

  @override
  String get reconnecting => 'دوبارہ جڑ رہا ہے…';

  @override
  String refundedToCustomer(Object amount) {
    return 'گاہک کو واپس کیے گئے: $amount';
  }

  @override
  String refundedToYou(Object amount) {
    return 'آپ کو واپس کیے گئے: $amount';
  }

  @override
  String get reject => 'مسترد کریں';

  @override
  String get rejectOfferQ => 'یہ پیشکش مسترد کریں؟';

  @override
  String get remove => 'ہٹائیں';

  @override
  String removeContactQ(String name) {
    return '$name کو ہٹائیں؟';
  }

  @override
  String get removeFromFavourites => 'محفوظ کردہ سے ہٹائیں';

  @override
  String get removePromo => 'ہٹائیں';

  @override
  String removeServiceQ(Object name) {
    return '$name ہٹائیں؟';
  }

  @override
  String get removeTimeOffBody => 'ان دنوں آپ کو دوبارہ کاموں کی اطلاع ملے گی۔';

  @override
  String get removeTimeOffTitle => 'یہ چھٹیاں ہٹائیں؟';

  @override
  String renewsOrEnds(Object date) {
    return '$date کو تجدید یا ختم';
  }

  @override
  String get repeatNewPassword => 'نیا پاس ورڈ دوبارہ لکھیں';

  @override
  String repeatSheetHint(String name) {
    return 'ہر بار سے دو دن پہلے $name کو یہ کام دوبارہ بکنگ کی درخواست کے طور پر ملے گا۔ اگر وہ فارغ نہ ہوں تو یہ قریب کے دوسرے ورکرز کو جائے گا۔ ہر بار آپ خود آفر قبول کریں گے۔';
  }

  @override
  String get repeatThisJob => 'یہ کام دہرائیں';

  @override
  String get repeatingJobs => 'دہرائے جانے والے کام';

  @override
  String get repeatingJobsCustomerHint =>
      'ایک ہی ورکر کے ساتھ دہرائے جانے والے کام';

  @override
  String get repeatingJobsWorkerHint => 'وہ گاہک جو ہر بار آپ کو چاہتے ہیں';

  @override
  String get reportAverage => 'فی کام اوسط';

  @override
  String reportBooking(Object id) {
    return 'بکنگ نمبر $id رپورٹ کریں';
  }

  @override
  String get reportByPayment => 'گاہکوں نے کیسے ادائیگی کی';

  @override
  String get reportByService => 'سروس کے لحاظ سے';

  @override
  String get reportByTime => 'وقت کے ساتھ کمائی';

  @override
  String get reportCash => 'نقد (آپ کے پاس)';

  @override
  String reportChangeDown(Object percent, int days) {
    return 'پچھلے $days دنوں سے $percent% کم';
  }

  @override
  String reportChangeUp(Object percent, int days) {
    return 'پچھلے $days دنوں سے $percent% زیادہ';
  }

  @override
  String get reportEmpty => 'ان تاریخوں میں کوئی کام مکمل نہیں ہوا۔';

  @override
  String get reportJobs => 'مکمل کام';

  @override
  String reportJobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کام',
      one: '1 کام',
    );
    return '$_temp0';
  }

  @override
  String get reportNet => 'آپ کی کمائی';

  @override
  String reportNoChange(int days) {
    return 'پچھلے $days دنوں جتنی';
  }

  @override
  String get reportNoShow => 'رپورٹ اور منسوخ کریں';

  @override
  String get reportOnline => 'آن لائن (KaamNow کے پاس)';

  @override
  String reportPreviousNone(int days) {
    return 'پچھلے $days دنوں میں کوئی کمائی نہیں';
  }

  @override
  String get reportProblem => 'مسئلہ رپورٹ کریں';

  @override
  String reportRefundShares(Object amount) {
    return 'رقم کی واپسی میں آپ کا حصہ کٹا: $amount';
  }

  @override
  String get reportUnpaid => 'ابھی ادائیگی نہیں ہوئی';

  @override
  String reqCancelRate(int days, Object value, Object target) {
    return '$days دنوں میں آپ کی منسوخ کردہ بکنگز: $value% (زیادہ سے زیادہ $target%)';
  }

  @override
  String reqJobs(Object value, Object target) {
    return 'مکمل کام: $target میں سے $value';
  }

  @override
  String reqNoShows(int days, Object value, Object target) {
    return '$days دنوں میں تصدیق شدہ غیر حاضری: $value (زیادہ سے زیادہ $target)';
  }

  @override
  String reqRating(Object value, Object target) {
    return 'اوسط ریٹنگ: $value (کم از کم $target)';
  }

  @override
  String reqReviews(Object value, Object target) {
    return 'ریویوز: $target میں سے $value';
  }

  @override
  String get request => 'درخواست';

  @override
  String get requestCancelled => 'درخواست منسوخ ہو گئی۔';

  @override
  String get requestFailed => 'درخواست ناکام رہی۔';

  @override
  String requestPayoutOf(Object amount) {
    return '$amount مانگیں';
  }

  @override
  String get requiredField => 'ضروری ہے';

  @override
  String resendIn(int seconds) {
    return '$seconds سیکنڈ بعد نیا کوڈ بھیجیں';
  }

  @override
  String get resetLinkIncomplete => 'یہ ری سیٹ لنک نامکمل ہے';

  @override
  String get resetLinkIncompleteHint =>
      'ای میل والا لنک دوبارہ کھولیں، یا لاگ اِن اسکرین سے نیا لنک منگوائیں۔';

  @override
  String get resetLinkSent =>
      'اگر اس نمبر کا اکاؤنٹ ای میل کے ساتھ موجود ہے تو ری سیٹ لنک بھیج دیا گیا ہے۔';

  @override
  String get resetPassword => 'پاس ورڈ ری سیٹ کریں';

  @override
  String get resumeRepeating => 'دوبارہ شروع کریں';

  @override
  String get resumedRepeating => 'دوبارہ شروع ہو گیا۔';

  @override
  String get reviewAddPhotos => 'تصاویر شامل کریں';

  @override
  String get reviewPhotoFailed =>
      'آپ کا جائزہ محفوظ ہو گیا، لیکن ایک تصویر اپ لوڈ نہیں ہو سکی۔';

  @override
  String reviewPhotosHint(Object count) {
    return 'مکمل کام کی زیادہ سے زیادہ $count تصاویر۔ مقام کی معلومات ہٹا دی جاتی ہیں۔';
  }

  @override
  String get reviewRemovePhoto => 'تصویر ہٹائیں';

  @override
  String get reviewReply => 'جواب دیں';

  @override
  String get reviewReplyHint =>
      'آپ کا جواب سب دیکھ سکتے ہیں۔ آپ ایک بار جواب دے سکتے ہیں۔';

  @override
  String get reviewReplyLabel => 'آپ کا جواب';

  @override
  String get reviewReplySent => 'جواب شائع ہو گیا۔';

  @override
  String get reviewReplyTitle => 'اس جائزے کا جواب دیں';

  @override
  String reviewWorkerReply(Object name) {
    return '$name کا جواب';
  }

  @override
  String reviewsHeading(Object n) {
    return 'ریویوز ($n)';
  }

  @override
  String get reviewsWithPhotos => 'تصاویر والے';

  @override
  String rewardsEarned(Object amount) {
    return 'حاصل شدہ انعامات: $amount';
  }

  @override
  String get rsPrefix => 'روپے ';

  @override
  String rupees(Object amount) {
    return '$amount روپے';
  }

  @override
  String get rupeesUnknown => '— روپے';

  @override
  String salam(Object name) {
    return 'السلام علیکم، $name';
  }

  @override
  String get samePriceAcceptInstead => 'یہی موجودہ قیمت ہے۔ اسے قبول کر لیں۔';

  @override
  String get save => 'محفوظ کریں';

  @override
  String get saveHours => 'اوقات محفوظ کریں';

  @override
  String get saveNewPassword => 'نیا پاس ورڈ محفوظ کریں';

  @override
  String get saveProfile => 'پروفائل محفوظ کریں';

  @override
  String get saveThisPlace => 'یہ جگہ محفوظ کریں';

  @override
  String get saveToFavourites => 'ورکر محفوظ کریں';

  @override
  String get savedAddresses => 'محفوظ پتے';

  @override
  String get savedAddressesHint =>
      'گھر، دفتر اور دوسری جگہیں جہاں سے آپ بکنگ کرتے ہیں';

  @override
  String get savedPlaces => 'آپ کی جگہیں';

  @override
  String get savedWorkers => 'محفوظ کردہ';

  @override
  String get saving => 'محفوظ ہو رہا ہے…';

  @override
  String get scheduleExplain =>
      'آپ کو صرف اپنے کام کے اوقات کے اندر والے کاموں کی اطلاع ملتی ہے اور انہی پر آفر بھیج سکتے ہیں۔ ایمرجنسی کام آپ تک تب پہنچتے ہیں جب آپ نے خود کو دستیاب رکھا ہو۔';

  @override
  String get scheduleSaved => 'کام کے اوقات محفوظ ہو گئے۔';

  @override
  String get securePayment => 'محفوظ ادائیگی';

  @override
  String get send => 'بھیجیں';

  @override
  String get sendCode => 'کوڈ بھیجیں';

  @override
  String get sendNewCode => 'نیا کوڈ بھیجیں';

  @override
  String get sendOffer => 'پیشکش بھیجیں';

  @override
  String get sendReport => 'رپورٹ بھیجیں';

  @override
  String get sendResetLink => 'ری سیٹ لنک بھیجیں';

  @override
  String get sendSos => 'ایس او ایس بھیجیں';

  @override
  String get sendToEveryone => 'سب کو بھیجیں';

  @override
  String get sendYourPrice => 'اپنی قیمت بھیجیں';

  @override
  String get sendingEvery15 =>
      'جب تک یہ صفحہ کھلا ہے، ہر 15 سیکنڈ بعد بھیجی جا رہی ہے۔';

  @override
  String sentAgo(Object when) {
    return 'بھیجی گئی $when';
  }

  @override
  String sentOnlyTo(String name) {
    return 'صرف $name کو بھیجا گیا۔ اگر وہ نہ آ سکیں تو کام قریبی تمام ورکرز کو بھیج دیں۔';
  }

  @override
  String get serverTrouble =>
      'کام ناؤ کو اس وقت مسئلہ درپیش ہے۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get service => 'سروس';

  @override
  String get serviceAdded => 'سروس شامل ہو گئی۔';

  @override
  String get services => 'خدمات';

  @override
  String get setLocationFirst =>
      'نقشے پر کام کی جگہ لگائیں، یا اپنی موجودہ لوکیشن استعمال کریں۔';

  @override
  String get setPinFirst => 'پہلے نقشے پر پن لگائیں۔';

  @override
  String get settlementCollection => 'کمیشن ادا کیا';

  @override
  String get settlementHistory => 'پے آؤٹس اور ادائیگیاں';

  @override
  String settlementLine(Object date, Object method) {
    return '$date · $method';
  }

  @override
  String get settlementPayout => 'آپ کو پے آؤٹ';

  @override
  String get shareLiveLocation => 'گاہک کے ساتھ اپنی لائیو لوکیشن شیئر کریں';

  @override
  String get shareTrip => 'گھر والوں سے شیئر کریں';

  @override
  String shareTripHint(String when) {
    return 'اس لنک والا کوئی بھی شخص کام کی صورتحال دیکھ سکتا ہے، اور جب ورکر راستے میں ہو تو وہ کہاں ہے۔ اس میں فون نمبر یا پتا کبھی نظر نہیں آتا۔ یہ $when کام کرنا بند کر دے گا۔';
  }

  @override
  String sharedByName(String name) {
    return '$name نے یہ کام آپ کے ساتھ شیئر کیا ہے';
  }

  @override
  String get sharedJobTitle => 'شیئر کیا گیا کام';

  @override
  String sharedLinkEnds(String when) {
    return 'یہ لنک $when کام کرنا بند کر دے گا۔';
  }

  @override
  String sharingOn(String time) {
    return 'گھر والوں سے $time تک شیئر کیا گیا';
  }

  @override
  String get sharingStopped => 'شیئر کرنا بند ہو گیا۔ لنک اب کام نہیں کرتا۔';

  @override
  String get shortBio => 'مختصر تعارف';

  @override
  String get showMore => 'مزید دکھائیں';

  @override
  String get sixDigitCode => 'گاہک سے ملا 6 ہندسوں کا کوڈ';

  @override
  String get skipNextVisit => 'اگلی بار چھوڑ دیں';

  @override
  String get skippedNextVisit => 'اگلی بار چھوڑ دی گئی۔';

  @override
  String get smsCode => '6 ہندسوں کا کوڈ';

  @override
  String get somethingWentWrong => 'کچھ غلط ہو گیا۔';

  @override
  String get somethingWrong => 'کچھ غلط ہو گیا۔';

  @override
  String get sortFastest => 'سب سے جلد آمد';

  @override
  String get sortHighestRating => 'بہترین ریٹنگ';

  @override
  String get sortLowestPrice => 'کم ترین قیمت';

  @override
  String get sortMostExperience => 'سب سے زیادہ تجربہ';

  @override
  String get sortMostJobs => 'سب سے زیادہ کام';

  @override
  String get sortNearest => 'سب سے قریب';

  @override
  String get sosBody =>
      'کام ناؤ کی ٹیم کو فوراً اطلاع ملے گی، اور آپ کے ہنگامی رابطوں کو اس کام کو دیکھنے کا لنک بھیجا جائے گا۔ دوسرے شخص کو نہیں بتایا جائے گا۔ اگر آپ خطرے میں ہیں تو پہلے 15 (پولیس) یا 1122 (ریسکیو) پر کال کریں۔';

  @override
  String get sosButton => 'ایس او ایس';

  @override
  String sosContactsTexted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ہنگامی رابطوں کو پیغام بھیجا گیا۔',
      zero: 'کسی ہنگامی رابطے کو پیغام نہیں گیا۔',
    );
    return '$_temp0';
  }

  @override
  String get sosNoteLabel => 'کیا ہو رہا ہے؟ (اختیاری)';

  @override
  String get sosOpenBanner =>
      'آپ کا ایس او ایس کھلا ہے۔ کام ناؤ کی ٹیم آپ کو کال کرے گی۔ اگر آپ خطرے میں ہیں تو 15 پر کال کریں۔';

  @override
  String get sosSeenBanner =>
      'کام ناؤ نے آپ کا ایس او ایس دیکھ لیا ہے اور اس پر کام کر رہی ہے۔';

  @override
  String get sosSent =>
      'ایس او ایس بھیج دیا گیا۔ ہماری ٹیم ابھی آپ کو کال کرے گی۔';

  @override
  String get sosTitle => 'مدد چاہیے؟';

  @override
  String get startRepeating => 'دہرانا شروع کریں';

  @override
  String get startWork => 'کام شروع کریں';

  @override
  String get startingPriceOptional => 'ابتدائی قیمت (اختیاری)';

  @override
  String get statementReady => 'اسٹیٹمنٹ ڈاؤن لوڈ ہو گئی۔';

  @override
  String get statusAccepted => 'قبول';

  @override
  String get statusActive => 'فعال';

  @override
  String get statusArrived => 'پہنچ گئے';

  @override
  String get statusBooked => 'بک ہو گیا';

  @override
  String get statusCancelled => 'منسوخ';

  @override
  String get statusCollected => 'وصول شدہ';

  @override
  String get statusCompleted => 'مکمل';

  @override
  String get statusConfirmed => 'تصدیق شدہ';

  @override
  String get statusDisputed => 'متنازع';

  @override
  String get statusExpired => 'میعاد ختم';

  @override
  String get statusFailed => 'ناکام';

  @override
  String get statusInProgress => 'کام جاری ہے';

  @override
  String get statusInReview => 'جائزے میں';

  @override
  String get statusOffered => 'پیشکش دی';

  @override
  String get statusOnTheWay => 'راستے میں';

  @override
  String get statusOpen => 'کھلا';

  @override
  String get statusPaid => 'ادا شدہ';

  @override
  String get statusPaused => 'رکا ہوا';

  @override
  String get statusPending => 'زیرِ التوا';

  @override
  String get statusPendingPayment => 'ادائیگی کا انتظار';

  @override
  String get statusRefunded => 'رقم واپس';

  @override
  String get statusRejected => 'مسترد';

  @override
  String get statusRequested => 'درخواست کی گئی';

  @override
  String get statusResolved => 'حل ہو گیا';

  @override
  String statusUpdated(Object status) {
    return 'اسٹیٹس اپ ڈیٹ ہو گیا: $status';
  }

  @override
  String get statusVerified => 'تصدیق شدہ';

  @override
  String get statusWithdrawn => 'واپس لے لی';

  @override
  String get stopGettingJobs => 'آپ کو یہ کام ملنا بند ہو جائیں گے۔';

  @override
  String get stopRepeating => 'دہرانا بند کریں';

  @override
  String get stopRepeatingBody =>
      'مزید کوئی کام پوسٹ نہیں ہوگا۔ پہلے سے پوسٹ کیے گئے کام ویسے ہی رہیں گے۔';

  @override
  String get stopRepeatingQ => 'یہ کام دہرانا بند کریں؟';

  @override
  String get stopSharing => 'شیئر کرنا بند کریں';

  @override
  String get stoppedRepeating => 'بند کر دیا گیا۔';

  @override
  String get subject => 'موضوع';

  @override
  String get submit => 'جمع کریں';

  @override
  String supportEmail(Object email) {
    return 'سپورٹ: $email';
  }

  @override
  String get switchToPlan => 'یہ پلان لیں';

  @override
  String switchedTo(Object name) {
    return '$name پر منتقل ہو گئے۔';
  }

  @override
  String get tabAccount => 'اکاؤنٹ';

  @override
  String get tabAlerts => 'اطلاعات';

  @override
  String get tabBookings => 'بکنگز';

  @override
  String get tabHome => 'ہوم';

  @override
  String get tabJobs => 'کام';

  @override
  String get tabMyOffers => 'میری پیشکشیں';

  @override
  String get tabMyRequests => 'میری درخواستیں';

  @override
  String get tagline => 'لاہور میں قابلِ اعتماد مدد، آپ کی قیمت پر';

  @override
  String get tapMapToPin => 'پن لگانے کے لیے نقشے پر ٹیپ کریں۔';

  @override
  String get tellUsWhatHappened => 'ہمیں بتائیں کیا ہوا';

  @override
  String get textMyContacts => 'اپنے ہنگامی رابطوں کو بھیجیں';

  @override
  String get thanksForReview => 'ریویو کا شکریہ!';

  @override
  String get thanksWillReview => 'شکریہ۔ کام ناؤ آپ کی رپورٹ کا جائزہ لے گا۔';

  @override
  String get timeOff => 'چھٹیاں';

  @override
  String get timeOffAdded => 'چھٹیاں شامل ہو گئیں۔';

  @override
  String get timeOffExplain =>
      'تعطیل، شادی یا رخصت۔ ان دنوں آپ کو نئے کام نہیں ملیں گے۔';

  @override
  String get timeOffReasonLabel => 'وجہ (اختیاری، صرف آپ دیکھ سکتے ہیں)';

  @override
  String get timeOffReasonTitle => 'چھٹی کی وجہ';

  @override
  String timeRange(String start, String end) {
    return '$start سے $end تک';
  }

  @override
  String timeWindow(String start, String end) {
    return '$start سے $end تک';
  }

  @override
  String get timeline => 'ٹائم لائن';

  @override
  String get tipCancelled => 'ٹپ منسوخ ہو گئی۔';

  @override
  String get tipCashOption => 'نقد، کاریگر کو ہاتھ میں';

  @override
  String get tipCashSent => 'شکریہ! کاریگر نقد ملنے کی تصدیق کرے گا۔';

  @override
  String get tipChange => 'ٹپ بدلیں';

  @override
  String get tipConfirmed => 'ٹپ کی تصدیق ہو گئی۔ شکریہ!';

  @override
  String get tipGotIt => 'مل گئی';

  @override
  String tipHint(Object name) {
    return 'پوری ٹپ $name کو جاتی ہے۔ KaamNow کچھ نہیں رکھتا۔';
  }

  @override
  String get tipHow => 'آپ کیسے ادا کریں گے؟';

  @override
  String get tipMessage => 'کاریگر کے لیے پیغام (اختیاری)';

  @override
  String get tipNotReceived => 'نہیں ملی';

  @override
  String get tipNotReceivedBody =>
      'ٹپ منسوخ کر دی جائے گی اور گاہک کو بتا دیا جائے گا۔';

  @override
  String get tipNotReceivedQ => 'نقد ٹپ نہیں ملی؟';

  @override
  String get tipOther => 'دوسری رقم (روپے)';

  @override
  String tipPaidCustomer(Object amount) {
    return 'آپ نے $amount ٹپ دی۔ شکریہ!';
  }

  @override
  String tipPendingCash(Object amount) {
    return 'آپ کی $amount کی نقد ٹپ کاریگر کی تصدیق کی منتظر ہے۔';
  }

  @override
  String tipPendingOnline(Object amount) {
    return 'آپ کی $amount کی ٹپ ابھی ادا نہیں ہوئی۔';
  }

  @override
  String tipRange(Object min, Object max) {
    return '$min سے $max تک لکھیں';
  }

  @override
  String get tipSend => 'ٹپ بھیجیں';

  @override
  String get tipStatusCancelled => 'منسوخ';

  @override
  String get tipStatusPaid => 'موصول';

  @override
  String get tipStatusPending => 'منتظر';

  @override
  String get tipTitle => 'ٹپ دے کر شکریہ ادا کریں';

  @override
  String tipWorker(Object name) {
    return '$name کو ٹپ دیں';
  }

  @override
  String tipWorkerPaid(Object amount) {
    return 'آپ کو $amount ٹپ ملی!';
  }

  @override
  String tipWorkerPending(Object amount) {
    return 'گاہک کہتا ہے کہ اس نے آپ کو $amount نقد ٹپ دی۔';
  }

  @override
  String tipWorkerPendingOnline(Object amount) {
    return 'گاہک نے $amount کی آن لائن ٹپ شروع کی ہے۔';
  }

  @override
  String tipsTotal(Object count, Object amount) {
    return 'موصول ٹپس: $count · کل $amount';
  }

  @override
  String get titleHint => 'مثلاً چھت کا پنکھا نہیں چل رہا';

  @override
  String get titleLabel => 'عنوان';

  @override
  String get titleTooShort => 'عنوان بہت چھوٹا ہے۔';

  @override
  String get toWord => 'سے';

  @override
  String get topLevelReached =>
      'آپ سب سے اونچے درجے پر ہیں۔ یوں ہی جاری رکھیں!';

  @override
  String get total => 'کل';

  @override
  String get trackingStarts =>
      'کاریگر کے روانہ ہوتے ہی ٹریکنگ شروع ہو جائے گی۔';

  @override
  String get tryAgain => 'دوبارہ کوشش کریں';

  @override
  String get turnOn => 'آن کریں';

  @override
  String get typeMessage => 'پیغام لکھیں';

  @override
  String get unlimitedOffers => 'لامحدود پیشکشیں';

  @override
  String get updateDocsTryAgain =>
      'اپنی دستاویزات اپ ڈیٹ کریں اور دوبارہ کوشش کریں۔';

  @override
  String updatedAgo(Object when) {
    return 'اپ ڈیٹ $when';
  }

  @override
  String get upload => 'اپ لوڈ';

  @override
  String urgentSubtitle(Object fee) {
    return 'کاریگروں کو سب سے پہلے دکھایا جائے گا۔ $fee اضافی فیس لگے گی۔';
  }

  @override
  String get urgentTitle => 'جلدی ہے؟ اپنے کام کو ایمرجنسی بنائیں';

  @override
  String get useAtLeast8 => 'کم از کم 8 حروف استعمال کریں';

  @override
  String useCredit(Object amount) {
    return 'میرا کریڈٹ استعمال کریں ($amount)';
  }

  @override
  String get useFirstSwitch => 'کام پوسٹ کرتے وقت یہ پتہ پہلے استعمال کریں';

  @override
  String get useMyLocation => 'میری لوکیشن استعمال کریں';

  @override
  String validUntil(Object time) {
    return '$time تک کارآمد';
  }

  @override
  String get verificationDocuments => 'تصدیقی دستاویزات';

  @override
  String get verificationRejected => 'تصدیق مسترد ہو گئی';

  @override
  String get verifiedByKaamNow => 'کام ناؤ سے تصدیق شدہ';

  @override
  String get verifiedByKaamnow => 'کام ناؤ سے تصدیق شدہ';

  @override
  String get viewReceipt => 'رسید';

  @override
  String get visitFailed => 'پوسٹ نہیں ہو سکا';

  @override
  String get visitSentToAll => 'قریب کے ورکرز کو بھیجا گیا';

  @override
  String get visitSentToWorker => 'آپ کے ورکر کو بھیجا گیا';

  @override
  String waitingForCounter(Object name) {
    return '$name کے جواب کا انتظار ہے۔';
  }

  @override
  String get waitingForCustomer => 'گاہک کا انتظار ہے۔';

  @override
  String get waitingForCustomerShort => 'گاہک کا انتظار';

  @override
  String get waitingForGateway => 'پیمنٹ گیٹ وے کی تصدیق کا انتظار ہے۔';

  @override
  String get waitingForOffers => 'پیشکشوں کا انتظار ہے';

  @override
  String get waitingForOffersHint =>
      'قریبی کاریگروں کو اطلاع دے دی گئی ہے۔ پیشکشیں آتے ہی یہاں نظر آئیں گی۔';

  @override
  String get waitingForWorkerConfirm => 'کاریگر کی تصدیق کا انتظار ہے۔';

  @override
  String get waitingForWorkerLocation => 'کاریگر کی لوکیشن کا انتظار ہے…';

  @override
  String get wallet => 'والٹ';

  @override
  String get walletBalance => 'کام ناؤ کے ساتھ بیلنس';

  @override
  String walletCommissionOwed(Object amount) {
    return 'کمیشن اور کٹوتیاں: $amount';
  }

  @override
  String walletEarningsHeld(Object amount) {
    return 'آن لائن ادائیگیوں سے: $amount';
  }

  @override
  String get walletExplain =>
      'جو گاہک آن لائن ادا کرتے ہیں وہ کام ناؤ کو ادا کرتے ہیں، اس لیے آپ کا حصہ ہمارے ذمے ہے۔ جو نقد ادا کرتے ہیں وہ آپ کو ادا کرتے ہیں، اس لیے ہمارا کمیشن آپ کے ذمے ہے۔ دونوں کا حساب یہاں برابر کیا جاتا ہے۔';

  @override
  String get walletNumber => 'موبائل اکاؤنٹ نمبر';

  @override
  String get walletOwedToYou => 'کام ناؤ کے ذمے آپ کے';

  @override
  String get walletSettled => 'سب حساب برابر';

  @override
  String get walletYouOwe => 'آپ کے ذمے کام ناؤ کے';

  @override
  String weekOf(Object date) {
    return '$date کا ہفتہ';
  }

  @override
  String get whatHelp => 'آپ کو کس کام میں مدد چاہیے؟';

  @override
  String get whatWentWrong => 'کیا مسئلہ ہوا؟';

  @override
  String whenWorkerFree(String name, String day) {
    return '$day کو $name کب فارغ ہیں';
  }

  @override
  String withWorkerName(String name) {
    return '$name کے ساتھ';
  }

  @override
  String get withdraw => 'واپس لیں';

  @override
  String get withdrawHint => 'آپ اس کام پر دوبارہ پیشکش نہیں دے سکیں گے۔';

  @override
  String get withdrawOfferQ => 'اپنی پیشکش واپس لیں؟';

  @override
  String get workRadius => 'کام کا دائرہ (کلومیٹر)';

  @override
  String get workedWithBefore => 'پہلے آپ کا کام کر چکے';

  @override
  String get worker => 'کاریگر';

  @override
  String workerAway(Object name, Object km) {
    return '$name $km کلومیٹر دور ہیں';
  }

  @override
  String get workerDidNotCome => 'ورکر نہیں آیا';

  @override
  String get workerDidNotComeQ => 'رپورٹ کریں کہ ورکر نہیں آیا؟';

  @override
  String get workerNotFreeThatDay => 'یہ ورکر اس دن فارغ نہیں۔ دوسرا دن چنیں۔';

  @override
  String get workerPositionNow => 'ورکر اس وقت کہاں ہے';

  @override
  String get workerProfile => 'کاریگر کا پروفائل';

  @override
  String get workerProfileServicesDocs => 'کاریگر پروفائل، خدمات اور دستاویزات';

  @override
  String get workerSaved =>
      'ورکر محفوظ ہو گیا۔ انہیں \"میرے ورکر\" میں دیکھیں۔';

  @override
  String get workerSignupHint =>
      'سائن اپ کے بعد اپنا شناختی کارڈ اپ لوڈ کریں تاکہ پیشکش بھیجنے سے پہلے کام ناؤ آپ کی تصدیق کر سکے۔';

  @override
  String get workerUnsaved => 'محفوظ کردہ ورکرز سے ہٹا دیا گیا۔';

  @override
  String get workingHours => 'کام کے اوقات';

  @override
  String worksIn(Object area) {
    return 'کام کا علاقہ: $area';
  }

  @override
  String get wrongNumberLogOut => 'یہ آپ کا نمبر نہیں؟ لاگ آؤٹ کریں';

  @override
  String yearsExp(Object n) {
    return '$n سال تجربہ';
  }

  @override
  String get yearsExperience => 'تجربہ (سال)';

  @override
  String get yes => 'ہاں';

  @override
  String get you => 'آپ';

  @override
  String get youAgreed => 'آپ راضی ہو گئے۔ گاہک کا انتظار ہے۔';

  @override
  String get youAreAvailable => 'آپ کام کے لیے دستیاب ہیں';

  @override
  String get youAreOffline => 'آپ آف لائن ہیں';

  @override
  String get youEarned => 'آپ کی کمائی';

  @override
  String youPay(Object amount) {
    return 'آپ $amount ادا کریں گے';
  }

  @override
  String get yourBadges => 'آپ کے بیجز';

  @override
  String get yourInviteCode => 'آپ کا دعوتی کوڈ';

  @override
  String get yourLevelIs => 'آپ کا درجہ';

  @override
  String get yourOffer => 'آپ کی پیشکش';

  @override
  String get yourPhoneNumber => 'آپ کا فون نمبر';

  @override
  String get yourPlan => 'آپ کا پلان';

  @override
  String get yourPrice => 'آپ کی قیمت';
}
