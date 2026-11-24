import 'package:web/web.dart' as web;

import '../models/models.dart';

/// Builds a hidden form with the gateway fields and submits it in a new tab.
bool openCheckout(Checkout checkout) {
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
  return true;
}
