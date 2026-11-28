// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String aboutMinutes(Object n) {
    return 'about $n min';
  }

  @override
  String get aboutYou => 'About you';

  @override
  String get accept => 'Accept';

  @override
  String get acceptAndPickTime => 'Accept and pick a time';

  @override
  String get accountTitle => 'Account holder name';

  @override
  String get add => 'Add';

  @override
  String get addAService => 'Add a service';

  @override
  String get addAddress => 'Add address';

  @override
  String get addAfterPhoto => 'Add an after photo';

  @override
  String get addBeforePhoto => 'Add a before photo';

  @override
  String get addContact => 'Add contact';

  @override
  String get addPackage => 'Add package';

  @override
  String get addPart => 'Add part';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get addServicesToSeeJobs =>
      'Add the services you offer to see matching jobs.';

  @override
  String get addTimeOff => 'Add days off';

  @override
  String get address => 'Address';

  @override
  String get addressAfterBooking =>
      'The exact address is shared once you are booked.';

  @override
  String get addressDefaultBadge => 'Default';

  @override
  String get addressDeleted => 'Address deleted.';

  @override
  String get addressHelper => 'Only the worker you book will see it';

  @override
  String get addressSaved => 'Address saved.';

  @override
  String get afterWork => 'After';

  @override
  String get agree => 'Agree';

  @override
  String agreeToAmount(Object amount) {
    return 'Agree to $amount';
  }

  @override
  String get agreeToHint => 'The customer then confirms to book you.';

  @override
  String agreeToQ(Object price) {
    return 'Agree to $price?';
  }

  @override
  String get agreedPrice => 'Agreed price';

  @override
  String get all => 'All';

  @override
  String get allBusyHint =>
      'No matching workers are free on this day. You can still post: workers may free up, or choose another day.';

  @override
  String get allServices => 'All';

  @override
  String get allServicesOffered => 'You already offer every service.';

  @override
  String amountDue(Object amount) {
    return 'Amount due: $amount';
  }

  @override
  String get anyWorkerNearby => 'Any free worker nearby';

  @override
  String get anythingToAdd => 'Anything to add? (optional)';

  @override
  String get appName => 'KaamNow';

  @override
  String appVersion(Object version) {
    return 'KaamNow $version';
  }

  @override
  String get applyPromo => 'Apply';

  @override
  String get approve => 'Approve';

  @override
  String get areaHint => 'e.g. DHA Phase 5';

  @override
  String areaLine(Object area) {
    return 'Area: $area';
  }

  @override
  String get areaOptional => 'Area (optional)';

  @override
  String get areasHint => 'e.g. Gulberg, Model Town';

  @override
  String get areasYouCover => 'Areas you cover';

  @override
  String get arriveInMinutes => 'You can arrive in (minutes)';

  @override
  String get askFreeFix => 'Ask for a free fix';

  @override
  String get askFreeFixHint =>
      'Tell the worker what went wrong again. They will answer within 48 hours.';

  @override
  String get askedForYou => 'The customer asked for you';

  @override
  String get atLeast5 => 'At least 5 characters';

  @override
  String get atLeast8 => 'At least 8 characters';

  @override
  String autoCompletesAt(Object time) {
    return 'If you do not answer, it completes on its own at $time.';
  }

  @override
  String autoCompletesAtWorker(Object time) {
    return 'If they do not answer, it completes on its own at $time.';
  }

  @override
  String get availableAnyTime => 'Available any time';

  @override
  String get availableAnyTimeHelp =>
      'Turn off to set the days and hours you work.';

  @override
  String get back => 'Back';

  @override
  String get backToLogin => 'Back to log in';

  @override
  String get badgeAlwaysOnTime => 'Always on time';

  @override
  String get badgeCustomerFavourite => 'Customer favourite';

  @override
  String get badgeExperienced => '5+ years experience';

  @override
  String get badgeJobs100 => '100+ jobs';

  @override
  String get badgeVerified => 'Verified';

  @override
  String get bankTransfer => 'Bank transfer';

  @override
  String get baseLocation => 'Base location';

  @override
  String get baseLocationHint =>
      'Jobs are matched by distance from here. Customers never see it.';

  @override
  String get beforeWork => 'Before';

  @override
  String get book => 'Book';

  @override
  String get bookAgain => 'Book again';

  @override
  String bookAgree(Object price) {
    return 'You agree to pay $price. All other offers will be closed.';
  }

  @override
  String bookAgreeEmergency(Object price, Object fee) {
    return 'You agree to pay $price plus the $fee emergency fee. All other offers will be closed.';
  }

  @override
  String bookFor(Object price) {
    return 'Book for $price';
  }

  @override
  String get bookPackage => 'Book';

  @override
  String get bookThisWorker => 'Book this worker';

  @override
  String bookWorkerQ(Object name) {
    return 'Book $name?';
  }

  @override
  String get booked => 'Booked!';

  @override
  String get booking => 'Booking';

  @override
  String get bookingCancelled => 'Booking cancelled.';

  @override
  String bookingNumber(Object id) {
    return 'Booking #$id';
  }

  @override
  String bookingNumberPrice(Object id, Object price) {
    return 'Booking #$id · $price';
  }

  @override
  String get bookingRemindersHint =>
      'A reminder the day before and an hour before each booked job';

  @override
  String get bookingRemindersSetting => 'Job reminders';

  @override
  String bookingWorkerDirectly(String name) {
    return 'Booking $name';
  }

  @override
  String get bookingWorkerDirectlyHint =>
      'Only this worker sees your job. If they cannot make it, you can send it to everyone.';

  @override
  String budget(Object amount) {
    return 'Budget: $amount';
  }

  @override
  String budgetLower(Object amount) {
    return 'budget $amount';
  }

  @override
  String get budgetOptional => 'Your budget (optional)';

  @override
  String get cancel => 'Cancel';

  @override
  String get cancelBooking => 'Cancel booking';

  @override
  String get cancelBookingQ => 'Cancel this booking?';

  @override
  String cancelFeeLate(Object amount) {
    return 'Cancelling now costs $amount, because the job starts soon. It goes to the worker for the time they set aside.';
  }

  @override
  String cancelFeeOnTheWay(Object amount) {
    return 'The worker is already on the way, so cancelling now costs $amount. It goes to the worker for their trip.';
  }

  @override
  String cancelFreeUntil(Object time, Object amount) {
    return 'Cancelling is free until $time. After that it costs $amount.';
  }

  @override
  String get cancelPayout => 'Cancel request';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get cancelRequestQ => 'Cancel this request?';

  @override
  String cancelledReason(Object reason) {
    return 'Cancelled: $reason';
  }

  @override
  String get cannotTakeJob => 'I cannot take this job';

  @override
  String get cannotTakeJobHint =>
      'The customer will be told, and the job goes to other workers nearby.';

  @override
  String get cannotTakeJobOk => 'Pass on it';

  @override
  String get cannotTakeJobQ => 'Pass on this job?';

  @override
  String get cantDoThisAnyMore => 'I cannot do this any more';

  @override
  String get cashReceivedQ => 'Cash received?';

  @override
  String get ccAppIssue => 'Problem with the app';

  @override
  String get ccBehaviour => 'Behaviour';

  @override
  String get ccDamage => 'Damage to property';

  @override
  String get ccFraud => 'Fraud';

  @override
  String get ccNoShow => 'Did not show up';

  @override
  String get ccOther => 'Something else';

  @override
  String get ccOvercharging => 'Overcharging';

  @override
  String get ccPayment => 'Payment problem';

  @override
  String get ccServiceQuality => 'Poor service quality';

  @override
  String get change => 'Change';

  @override
  String get changeHowOften => 'Change how often';

  @override
  String get changePassword => 'Change password';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get chat => 'Chat';

  @override
  String get chooseAService => 'Choose a service';

  @override
  String get chooseDaysOff => 'Choose your days off';

  @override
  String get chooseNewPassword => 'Choose a new password';

  @override
  String get chooseOneWorkingDay =>
      'Choose at least one working day, or turn on \"Available any time\".';

  @override
  String get chooseService => 'Choose a service.';

  @override
  String get claimAcceptedMsg => 'Accepted. The customer has been told.';

  @override
  String claimAnswerBy(Object time) {
    return 'The customer asked for a free fix. Please answer by $time.';
  }

  @override
  String get claimDeclined => 'The worker declined the claim.';

  @override
  String get claimDeclinedMsg => 'Declined. The customer has been told.';

  @override
  String get claimEscalated => 'Sent to the KaamNow team. We will contact you.';

  @override
  String get claimEscalatedMsg => 'Sent. You can follow it under complaints.';

  @override
  String get claimFixed => 'Fixed. The claim is closed.';

  @override
  String get claimRedoDone => 'The worker says it is fixed.';

  @override
  String get claimRedoDoneMsg => 'The customer will be asked to confirm.';

  @override
  String get claimSent => 'Claim sent to the worker.';

  @override
  String get claimWaitingWorker => 'Waiting for the worker to answer.';

  @override
  String get claimWithdrawn => 'The claim was withdrawn.';

  @override
  String get claimWithdrawnMsg => 'Claim withdrawn.';

  @override
  String claimWorkerComing(Object time) {
    return 'The worker will come back $time to fix it for free.';
  }

  @override
  String get close => 'Close';

  @override
  String get cnicNumber => 'CNIC number';

  @override
  String get cnicPrivate =>
      'CNIC images are private. Only KaamNow staff can see them.';

  @override
  String codeSentTo(String phone) {
    return 'Enter the code we sent to $phone.';
  }

  @override
  String comingSoon(Object method) {
    return '$method (coming soon)';
  }

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String commissionDue(Object amount) {
    return 'Commission due: $amount';
  }

  @override
  String get commissionDueHint =>
      'From cash jobs. KaamNow will contact you about settling it.';

  @override
  String commissionKeep(Object percent, Object amount, Object earning) {
    return 'KaamNow commission $percent%: $amount. You keep $earning.';
  }

  @override
  String commissionLine(Object percent, Object amount, Object date) {
    return '$percent% commission $amount · $date';
  }

  @override
  String commissionPaymentOpen(Object amount) {
    return 'Commission payment of $amount in progress';
  }

  @override
  String get commissionPaymentWindowClosed =>
      'Payment window closed. Your wallet updates once JazzCash or Easypaisa confirms it.';

  @override
  String commissionPercent(Object percent) {
    return 'Commission $percent%';
  }

  @override
  String commissionRateNow(Object percent) {
    return 'Your current commission rate is $percent%.';
  }

  @override
  String get commissionStandard => 'Commission standard';

  @override
  String get complete => 'Complete';

  @override
  String get completeJob => 'Complete job';

  @override
  String get completePaymentNewTab =>
      'Complete the payment in the new tab. This page updates once the gateway confirms it.';

  @override
  String get completeWithCode => 'Complete with customer’s code';

  @override
  String get completedJobs => 'Completed jobs';

  @override
  String get completionCode => 'Completion code';

  @override
  String get completionCodeHint =>
      'Give this code to the worker only when the job is done to your satisfaction.';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get confirmBooking => 'Confirm booking';

  @override
  String confirmCashAmount(Object amount) {
    return 'Confirm you received $amount in cash.';
  }

  @override
  String get confirmJobDone => 'Confirm job is done';

  @override
  String confirmNumberHint(String phone) {
    return 'We will send a 6-digit code by SMS to $phone. This keeps KaamNow safe for customers and workers.';
  }

  @override
  String get confirmOncePaid => 'Confirm once the customer has paid you.';

  @override
  String get confirmYourNumber => 'Confirm your phone number';

  @override
  String get contact => 'Contact';

  @override
  String get contactAdded => 'Added.';

  @override
  String get contactPhoneLabel => 'Mobile number';

  @override
  String get contactRemoved => 'Removed.';

  @override
  String get continueAction => 'Continue';

  @override
  String get copyInvite => 'Copy invite';

  @override
  String get copyLink => 'Copy link';

  @override
  String get couldNotGetLocation => 'Could not get your location.';

  @override
  String get couldNotSendLocation => 'Could not send your location.';

  @override
  String get counter => 'Counter';

  @override
  String get counterOffer => 'Counter offer';

  @override
  String get counterSent => 'Counter offer sent.';

  @override
  String get createAccount => 'Create account';

  @override
  String get createAnAccount => 'Create an account';

  @override
  String get creditAdmin => 'From KaamNow';

  @override
  String creditApplied(Object amount) {
    return 'Credit: $amount off';
  }

  @override
  String creditBalance(Object amount) {
    return 'Your credit: $amount';
  }

  @override
  String get creditHistory => 'Credit history';

  @override
  String get creditReferral => 'Invite reward';

  @override
  String get creditReturned => 'Returned';

  @override
  String get creditSpent => 'Used on a booking';

  @override
  String get creditWelcome => 'Welcome credit';

  @override
  String get currentPassword => 'Current password';

  @override
  String currentPlan(Object name) {
    return 'Current plan: $name';
  }

  @override
  String currentPrice(Object amount) {
    return 'Current price: $amount';
  }

  @override
  String get customer => 'Customer';

  @override
  String get customerAskedToConfirm =>
      'The customer has been asked to confirm.';

  @override
  String customerBudget(Object amount) {
    return 'Customer budget: $amount';
  }

  @override
  String get customerCounteredShort => 'Customer countered. Your move.';

  @override
  String get customerCounteredYourMove =>
      'The customer made a counter offer. Your move.';

  @override
  String get customerDoneHint =>
      'When the work is done, tap Job completed. The job closes and the worker is free for new requests.';

  @override
  String get customerNotPaid => 'The customer has not paid yet.';

  @override
  String get customerNotThere => 'Customer not there';

  @override
  String get customerNotThereQ => 'Report that the customer was not there?';

  @override
  String get customersPaid => 'Customers paid';

  @override
  String dateRange(String start, String end) {
    return '$start to $end';
  }

  @override
  String get dayOff => 'Day off';

  @override
  String daysAgo(Object n) {
    return '$n d ago';
  }

  @override
  String get declineClaim => 'Decline';

  @override
  String get declineClaimHint =>
      'Tell the customer why. They can send the claim to the KaamNow team if they disagree.';

  @override
  String get defaultAddress => 'Default address';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAddressQ => 'Delete this address?';

  @override
  String get deletePackageBody => 'Bookings already made from it are kept.';

  @override
  String get deletePackageQ => 'Delete this package?';

  @override
  String get deletePhotoBody => 'Customers will no longer see it.';

  @override
  String get deletePhotoQ => 'Delete this photo?';

  @override
  String get describeProblem => 'Describe the problem';

  @override
  String get details => 'Details';

  @override
  String get discountNote =>
      'KaamNow pays the discount. Your worker still gets their full share.';

  @override
  String distanceKm(Object km) {
    return '$km km';
  }

  @override
  String get docCertificate => 'Certificate';

  @override
  String get docCnicBack => 'CNIC back';

  @override
  String get docCnicFront => 'CNIC front';

  @override
  String get docOther => 'Other';

  @override
  String docUploaded(Object doc) {
    return '$doc uploaded.';
  }

  @override
  String get done => 'Done';

  @override
  String get downloadFailed => 'Download failed.';

  @override
  String get downloadReceiptPdf => 'Download PDF';

  @override
  String get downloadStatement => 'Download statement (CSV)';

  @override
  String durationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get earnings => 'Earnings';

  @override
  String get earningsReports => 'Earnings reports';

  @override
  String get earningsReportsHint =>
      'By week or month, by service, cash and online, with a statement to download';

  @override
  String get edit => 'Edit';

  @override
  String get editAddress => 'Edit address';

  @override
  String get editCaption => 'Edit caption';

  @override
  String get editPackage => 'Edit package';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get email => 'Email';

  @override
  String get emailOptional => 'Email (optional, for password reset)';

  @override
  String get emergency => 'Emergency';

  @override
  String get emergencyContacts => 'Emergency contacts';

  @override
  String get emergencyContactsHint => 'Texted when you press SOS during a job';

  @override
  String emergencyFee(Object fee) {
    return 'Emergency · fee $fee';
  }

  @override
  String get emergencyFeeLabel => 'Emergency fee';

  @override
  String get emergencyJob => 'Emergency job';

  @override
  String emergencySubtitle(Object fee) {
    return 'Shown first to workers. Adds $fee to the total.';
  }

  @override
  String endAfterStartFor(String day) {
    return 'On $day, the end time must be after the start time.';
  }

  @override
  String get enterAddress => 'Enter the address';

  @override
  String get enterCnic => 'Enter your CNIC number';

  @override
  String get enterCompletionCode => 'Enter completion code';

  @override
  String get enterFullName => 'Enter your full name';

  @override
  String get enterMinutes => 'Enter minutes';

  @override
  String get enterNumber => 'Enter a number';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get enterPhone => 'Enter your phone number';

  @override
  String get enterPrice => 'Enter a price';

  @override
  String get enterTheCode => 'Enter the code from the SMS.';

  @override
  String get enterValidPhone => 'Enter a valid phone number';

  @override
  String etaMinutes(Object n) {
    return '~$n min';
  }

  @override
  String feeCustomerOwed(Object amount) {
    return 'Late cancellation fee: $amount. Please pay it before booking again.';
  }

  @override
  String feeCustomerPaid(Object amount) {
    return 'Late cancellation fee of $amount paid. Thank you.';
  }

  @override
  String get feeOwedHint =>
      'Tap to pay it. You can book again once it is paid.';

  @override
  String feeOwedTitle(Object amount) {
    return 'You owe a late cancellation fee of $amount';
  }

  @override
  String get feePayOffice =>
      'Online payment is not available yet. Pay at the KaamNow office or contact support.';

  @override
  String get feeWaived => 'The cancellation fee was waived.';

  @override
  String feeWorkerOwed(Object amount) {
    return 'You get $amount once the customer pays the late cancellation fee.';
  }

  @override
  String feeWorkerPaid(Object amount) {
    return '$amount cancellation fee added to your wallet.';
  }

  @override
  String get filterActive => 'Active';

  @override
  String get finishPayingNewTab =>
      'Finish paying in the new tab. Your plan activates once it is confirmed.';

  @override
  String get finishedBody => 'The customer will be asked to tap Job completed.';

  @override
  String get finishedQ => 'Finished the work?';

  @override
  String get firstVisit => 'First visit';

  @override
  String get fixedPricePackage => 'Fixed-price package';

  @override
  String get fixedPricePackages => 'Fixed-price packages';

  @override
  String forgotCodeHint(String phone) {
    return 'If $phone has a KaamNow account, we have sent it a code by SMS.';
  }

  @override
  String get forgotEmailOnly =>
      'If this number has an account with an email address, we have emailed a link to reset the password.';

  @override
  String get forgotHint =>
      'Enter your phone number. We will send you a code by SMS to choose a new password.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotTitle => 'Forgot your password?';

  @override
  String get free => 'Free';

  @override
  String freeWorkersOn(String day) {
    return 'Free workers on $day';
  }

  @override
  String get freqBiweekly => 'Every two weeks';

  @override
  String get freqMonthly => 'Every month';

  @override
  String get freqWeekly => 'Every week';

  @override
  String get fromKaamNowJob => 'From a KaamNow job';

  @override
  String fromPrice(Object price) {
    return 'from $price';
  }

  @override
  String fromPriceCap(Object price) {
    return 'From $price';
  }

  @override
  String get fullName => 'Full name';

  @override
  String get getCompletionCode => 'Get completion code';

  @override
  String get getPaid => 'Get paid';

  @override
  String get getVerified => 'Get verified to send offers';

  @override
  String get getVerifiedHint =>
      'Upload both sides of your CNIC, add your services and set your base location. KaamNow reviews new workers before they can bid.';

  @override
  String get guaranteeClaim => 'Work guarantee';

  @override
  String guaranteeUntil(Object date) {
    return 'guarantee until $date';
  }

  @override
  String get helpAndComplaints => 'Help and complaints';

  @override
  String get hireHelp => 'Hire help';

  @override
  String get homeIntro =>
      'Describe the job, get prices from nearby verified workers, and pick the one you like.';

  @override
  String hoursAgo(Object n) {
    return '$n h ago';
  }

  @override
  String get howLongJob => 'How long will the job take?';

  @override
  String get howLongJobHelp =>
      'A rough guess. Workers keep this time free for you.';

  @override
  String get howOften => 'How often?';

  @override
  String get howToInstall => 'How to install';

  @override
  String get iWantTo => 'I want to';

  @override
  String get iban => 'IBAN';

  @override
  String get imOnMyWay => 'I’m on my way';

  @override
  String get install => 'Install';

  @override
  String get installApp => 'Install app';

  @override
  String get installHint =>
      'Add it to your home screen and open it like an app.';

  @override
  String get installTitle => 'Install KaamNow';

  @override
  String get installedThanks =>
      'KaamNow is installed. You can open it from your home screen.';

  @override
  String get inviteCodeHint =>
      'Got a code from a friend? You get credit off your first booking.';

  @override
  String get inviteCodeOptional => 'Invite code (optional)';

  @override
  String get inviteCopied => 'Invite copied. Paste it in WhatsApp or SMS.';

  @override
  String inviteExplain(Object welcome, Object min, Object reward) {
    return 'Friends who sign up with your code get $welcome off their first booking. When they pay a booking of $min or more, you get $reward credit.';
  }

  @override
  String inviteExplainWorker(Object welcome, Object min, Object reward) {
    return 'Customers who sign up with your code get $welcome off their first booking. When they pay a booking of $min or more, $reward is added to your wallet.';
  }

  @override
  String get inviteFriends => 'Invite friends';

  @override
  String inviteMessage(Object code, Object amount, Object link) {
    return 'Book trusted workers in Lahore with KaamNow. Sign up with my code $code and get $amount off your first booking: $link';
  }

  @override
  String invitedCount(int count) {
    return 'Friends who joined: $count';
  }

  @override
  String get iosInstallSteps =>
      'In Safari, tap the Share button, then choose “Add to Home Screen”.';

  @override
  String get itsFixed => 'It\'s fixed';

  @override
  String get iveArrived => 'I’ve arrived';

  @override
  String get iveFinished => 'I\'ve finished the job';

  @override
  String get job => 'Job';

  @override
  String get jobAddress => 'Job address';

  @override
  String get jobCompleted => 'Job completed.';

  @override
  String get jobCompletedButton => 'Job completed';

  @override
  String get jobIsBooked => 'This job is booked';

  @override
  String get jobLocation => 'Job location';

  @override
  String get jobNowRepeats => 'This job now repeats.';

  @override
  String jobNumberPrice(Object id, Object price) {
    return 'Job #$id · $price';
  }

  @override
  String get jobPassedOn => 'Done. The job went to other workers.';

  @override
  String get jobPhotoAdded => 'Photo added.';

  @override
  String get jobPhotos => 'Job photos';

  @override
  String get jobPhotosWorkerHint =>
      'Take photos before you start and after you finish. The customer sees them, and they help if there is ever a dispute.';

  @override
  String get jobPosted => 'Job posted.';

  @override
  String get jobPostedNoWorkers =>
      'Job posted, but no worker nearby offers this service right now. We will keep it open, and workers who come online can still send offers.';

  @override
  String jobPostedNotified(Object n) {
    return 'Job posted. $n nearby workers were notified.';
  }

  @override
  String jobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
    );
    return '$_temp0';
  }

  @override
  String jobsDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs done',
      one: '1 job done',
    );
    return '$_temp0';
  }

  @override
  String get jobsNearYou => 'Jobs near you';

  @override
  String get justNow => 'just now';

  @override
  String get kaamnowCommission => 'KaamNow commission';

  @override
  String kaamnowReply(Object text) {
    return 'KaamNow: $text';
  }

  @override
  String get labelHome => 'Home';

  @override
  String get labelOther => 'Other';

  @override
  String get labelWork => 'Work';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String lastAttempt(Object status, Object reason) {
    return 'Last attempt: $status. $reason';
  }

  @override
  String lastBooked(String date) {
    return 'Last job for you: $date';
  }

  @override
  String leaveRepeatingBody(String name) {
    return '$name will be told, and future visits will go to other workers nearby.';
  }

  @override
  String get leaveRepeatingQ => 'Stop doing this job?';

  @override
  String get leftRepeating => 'Done. You will not get these visits any more.';

  @override
  String get levelHelp =>
      'KaamNow level, from jobs done, ratings and reliability';

  @override
  String get levelNeedsVerification =>
      'Levels start once your account is verified.';

  @override
  String get levelNew => 'New';

  @override
  String get levelRising => 'Rising';

  @override
  String get levelShownHint =>
      'Customers see your level on your offers and profile.';

  @override
  String get levelTopRated => 'Top rated';

  @override
  String get levelTrusted => 'Trusted';

  @override
  String get linkCopied => 'Link copied.';

  @override
  String get linkExpired => 'This link has expired or was turned off.';

  @override
  String get live => 'Live';

  @override
  String get liveTracking => 'Live tracking';

  @override
  String get loadMore => 'Load more';

  @override
  String get location => 'Location';

  @override
  String get locationDenied =>
      'Location permission was denied. You can still place the pin on the map.';

  @override
  String get locationOff => 'Location services are turned off.';

  @override
  String get logIn => 'Log in';

  @override
  String get logOut => 'Log out';

  @override
  String get loginWithNewPassword =>
      'You can log in with your new password now.';

  @override
  String get makeDefault => 'Use first';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get markCompleteQ => 'Mark the job as complete?';

  @override
  String get markFixDone => 'Mark fix done';

  @override
  String get maxAddressesReached => 'You have 10 addresses, the most allowed.';

  @override
  String get maxContactsReached => 'You have 3 contacts, the most allowed.';

  @override
  String get maxPhotosReached =>
      'You have 12 photos, the most allowed. Delete one to add another.';

  @override
  String get messageNotSent => 'Message not sent.';

  @override
  String get messageToCustomer => 'Message to the customer (optional)';

  @override
  String get messagesPrivate =>
      'Messages are private between you and the other person on this booking.';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodEasypaisa => 'Easypaisa';

  @override
  String get methodJazzcash => 'JazzCash';

  @override
  String methodRef(Object method, Object ref) {
    return '$method · ref $ref';
  }

  @override
  String minPayoutHint(Object amount) {
    return 'You can ask for a payout from $amount.';
  }

  @override
  String minimumIs(Object amount) {
    return 'Minimum is $amount';
  }

  @override
  String minutesAgo(Object n) {
    return '$n min ago';
  }

  @override
  String get moreDetail => 'Please give a bit more detail (20+ characters)';

  @override
  String get moveEarlier => 'Move earlier';

  @override
  String get moveLater => 'Move later';

  @override
  String get myLevel => 'My level';

  @override
  String get myLevelHint =>
      'Your level and badges, and how to reach the next level';

  @override
  String get myPackages => 'My packages';

  @override
  String get myPackagesHint =>
      'Fixed-price jobs customers can book straight away';

  @override
  String get myPortfolio => 'My work photos';

  @override
  String get myPortfolioHint => 'Show customers what you have done';

  @override
  String get myReviews => 'My reviews';

  @override
  String get myReviewsHint => 'See what customers said and reply';

  @override
  String get myScheduleSubtitle => 'Days and times you take jobs, and days off';

  @override
  String get myScheduleTitle => 'My working hours';

  @override
  String get myTips => 'My tips';

  @override
  String get myTipsHint => 'Tips customers gave you';

  @override
  String get myWorkerProfile => 'My worker profile';

  @override
  String get myWorkers => 'My workers';

  @override
  String get myWorkersHomeHint => 'Book a worker you liked again';

  @override
  String nFree(int count) {
    return '$count free';
  }

  @override
  String negAccept(Object who, Object amount) {
    return '$who accepted at $amount';
  }

  @override
  String negAgree(Object who, Object amount) {
    return '$who agreed to $amount';
  }

  @override
  String negCounter(Object who, Object amount) {
    return '$who countered with $amount';
  }

  @override
  String negOffer(Object who, Object amount) {
    return '$who offered $amount';
  }

  @override
  String negReject(Object who) {
    return '$who rejected';
  }

  @override
  String negRevise(Object who, Object amount) {
    return '$who revised the price to $amount';
  }

  @override
  String negWithdraw(Object who) {
    return '$who withdrew';
  }

  @override
  String get networkError => 'Could not reach KaamNow. Check your connection.';

  @override
  String get newPassword => 'New password';

  @override
  String nextLevelIs(Object level) {
    return 'To become $level';
  }

  @override
  String nextVisitOn(String when) {
    return 'Next visit: $when';
  }

  @override
  String get no => 'No';

  @override
  String get noActiveBookings => 'No active bookings';

  @override
  String get noAlertsYet => 'No alerts yet';

  @override
  String get noBadgesYet =>
      'No badges yet. They come with experience, saved-by customers and always being on time.';

  @override
  String get noBookingsCustomerHint =>
      'Accept an offer on one of your requests to book a worker.';

  @override
  String get noBookingsWorkerHint =>
      'When a customer accepts your offer, the job appears here.';

  @override
  String get noCancelledBookings => 'No cancelled bookings';

  @override
  String get noComplaints => 'No complaints';

  @override
  String get noComplaintsHint =>
      'If something goes wrong with a job, report it here and KaamNow will look into it.';

  @override
  String get noCompletedBookings => 'No completed bookings';

  @override
  String get noCompletedJobs => 'No completed jobs yet.';

  @override
  String get noEmergencyContacts => 'No emergency contacts yet';

  @override
  String get noEmergencyContactsHint =>
      'Add up to 3 people you trust. When you press SOS during a job, they get a text with a link to follow it.';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get noOffers => 'No offers';

  @override
  String get noOffersHere => 'No offers here';

  @override
  String get noOffersHereHint => 'Offers you send on jobs appear here.';

  @override
  String get noOpenJobs => 'No open jobs right now';

  @override
  String get noOpenJobsHint =>
      'New jobs in your area and services will show up here, and you will get an alert.';

  @override
  String get noPackagesFound => 'No packages here yet';

  @override
  String get noPackagesFoundHint =>
      'Post a job instead and workers nearby will send you offers.';

  @override
  String get noPackagesYet => 'No packages yet';

  @override
  String get noPortfolioHint =>
      'Add up to 12 photos of jobs you did. Customers see them on your profile. Location and camera details are removed from each photo.';

  @override
  String get noPortfolioYet => 'No work photos yet';

  @override
  String get noRepeatingJobs => 'No repeating jobs';

  @override
  String get noRepeatingJobsCustomer =>
      'Open a booking and tap Repeat this job to have it done every week or month.';

  @override
  String get noRepeatingJobsWorker =>
      'When a customer repeats a job with you, it shows here.';

  @override
  String get noRequestsHint => 'Post a job to get prices from nearby workers.';

  @override
  String get noRequestsYet => 'No requests yet';

  @override
  String get noReviewsYet => 'No reviews yet.';

  @override
  String get noSavedAddresses => 'No saved addresses';

  @override
  String get noSavedAddressesHint =>
      'Save Home, Work and other places (up to 10) to post jobs faster, with the pin in the right place.';

  @override
  String get noService => 'None';

  @override
  String get noServicesYet => 'No services yet';

  @override
  String get noShowCustomerReported => 'Reported: the customer was not there.';

  @override
  String get noShowNoteLabel => 'What happened? (optional)';

  @override
  String get noShowReported =>
      'Reported. The booking is cancelled and our team will review it.';

  @override
  String noShowWait(String time) {
    return 'You can report this after $time. Try calling first.';
  }

  @override
  String get noShowWorkerReported => 'Reported: the worker did not come.';

  @override
  String get noSlotsLeft =>
      'No time slots left on this day. Choose another day.';

  @override
  String get noTimeOff => 'No days off planned.';

  @override
  String get noTips =>
      'No tips yet. Great work and a friendly word often bring one.';

  @override
  String get noWorkersYet => 'No workers yet';

  @override
  String get noWorkersYetHint =>
      'Tap the heart on a worker you liked to save them. Workers who finish a job for you also show here.';

  @override
  String get noneFree => 'none free';

  @override
  String get notFinishedReason => 'What is still left to do?';

  @override
  String get notFinishedYet => 'Not finished yet';

  @override
  String get notNow => 'Not now';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get numberConfirmed => 'Phone number confirmed.';

  @override
  String get off => 'Off';

  @override
  String get offerSent => 'Offer sent. The customer will be notified.';

  @override
  String get offerServices => 'Offer services';

  @override
  String offersADay(Object n) {
    return '$n offers a day';
  }

  @override
  String offersBlockedDebt(Object amount) {
    return 'You owe more than $amount in commission, so you cannot send offers until you pay.';
  }

  @override
  String offersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers',
      one: '1 offer',
    );
    return '$_temp0';
  }

  @override
  String offersHeading(Object n) {
    return 'Offers ($n)';
  }

  @override
  String offersLeftToday(Object n) {
    return '$n offers left today';
  }

  @override
  String get ok => 'OK';

  @override
  String get onlinePaymentSoon =>
      'Online payment is coming soon. Contact KaamNow support to upgrade.';

  @override
  String get onlinePaymentUnavailable =>
      'Online payment is not available on this device yet.';

  @override
  String get onlyAvailableGetAlerts =>
      'Only available workers get new job alerts.';

  @override
  String get onlyIfDone => 'Only confirm if the work is done.';

  @override
  String get openAction => 'Open';

  @override
  String get openBooking => 'Open booking';

  @override
  String get osmCredit => '© OpenStreetMap contributors';

  @override
  String get otherDay => 'Other day';

  @override
  String get packageBooked => 'Booked! The worker has been told.';

  @override
  String packageBookedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Booked $count times',
      one: 'Booked once',
    );
    return '$_temp0';
  }

  @override
  String get packageChooseAddress => 'Choose an address, or use your location.';

  @override
  String get packageDeleted => 'Package deleted.';

  @override
  String get packageDescription => 'Description (optional)';

  @override
  String get packageDuration => 'How long it takes';

  @override
  String get packageFixedPriceNote =>
      'Customers pay exactly this price. Parts or extra work not listed are agreed in chat before you start.';

  @override
  String packageHiddenByAdmin(Object reason) {
    return 'Hidden by KaamNow: $reason';
  }

  @override
  String get packageIncludes => 'What\'s included (one per line)';

  @override
  String get packageIncludesHint => 'Filter wash\nGas pressure check';

  @override
  String get packageIncludesTooLong => 'Keep each line under 80 characters.';

  @override
  String get packageIncludesTooMany => 'List up to 8 things.';

  @override
  String get packageLive => 'Package is live again.';

  @override
  String get packageNoBidding =>
      'Fixed price. No offers or bargaining. You pay after the job is done.';

  @override
  String get packageNotes => 'Notes for the worker (optional)';

  @override
  String get packageNotesHint => 'e.g. gate code, AC brand, floor';

  @override
  String get packagePaused => 'Package paused. Customers no longer see it.';

  @override
  String get packagePausedLabel => 'Paused';

  @override
  String get packagePrice => 'Fixed price';

  @override
  String get packagePriceLabel => 'Package price';

  @override
  String get packageSaved => 'Package saved.';

  @override
  String get packageShown => 'Shown to customers';

  @override
  String get packageTitle => 'Package name';

  @override
  String get packageTitleHint => 'e.g. AC service (1 unit)';

  @override
  String packageTotal(Object amount) {
    return 'Total: $amount';
  }

  @override
  String get packageWhen => 'When';

  @override
  String get packageWhere => 'Where';

  @override
  String get packageWriteAddress =>
      'Write the full address (house, street, block).';

  @override
  String get packagesBrowseIntro =>
      'Each package has a fixed price. Pick a time the worker is free and your booking is confirmed straight away.';

  @override
  String get packagesHomeHint => 'Book a set job at a set price, no bargaining';

  @override
  String get packagesIntro =>
      'Offer set jobs at a set price, like \"AC service, Rs 2,500\". Customers book a time you are free, with no bargaining.';

  @override
  String packagesLimit(int n) {
    return 'You can have up to $n packages.';
  }

  @override
  String packagesNear(Object place) {
    return 'Showing workers who come to $place';
  }

  @override
  String get packagesNeedService =>
      'Add a service to your profile first, then make packages for it.';

  @override
  String paidAmount(Object amount) {
    return 'Paid $amount';
  }

  @override
  String get partAddReceipt => 'Add receipt photo (optional)';

  @override
  String get partAdded =>
      'Part added. The customer has been asked to approve it.';

  @override
  String get partApprovalNote =>
      'The customer must approve this before it is added to the bill.';

  @override
  String get partApproved => 'Part approved. It is added to your bill.';

  @override
  String partEach(Object amount) {
    return '$amount each';
  }

  @override
  String get partName => 'What did you buy?';

  @override
  String get partNameHint => 'e.g. 10 amp breaker';

  @override
  String get partQuantity => 'Quantity';

  @override
  String get partReceipt => 'Receipt';

  @override
  String get partReceiptAdded => 'Receipt photo added';

  @override
  String get partRejected => 'Part rejected. The worker has been told.';

  @override
  String partRejectedBecause(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get partStatusApproved => 'Approved';

  @override
  String get partStatusPending => 'Waiting for the customer';

  @override
  String get partStatusRejected => 'Rejected';

  @override
  String partTotalIs(Object amount) {
    return 'Total: $amount';
  }

  @override
  String get partUnitPrice => 'Price for one';

  @override
  String get partsAndMaterials => 'Parts and materials';

  @override
  String get partsApprovedTotal => 'Approved parts';

  @override
  String get partsCustomerHint =>
      'Parts the worker bought for your job. Only the ones you approve are added to your bill.';

  @override
  String get partsLabel => 'Parts and materials';

  @override
  String partsPendingBeforePay(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n parts are waiting for you. Approve or reject them before paying.',
      one: '1 part is waiting for you. Approve or reject it before paying.',
    );
    return '$_temp0';
  }

  @override
  String get partsWorkerHint =>
      'Add the parts you bought for this job. The customer approves each one before paying. KaamNow takes no commission on parts.';

  @override
  String get password => 'Password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get passwordChangedShort => 'Password changed.';

  @override
  String get passwordsDontMatch => 'The passwords do not match';

  @override
  String get pastWork => 'Past work';

  @override
  String get pauseRepeating => 'Pause';

  @override
  String get pausedRepeating => 'Paused. No visits until you resume.';

  @override
  String get payCash =>
      'Pay the worker in cash. They will confirm when they receive it.';

  @override
  String get payCommission => 'Pay commission';

  @override
  String get payCommissionOffice =>
      'Pay online when available, or hand it to the KaamNow office and they will record it.';

  @override
  String payWith(Object method) {
    return 'Pay with $method';
  }

  @override
  String get payment => 'Payment';

  @override
  String get paymentConfirmed => 'Payment confirmed.';

  @override
  String get paymentPageFailed =>
      'The payment page could not be opened. Check your connection and try again.';

  @override
  String paymentPending(Object method, Object amount) {
    return '$method payment of $amount pending';
  }

  @override
  String paymentRefunded(Object amount) {
    return 'Your payment of $amount was refunded.';
  }

  @override
  String get paymentWindowClosed =>
      'This page updates once the gateway confirms the payment.';

  @override
  String get payoutCancelled => 'Payout request cancelled.';

  @override
  String payoutOpen(Object amount) {
    return 'Payout of $amount requested';
  }

  @override
  String payoutOpenHint(Object method, Object account) {
    return 'To $method $account. Jobs in it are not counted in your balance until it is sent or declined.';
  }

  @override
  String get payoutRequested => 'Payout requested. We will send it soon.';

  @override
  String get payoutTo => 'Send it to';

  @override
  String get periodCustom => 'Choose dates';

  @override
  String get periodLastMonth => 'Last month';

  @override
  String periodRange(Object start, Object end) {
    return '$start to $end';
  }

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodThisWeek => 'This week';

  @override
  String get periodThisYear => 'This year';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get photoAdded => 'Photo added.';

  @override
  String get photoCaptionLabel => 'What is in the photo? (optional)';

  @override
  String get photoDeleted => 'Photo deleted.';

  @override
  String photoHiddenBy(String reason) {
    return 'Hidden by KaamNow: $reason';
  }

  @override
  String get photoServiceLabel => 'Service (optional)';

  @override
  String get photoUpdated => 'Photo updated.';

  @override
  String photosCount(int count, int max) {
    return '$count of $max photos';
  }

  @override
  String get photosOptional => 'Photos (optional)';

  @override
  String get pickATime => 'Pick a time first.';

  @override
  String get pinPlaced => 'Pin placed. Tap the map to move it.';

  @override
  String get placeNameHint => 'e.g. Ammi\'s house';

  @override
  String get placeNameLabel => 'Name of this place';

  @override
  String get planPaymentWindowClosed =>
      'Your plan activates once the payment is confirmed.';

  @override
  String get plans => 'Plans';

  @override
  String get postAJob => 'Post a job';

  @override
  String get postJobGetOffers => 'Post job and get offers';

  @override
  String get preferredTime => 'Preferred time';

  @override
  String pricePerDays(Object price, Object days) {
    return '$price / $days days';
  }

  @override
  String get problem => 'Problem';

  @override
  String get problemCameBack => 'Problem came back? Ask for a free fix';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String promoApplied(Object code, Object amount) {
    return '$code: $amount off';
  }

  @override
  String get promoCode => 'Promo code';

  @override
  String get pushBlockedHint =>
      'Blocked in your browser. Allow notifications for this site in the browser settings.';

  @override
  String get pushBlockedHintPhone =>
      'Blocked in your phone settings. Allow notifications for KaamNow in Settings.';

  @override
  String get pushHintCustomer =>
      'Know right away when workers send offers and when your booking changes.';

  @override
  String get pushHintWorker =>
      'Hear about new jobs nearby and customer replies right away.';

  @override
  String get pushNeedsInstallHint =>
      'On iPhone, first install KaamNow (Share, then “Add to Home Screen”), then turn this on in the installed app.';

  @override
  String get pushNotAllowed => 'Notifications were not allowed.';

  @override
  String get pushOffHint => 'Off: you will only see alerts inside the app.';

  @override
  String get pushOnHint =>
      'On: offers, bookings and messages arrive even when KaamNow is closed.';

  @override
  String get pushSetting => 'Notifications on this device';

  @override
  String get pushTitle => 'Get alerts on this device';

  @override
  String get pushTurnedOn => 'Notifications are on for this device.';

  @override
  String get rateThisJob => 'Rate this job';

  @override
  String rateWorker(Object name) {
    return 'Rate $name';
  }

  @override
  String get ratingNew => 'New';

  @override
  String get reason => 'Reason';

  @override
  String reasonLine(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get reasonOptional => 'Reason (optional)';

  @override
  String get receiptBilledTo => 'Billed to';

  @override
  String get receiptBooking => 'Booking';

  @override
  String get receiptDate => 'Date';

  @override
  String get receiptDownloaded => 'Receipt downloaded.';

  @override
  String get receiptFooter =>
      'This receipt was made by computer and needs no signature.';

  @override
  String get receiptJob => 'Job';

  @override
  String get receiptNumber => 'Receipt number';

  @override
  String get receiptPaidAfterRefunds => 'Paid after refunds';

  @override
  String get receiptPaidBy => 'Paid by';

  @override
  String receiptRefundOn(Object date) {
    return 'Refund on $date';
  }

  @override
  String get receiptRefundedTitle => 'Receipt (refunded)';

  @override
  String get receiptService => 'Service';

  @override
  String receiptTaxNumber(Object number) {
    return 'Tax number: $number';
  }

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get receiptTotalPaid => 'Total paid';

  @override
  String get receiptTransactionId => 'Transaction ID';

  @override
  String get receiptWorkDoneBy => 'Work done by';

  @override
  String get received => 'Received';

  @override
  String get recentJobs => 'Recent jobs';

  @override
  String get recentVisits => 'Recent visits';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get refreshJobs => 'Refresh jobs';

  @override
  String refundedToCustomer(Object amount) {
    return 'Refunded to the customer: $amount';
  }

  @override
  String refundedToYou(Object amount) {
    return 'Refunded to you: $amount';
  }

  @override
  String get reject => 'Reject';

  @override
  String get rejectOfferQ => 'Reject this offer?';

  @override
  String get rejectPartReason => 'Why? The worker will see this.';

  @override
  String rejectPartTitle(Object name) {
    return 'Reject $name?';
  }

  @override
  String get remindCustomer => 'Remind the customer';

  @override
  String get reminderSent => 'Reminder sent.';

  @override
  String get remove => 'Remove';

  @override
  String removeContactQ(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeFromFavourites => 'Remove from saved';

  @override
  String get removePartQ => 'Remove this part?';

  @override
  String get removePhotoBody => 'The customer will no longer see it.';

  @override
  String get removePhotoQ => 'Remove this photo?';

  @override
  String get removePromo => 'Remove';

  @override
  String removeServiceQ(Object name) {
    return 'Remove $name?';
  }

  @override
  String get removeTimeOffBody =>
      'You will get job alerts on these days again.';

  @override
  String get removeTimeOffTitle => 'Remove these days off?';

  @override
  String renewsOrEnds(Object date) {
    return 'Renews or ends $date';
  }

  @override
  String get repeatNewPassword => 'Repeat new password';

  @override
  String repeatSheetHint(String name) {
    return 'Two days before each visit, $name gets the job as a book-again request. If they are not free, it goes to other workers nearby. You still accept an offer each time.';
  }

  @override
  String get repeatThisJob => 'Repeat this job';

  @override
  String get repeatingJobs => 'Repeating jobs';

  @override
  String get repeatingJobsCustomerHint =>
      'Jobs that repeat with the same worker';

  @override
  String get repeatingJobsWorkerHint => 'Customers who want you every time';

  @override
  String get reportAverage => 'Average per job';

  @override
  String reportBooking(Object id) {
    return 'Report booking #$id';
  }

  @override
  String get reportByPayment => 'How customers paid';

  @override
  String get reportByService => 'By service';

  @override
  String get reportByTime => 'Earnings over time';

  @override
  String get reportCash => 'Cash (you hold it)';

  @override
  String reportChangeDown(Object percent, int days) {
    return '$percent% less than the $days days before';
  }

  @override
  String reportChangeUp(Object percent, int days) {
    return '$percent% more than the $days days before';
  }

  @override
  String get reportEmpty => 'No completed jobs in these dates.';

  @override
  String get reportJobs => 'Jobs done';

  @override
  String reportJobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
    );
    return '$_temp0';
  }

  @override
  String get reportNet => 'You earned';

  @override
  String reportNoChange(int days) {
    return 'Same as the $days days before';
  }

  @override
  String get reportNoShow => 'Report and cancel';

  @override
  String get reportOnline => 'Online (KaamNow holds it)';

  @override
  String reportPreviousNone(int days) {
    return 'Nothing earned in the $days days before';
  }

  @override
  String get reportProblem => 'Report a problem';

  @override
  String reportRefundShares(Object amount) {
    return 'Refund shares taken: $amount';
  }

  @override
  String get reportUnpaid => 'Not paid yet';

  @override
  String reqCancelRate(int days, Object value, Object target) {
    return 'Bookings you cancelled in $days days: $value% (at most $target%)';
  }

  @override
  String reqJobs(Object value, Object target) {
    return 'Jobs done: $value of $target';
  }

  @override
  String reqNoShows(int days, Object value, Object target) {
    return 'Confirmed no-shows in $days days: $value (at most $target)';
  }

  @override
  String reqRating(Object value, Object target) {
    return 'Average rating: $value (needs $target)';
  }

  @override
  String reqReviews(Object value, Object target) {
    return 'Reviews: $value of $target';
  }

  @override
  String get request => 'Request';

  @override
  String get requestCancelled => 'Request cancelled.';

  @override
  String get requestFailed => 'Request failed.';

  @override
  String requestPayoutOf(Object amount) {
    return 'Ask for $amount';
  }

  @override
  String get requiredField => 'Required';

  @override
  String resendIn(int seconds) {
    return 'Send a new code in ${seconds}s';
  }

  @override
  String get resetLinkIncomplete => 'This reset link is incomplete';

  @override
  String get resetLinkIncompleteHint =>
      'Open the link from the email again, or ask for a new one from the login screen.';

  @override
  String get resetLinkSent =>
      'If that number has an account with an email, a reset link is on its way.';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resumeRepeating => 'Resume';

  @override
  String get resumedRepeating => 'Resumed.';

  @override
  String get reviewAddPhotos => 'Add photos';

  @override
  String get reviewPhotoFailed =>
      'Your review was saved, but a photo could not be uploaded.';

  @override
  String reviewPhotosHint(Object count) {
    return 'Up to $count photos of the finished work. Location data is removed.';
  }

  @override
  String get reviewRemovePhoto => 'Remove photo';

  @override
  String get reviewReply => 'Reply';

  @override
  String get reviewReplyHint =>
      'Everyone can see your reply. You can reply once.';

  @override
  String get reviewReplyLabel => 'Your reply';

  @override
  String get reviewReplySent => 'Reply posted.';

  @override
  String get reviewReplyTitle => 'Reply to this review';

  @override
  String reviewWorkerReply(Object name) {
    return 'Reply from $name';
  }

  @override
  String reviewsHeading(Object n) {
    return 'Reviews ($n)';
  }

  @override
  String get reviewsWithPhotos => 'With photos';

  @override
  String rewardsEarned(Object amount) {
    return 'Rewards earned: $amount';
  }

  @override
  String get rsPrefix => 'Rs ';

  @override
  String rupees(Object amount) {
    return 'Rs $amount';
  }

  @override
  String get rupeesUnknown => 'Rs —';

  @override
  String salam(Object name) {
    return 'Salam, $name';
  }

  @override
  String get samePriceAcceptInstead =>
      'That is the current price. Accept instead.';

  @override
  String get save => 'Save';

  @override
  String get saveHours => 'Save hours';

  @override
  String get saveNewPassword => 'Save new password';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get saveThisPlace => 'Save this place';

  @override
  String get saveToFavourites => 'Save worker';

  @override
  String get savedAddresses => 'Saved addresses';

  @override
  String get savedAddressesHint => 'Home, work and other places you book from';

  @override
  String get savedPlaces => 'Your places';

  @override
  String get savedWorkers => 'Saved';

  @override
  String get saving => 'Saving…';

  @override
  String get scheduleExplain =>
      'You only get job alerts and can only send offers for jobs inside your working hours. Emergency jobs reach you whenever you are switched on as available.';

  @override
  String get scheduleSaved => 'Working hours saved.';

  @override
  String get securePayment => 'Secure payment';

  @override
  String get send => 'Send';

  @override
  String get sendClaim => 'Send claim';

  @override
  String get sendCode => 'Send code';

  @override
  String get sendNewCode => 'Send a new code';

  @override
  String get sendOffer => 'Send offer';

  @override
  String get sendReport => 'Send report';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get sendSos => 'Send SOS';

  @override
  String get sendToEveryone => 'Send to everyone';

  @override
  String get sendToKaamNow => 'Send to KaamNow team';

  @override
  String get sendToKaamNowHint =>
      'Our team will look at the job, the photos and the chat, and contact you.';

  @override
  String get sendYourPrice => 'Send your price';

  @override
  String get sendingEvery15 =>
      'Sending every 15 seconds while this page is open.';

  @override
  String sentAgo(Object when) {
    return 'Sent $when';
  }

  @override
  String sentOnlyTo(String name) {
    return 'Sent only to $name. If they cannot make it, send the job to every worker nearby.';
  }

  @override
  String get serverTrouble =>
      'KaamNow is having trouble right now. Please try again.';

  @override
  String get service => 'Service';

  @override
  String get serviceAdded => 'Service added.';

  @override
  String get services => 'Services';

  @override
  String get setLocationFirst =>
      'Set the job location on the map, or use your current location.';

  @override
  String get setPinFirst => 'Put the pin on the map first.';

  @override
  String get settlementCollection => 'Commission paid';

  @override
  String get settlementHistory => 'Payouts and payments';

  @override
  String settlementLine(Object date, Object method) {
    return '$date · $method';
  }

  @override
  String get settlementPayout => 'Payout to you';

  @override
  String get shareLiveLocation => 'Share my live location with the customer';

  @override
  String get shareTrip => 'Share with family';

  @override
  String shareTripHint(String when) {
    return 'Anyone with this link can see the job\'s status and, while the worker is on the way, where they are. It never shows phone numbers or the address. It stops working $when.';
  }

  @override
  String sharedByName(String name) {
    return '$name shared this job with you';
  }

  @override
  String get sharedJobTitle => 'Shared job';

  @override
  String sharedLinkEnds(String when) {
    return 'This link stops working $when.';
  }

  @override
  String sharingOn(String time) {
    return 'Shared with family until $time';
  }

  @override
  String get sharingStopped => 'Sharing stopped. The link no longer works.';

  @override
  String get shortBio => 'Short bio';

  @override
  String get showMore => 'Show more';

  @override
  String get sixDigitCode => '6-digit code from the customer';

  @override
  String get skipNextVisit => 'Skip next visit';

  @override
  String get skippedNextVisit => 'Next visit skipped.';

  @override
  String get smsCode => '6-digit code';

  @override
  String get somethingWentWrong => 'Something went wrong.';

  @override
  String get somethingWrong => 'Something went wrong.';

  @override
  String get sortFastest => 'Fastest arrival';

  @override
  String get sortHighestRating => 'Highest rating';

  @override
  String get sortLowestPrice => 'Lowest price';

  @override
  String get sortMostExperience => 'Most experience';

  @override
  String get sortMostJobs => 'Most jobs';

  @override
  String get sortNearest => 'Nearest';

  @override
  String get sosBody =>
      'KaamNow\'s team is alerted at once, and your emergency contacts get a text with a link to follow this job. The other person is not told. If you are in danger, call 15 (police) or 1122 (rescue) first.';

  @override
  String get sosButton => 'SOS';

  @override
  String sosContactsTexted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count emergency contacts were texted.',
      one: '1 emergency contact was texted.',
      zero: 'No emergency contacts were texted.',
    );
    return '$_temp0';
  }

  @override
  String get sosNoteLabel => 'What is happening? (optional)';

  @override
  String get sosOpenBanner =>
      'Your SOS is open. KaamNow\'s team will call you. If you are in danger, call 15.';

  @override
  String get sosSeenBanner => 'KaamNow has seen your SOS and is on it.';

  @override
  String get sosSent => 'SOS sent. Our team will call you now.';

  @override
  String get sosTitle => 'Need help?';

  @override
  String get startRepeating => 'Start repeating';

  @override
  String get startWork => 'Start work';

  @override
  String get startingPriceOptional => 'Starting price (optional)';

  @override
  String get statementReady => 'Statement downloaded.';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusActive => 'Active';

  @override
  String get statusArrived => 'Arrived';

  @override
  String get statusBooked => 'Booked';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusCollected => 'Collected';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusDisputed => 'Disputed';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusInProgress => 'Work in progress';

  @override
  String get statusInReview => 'In review';

  @override
  String get statusOffered => 'Offered';

  @override
  String get statusOnTheWay => 'On the way';

  @override
  String get statusOpen => 'Open';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusPendingPayment => 'Awaiting payment';

  @override
  String get statusRefunded => 'Refunded';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusRequested => 'Requested';

  @override
  String get statusResolved => 'Resolved';

  @override
  String statusUpdated(Object status) {
    return 'Status updated: $status';
  }

  @override
  String get statusVerified => 'Verified';

  @override
  String get statusWithdrawn => 'Withdrawn';

  @override
  String get stopGettingJobs => 'You will stop getting these jobs.';

  @override
  String get stopRepeating => 'Stop repeating';

  @override
  String get stopRepeatingBody =>
      'No more visits will be posted. Jobs already posted stay as they are.';

  @override
  String get stopRepeatingQ => 'Stop repeating this job?';

  @override
  String get stopSharing => 'Stop sharing';

  @override
  String get stoppedRepeating => 'Stopped.';

  @override
  String get subject => 'Subject';

  @override
  String get submit => 'Submit';

  @override
  String supportEmail(Object email) {
    return 'Support: $email';
  }

  @override
  String get switchToPlan => 'Switch to this plan';

  @override
  String switchedTo(Object name) {
    return 'Switched to $name.';
  }

  @override
  String get tabAccount => 'Account';

  @override
  String get tabAlerts => 'Alerts';

  @override
  String get tabBookings => 'Bookings';

  @override
  String get tabHome => 'Home';

  @override
  String get tabJobs => 'Jobs';

  @override
  String get tabMyOffers => 'My offers';

  @override
  String get tabMyRequests => 'My requests';

  @override
  String get tagline => 'Trusted help in Lahore, at your price';

  @override
  String get tapMapToPin => 'Tap the map to place the pin.';

  @override
  String get tellUsWhatHappened => 'Tell us what happened';

  @override
  String get textMyContacts => 'Text it to my emergency contacts';

  @override
  String get thanksConfirmed => 'Thanks for confirming.';

  @override
  String get thanksForReview => 'Thanks for your review!';

  @override
  String get thanksWillReview => 'Thanks. KaamNow will review your report.';

  @override
  String get timeOff => 'Days off';

  @override
  String get timeOffAdded => 'Days off added.';

  @override
  String get timeOffExplain =>
      'Holiday, wedding or leave. You get no new jobs on these days.';

  @override
  String get timeOffReasonLabel => 'Reason (optional, only you see it)';

  @override
  String get timeOffReasonTitle => 'Reason for days off';

  @override
  String timeRange(String start, String end) {
    return '$start to $end';
  }

  @override
  String timeWindow(String start, String end) {
    return '$start to $end';
  }

  @override
  String get timeline => 'Timeline';

  @override
  String get tipCancelled => 'Tip cancelled.';

  @override
  String get tipCashOption => 'Cash, handed to the worker';

  @override
  String get tipCashSent =>
      'Thanks! The worker will confirm they got the cash.';

  @override
  String get tipChange => 'Change tip';

  @override
  String get tipConfirmed => 'Tip confirmed. Thank you!';

  @override
  String get tipGotIt => 'I got it';

  @override
  String tipHint(Object name) {
    return 'The whole tip goes to $name. KaamNow keeps nothing.';
  }

  @override
  String get tipHow => 'How will you pay?';

  @override
  String get tipMessage => 'Note for the worker (optional)';

  @override
  String get tipNotReceived => 'Not received';

  @override
  String get tipNotReceivedBody =>
      'The tip will be cancelled and the customer told.';

  @override
  String get tipNotReceivedQ => 'Cash tip not received?';

  @override
  String get tipOther => 'Other amount (Rs)';

  @override
  String tipPaidCustomer(Object amount) {
    return 'You tipped $amount. Thank you!';
  }

  @override
  String tipPendingCash(Object amount) {
    return 'Your cash tip of $amount is waiting for the worker to confirm.';
  }

  @override
  String tipPendingOnline(Object amount) {
    return 'Your tip of $amount is not paid yet.';
  }

  @override
  String tipRange(Object min, Object max) {
    return 'Enter $min to $max';
  }

  @override
  String get tipSend => 'Send tip';

  @override
  String get tipStatusCancelled => 'Cancelled';

  @override
  String get tipStatusPaid => 'Received';

  @override
  String get tipStatusPending => 'Waiting';

  @override
  String get tipTitle => 'Say thanks with a tip';

  @override
  String tipWorker(Object name) {
    return 'Tip $name';
  }

  @override
  String tipWorkerPaid(Object amount) {
    return 'You got a tip of $amount!';
  }

  @override
  String tipWorkerPending(Object amount) {
    return 'The customer says they gave you a cash tip of $amount.';
  }

  @override
  String tipWorkerPendingOnline(Object amount) {
    return 'The customer started an online tip of $amount.';
  }

  @override
  String tipsTotal(Object count, Object amount) {
    return 'Tips received: $count · Total $amount';
  }

  @override
  String get titleHint => 'e.g. Ceiling fan not working';

  @override
  String get titleLabel => 'Title';

  @override
  String get titleTooShort => 'Title is too short.';

  @override
  String get toWord => 'to';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get topLevelReached => 'You are at the top level. Keep it up!';

  @override
  String get total => 'Total';

  @override
  String get trackingStarts => 'Tracking starts when the worker sets off.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get turnOn => 'Turn on';

  @override
  String get typeMessage => 'Type a message';

  @override
  String get unlimitedOffers => 'Unlimited offers';

  @override
  String get updateDocsTryAgain => 'Update your documents and try again.';

  @override
  String updatedAgo(Object when) {
    return 'updated $when';
  }

  @override
  String get upload => 'Upload';

  @override
  String urgentSubtitle(Object fee) {
    return 'Shown first to workers. Adds a $fee fee.';
  }

  @override
  String get urgentTitle => 'Urgent? Mark your job as an emergency';

  @override
  String get useAtLeast8 => 'Use at least 8 characters';

  @override
  String useCredit(Object amount) {
    return 'Use my credit ($amount)';
  }

  @override
  String get useFirstSwitch => 'Use this address first when posting a job';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String validUntil(Object time) {
    return 'Valid until $time';
  }

  @override
  String get verificationDocuments => 'Verification documents';

  @override
  String get verificationRejected => 'Verification was rejected';

  @override
  String get verifiedByKaamNow => 'Verified by KaamNow';

  @override
  String get verifiedByKaamnow => 'Verified by KaamNow';

  @override
  String get viewReceipt => 'Receipt';

  @override
  String get visitFailed => 'Could not be posted';

  @override
  String get visitSentToAll => 'Sent to workers nearby';

  @override
  String get visitSentToWorker => 'Sent to your worker';

  @override
  String waitingForCounter(Object name) {
    return 'Waiting for $name to respond to your counter offer.';
  }

  @override
  String get waitingForCustomer => 'Waiting for the customer.';

  @override
  String get waitingForCustomerDone =>
      'Waiting for the customer to tap Job completed.';

  @override
  String get waitingForCustomerShort => 'Waiting for customer';

  @override
  String get waitingForGateway => 'Waiting for the payment gateway to confirm.';

  @override
  String get waitingForOffers => 'Waiting for offers';

  @override
  String get waitingForOffersHint =>
      'Nearby workers have been notified. Offers appear here as they arrive.';

  @override
  String get waitingForWorkerConfirm => 'Waiting for the worker to confirm.';

  @override
  String get waitingForWorkerLocation => 'Waiting for the worker’s location…';

  @override
  String get wallet => 'Wallet';

  @override
  String get walletBalance => 'Balance with KaamNow';

  @override
  String walletCommissionOwed(Object amount) {
    return 'Commission and charges: $amount';
  }

  @override
  String walletEarningsHeld(Object amount) {
    return 'From online payments: $amount';
  }

  @override
  String get walletExplain =>
      'Customers who pay online pay KaamNow, so we owe you your share. Customers who pay cash pay you, so you owe our commission. The two are netted here.';

  @override
  String get walletNumber => 'Mobile account number';

  @override
  String get walletOwedToYou => 'KaamNow owes you';

  @override
  String get walletSettled => 'All settled';

  @override
  String get walletYouOwe => 'You owe KaamNow';

  @override
  String weekOf(Object date) {
    return 'Week of $date';
  }

  @override
  String get whatHelp => 'What do you need help with?';

  @override
  String get whatWentWrong => 'What went wrong?';

  @override
  String get whatWentWrongAgain => 'What went wrong?';

  @override
  String get whenComeBack => 'When will you come back?';

  @override
  String whenWorkerFree(String name, String day) {
    return 'When $name is free on $day';
  }

  @override
  String withWorkerName(String name) {
    return 'With $name';
  }

  @override
  String get withdraw => 'Withdraw';

  @override
  String get withdrawClaimBody => 'You cannot make another claim for this job.';

  @override
  String get withdrawClaimQ => 'Withdraw this claim?';

  @override
  String get withdrawHint => 'You cannot bid on this job again.';

  @override
  String get withdrawOfferQ => 'Withdraw your offer?';

  @override
  String get workRadius => 'Work radius (km)';

  @override
  String get workedWithBefore => 'Worked for you before';

  @override
  String get worker => 'Worker';

  @override
  String workerAway(Object name, Object km) {
    return '$name is $km km away';
  }

  @override
  String get workerDidNotCome => 'Worker did not come';

  @override
  String get workerDidNotComeQ => 'Report that the worker did not come?';

  @override
  String get workerNotFreeThatDay =>
      'This worker is not free on this day. Choose another day.';

  @override
  String get workerPositionNow => 'Where the worker is now';

  @override
  String get workerProfile => 'Worker profile';

  @override
  String get workerProfileServicesDocs =>
      'Worker profile, services and documents';

  @override
  String get workerSaved => 'Worker saved. Find them in My workers.';

  @override
  String get workerSays => 'Worker';

  @override
  String workerSaysFinished(Object name) {
    return '$name says the work is finished. Tap Job completed if you are happy with it.';
  }

  @override
  String get workerSignupHint =>
      'After signing up, upload your CNIC so KaamNow can verify you before you send offers.';

  @override
  String get workerToldNotFinished => 'The worker has been told.';

  @override
  String get workerUnsaved => 'Removed from saved workers.';

  @override
  String get workingHours => 'Working hours';

  @override
  String worksIn(Object area) {
    return 'Works in $area';
  }

  @override
  String get wrongNumberLogOut => 'Not your number? Log out';

  @override
  String yearsExp(Object n) {
    return '$n yrs exp';
  }

  @override
  String get yearsExperience => 'Years of experience';

  @override
  String get yes => 'Yes';

  @override
  String get you => 'You';

  @override
  String get youAgreed => 'You agreed. Waiting for the customer.';

  @override
  String get youAreAvailable => 'You are available for jobs';

  @override
  String get youAreOffline => 'You are offline';

  @override
  String get youEarned => 'You earned';

  @override
  String youPay(Object amount) {
    return 'You pay $amount';
  }

  @override
  String get yourBadges => 'Your badges';

  @override
  String get yourInviteCode => 'Your invite code';

  @override
  String get yourLevelIs => 'Your level';

  @override
  String get yourOffer => 'Your offer';

  @override
  String get yourPhoneNumber => 'Your phone number';

  @override
  String get yourPlan => 'Your plan';

  @override
  String get yourPrice => 'Your price';
}
