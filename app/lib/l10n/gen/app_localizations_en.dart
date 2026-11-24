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
  String get add => 'Add';

  @override
  String get addAService => 'Add a service';

  @override
  String get addServicesToSeeJobs =>
      'Add the services you offer to see matching jobs.';

  @override
  String get address => 'Address';

  @override
  String get addressAfterBooking =>
      'The exact address is shared once you are booked.';

  @override
  String get addressHelper => 'Only the worker you book will see it';

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
  String get allServicesOffered => 'You already offer every service.';

  @override
  String amountDue(Object amount) {
    return 'Amount due: $amount';
  }

  @override
  String get appName => 'KaamNow';

  @override
  String appVersion(Object version) {
    return 'KaamNow $version';
  }

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
  String get atLeast5 => 'At least 5 characters';

  @override
  String get atLeast8 => 'At least 8 characters';

  @override
  String get back => 'Back';

  @override
  String get baseLocation => 'Base location';

  @override
  String get baseLocationHint =>
      'Jobs are matched by distance from here. Customers never see it.';

  @override
  String get book => 'Book';

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
  String get cancelRequest => 'Cancel request';

  @override
  String get cancelRequestQ => 'Cancel this request?';

  @override
  String cancelledReason(Object reason) {
    return 'Cancelled: $reason';
  }

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
  String get changePassword => 'Change password';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get chat => 'Chat';

  @override
  String get chooseAService => 'Choose a service';

  @override
  String get chooseNewPassword => 'Choose a new password';

  @override
  String get chooseService => 'Choose a service.';

  @override
  String get close => 'Close';

  @override
  String get cnicNumber => 'CNIC number';

  @override
  String get cnicPrivate =>
      'CNIC images are private. Only KaamNow staff can see them.';

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
  String confirmCashAmount(Object amount) {
    return 'Confirm you received $amount in cash.';
  }

  @override
  String get confirmJobDone => 'Confirm job is done';

  @override
  String get confirmOncePaid => 'Confirm once the customer has paid you.';

  @override
  String get contact => 'Contact';

  @override
  String get continueAction => 'Continue';

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
  String customerBudget(Object amount) {
    return 'Customer budget: $amount';
  }

  @override
  String get customerCounteredShort => 'Customer countered. Your move.';

  @override
  String get customerCounteredYourMove =>
      'The customer made a counter offer. Your move.';

  @override
  String get customerNotPaid => 'The customer has not paid yet.';

  @override
  String get customersPaid => 'Customers paid';

  @override
  String daysAgo(Object n) {
    return '$n d ago';
  }

  @override
  String get defaultAddress => 'Default address';

  @override
  String get describeProblem => 'Describe the problem';

  @override
  String get details => 'Details';

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
  String get earnings => 'Earnings';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get email => 'Email';

  @override
  String get emailOptional => 'Email (optional, for password reset)';

  @override
  String get emergency => 'Emergency';

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
  String get enterValidPhone => 'Enter a valid phone number';

  @override
  String etaMinutes(Object n) {
    return '~$n min';
  }

  @override
  String get filterActive => 'Active';

  @override
  String get finishPayingNewTab =>
      'Finish paying in the new tab. Your plan activates once it is confirmed.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get free => 'Free';

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
  String get getVerified => 'Get verified to send offers';

  @override
  String get getVerifiedHint =>
      'Upload both sides of your CNIC, add your services and set your base location. KaamNow reviews new workers before they can bid.';

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
  String get howToInstall => 'How to install';

  @override
  String get iWantTo => 'I want to';

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
  String get iosInstallSteps =>
      'In Safari, tap the Share button, then choose “Add to Home Screen”.';

  @override
  String get iveArrived => 'I’ve arrived';

  @override
  String get job => 'Job';

  @override
  String get jobAddress => 'Job address';

  @override
  String get jobCompleted => 'Job completed.';

  @override
  String get jobIsBooked => 'This job is booked';

  @override
  String get jobLocation => 'Job location';

  @override
  String jobNumberPrice(Object id, Object price) {
    return 'Job #$id · $price';
  }

  @override
  String get jobPosted => 'Job posted.';

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
  String get markAllRead => 'Mark all read';

  @override
  String get markCompleteQ => 'Mark the job as complete?';

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
  String get myWorkerProfile => 'My worker profile';

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
  String get no => 'No';

  @override
  String get noActiveBookings => 'No active bookings';

  @override
  String get noAlertsYet => 'No alerts yet';

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
  String get noRequestsHint => 'Post a job to get prices from nearby workers.';

  @override
  String get noRequestsYet => 'No requests yet';

  @override
  String get noReviewsYet => 'No reviews yet.';

  @override
  String get noServicesYet => 'No services yet';

  @override
  String get notNow => 'Not now';

  @override
  String get noteOptional => 'Note (optional)';

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
  String get openBooking => 'Open booking';

  @override
  String get osmCredit => '© OpenStreetMap contributors';

  @override
  String paidAmount(Object amount) {
    return 'Paid $amount';
  }

  @override
  String get password => 'Password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get passwordChangedShort => 'Password changed.';

  @override
  String get passwordsDontMatch => 'The passwords do not match';

  @override
  String get payCash =>
      'Pay the worker in cash. They will confirm when they receive it.';

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
  String get paymentWindowClosed =>
      'This page updates once the gateway confirms the payment.';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get photoUpdated => 'Photo updated.';

  @override
  String get photosOptional => 'Photos (optional)';

  @override
  String get pinPlaced => 'Pin placed. Tap the map to move it.';

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
  String get profileSaved => 'Profile saved.';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String get pushBlockedHint =>
      'Blocked in your browser. Allow notifications for this site in the browser settings.';

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
  String get received => 'Received';

  @override
  String get recentJobs => 'Recent jobs';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get reject => 'Reject';

  @override
  String get rejectOfferQ => 'Reject this offer?';

  @override
  String get remove => 'Remove';

  @override
  String removeServiceQ(Object name) {
    return 'Remove $name?';
  }

  @override
  String renewsOrEnds(Object date) {
    return 'Renews or ends $date';
  }

  @override
  String get repeatNewPassword => 'Repeat new password';

  @override
  String reportBooking(Object id) {
    return 'Report booking #$id';
  }

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get request => 'Request';

  @override
  String get requestCancelled => 'Request cancelled.';

  @override
  String get requestFailed => 'Request failed.';

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
  String reviewsHeading(Object n) {
    return 'Reviews ($n)';
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
  String get saveNewPassword => 'Save new password';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get saving => 'Saving…';

  @override
  String get securePayment => 'Secure payment';

  @override
  String get send => 'Send';

  @override
  String get sendOffer => 'Send offer';

  @override
  String get sendReport => 'Send report';

  @override
  String get sendResetLink => 'Send reset link';

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
  String get shareLiveLocation => 'Share my live location with the customer';

  @override
  String get shortBio => 'Short bio';

  @override
  String get sixDigitCode => '6-digit code from the customer';

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
  String get startWork => 'Start work';

  @override
  String get startingPriceOptional => 'Starting price (optional)';

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
  String get statusPending => 'Pending';

  @override
  String get statusPendingPayment => 'Awaiting payment';

  @override
  String get statusRejected => 'Rejected';

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
  String get thanksForReview => 'Thanks for your review!';

  @override
  String get thanksWillReview => 'Thanks. KaamNow will review your report.';

  @override
  String get timeline => 'Timeline';

  @override
  String get titleHint => 'e.g. Ceiling fan not working';

  @override
  String get titleLabel => 'Title';

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
  String get verifiedByKaamnow => 'Verified by KaamNow';

  @override
  String waitingForCounter(Object name) {
    return 'Waiting for $name to respond to your counter offer.';
  }

  @override
  String get waitingForCustomer => 'Waiting for the customer.';

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
  String get whatHelp => 'What do you need help with?';

  @override
  String get whatWentWrong => 'What went wrong?';

  @override
  String get withdraw => 'Withdraw';

  @override
  String get withdrawHint => 'You cannot bid on this job again.';

  @override
  String get withdrawOfferQ => 'Withdraw your offer?';

  @override
  String get workRadius => 'Work radius (km)';

  @override
  String get worker => 'Worker';

  @override
  String workerAway(Object name, Object km) {
    return '$name is $km km away';
  }

  @override
  String get workerProfile => 'Worker profile';

  @override
  String get workerProfileServicesDocs =>
      'Worker profile, services and documents';

  @override
  String get workerSignupHint =>
      'After signing up, upload your CNIC so KaamNow can verify you before you send offers.';

  @override
  String worksIn(Object area) {
    return 'Works in $area';
  }

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
  String get yourOffer => 'Your offer';

  @override
  String get yourPhoneNumber => 'Your phone number';

  @override
  String get yourPlan => 'Your plan';

  @override
  String get yourPrice => 'Your price';
}
