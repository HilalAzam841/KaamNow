import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/gen/app_localizations.dart';

/// Strings for code without a BuildContext (formatting helpers, API errors).
/// KaamNowApp points this at the current language on every build.
AppLocalizations strings = lookupAppLocalizations(const Locale('en'));

void useStrings(AppLocalizations t) => strings = t;

String get _lang => strings.localeName;

String rs(String? amount) {
  final v = double.tryParse(amount ?? '');
  if (v == null) return strings.rupeesUnknown;
  return strings.rupees(NumberFormat.decimalPattern('en_PK').format(v.round()));
}

/// Urdu uses the 24-hour clock: the Urdu AM/PM marks are rarely used in apps.
String when(DateTime? d) =>
    d == null ? '' : DateFormat(_lang == 'ur' ? 'd MMM، HH:mm' : 'd MMM, h:mm a', _lang).format(d);
String day(DateTime? d) => d == null ? '' : DateFormat('d MMM yyyy', _lang).format(d);

String ago(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return strings.justNow;
  if (diff.inMinutes < 60) return strings.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return strings.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return strings.daysAgo(diff.inDays);
  return day(d);
}

/// "some_code" -> "Some code" (fallback for codes without a translation).
String humanize(String code) {
  final s = code.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Label for a booking, request, offer, payment or complaint status, in the current language.
String statusLabel(String s) => switch (s) {
      'confirmed' => strings.statusConfirmed,
      'on_the_way' => strings.statusOnTheWay,
      'arrived' => strings.statusArrived,
      'in_progress' => strings.statusInProgress,
      'completed' => strings.statusCompleted,
      'cancelled' => strings.statusCancelled,
      'open' => strings.statusOpen,
      'pending' => strings.statusPending,
      'accepted' => strings.statusAccepted,
      'rejected' => strings.statusRejected,
      'withdrawn' => strings.statusWithdrawn,
      'expired' => strings.statusExpired,
      'booked' => strings.statusBooked,
      'verified' => strings.statusVerified,
      'in_review' => strings.statusInReview,
      'resolved' => strings.statusResolved,
      'active' => strings.statusActive,
      'pending_payment' => strings.statusPendingPayment,
      'failed' => strings.statusFailed,
      'paid' => strings.statusPaid,
      'collected' => strings.statusCollected,
      'disputed' => strings.statusDisputed,
      'offered' => strings.statusOffered,
      'requested' => strings.statusRequested,
      _ => humanize(s),
    };

String bookingStatusLabel(String s) => statusLabel(s);

String paymentMethodLabel(String code) => switch (code) {
      'cash' => strings.methodCash,
      'jazzcash' => strings.methodJazzcash,
      'easypaisa' => strings.methodEasypaisa,
      _ => humanize(code),
    };

/// Keeps phone numbers, emails and codes left to right inside Urdu (right-to-left) text.
String ltr(String s) => '\u2066$s\u2069';
