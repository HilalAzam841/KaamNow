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
  String get addServicesToSeeJobs =>
      'متعلقہ کام دیکھنے کے لیے اپنی خدمات شامل کریں۔';

  @override
  String get addTimeOff => 'چھٹیاں شامل کریں';

  @override
  String get address => 'پتہ';

  @override
  String get addressAfterBooking => 'بکنگ کے بعد مکمل پتہ بتا دیا جائے گا۔';

  @override
  String get addressHelper => 'صرف وہی کاریگر دیکھ سکے گا جسے آپ بک کریں گے';

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
  String get allServicesOffered => 'آپ پہلے ہی تمام خدمات پیش کر رہے ہیں۔';

  @override
  String amountDue(Object amount) {
    return 'واجب الادا رقم: $amount';
  }

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
  String get continueAction => 'جاری رکھیں';

  @override
  String get copyInvite => 'دعوت کاپی کریں';

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
  String get editProfile => 'پروفائل میں ترمیم';

  @override
  String get email => 'ای میل';

  @override
  String get emailOptional => 'ای میل (اختیاری، پاس ورڈ ری سیٹ کے لیے)';

  @override
  String get emergency => 'ایمرجنسی';

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
  String get filterActive => 'جاری';

  @override
  String get finishPayingNewTab =>
      'نئے ٹیب میں ادائیگی مکمل کریں۔ تصدیق ہوتے ہی آپ کا پلان فعال ہو جائے گا۔';

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
  String get markAllRead => 'سب پڑھ لیے';

  @override
  String get markCompleteQ => 'کام کو مکمل قرار دیں؟';

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
  String get myScheduleSubtitle =>
      'وہ دن اور اوقات جب آپ کام لیتے ہیں، اور چھٹیاں';

  @override
  String get myScheduleTitle => 'میرے کام کے اوقات';

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
  String get no => 'نہیں';

  @override
  String get noActiveBookings => 'کوئی جاری بکنگ نہیں';

  @override
  String get noAlertsYet => 'ابھی کوئی اطلاع نہیں';

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
  String get noRequestsHint =>
      'قریبی کاریگروں سے قیمتیں لینے کے لیے کام پوسٹ کریں۔';

  @override
  String get noRequestsYet => 'ابھی کوئی درخواست نہیں';

  @override
  String get noReviewsYet => 'ابھی کوئی ریویو نہیں۔';

  @override
  String get noServicesYet => 'ابھی کوئی سروس دستیاب نہیں';

  @override
  String get noSlotsLeft => 'اس دن کوئی وقت باقی نہیں۔ دوسرا دن چنیں۔';

  @override
  String get noTimeOff => 'کوئی چھٹی طے نہیں۔';

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
  String get phoneNumber => 'فون نمبر';

  @override
  String get photoUpdated => 'تصویر اپ ڈیٹ ہو گئی۔';

  @override
  String get photosOptional => 'تصاویر (اختیاری)';

  @override
  String get pinPlaced => 'پن لگ گیا۔ جگہ بدلنے کے لیے نقشے پر ٹیپ کریں۔';

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
  String get received => 'مل گئے';

  @override
  String get recentJobs => 'حالیہ کام';

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
  String reportBooking(Object id) {
    return 'بکنگ نمبر $id رپورٹ کریں';
  }

  @override
  String get reportProblem => 'مسئلہ رپورٹ کریں';

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
  String reviewsHeading(Object n) {
    return 'ریویوز ($n)';
  }

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
  String get saveToFavourites => 'ورکر محفوظ کریں';

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
  String get shortBio => 'مختصر تعارف';

  @override
  String get sixDigitCode => 'گاہک سے ملا 6 ہندسوں کا کوڈ';

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
  String get startWork => 'کام شروع کریں';

  @override
  String get startingPriceOptional => 'ابتدائی قیمت (اختیاری)';

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
  String get titleHint => 'مثلاً چھت کا پنکھا نہیں چل رہا';

  @override
  String get titleLabel => 'عنوان';

  @override
  String get toWord => 'سے';

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
  String get verifiedByKaamnow => 'کام ناؤ سے تصدیق شدہ';

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
  String get whatHelp => 'آپ کو کس کام میں مدد چاہیے؟';

  @override
  String get whatWentWrong => 'کیا مسئلہ ہوا؟';

  @override
  String whenWorkerFree(String name, String day) {
    return '$day کو $name کب فارغ ہیں';
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
  String get workerNotFreeThatDay => 'یہ ورکر اس دن فارغ نہیں۔ دوسرا دن چنیں۔';

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
  String get yourInviteCode => 'آپ کا دعوتی کوڈ';

  @override
  String get yourOffer => 'آپ کی پیشکش';

  @override
  String get yourPhoneNumber => 'آپ کا فون نمبر';

  @override
  String get yourPlan => 'آپ کا پلان';

  @override
  String get yourPrice => 'آپ کی قیمت';
}
