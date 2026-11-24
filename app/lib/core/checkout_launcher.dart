import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import 'checkout_launcher_mobile.dart' if (dart.library.js_interop) 'checkout_launcher_web.dart' as impl;

enum CheckoutOutcome {
  /// The web app opened the gateway in a new browser tab.
  openedInNewTab,

  /// The phone app showed the gateway inside the app and the user has come back from it.
  returned,

  /// The gateway page could not be shown.
  failed,
}

/// Opens a payment gateway's hosted checkout (a form POST to JazzCash / Easypaisa).
/// The server only marks the payment paid after verifying the gateway's callback, so the
/// outcome here never means "paid"; the caller reloads and shows what the server says.
Future<CheckoutOutcome> openCheckout(BuildContext context, Checkout checkout) => impl.openCheckout(context, checkout);
