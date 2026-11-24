import '../models/models.dart';
import 'checkout_launcher_stub.dart' if (dart.library.js_interop) 'checkout_launcher_web.dart' as impl;

/// Opens a payment gateway's hosted checkout (a form POST to JazzCash / Easypaisa).
/// The server only marks the payment paid after verifying the gateway's callback.
bool openCheckout(Checkout checkout) => impl.openCheckout(checkout);
