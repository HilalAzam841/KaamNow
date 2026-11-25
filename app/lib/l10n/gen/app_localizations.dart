import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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
    Locale('ur'),
  ];

  /// No description provided for @aboutMinutes.
  ///
  /// In en, this message translates to:
  /// **'about {n} min'**
  String aboutMinutes(Object n);

  /// No description provided for @aboutYou.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get aboutYou;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get accountTitle;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAService.
  ///
  /// In en, this message translates to:
  /// **'Add a service'**
  String get addAService;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @addServicesToSeeJobs.
  ///
  /// In en, this message translates to:
  /// **'Add the services you offer to see matching jobs.'**
  String get addServicesToSeeJobs;

  /// No description provided for @addTimeOff.
  ///
  /// In en, this message translates to:
  /// **'Add days off'**
  String get addTimeOff;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressAfterBooking.
  ///
  /// In en, this message translates to:
  /// **'The exact address is shared once you are booked.'**
  String get addressAfterBooking;

  /// No description provided for @addressHelper.
  ///
  /// In en, this message translates to:
  /// **'Only the worker you book will see it'**
  String get addressHelper;

  /// No description provided for @agree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get agree;

  /// No description provided for @agreeToAmount.
  ///
  /// In en, this message translates to:
  /// **'Agree to {amount}'**
  String agreeToAmount(Object amount);

  /// No description provided for @agreeToHint.
  ///
  /// In en, this message translates to:
  /// **'The customer then confirms to book you.'**
  String get agreeToHint;

  /// No description provided for @agreeToQ.
  ///
  /// In en, this message translates to:
  /// **'Agree to {price}?'**
  String agreeToQ(Object price);

  /// No description provided for @agreedPrice.
  ///
  /// In en, this message translates to:
  /// **'Agreed price'**
  String get agreedPrice;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allBusyHint.
  ///
  /// In en, this message translates to:
  /// **'No matching workers are free on this day. You can still post: workers may free up, or choose another day.'**
  String get allBusyHint;

  /// No description provided for @allServicesOffered.
  ///
  /// In en, this message translates to:
  /// **'You already offer every service.'**
  String get allServicesOffered;

  /// No description provided for @amountDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due: {amount}'**
  String amountDue(Object amount);

  /// No description provided for @anyWorkerNearby.
  ///
  /// In en, this message translates to:
  /// **'Any free worker nearby'**
  String get anyWorkerNearby;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'KaamNow'**
  String get appName;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'KaamNow {version}'**
  String appVersion(Object version);

  /// No description provided for @applyPromo.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyPromo;

  /// No description provided for @areaHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. DHA Phase 5'**
  String get areaHint;

  /// No description provided for @areaLine.
  ///
  /// In en, this message translates to:
  /// **'Area: {area}'**
  String areaLine(Object area);

  /// No description provided for @areaOptional.
  ///
  /// In en, this message translates to:
  /// **'Area (optional)'**
  String get areaOptional;

  /// No description provided for @areasHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Gulberg, Model Town'**
  String get areasHint;

  /// No description provided for @areasYouCover.
  ///
  /// In en, this message translates to:
  /// **'Areas you cover'**
  String get areasYouCover;

  /// No description provided for @arriveInMinutes.
  ///
  /// In en, this message translates to:
  /// **'You can arrive in (minutes)'**
  String get arriveInMinutes;

  /// No description provided for @askedForYou.
  ///
  /// In en, this message translates to:
  /// **'The customer asked for you'**
  String get askedForYou;

  /// No description provided for @atLeast5.
  ///
  /// In en, this message translates to:
  /// **'At least 5 characters'**
  String get atLeast5;

  /// No description provided for @atLeast8.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get atLeast8;

  /// No description provided for @availableAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Available any time'**
  String get availableAnyTime;

  /// No description provided for @availableAnyTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off to set the days and hours you work.'**
  String get availableAnyTimeHelp;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to log in'**
  String get backToLogin;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get bankTransfer;

  /// No description provided for @baseLocation.
  ///
  /// In en, this message translates to:
  /// **'Base location'**
  String get baseLocation;

  /// No description provided for @baseLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Jobs are matched by distance from here. Customers never see it.'**
  String get baseLocationHint;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @bookAgain.
  ///
  /// In en, this message translates to:
  /// **'Book again'**
  String get bookAgain;

  /// No description provided for @bookAgree.
  ///
  /// In en, this message translates to:
  /// **'You agree to pay {price}. All other offers will be closed.'**
  String bookAgree(Object price);

  /// No description provided for @bookAgreeEmergency.
  ///
  /// In en, this message translates to:
  /// **'You agree to pay {price} plus the {fee} emergency fee. All other offers will be closed.'**
  String bookAgreeEmergency(Object price, Object fee);

  /// No description provided for @bookFor.
  ///
  /// In en, this message translates to:
  /// **'Book for {price}'**
  String bookFor(Object price);

  /// No description provided for @bookThisWorker.
  ///
  /// In en, this message translates to:
  /// **'Book this worker'**
  String get bookThisWorker;

  /// No description provided for @bookWorkerQ.
  ///
  /// In en, this message translates to:
  /// **'Book {name}?'**
  String bookWorkerQ(Object name);

  /// No description provided for @booked.
  ///
  /// In en, this message translates to:
  /// **'Booked!'**
  String get booked;

  /// No description provided for @booking.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get booking;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled.'**
  String get bookingCancelled;

  /// No description provided for @bookingNumber.
  ///
  /// In en, this message translates to:
  /// **'Booking #{id}'**
  String bookingNumber(Object id);

  /// No description provided for @bookingNumberPrice.
  ///
  /// In en, this message translates to:
  /// **'Booking #{id} · {price}'**
  String bookingNumberPrice(Object id, Object price);

  /// No description provided for @bookingRemindersHint.
  ///
  /// In en, this message translates to:
  /// **'A reminder the day before and an hour before each booked job'**
  String get bookingRemindersHint;

  /// No description provided for @bookingRemindersSetting.
  ///
  /// In en, this message translates to:
  /// **'Job reminders'**
  String get bookingRemindersSetting;

  /// No description provided for @bookingWorkerDirectly.
  ///
  /// In en, this message translates to:
  /// **'Booking {name}'**
  String bookingWorkerDirectly(String name);

  /// No description provided for @bookingWorkerDirectlyHint.
  ///
  /// In en, this message translates to:
  /// **'Only this worker sees your job. If they cannot make it, you can send it to everyone.'**
  String get bookingWorkerDirectlyHint;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget: {amount}'**
  String budget(Object amount);

  /// No description provided for @budgetLower.
  ///
  /// In en, this message translates to:
  /// **'budget {amount}'**
  String budgetLower(Object amount);

  /// No description provided for @budgetOptional.
  ///
  /// In en, this message translates to:
  /// **'Your budget (optional)'**
  String get budgetOptional;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelBooking;

  /// No description provided for @cancelBookingQ.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get cancelBookingQ;

  /// No description provided for @cancelPayout.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelPayout;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// No description provided for @cancelRequestQ.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request?'**
  String get cancelRequestQ;

  /// No description provided for @cancelledReason.
  ///
  /// In en, this message translates to:
  /// **'Cancelled: {reason}'**
  String cancelledReason(Object reason);

  /// No description provided for @cannotTakeJob.
  ///
  /// In en, this message translates to:
  /// **'I cannot take this job'**
  String get cannotTakeJob;

  /// No description provided for @cannotTakeJobHint.
  ///
  /// In en, this message translates to:
  /// **'The customer will be told, and the job goes to other workers nearby.'**
  String get cannotTakeJobHint;

  /// No description provided for @cannotTakeJobOk.
  ///
  /// In en, this message translates to:
  /// **'Pass on it'**
  String get cannotTakeJobOk;

  /// No description provided for @cannotTakeJobQ.
  ///
  /// In en, this message translates to:
  /// **'Pass on this job?'**
  String get cannotTakeJobQ;

  /// No description provided for @cantDoThisAnyMore.
  ///
  /// In en, this message translates to:
  /// **'I cannot do this any more'**
  String get cantDoThisAnyMore;

  /// No description provided for @cashReceivedQ.
  ///
  /// In en, this message translates to:
  /// **'Cash received?'**
  String get cashReceivedQ;

  /// No description provided for @ccAppIssue.
  ///
  /// In en, this message translates to:
  /// **'Problem with the app'**
  String get ccAppIssue;

  /// No description provided for @ccBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get ccBehaviour;

  /// No description provided for @ccDamage.
  ///
  /// In en, this message translates to:
  /// **'Damage to property'**
  String get ccDamage;

  /// No description provided for @ccFraud.
  ///
  /// In en, this message translates to:
  /// **'Fraud'**
  String get ccFraud;

  /// No description provided for @ccNoShow.
  ///
  /// In en, this message translates to:
  /// **'Did not show up'**
  String get ccNoShow;

  /// No description provided for @ccOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get ccOther;

  /// No description provided for @ccOvercharging.
  ///
  /// In en, this message translates to:
  /// **'Overcharging'**
  String get ccOvercharging;

  /// No description provided for @ccPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment problem'**
  String get ccPayment;

  /// No description provided for @ccServiceQuality.
  ///
  /// In en, this message translates to:
  /// **'Poor service quality'**
  String get ccServiceQuality;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @changeHowOften.
  ///
  /// In en, this message translates to:
  /// **'Change how often'**
  String get changeHowOften;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @chooseAService.
  ///
  /// In en, this message translates to:
  /// **'Choose a service'**
  String get chooseAService;

  /// No description provided for @chooseDaysOff.
  ///
  /// In en, this message translates to:
  /// **'Choose your days off'**
  String get chooseDaysOff;

  /// No description provided for @chooseNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get chooseNewPassword;

  /// No description provided for @chooseOneWorkingDay.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one working day, or turn on \"Available any time\".'**
  String get chooseOneWorkingDay;

  /// No description provided for @chooseService.
  ///
  /// In en, this message translates to:
  /// **'Choose a service.'**
  String get chooseService;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cnicNumber.
  ///
  /// In en, this message translates to:
  /// **'CNIC number'**
  String get cnicNumber;

  /// No description provided for @cnicPrivate.
  ///
  /// In en, this message translates to:
  /// **'CNIC images are private. Only KaamNow staff can see them.'**
  String get cnicPrivate;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent to {phone}.'**
  String codeSentTo(String phone);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{method} (coming soon)'**
  String comingSoon(Object method);

  /// No description provided for @commentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get commentOptional;

  /// No description provided for @commissionDue.
  ///
  /// In en, this message translates to:
  /// **'Commission due: {amount}'**
  String commissionDue(Object amount);

  /// No description provided for @commissionDueHint.
  ///
  /// In en, this message translates to:
  /// **'From cash jobs. KaamNow will contact you about settling it.'**
  String get commissionDueHint;

  /// No description provided for @commissionKeep.
  ///
  /// In en, this message translates to:
  /// **'KaamNow commission {percent}%: {amount}. You keep {earning}.'**
  String commissionKeep(Object percent, Object amount, Object earning);

  /// No description provided for @commissionLine.
  ///
  /// In en, this message translates to:
  /// **'{percent}% commission {amount} · {date}'**
  String commissionLine(Object percent, Object amount, Object date);

  /// No description provided for @commissionPaymentOpen.
  ///
  /// In en, this message translates to:
  /// **'Commission payment of {amount} in progress'**
  String commissionPaymentOpen(Object amount);

  /// No description provided for @commissionPaymentWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'Payment window closed. Your wallet updates once JazzCash or Easypaisa confirms it.'**
  String get commissionPaymentWindowClosed;

  /// No description provided for @commissionPercent.
  ///
  /// In en, this message translates to:
  /// **'Commission {percent}%'**
  String commissionPercent(Object percent);

  /// No description provided for @commissionRateNow.
  ///
  /// In en, this message translates to:
  /// **'Your current commission rate is {percent}%.'**
  String commissionRateNow(Object percent);

  /// No description provided for @commissionStandard.
  ///
  /// In en, this message translates to:
  /// **'Commission standard'**
  String get commissionStandard;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @completeJob.
  ///
  /// In en, this message translates to:
  /// **'Complete job'**
  String get completeJob;

  /// No description provided for @completePaymentNewTab.
  ///
  /// In en, this message translates to:
  /// **'Complete the payment in the new tab. This page updates once the gateway confirms it.'**
  String get completePaymentNewTab;

  /// No description provided for @completeWithCode.
  ///
  /// In en, this message translates to:
  /// **'Complete with customer’s code'**
  String get completeWithCode;

  /// No description provided for @completedJobs.
  ///
  /// In en, this message translates to:
  /// **'Completed jobs'**
  String get completedJobs;

  /// No description provided for @completionCode.
  ///
  /// In en, this message translates to:
  /// **'Completion code'**
  String get completionCode;

  /// No description provided for @completionCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Give this code to the worker only when the job is done to your satisfaction.'**
  String get completionCodeHint;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @confirmCashAmount.
  ///
  /// In en, this message translates to:
  /// **'Confirm you received {amount} in cash.'**
  String confirmCashAmount(Object amount);

  /// No description provided for @confirmJobDone.
  ///
  /// In en, this message translates to:
  /// **'Confirm job is done'**
  String get confirmJobDone;

  /// No description provided for @confirmNumberHint.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit code by SMS to {phone}. This keeps KaamNow safe for customers and workers.'**
  String confirmNumberHint(String phone);

  /// No description provided for @confirmOncePaid.
  ///
  /// In en, this message translates to:
  /// **'Confirm once the customer has paid you.'**
  String get confirmOncePaid;

  /// No description provided for @confirmYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Confirm your phone number'**
  String get confirmYourNumber;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @contactAdded.
  ///
  /// In en, this message translates to:
  /// **'Added.'**
  String get contactAdded;

  /// No description provided for @contactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get contactPhoneLabel;

  /// No description provided for @contactRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed.'**
  String get contactRemoved;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @copyInvite.
  ///
  /// In en, this message translates to:
  /// **'Copy invite'**
  String get copyInvite;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @couldNotGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location.'**
  String get couldNotGetLocation;

  /// No description provided for @couldNotSendLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not send your location.'**
  String get couldNotSendLocation;

  /// No description provided for @counter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get counter;

  /// No description provided for @counterOffer.
  ///
  /// In en, this message translates to:
  /// **'Counter offer'**
  String get counterOffer;

  /// No description provided for @counterSent.
  ///
  /// In en, this message translates to:
  /// **'Counter offer sent.'**
  String get counterSent;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @createAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAnAccount;

  /// No description provided for @creditAdmin.
  ///
  /// In en, this message translates to:
  /// **'From KaamNow'**
  String get creditAdmin;

  /// No description provided for @creditApplied.
  ///
  /// In en, this message translates to:
  /// **'Credit: {amount} off'**
  String creditApplied(Object amount);

  /// No description provided for @creditBalance.
  ///
  /// In en, this message translates to:
  /// **'Your credit: {amount}'**
  String creditBalance(Object amount);

  /// No description provided for @creditHistory.
  ///
  /// In en, this message translates to:
  /// **'Credit history'**
  String get creditHistory;

  /// No description provided for @creditReferral.
  ///
  /// In en, this message translates to:
  /// **'Invite reward'**
  String get creditReferral;

  /// No description provided for @creditReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get creditReturned;

  /// No description provided for @creditSpent.
  ///
  /// In en, this message translates to:
  /// **'Used on a booking'**
  String get creditSpent;

  /// No description provided for @creditWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome credit'**
  String get creditWelcome;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan: {name}'**
  String currentPlan(Object name);

  /// No description provided for @currentPrice.
  ///
  /// In en, this message translates to:
  /// **'Current price: {amount}'**
  String currentPrice(Object amount);

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @customerBudget.
  ///
  /// In en, this message translates to:
  /// **'Customer budget: {amount}'**
  String customerBudget(Object amount);

  /// No description provided for @customerCounteredShort.
  ///
  /// In en, this message translates to:
  /// **'Customer countered. Your move.'**
  String get customerCounteredShort;

  /// No description provided for @customerCounteredYourMove.
  ///
  /// In en, this message translates to:
  /// **'The customer made a counter offer. Your move.'**
  String get customerCounteredYourMove;

  /// No description provided for @customerNotPaid.
  ///
  /// In en, this message translates to:
  /// **'The customer has not paid yet.'**
  String get customerNotPaid;

  /// No description provided for @customerNotThere.
  ///
  /// In en, this message translates to:
  /// **'Customer not there'**
  String get customerNotThere;

  /// No description provided for @customerNotThereQ.
  ///
  /// In en, this message translates to:
  /// **'Report that the customer was not there?'**
  String get customerNotThereQ;

  /// No description provided for @customersPaid.
  ///
  /// In en, this message translates to:
  /// **'Customers paid'**
  String get customersPaid;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String dateRange(String start, String end);

  /// No description provided for @dayOff.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get dayOff;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String daysAgo(Object n);

  /// No description provided for @defaultAddress.
  ///
  /// In en, this message translates to:
  /// **'Default address'**
  String get defaultAddress;

  /// No description provided for @deletePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'Customers will no longer see it.'**
  String get deletePhotoBody;

  /// No description provided for @deletePhotoQ.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get deletePhotoQ;

  /// No description provided for @describeProblem.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem'**
  String get describeProblem;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @discountNote.
  ///
  /// In en, this message translates to:
  /// **'KaamNow pays the discount. Your worker still gets their full share.'**
  String get discountNote;

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(Object km);

  /// No description provided for @docCertificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get docCertificate;

  /// No description provided for @docCnicBack.
  ///
  /// In en, this message translates to:
  /// **'CNIC back'**
  String get docCnicBack;

  /// No description provided for @docCnicFront.
  ///
  /// In en, this message translates to:
  /// **'CNIC front'**
  String get docCnicFront;

  /// No description provided for @docOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get docOther;

  /// No description provided for @docUploaded.
  ///
  /// In en, this message translates to:
  /// **'{doc} uploaded.'**
  String docUploaded(Object doc);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed.'**
  String get downloadFailed;

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour} other{{hours} hours}}'**
  String durationHours(int hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @editCaption.
  ///
  /// In en, this message translates to:
  /// **'Edit caption'**
  String get editCaption;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional, for password reset)'**
  String get emailOptional;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @emergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts'**
  String get emergencyContacts;

  /// No description provided for @emergencyContactsHint.
  ///
  /// In en, this message translates to:
  /// **'Texted when you press SOS during a job'**
  String get emergencyContactsHint;

  /// No description provided for @emergencyFee.
  ///
  /// In en, this message translates to:
  /// **'Emergency · fee {fee}'**
  String emergencyFee(Object fee);

  /// No description provided for @emergencyFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Emergency fee'**
  String get emergencyFeeLabel;

  /// No description provided for @emergencyJob.
  ///
  /// In en, this message translates to:
  /// **'Emergency job'**
  String get emergencyJob;

  /// No description provided for @emergencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shown first to workers. Adds {fee} to the total.'**
  String emergencySubtitle(Object fee);

  /// No description provided for @endAfterStartFor.
  ///
  /// In en, this message translates to:
  /// **'On {day}, the end time must be after the start time.'**
  String endAfterStartFor(String day);

  /// No description provided for @enterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter the address'**
  String get enterAddress;

  /// No description provided for @enterCnic.
  ///
  /// In en, this message translates to:
  /// **'Enter your CNIC number'**
  String get enterCnic;

  /// No description provided for @enterCompletionCode.
  ///
  /// In en, this message translates to:
  /// **'Enter completion code'**
  String get enterCompletionCode;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterFullName;

  /// No description provided for @enterMinutes.
  ///
  /// In en, this message translates to:
  /// **'Enter minutes'**
  String get enterMinutes;

  /// No description provided for @enterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get enterNumber;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhone;

  /// No description provided for @enterPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a price'**
  String get enterPrice;

  /// No description provided for @enterTheCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the SMS.'**
  String get enterTheCode;

  /// No description provided for @enterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get enterValidPhone;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'~{n} min'**
  String etaMinutes(Object n);

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// No description provided for @finishPayingNewTab.
  ///
  /// In en, this message translates to:
  /// **'Finish paying in the new tab. Your plan activates once it is confirmed.'**
  String get finishPayingNewTab;

  /// No description provided for @firstVisit.
  ///
  /// In en, this message translates to:
  /// **'First visit'**
  String get firstVisit;

  /// No description provided for @forgotCodeHint.
  ///
  /// In en, this message translates to:
  /// **'If {phone} has a KaamNow account, we have sent it a code by SMS.'**
  String forgotCodeHint(String phone);

  /// No description provided for @forgotEmailOnly.
  ///
  /// In en, this message translates to:
  /// **'If this number has an account with an email address, we have emailed a link to reset the password.'**
  String get forgotEmailOnly;

  /// No description provided for @forgotHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number. We will send you a code by SMS to choose a new password.'**
  String get forgotHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotTitle;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @freeWorkersOn.
  ///
  /// In en, this message translates to:
  /// **'Free workers on {day}'**
  String freeWorkersOn(String day);

  /// No description provided for @freqBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every two weeks'**
  String get freqBiweekly;

  /// No description provided for @freqMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get freqMonthly;

  /// No description provided for @freqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get freqWeekly;

  /// No description provided for @fromKaamNowJob.
  ///
  /// In en, this message translates to:
  /// **'From a KaamNow job'**
  String get fromKaamNowJob;

  /// No description provided for @fromPrice.
  ///
  /// In en, this message translates to:
  /// **'from {price}'**
  String fromPrice(Object price);

  /// No description provided for @fromPriceCap.
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String fromPriceCap(Object price);

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @getCompletionCode.
  ///
  /// In en, this message translates to:
  /// **'Get completion code'**
  String get getCompletionCode;

  /// No description provided for @getPaid.
  ///
  /// In en, this message translates to:
  /// **'Get paid'**
  String get getPaid;

  /// No description provided for @getVerified.
  ///
  /// In en, this message translates to:
  /// **'Get verified to send offers'**
  String get getVerified;

  /// No description provided for @getVerifiedHint.
  ///
  /// In en, this message translates to:
  /// **'Upload both sides of your CNIC, add your services and set your base location. KaamNow reviews new workers before they can bid.'**
  String get getVerifiedHint;

  /// No description provided for @helpAndComplaints.
  ///
  /// In en, this message translates to:
  /// **'Help and complaints'**
  String get helpAndComplaints;

  /// No description provided for @hireHelp.
  ///
  /// In en, this message translates to:
  /// **'Hire help'**
  String get hireHelp;

  /// No description provided for @homeIntro.
  ///
  /// In en, this message translates to:
  /// **'Describe the job, get prices from nearby verified workers, and pick the one you like.'**
  String get homeIntro;

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String hoursAgo(Object n);

  /// No description provided for @howLongJob.
  ///
  /// In en, this message translates to:
  /// **'How long will the job take?'**
  String get howLongJob;

  /// No description provided for @howLongJobHelp.
  ///
  /// In en, this message translates to:
  /// **'A rough guess. Workers keep this time free for you.'**
  String get howLongJobHelp;

  /// No description provided for @howOften.
  ///
  /// In en, this message translates to:
  /// **'How often?'**
  String get howOften;

  /// No description provided for @howToInstall.
  ///
  /// In en, this message translates to:
  /// **'How to install'**
  String get howToInstall;

  /// No description provided for @iWantTo.
  ///
  /// In en, this message translates to:
  /// **'I want to'**
  String get iWantTo;

  /// No description provided for @iban.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get iban;

  /// No description provided for @imOnMyWay.
  ///
  /// In en, this message translates to:
  /// **'I’m on my way'**
  String get imOnMyWay;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @installApp.
  ///
  /// In en, this message translates to:
  /// **'Install app'**
  String get installApp;

  /// No description provided for @installHint.
  ///
  /// In en, this message translates to:
  /// **'Add it to your home screen and open it like an app.'**
  String get installHint;

  /// No description provided for @installTitle.
  ///
  /// In en, this message translates to:
  /// **'Install KaamNow'**
  String get installTitle;

  /// No description provided for @installedThanks.
  ///
  /// In en, this message translates to:
  /// **'KaamNow is installed. You can open it from your home screen.'**
  String get installedThanks;

  /// No description provided for @inviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Got a code from a friend? You get credit off your first booking.'**
  String get inviteCodeHint;

  /// No description provided for @inviteCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Invite code (optional)'**
  String get inviteCodeOptional;

  /// No description provided for @inviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite copied. Paste it in WhatsApp or SMS.'**
  String get inviteCopied;

  /// No description provided for @inviteExplain.
  ///
  /// In en, this message translates to:
  /// **'Friends who sign up with your code get {welcome} off their first booking. When they pay a booking of {min} or more, you get {reward} credit.'**
  String inviteExplain(Object welcome, Object min, Object reward);

  /// No description provided for @inviteExplainWorker.
  ///
  /// In en, this message translates to:
  /// **'Customers who sign up with your code get {welcome} off their first booking. When they pay a booking of {min} or more, {reward} is added to your wallet.'**
  String inviteExplainWorker(Object welcome, Object min, Object reward);

  /// No description provided for @inviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteFriends;

  /// No description provided for @inviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Book trusted workers in Lahore with KaamNow. Sign up with my code {code} and get {amount} off your first booking: {link}'**
  String inviteMessage(Object code, Object amount, Object link);

  /// No description provided for @invitedCount.
  ///
  /// In en, this message translates to:
  /// **'Friends who joined: {count}'**
  String invitedCount(int count);

  /// No description provided for @iosInstallSteps.
  ///
  /// In en, this message translates to:
  /// **'In Safari, tap the Share button, then choose “Add to Home Screen”.'**
  String get iosInstallSteps;

  /// No description provided for @iveArrived.
  ///
  /// In en, this message translates to:
  /// **'I’ve arrived'**
  String get iveArrived;

  /// No description provided for @job.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get job;

  /// No description provided for @jobAddress.
  ///
  /// In en, this message translates to:
  /// **'Job address'**
  String get jobAddress;

  /// No description provided for @jobCompleted.
  ///
  /// In en, this message translates to:
  /// **'Job completed.'**
  String get jobCompleted;

  /// No description provided for @jobIsBooked.
  ///
  /// In en, this message translates to:
  /// **'This job is booked'**
  String get jobIsBooked;

  /// No description provided for @jobLocation.
  ///
  /// In en, this message translates to:
  /// **'Job location'**
  String get jobLocation;

  /// No description provided for @jobNowRepeats.
  ///
  /// In en, this message translates to:
  /// **'This job now repeats.'**
  String get jobNowRepeats;

  /// No description provided for @jobNumberPrice.
  ///
  /// In en, this message translates to:
  /// **'Job #{id} · {price}'**
  String jobNumberPrice(Object id, Object price);

  /// No description provided for @jobPassedOn.
  ///
  /// In en, this message translates to:
  /// **'Done. The job went to other workers.'**
  String get jobPassedOn;

  /// No description provided for @jobPosted.
  ///
  /// In en, this message translates to:
  /// **'Job posted.'**
  String get jobPosted;

  /// No description provided for @jobPostedNotified.
  ///
  /// In en, this message translates to:
  /// **'Job posted. {n} nearby workers were notified.'**
  String jobPostedNotified(Object n);

  /// No description provided for @jobsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 job} other{{count} jobs}}'**
  String jobsCount(int count);

  /// No description provided for @jobsDoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 job done} other{{count} jobs done}}'**
  String jobsDoneCount(int count);

  /// No description provided for @jobsNearYou.
  ///
  /// In en, this message translates to:
  /// **'Jobs near you'**
  String get jobsNearYou;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @kaamnowCommission.
  ///
  /// In en, this message translates to:
  /// **'KaamNow commission'**
  String get kaamnowCommission;

  /// No description provided for @kaamnowReply.
  ///
  /// In en, this message translates to:
  /// **'KaamNow: {text}'**
  String kaamnowReply(Object text);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUrdu.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get languageUrdu;

  /// No description provided for @lastAttempt.
  ///
  /// In en, this message translates to:
  /// **'Last attempt: {status}. {reason}'**
  String lastAttempt(Object status, Object reason);

  /// No description provided for @lastBooked.
  ///
  /// In en, this message translates to:
  /// **'Last job for you: {date}'**
  String lastBooked(String date);

  /// No description provided for @leaveRepeatingBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be told, and future visits will go to other workers nearby.'**
  String leaveRepeatingBody(String name);

  /// No description provided for @leaveRepeatingQ.
  ///
  /// In en, this message translates to:
  /// **'Stop doing this job?'**
  String get leaveRepeatingQ;

  /// No description provided for @leftRepeating.
  ///
  /// In en, this message translates to:
  /// **'Done. You will not get these visits any more.'**
  String get leftRepeating;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get linkCopied;

  /// No description provided for @linkExpired.
  ///
  /// In en, this message translates to:
  /// **'This link has expired or was turned off.'**
  String get linkExpired;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'Live tracking'**
  String get liveTracking;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied. You can still place the pin on the map.'**
  String get locationDenied;

  /// No description provided for @locationOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off.'**
  String get locationOff;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @loginWithNewPassword.
  ///
  /// In en, this message translates to:
  /// **'You can log in with your new password now.'**
  String get loginWithNewPassword;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @markCompleteQ.
  ///
  /// In en, this message translates to:
  /// **'Mark the job as complete?'**
  String get markCompleteQ;

  /// No description provided for @maxContactsReached.
  ///
  /// In en, this message translates to:
  /// **'You have 3 contacts, the most allowed.'**
  String get maxContactsReached;

  /// No description provided for @maxPhotosReached.
  ///
  /// In en, this message translates to:
  /// **'You have 12 photos, the most allowed. Delete one to add another.'**
  String get maxPhotosReached;

  /// No description provided for @messageNotSent.
  ///
  /// In en, this message translates to:
  /// **'Message not sent.'**
  String get messageNotSent;

  /// No description provided for @messageToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Message to the customer (optional)'**
  String get messageToCustomer;

  /// No description provided for @messagesPrivate.
  ///
  /// In en, this message translates to:
  /// **'Messages are private between you and the other person on this booking.'**
  String get messagesPrivate;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodEasypaisa.
  ///
  /// In en, this message translates to:
  /// **'Easypaisa'**
  String get methodEasypaisa;

  /// No description provided for @methodJazzcash.
  ///
  /// In en, this message translates to:
  /// **'JazzCash'**
  String get methodJazzcash;

  /// No description provided for @methodRef.
  ///
  /// In en, this message translates to:
  /// **'{method} · ref {ref}'**
  String methodRef(Object method, Object ref);

  /// No description provided for @minPayoutHint.
  ///
  /// In en, this message translates to:
  /// **'You can ask for a payout from {amount}.'**
  String minPayoutHint(Object amount);

  /// No description provided for @minimumIs.
  ///
  /// In en, this message translates to:
  /// **'Minimum is {amount}'**
  String minimumIs(Object amount);

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String minutesAgo(Object n);

  /// No description provided for @moreDetail.
  ///
  /// In en, this message translates to:
  /// **'Please give a bit more detail (20+ characters)'**
  String get moreDetail;

  /// No description provided for @moveEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get moveEarlier;

  /// No description provided for @moveLater.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get moveLater;

  /// No description provided for @myPortfolio.
  ///
  /// In en, this message translates to:
  /// **'My work photos'**
  String get myPortfolio;

  /// No description provided for @myPortfolioHint.
  ///
  /// In en, this message translates to:
  /// **'Show customers what you have done'**
  String get myPortfolioHint;

  /// No description provided for @myScheduleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Days and times you take jobs, and days off'**
  String get myScheduleSubtitle;

  /// No description provided for @myScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'My working hours'**
  String get myScheduleTitle;

  /// No description provided for @myWorkerProfile.
  ///
  /// In en, this message translates to:
  /// **'My worker profile'**
  String get myWorkerProfile;

  /// No description provided for @myWorkers.
  ///
  /// In en, this message translates to:
  /// **'My workers'**
  String get myWorkers;

  /// No description provided for @myWorkersHomeHint.
  ///
  /// In en, this message translates to:
  /// **'Book a worker you liked again'**
  String get myWorkersHomeHint;

  /// No description provided for @nFree.
  ///
  /// In en, this message translates to:
  /// **'{count} free'**
  String nFree(int count);

  /// No description provided for @negAccept.
  ///
  /// In en, this message translates to:
  /// **'{who} accepted at {amount}'**
  String negAccept(Object who, Object amount);

  /// No description provided for @negAgree.
  ///
  /// In en, this message translates to:
  /// **'{who} agreed to {amount}'**
  String negAgree(Object who, Object amount);

  /// No description provided for @negCounter.
  ///
  /// In en, this message translates to:
  /// **'{who} countered with {amount}'**
  String negCounter(Object who, Object amount);

  /// No description provided for @negOffer.
  ///
  /// In en, this message translates to:
  /// **'{who} offered {amount}'**
  String negOffer(Object who, Object amount);

  /// No description provided for @negReject.
  ///
  /// In en, this message translates to:
  /// **'{who} rejected'**
  String negReject(Object who);

  /// No description provided for @negRevise.
  ///
  /// In en, this message translates to:
  /// **'{who} revised the price to {amount}'**
  String negRevise(Object who, Object amount);

  /// No description provided for @negWithdraw.
  ///
  /// In en, this message translates to:
  /// **'{who} withdrew'**
  String negWithdraw(Object who);

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach KaamNow. Check your connection.'**
  String get networkError;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @nextVisitOn.
  ///
  /// In en, this message translates to:
  /// **'Next visit: {when}'**
  String nextVisitOn(String when);

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @noActiveBookings.
  ///
  /// In en, this message translates to:
  /// **'No active bookings'**
  String get noActiveBookings;

  /// No description provided for @noAlertsYet.
  ///
  /// In en, this message translates to:
  /// **'No alerts yet'**
  String get noAlertsYet;

  /// No description provided for @noBookingsCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Accept an offer on one of your requests to book a worker.'**
  String get noBookingsCustomerHint;

  /// No description provided for @noBookingsWorkerHint.
  ///
  /// In en, this message translates to:
  /// **'When a customer accepts your offer, the job appears here.'**
  String get noBookingsWorkerHint;

  /// No description provided for @noCancelledBookings.
  ///
  /// In en, this message translates to:
  /// **'No cancelled bookings'**
  String get noCancelledBookings;

  /// No description provided for @noComplaints.
  ///
  /// In en, this message translates to:
  /// **'No complaints'**
  String get noComplaints;

  /// No description provided for @noComplaintsHint.
  ///
  /// In en, this message translates to:
  /// **'If something goes wrong with a job, report it here and KaamNow will look into it.'**
  String get noComplaintsHint;

  /// No description provided for @noCompletedBookings.
  ///
  /// In en, this message translates to:
  /// **'No completed bookings'**
  String get noCompletedBookings;

  /// No description provided for @noCompletedJobs.
  ///
  /// In en, this message translates to:
  /// **'No completed jobs yet.'**
  String get noCompletedJobs;

  /// No description provided for @noEmergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'No emergency contacts yet'**
  String get noEmergencyContacts;

  /// No description provided for @noEmergencyContactsHint.
  ///
  /// In en, this message translates to:
  /// **'Add up to 3 people you trust. When you press SOS during a job, they get a text with a link to follow it.'**
  String get noEmergencyContactsHint;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @noOffers.
  ///
  /// In en, this message translates to:
  /// **'No offers'**
  String get noOffers;

  /// No description provided for @noOffersHere.
  ///
  /// In en, this message translates to:
  /// **'No offers here'**
  String get noOffersHere;

  /// No description provided for @noOffersHereHint.
  ///
  /// In en, this message translates to:
  /// **'Offers you send on jobs appear here.'**
  String get noOffersHereHint;

  /// No description provided for @noOpenJobs.
  ///
  /// In en, this message translates to:
  /// **'No open jobs right now'**
  String get noOpenJobs;

  /// No description provided for @noOpenJobsHint.
  ///
  /// In en, this message translates to:
  /// **'New jobs in your area and services will show up here, and you will get an alert.'**
  String get noOpenJobsHint;

  /// No description provided for @noPortfolioHint.
  ///
  /// In en, this message translates to:
  /// **'Add up to 12 photos of jobs you did. Customers see them on your profile. Location and camera details are removed from each photo.'**
  String get noPortfolioHint;

  /// No description provided for @noPortfolioYet.
  ///
  /// In en, this message translates to:
  /// **'No work photos yet'**
  String get noPortfolioYet;

  /// No description provided for @noRepeatingJobs.
  ///
  /// In en, this message translates to:
  /// **'No repeating jobs'**
  String get noRepeatingJobs;

  /// No description provided for @noRepeatingJobsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Open a booking and tap Repeat this job to have it done every week or month.'**
  String get noRepeatingJobsCustomer;

  /// No description provided for @noRepeatingJobsWorker.
  ///
  /// In en, this message translates to:
  /// **'When a customer repeats a job with you, it shows here.'**
  String get noRepeatingJobsWorker;

  /// No description provided for @noRequestsHint.
  ///
  /// In en, this message translates to:
  /// **'Post a job to get prices from nearby workers.'**
  String get noRequestsHint;

  /// No description provided for @noRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get noRequestsYet;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get noReviewsYet;

  /// No description provided for @noService.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noService;

  /// No description provided for @noServicesYet.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get noServicesYet;

  /// No description provided for @noShowCustomerReported.
  ///
  /// In en, this message translates to:
  /// **'Reported: the customer was not there.'**
  String get noShowCustomerReported;

  /// No description provided for @noShowNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'What happened? (optional)'**
  String get noShowNoteLabel;

  /// No description provided for @noShowReported.
  ///
  /// In en, this message translates to:
  /// **'Reported. The booking is cancelled and our team will review it.'**
  String get noShowReported;

  /// No description provided for @noShowWait.
  ///
  /// In en, this message translates to:
  /// **'You can report this after {time}. Try calling first.'**
  String noShowWait(String time);

  /// No description provided for @noShowWorkerReported.
  ///
  /// In en, this message translates to:
  /// **'Reported: the worker did not come.'**
  String get noShowWorkerReported;

  /// No description provided for @noSlotsLeft.
  ///
  /// In en, this message translates to:
  /// **'No time slots left on this day. Choose another day.'**
  String get noSlotsLeft;

  /// No description provided for @noTimeOff.
  ///
  /// In en, this message translates to:
  /// **'No days off planned.'**
  String get noTimeOff;

  /// No description provided for @noWorkersYet.
  ///
  /// In en, this message translates to:
  /// **'No workers yet'**
  String get noWorkersYet;

  /// No description provided for @noWorkersYetHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a worker you liked to save them. Workers who finish a job for you also show here.'**
  String get noWorkersYetHint;

  /// No description provided for @noneFree.
  ///
  /// In en, this message translates to:
  /// **'none free'**
  String get noneFree;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @numberConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Phone number confirmed.'**
  String get numberConfirmed;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @offerSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent. The customer will be notified.'**
  String get offerSent;

  /// No description provided for @offerServices.
  ///
  /// In en, this message translates to:
  /// **'Offer services'**
  String get offerServices;

  /// No description provided for @offersADay.
  ///
  /// In en, this message translates to:
  /// **'{n} offers a day'**
  String offersADay(Object n);

  /// No description provided for @offersBlockedDebt.
  ///
  /// In en, this message translates to:
  /// **'You owe more than {amount} in commission, so you cannot send offers until you pay.'**
  String offersBlockedDebt(Object amount);

  /// No description provided for @offersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 offer} other{{count} offers}}'**
  String offersCount(int count);

  /// No description provided for @offersHeading.
  ///
  /// In en, this message translates to:
  /// **'Offers ({n})'**
  String offersHeading(Object n);

  /// No description provided for @offersLeftToday.
  ///
  /// In en, this message translates to:
  /// **'{n} offers left today'**
  String offersLeftToday(Object n);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @onlinePaymentSoon.
  ///
  /// In en, this message translates to:
  /// **'Online payment is coming soon. Contact KaamNow support to upgrade.'**
  String get onlinePaymentSoon;

  /// No description provided for @onlinePaymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Online payment is not available on this device yet.'**
  String get onlinePaymentUnavailable;

  /// No description provided for @onlyAvailableGetAlerts.
  ///
  /// In en, this message translates to:
  /// **'Only available workers get new job alerts.'**
  String get onlyAvailableGetAlerts;

  /// No description provided for @onlyIfDone.
  ///
  /// In en, this message translates to:
  /// **'Only confirm if the work is done.'**
  String get onlyIfDone;

  /// No description provided for @openAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openAction;

  /// No description provided for @openBooking.
  ///
  /// In en, this message translates to:
  /// **'Open booking'**
  String get openBooking;

  /// No description provided for @osmCredit.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get osmCredit;

  /// No description provided for @otherDay.
  ///
  /// In en, this message translates to:
  /// **'Other day'**
  String get otherDay;

  /// No description provided for @paidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount}'**
  String paidAmount(Object amount);

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @passwordChangedShort.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChangedShort;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match'**
  String get passwordsDontMatch;

  /// No description provided for @pastWork.
  ///
  /// In en, this message translates to:
  /// **'Past work'**
  String get pastWork;

  /// No description provided for @pauseRepeating.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseRepeating;

  /// No description provided for @pausedRepeating.
  ///
  /// In en, this message translates to:
  /// **'Paused. No visits until you resume.'**
  String get pausedRepeating;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Pay the worker in cash. They will confirm when they receive it.'**
  String get payCash;

  /// No description provided for @payCommission.
  ///
  /// In en, this message translates to:
  /// **'Pay commission'**
  String get payCommission;

  /// No description provided for @payCommissionOffice.
  ///
  /// In en, this message translates to:
  /// **'Pay online when available, or hand it to the KaamNow office and they will record it.'**
  String get payCommissionOffice;

  /// No description provided for @payWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with {method}'**
  String payWith(Object method);

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed.'**
  String get paymentConfirmed;

  /// No description provided for @paymentPageFailed.
  ///
  /// In en, this message translates to:
  /// **'The payment page could not be opened. Check your connection and try again.'**
  String get paymentPageFailed;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'{method} payment of {amount} pending'**
  String paymentPending(Object method, Object amount);

  /// No description provided for @paymentRefunded.
  ///
  /// In en, this message translates to:
  /// **'Your payment of {amount} was refunded.'**
  String paymentRefunded(Object amount);

  /// No description provided for @paymentWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'This page updates once the gateway confirms the payment.'**
  String get paymentWindowClosed;

  /// No description provided for @payoutCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payout request cancelled.'**
  String get payoutCancelled;

  /// No description provided for @payoutOpen.
  ///
  /// In en, this message translates to:
  /// **'Payout of {amount} requested'**
  String payoutOpen(Object amount);

  /// No description provided for @payoutOpenHint.
  ///
  /// In en, this message translates to:
  /// **'To {method} {account}. Jobs in it are not counted in your balance until it is sent or declined.'**
  String payoutOpenHint(Object method, Object account);

  /// No description provided for @payoutRequested.
  ///
  /// In en, this message translates to:
  /// **'Payout requested. We will send it soon.'**
  String get payoutRequested;

  /// No description provided for @payoutTo.
  ///
  /// In en, this message translates to:
  /// **'Send it to'**
  String get payoutTo;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @photoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added.'**
  String get photoAdded;

  /// No description provided for @photoCaptionLabel.
  ///
  /// In en, this message translates to:
  /// **'What is in the photo? (optional)'**
  String get photoCaptionLabel;

  /// No description provided for @photoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Photo deleted.'**
  String get photoDeleted;

  /// No description provided for @photoHiddenBy.
  ///
  /// In en, this message translates to:
  /// **'Hidden by KaamNow: {reason}'**
  String photoHiddenBy(String reason);

  /// No description provided for @photoServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Service (optional)'**
  String get photoServiceLabel;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated.'**
  String get photoUpdated;

  /// No description provided for @photosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} photos'**
  String photosCount(int count, int max);

  /// No description provided for @photosOptional.
  ///
  /// In en, this message translates to:
  /// **'Photos (optional)'**
  String get photosOptional;

  /// No description provided for @pinPlaced.
  ///
  /// In en, this message translates to:
  /// **'Pin placed. Tap the map to move it.'**
  String get pinPlaced;

  /// No description provided for @planPaymentWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'Your plan activates once the payment is confirmed.'**
  String get planPaymentWindowClosed;

  /// No description provided for @plans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plans;

  /// No description provided for @postAJob.
  ///
  /// In en, this message translates to:
  /// **'Post a job'**
  String get postAJob;

  /// No description provided for @postJobGetOffers.
  ///
  /// In en, this message translates to:
  /// **'Post job and get offers'**
  String get postJobGetOffers;

  /// No description provided for @preferredTime.
  ///
  /// In en, this message translates to:
  /// **'Preferred time'**
  String get preferredTime;

  /// No description provided for @pricePerDays.
  ///
  /// In en, this message translates to:
  /// **'{price} / {days} days'**
  String pricePerDays(Object price, Object days);

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// No description provided for @promoApplied.
  ///
  /// In en, this message translates to:
  /// **'{code}: {amount} off'**
  String promoApplied(Object code, Object amount);

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get promoCode;

  /// No description provided for @pushBlockedHint.
  ///
  /// In en, this message translates to:
  /// **'Blocked in your browser. Allow notifications for this site in the browser settings.'**
  String get pushBlockedHint;

  /// No description provided for @pushBlockedHintPhone.
  ///
  /// In en, this message translates to:
  /// **'Blocked in your phone settings. Allow notifications for KaamNow in Settings.'**
  String get pushBlockedHintPhone;

  /// No description provided for @pushHintCustomer.
  ///
  /// In en, this message translates to:
  /// **'Know right away when workers send offers and when your booking changes.'**
  String get pushHintCustomer;

  /// No description provided for @pushHintWorker.
  ///
  /// In en, this message translates to:
  /// **'Hear about new jobs nearby and customer replies right away.'**
  String get pushHintWorker;

  /// No description provided for @pushNeedsInstallHint.
  ///
  /// In en, this message translates to:
  /// **'On iPhone, first install KaamNow (Share, then “Add to Home Screen”), then turn this on in the installed app.'**
  String get pushNeedsInstallHint;

  /// No description provided for @pushNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications were not allowed.'**
  String get pushNotAllowed;

  /// No description provided for @pushOffHint.
  ///
  /// In en, this message translates to:
  /// **'Off: you will only see alerts inside the app.'**
  String get pushOffHint;

  /// No description provided for @pushOnHint.
  ///
  /// In en, this message translates to:
  /// **'On: offers, bookings and messages arrive even when KaamNow is closed.'**
  String get pushOnHint;

  /// No description provided for @pushSetting.
  ///
  /// In en, this message translates to:
  /// **'Notifications on this device'**
  String get pushSetting;

  /// No description provided for @pushTitle.
  ///
  /// In en, this message translates to:
  /// **'Get alerts on this device'**
  String get pushTitle;

  /// No description provided for @pushTurnedOn.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on for this device.'**
  String get pushTurnedOn;

  /// No description provided for @rateThisJob.
  ///
  /// In en, this message translates to:
  /// **'Rate this job'**
  String get rateThisJob;

  /// No description provided for @rateWorker.
  ///
  /// In en, this message translates to:
  /// **'Rate {name}'**
  String rateWorker(Object name);

  /// No description provided for @ratingNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get ratingNew;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @reasonLine.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reasonLine(Object reason);

  /// No description provided for @reasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reasonOptional;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @recentJobs.
  ///
  /// In en, this message translates to:
  /// **'Recent jobs'**
  String get recentJobs;

  /// No description provided for @recentVisits.
  ///
  /// In en, this message translates to:
  /// **'Recent visits'**
  String get recentVisits;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get reconnecting;

  /// No description provided for @refundedToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Refunded to the customer: {amount}'**
  String refundedToCustomer(Object amount);

  /// No description provided for @refundedToYou.
  ///
  /// In en, this message translates to:
  /// **'Refunded to you: {amount}'**
  String refundedToYou(Object amount);

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @rejectOfferQ.
  ///
  /// In en, this message translates to:
  /// **'Reject this offer?'**
  String get rejectOfferQ;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeContactQ.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeContactQ(String name);

  /// No description provided for @removeFromFavourites.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get removeFromFavourites;

  /// No description provided for @removePromo.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePromo;

  /// No description provided for @removeServiceQ.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeServiceQ(Object name);

  /// No description provided for @removeTimeOffBody.
  ///
  /// In en, this message translates to:
  /// **'You will get job alerts on these days again.'**
  String get removeTimeOffBody;

  /// No description provided for @removeTimeOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove these days off?'**
  String get removeTimeOffTitle;

  /// No description provided for @renewsOrEnds.
  ///
  /// In en, this message translates to:
  /// **'Renews or ends {date}'**
  String renewsOrEnds(Object date);

  /// No description provided for @repeatNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get repeatNewPassword;

  /// No description provided for @repeatSheetHint.
  ///
  /// In en, this message translates to:
  /// **'Two days before each visit, {name} gets the job as a book-again request. If they are not free, it goes to other workers nearby. You still accept an offer each time.'**
  String repeatSheetHint(String name);

  /// No description provided for @repeatThisJob.
  ///
  /// In en, this message translates to:
  /// **'Repeat this job'**
  String get repeatThisJob;

  /// No description provided for @repeatingJobs.
  ///
  /// In en, this message translates to:
  /// **'Repeating jobs'**
  String get repeatingJobs;

  /// No description provided for @repeatingJobsCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Jobs that repeat with the same worker'**
  String get repeatingJobsCustomerHint;

  /// No description provided for @repeatingJobsWorkerHint.
  ///
  /// In en, this message translates to:
  /// **'Customers who want you every time'**
  String get repeatingJobsWorkerHint;

  /// No description provided for @reportBooking.
  ///
  /// In en, this message translates to:
  /// **'Report booking #{id}'**
  String reportBooking(Object id);

  /// No description provided for @reportNoShow.
  ///
  /// In en, this message translates to:
  /// **'Report and cancel'**
  String get reportNoShow;

  /// No description provided for @reportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblem;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @requestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled.'**
  String get requestCancelled;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed.'**
  String get requestFailed;

  /// No description provided for @requestPayoutOf.
  ///
  /// In en, this message translates to:
  /// **'Ask for {amount}'**
  String requestPayoutOf(Object amount);

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Send a new code in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @resetLinkIncomplete.
  ///
  /// In en, this message translates to:
  /// **'This reset link is incomplete'**
  String get resetLinkIncomplete;

  /// No description provided for @resetLinkIncompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Open the link from the email again, or ask for a new one from the login screen.'**
  String get resetLinkIncompleteHint;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'If that number has an account with an email, a reset link is on its way.'**
  String get resetLinkSent;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @resumeRepeating.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeRepeating;

  /// No description provided for @resumedRepeating.
  ///
  /// In en, this message translates to:
  /// **'Resumed.'**
  String get resumedRepeating;

  /// No description provided for @reviewsHeading.
  ///
  /// In en, this message translates to:
  /// **'Reviews ({n})'**
  String reviewsHeading(Object n);

  /// No description provided for @rewardsEarned.
  ///
  /// In en, this message translates to:
  /// **'Rewards earned: {amount}'**
  String rewardsEarned(Object amount);

  /// No description provided for @rsPrefix.
  ///
  /// In en, this message translates to:
  /// **'Rs '**
  String get rsPrefix;

  /// No description provided for @rupees.
  ///
  /// In en, this message translates to:
  /// **'Rs {amount}'**
  String rupees(Object amount);

  /// No description provided for @rupeesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Rs —'**
  String get rupeesUnknown;

  /// No description provided for @salam.
  ///
  /// In en, this message translates to:
  /// **'Salam, {name}'**
  String salam(Object name);

  /// No description provided for @samePriceAcceptInstead.
  ///
  /// In en, this message translates to:
  /// **'That is the current price. Accept instead.'**
  String get samePriceAcceptInstead;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveHours.
  ///
  /// In en, this message translates to:
  /// **'Save hours'**
  String get saveHours;

  /// No description provided for @saveNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get saveNewPassword;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @saveToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Save worker'**
  String get saveToFavourites;

  /// No description provided for @savedWorkers.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedWorkers;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @scheduleExplain.
  ///
  /// In en, this message translates to:
  /// **'You only get job alerts and can only send offers for jobs inside your working hours. Emergency jobs reach you whenever you are switched on as available.'**
  String get scheduleExplain;

  /// No description provided for @scheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Working hours saved.'**
  String get scheduleSaved;

  /// No description provided for @securePayment.
  ///
  /// In en, this message translates to:
  /// **'Secure payment'**
  String get securePayment;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @sendNewCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get sendNewCode;

  /// No description provided for @sendOffer.
  ///
  /// In en, this message translates to:
  /// **'Send offer'**
  String get sendOffer;

  /// No description provided for @sendReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get sendReport;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @sendSos.
  ///
  /// In en, this message translates to:
  /// **'Send SOS'**
  String get sendSos;

  /// No description provided for @sendToEveryone.
  ///
  /// In en, this message translates to:
  /// **'Send to everyone'**
  String get sendToEveryone;

  /// No description provided for @sendYourPrice.
  ///
  /// In en, this message translates to:
  /// **'Send your price'**
  String get sendYourPrice;

  /// No description provided for @sendingEvery15.
  ///
  /// In en, this message translates to:
  /// **'Sending every 15 seconds while this page is open.'**
  String get sendingEvery15;

  /// No description provided for @sentAgo.
  ///
  /// In en, this message translates to:
  /// **'Sent {when}'**
  String sentAgo(Object when);

  /// No description provided for @sentOnlyTo.
  ///
  /// In en, this message translates to:
  /// **'Sent only to {name}. If they cannot make it, send the job to every worker nearby.'**
  String sentOnlyTo(String name);

  /// No description provided for @serverTrouble.
  ///
  /// In en, this message translates to:
  /// **'KaamNow is having trouble right now. Please try again.'**
  String get serverTrouble;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @serviceAdded.
  ///
  /// In en, this message translates to:
  /// **'Service added.'**
  String get serviceAdded;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @setLocationFirst.
  ///
  /// In en, this message translates to:
  /// **'Set the job location on the map, or use your current location.'**
  String get setLocationFirst;

  /// No description provided for @settlementCollection.
  ///
  /// In en, this message translates to:
  /// **'Commission paid'**
  String get settlementCollection;

  /// No description provided for @settlementHistory.
  ///
  /// In en, this message translates to:
  /// **'Payouts and payments'**
  String get settlementHistory;

  /// No description provided for @settlementLine.
  ///
  /// In en, this message translates to:
  /// **'{date} · {method}'**
  String settlementLine(Object date, Object method);

  /// No description provided for @settlementPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout to you'**
  String get settlementPayout;

  /// No description provided for @shareLiveLocation.
  ///
  /// In en, this message translates to:
  /// **'Share my live location with the customer'**
  String get shareLiveLocation;

  /// No description provided for @shareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share with family'**
  String get shareTrip;

  /// No description provided for @shareTripHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can see the job\'s status and, while the worker is on the way, where they are. It never shows phone numbers or the address. It stops working {when}.'**
  String shareTripHint(String when);

  /// No description provided for @sharedByName.
  ///
  /// In en, this message translates to:
  /// **'{name} shared this job with you'**
  String sharedByName(String name);

  /// No description provided for @sharedJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared job'**
  String get sharedJobTitle;

  /// No description provided for @sharedLinkEnds.
  ///
  /// In en, this message translates to:
  /// **'This link stops working {when}.'**
  String sharedLinkEnds(String when);

  /// No description provided for @sharingOn.
  ///
  /// In en, this message translates to:
  /// **'Shared with family until {time}'**
  String sharingOn(String time);

  /// No description provided for @sharingStopped.
  ///
  /// In en, this message translates to:
  /// **'Sharing stopped. The link no longer works.'**
  String get sharingStopped;

  /// No description provided for @shortBio.
  ///
  /// In en, this message translates to:
  /// **'Short bio'**
  String get shortBio;

  /// No description provided for @sixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code from the customer'**
  String get sixDigitCode;

  /// No description provided for @skipNextVisit.
  ///
  /// In en, this message translates to:
  /// **'Skip next visit'**
  String get skipNextVisit;

  /// No description provided for @skippedNextVisit.
  ///
  /// In en, this message translates to:
  /// **'Next visit skipped.'**
  String get skippedNextVisit;

  /// No description provided for @smsCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get smsCode;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWentWrong;

  /// No description provided for @somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWrong;

  /// No description provided for @sortFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest arrival'**
  String get sortFastest;

  /// No description provided for @sortHighestRating.
  ///
  /// In en, this message translates to:
  /// **'Highest rating'**
  String get sortHighestRating;

  /// No description provided for @sortLowestPrice.
  ///
  /// In en, this message translates to:
  /// **'Lowest price'**
  String get sortLowestPrice;

  /// No description provided for @sortMostExperience.
  ///
  /// In en, this message translates to:
  /// **'Most experience'**
  String get sortMostExperience;

  /// No description provided for @sortMostJobs.
  ///
  /// In en, this message translates to:
  /// **'Most jobs'**
  String get sortMostJobs;

  /// No description provided for @sortNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get sortNearest;

  /// No description provided for @sosBody.
  ///
  /// In en, this message translates to:
  /// **'KaamNow\'s team is alerted at once, and your emergency contacts get a text with a link to follow this job. The other person is not told. If you are in danger, call 15 (police) or 1122 (rescue) first.'**
  String get sosBody;

  /// No description provided for @sosButton.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sosButton;

  /// No description provided for @sosContactsTexted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No emergency contacts were texted.} =1{1 emergency contact was texted.} other{{count} emergency contacts were texted.}}'**
  String sosContactsTexted(int count);

  /// No description provided for @sosNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'What is happening? (optional)'**
  String get sosNoteLabel;

  /// No description provided for @sosOpenBanner.
  ///
  /// In en, this message translates to:
  /// **'Your SOS is open. KaamNow\'s team will call you. If you are in danger, call 15.'**
  String get sosOpenBanner;

  /// No description provided for @sosSeenBanner.
  ///
  /// In en, this message translates to:
  /// **'KaamNow has seen your SOS and is on it.'**
  String get sosSeenBanner;

  /// No description provided for @sosSent.
  ///
  /// In en, this message translates to:
  /// **'SOS sent. Our team will call you now.'**
  String get sosSent;

  /// No description provided for @sosTitle.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get sosTitle;

  /// No description provided for @startRepeating.
  ///
  /// In en, this message translates to:
  /// **'Start repeating'**
  String get startRepeating;

  /// No description provided for @startWork.
  ///
  /// In en, this message translates to:
  /// **'Start work'**
  String get startWork;

  /// No description provided for @startingPriceOptional.
  ///
  /// In en, this message translates to:
  /// **'Starting price (optional)'**
  String get startingPriceOptional;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get statusAccepted;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get statusArrived;

  /// No description provided for @statusBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get statusBooked;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get statusCollected;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get statusDisputed;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'Work in progress'**
  String get statusInProgress;

  /// No description provided for @statusInReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get statusInReview;

  /// No description provided for @statusOffered.
  ///
  /// In en, this message translates to:
  /// **'Offered'**
  String get statusOffered;

  /// No description provided for @statusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get statusOnTheWay;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get statusPendingPayment;

  /// No description provided for @statusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get statusRefunded;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get statusRequested;

  /// No description provided for @statusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get statusResolved;

  /// No description provided for @statusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Status updated: {status}'**
  String statusUpdated(Object status);

  /// No description provided for @statusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get statusVerified;

  /// No description provided for @statusWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get statusWithdrawn;

  /// No description provided for @stopGettingJobs.
  ///
  /// In en, this message translates to:
  /// **'You will stop getting these jobs.'**
  String get stopGettingJobs;

  /// No description provided for @stopRepeating.
  ///
  /// In en, this message translates to:
  /// **'Stop repeating'**
  String get stopRepeating;

  /// No description provided for @stopRepeatingBody.
  ///
  /// In en, this message translates to:
  /// **'No more visits will be posted. Jobs already posted stay as they are.'**
  String get stopRepeatingBody;

  /// No description provided for @stopRepeatingQ.
  ///
  /// In en, this message translates to:
  /// **'Stop repeating this job?'**
  String get stopRepeatingQ;

  /// No description provided for @stopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get stopSharing;

  /// No description provided for @stoppedRepeating.
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get stoppedRepeating;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support: {email}'**
  String supportEmail(Object email);

  /// No description provided for @switchToPlan.
  ///
  /// In en, this message translates to:
  /// **'Switch to this plan'**
  String get switchToPlan;

  /// No description provided for @switchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}.'**
  String switchedTo(Object name);

  /// No description provided for @tabAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// No description provided for @tabAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabAlerts;

  /// No description provided for @tabBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get tabBookings;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get tabJobs;

  /// No description provided for @tabMyOffers.
  ///
  /// In en, this message translates to:
  /// **'My offers'**
  String get tabMyOffers;

  /// No description provided for @tabMyRequests.
  ///
  /// In en, this message translates to:
  /// **'My requests'**
  String get tabMyRequests;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Trusted help in Lahore, at your price'**
  String get tagline;

  /// No description provided for @tapMapToPin.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to place the pin.'**
  String get tapMapToPin;

  /// No description provided for @tellUsWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened'**
  String get tellUsWhatHappened;

  /// No description provided for @textMyContacts.
  ///
  /// In en, this message translates to:
  /// **'Text it to my emergency contacts'**
  String get textMyContacts;

  /// No description provided for @thanksForReview.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your review!'**
  String get thanksForReview;

  /// No description provided for @thanksWillReview.
  ///
  /// In en, this message translates to:
  /// **'Thanks. KaamNow will review your report.'**
  String get thanksWillReview;

  /// No description provided for @timeOff.
  ///
  /// In en, this message translates to:
  /// **'Days off'**
  String get timeOff;

  /// No description provided for @timeOffAdded.
  ///
  /// In en, this message translates to:
  /// **'Days off added.'**
  String get timeOffAdded;

  /// No description provided for @timeOffExplain.
  ///
  /// In en, this message translates to:
  /// **'Holiday, wedding or leave. You get no new jobs on these days.'**
  String get timeOffExplain;

  /// No description provided for @timeOffReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional, only you see it)'**
  String get timeOffReasonLabel;

  /// No description provided for @timeOffReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Reason for days off'**
  String get timeOffReasonTitle;

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String timeRange(String start, String end);

  /// No description provided for @timeWindow.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String timeWindow(String start, String end);

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ceiling fan not working'**
  String get titleHint;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @toWord.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get toWord;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @trackingStarts.
  ///
  /// In en, this message translates to:
  /// **'Tracking starts when the worker sets off.'**
  String get trackingStarts;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get typeMessage;

  /// No description provided for @unlimitedOffers.
  ///
  /// In en, this message translates to:
  /// **'Unlimited offers'**
  String get unlimitedOffers;

  /// No description provided for @updateDocsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Update your documents and try again.'**
  String get updateDocsTryAgain;

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'updated {when}'**
  String updatedAgo(Object when);

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @urgentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shown first to workers. Adds a {fee} fee.'**
  String urgentSubtitle(Object fee);

  /// No description provided for @urgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Urgent? Mark your job as an emergency'**
  String get urgentTitle;

  /// No description provided for @useAtLeast8.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get useAtLeast8;

  /// No description provided for @useCredit.
  ///
  /// In en, this message translates to:
  /// **'Use my credit ({amount})'**
  String useCredit(Object amount);

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {time}'**
  String validUntil(Object time);

  /// No description provided for @verificationDocuments.
  ///
  /// In en, this message translates to:
  /// **'Verification documents'**
  String get verificationDocuments;

  /// No description provided for @verificationRejected.
  ///
  /// In en, this message translates to:
  /// **'Verification was rejected'**
  String get verificationRejected;

  /// No description provided for @verifiedByKaamNow.
  ///
  /// In en, this message translates to:
  /// **'Verified by KaamNow'**
  String get verifiedByKaamNow;

  /// No description provided for @verifiedByKaamnow.
  ///
  /// In en, this message translates to:
  /// **'Verified by KaamNow'**
  String get verifiedByKaamnow;

  /// No description provided for @visitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not be posted'**
  String get visitFailed;

  /// No description provided for @visitSentToAll.
  ///
  /// In en, this message translates to:
  /// **'Sent to workers nearby'**
  String get visitSentToAll;

  /// No description provided for @visitSentToWorker.
  ///
  /// In en, this message translates to:
  /// **'Sent to your worker'**
  String get visitSentToWorker;

  /// No description provided for @waitingForCounter.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to respond to your counter offer.'**
  String waitingForCounter(Object name);

  /// No description provided for @waitingForCustomer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the customer.'**
  String get waitingForCustomer;

  /// No description provided for @waitingForCustomerShort.
  ///
  /// In en, this message translates to:
  /// **'Waiting for customer'**
  String get waitingForCustomerShort;

  /// No description provided for @waitingForGateway.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the payment gateway to confirm.'**
  String get waitingForGateway;

  /// No description provided for @waitingForOffers.
  ///
  /// In en, this message translates to:
  /// **'Waiting for offers'**
  String get waitingForOffers;

  /// No description provided for @waitingForOffersHint.
  ///
  /// In en, this message translates to:
  /// **'Nearby workers have been notified. Offers appear here as they arrive.'**
  String get waitingForOffersHint;

  /// No description provided for @waitingForWorkerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the worker to confirm.'**
  String get waitingForWorkerConfirm;

  /// No description provided for @waitingForWorkerLocation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the worker’s location…'**
  String get waitingForWorkerLocation;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance with KaamNow'**
  String get walletBalance;

  /// No description provided for @walletCommissionOwed.
  ///
  /// In en, this message translates to:
  /// **'Commission and charges: {amount}'**
  String walletCommissionOwed(Object amount);

  /// No description provided for @walletEarningsHeld.
  ///
  /// In en, this message translates to:
  /// **'From online payments: {amount}'**
  String walletEarningsHeld(Object amount);

  /// No description provided for @walletExplain.
  ///
  /// In en, this message translates to:
  /// **'Customers who pay online pay KaamNow, so we owe you your share. Customers who pay cash pay you, so you owe our commission. The two are netted here.'**
  String get walletExplain;

  /// No description provided for @walletNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile account number'**
  String get walletNumber;

  /// No description provided for @walletOwedToYou.
  ///
  /// In en, this message translates to:
  /// **'KaamNow owes you'**
  String get walletOwedToYou;

  /// No description provided for @walletSettled.
  ///
  /// In en, this message translates to:
  /// **'All settled'**
  String get walletSettled;

  /// No description provided for @walletYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe KaamNow'**
  String get walletYouOwe;

  /// No description provided for @whatHelp.
  ///
  /// In en, this message translates to:
  /// **'What do you need help with?'**
  String get whatHelp;

  /// No description provided for @whatWentWrong.
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get whatWentWrong;

  /// No description provided for @whenWorkerFree.
  ///
  /// In en, this message translates to:
  /// **'When {name} is free on {day}'**
  String whenWorkerFree(String name, String day);

  /// No description provided for @withWorkerName.
  ///
  /// In en, this message translates to:
  /// **'With {name}'**
  String withWorkerName(String name);

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @withdrawHint.
  ///
  /// In en, this message translates to:
  /// **'You cannot bid on this job again.'**
  String get withdrawHint;

  /// No description provided for @withdrawOfferQ.
  ///
  /// In en, this message translates to:
  /// **'Withdraw your offer?'**
  String get withdrawOfferQ;

  /// No description provided for @workRadius.
  ///
  /// In en, this message translates to:
  /// **'Work radius (km)'**
  String get workRadius;

  /// No description provided for @workedWithBefore.
  ///
  /// In en, this message translates to:
  /// **'Worked for you before'**
  String get workedWithBefore;

  /// No description provided for @worker.
  ///
  /// In en, this message translates to:
  /// **'Worker'**
  String get worker;

  /// No description provided for @workerAway.
  ///
  /// In en, this message translates to:
  /// **'{name} is {km} km away'**
  String workerAway(Object name, Object km);

  /// No description provided for @workerDidNotCome.
  ///
  /// In en, this message translates to:
  /// **'Worker did not come'**
  String get workerDidNotCome;

  /// No description provided for @workerDidNotComeQ.
  ///
  /// In en, this message translates to:
  /// **'Report that the worker did not come?'**
  String get workerDidNotComeQ;

  /// No description provided for @workerNotFreeThatDay.
  ///
  /// In en, this message translates to:
  /// **'This worker is not free on this day. Choose another day.'**
  String get workerNotFreeThatDay;

  /// No description provided for @workerPositionNow.
  ///
  /// In en, this message translates to:
  /// **'Where the worker is now'**
  String get workerPositionNow;

  /// No description provided for @workerProfile.
  ///
  /// In en, this message translates to:
  /// **'Worker profile'**
  String get workerProfile;

  /// No description provided for @workerProfileServicesDocs.
  ///
  /// In en, this message translates to:
  /// **'Worker profile, services and documents'**
  String get workerProfileServicesDocs;

  /// No description provided for @workerSaved.
  ///
  /// In en, this message translates to:
  /// **'Worker saved. Find them in My workers.'**
  String get workerSaved;

  /// No description provided for @workerSignupHint.
  ///
  /// In en, this message translates to:
  /// **'After signing up, upload your CNIC so KaamNow can verify you before you send offers.'**
  String get workerSignupHint;

  /// No description provided for @workerUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved workers.'**
  String get workerUnsaved;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get workingHours;

  /// No description provided for @worksIn.
  ///
  /// In en, this message translates to:
  /// **'Works in {area}'**
  String worksIn(Object area);

  /// No description provided for @wrongNumberLogOut.
  ///
  /// In en, this message translates to:
  /// **'Not your number? Log out'**
  String get wrongNumberLogOut;

  /// No description provided for @yearsExp.
  ///
  /// In en, this message translates to:
  /// **'{n} yrs exp'**
  String yearsExp(Object n);

  /// No description provided for @yearsExperience.
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get yearsExperience;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @youAgreed.
  ///
  /// In en, this message translates to:
  /// **'You agreed. Waiting for the customer.'**
  String get youAgreed;

  /// No description provided for @youAreAvailable.
  ///
  /// In en, this message translates to:
  /// **'You are available for jobs'**
  String get youAreAvailable;

  /// No description provided for @youAreOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get youAreOffline;

  /// No description provided for @youEarned.
  ///
  /// In en, this message translates to:
  /// **'You earned'**
  String get youEarned;

  /// No description provided for @youPay.
  ///
  /// In en, this message translates to:
  /// **'You pay {amount}'**
  String youPay(Object amount);

  /// No description provided for @yourInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Your invite code'**
  String get yourInviteCode;

  /// No description provided for @yourOffer.
  ///
  /// In en, this message translates to:
  /// **'Your offer'**
  String get yourOffer;

  /// No description provided for @yourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get yourPhoneNumber;

  /// No description provided for @yourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get yourPlan;

  /// No description provided for @yourPrice.
  ///
  /// In en, this message translates to:
  /// **'Your price'**
  String get yourPrice;
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
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
