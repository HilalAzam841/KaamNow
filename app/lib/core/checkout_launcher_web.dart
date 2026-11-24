import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../models/models.dart';
import 'checkout_launcher.dart';

/// Builds a hidden form with the gateway fields and submits it in a new tab.
Future<CheckoutOutcome> openCheckout(BuildContext context, Checkout checkout) async {
  final form = web.document.createElement('form') as web.HTMLFormElement
    ..method = checkout.method
    ..action = checkout.url
    ..target = '_blank';
  checkout.fields.forEach((name, value) {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'hidden'
      ..name = name
      ..value = value;
    form.append(input);
  });
  web.document.body!.append(form);
  form.submit();
  form.remove();
  return CheckoutOutcome.openedInNewTab;
}
