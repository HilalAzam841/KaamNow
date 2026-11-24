import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import 'checkout_launcher.dart';

/// Phone app: shows the gateway's hosted checkout full screen inside the app, posting the
/// signed fields from the server exactly as the web form does. Closing the page returns to
/// the booking or plan, which then reloads the payment state from the server.
Future<CheckoutOutcome> openCheckout(BuildContext context, Checkout checkout) async {
  final uri = Uri.tryParse(checkout.url);
  if (uri == null || uri.scheme != 'https' || defaultTargetPlatform != TargetPlatform.android) {
    return CheckoutOutcome.failed;
  }
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => CheckoutPage(checkout: checkout),
  ));
  return ok == false ? CheckoutOutcome.failed : CheckoutOutcome.returned;
}

/// An HTML page that immediately submits the gateway form. Values are HTML-escaped.
@visibleForTesting
String checkoutHtml(Checkout checkout) {
  const esc = HtmlEscape(HtmlEscapeMode.attribute);
  final inputs = checkout.fields.entries
      .map((e) => '<input type="hidden" name="${esc.convert(e.key)}" value="${esc.convert(e.value)}">')
      .join();
  final method = checkout.method.toUpperCase() == 'GET' ? 'get' : 'post';
  return '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>'
      '<body onload="document.forms[0].submit()">'
      '<form method="$method" action="${esc.convert(checkout.url)}">$inputs</form></body></html>';
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.checkout});
  final Checkout checkout;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final WebViewController _web;
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // the gateways' pages need it
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => mounted ? setState(() => _loading = false) : null,
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _failed = true);
        },
        // Stay on https pages; anything else (app links, plain http) is not followed.
        onNavigationRequest: (r) =>
            r.url.startsWith('https://') || r.url.startsWith('about:') || r.url.startsWith('data:')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
      ))
      ..loadHtmlString(checkoutHtml(widget.checkout), baseUrl: widget.checkout.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.securePayment),
        leading: IconButton(
          key: const ValueKey('checkout-close'),
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(!_failed),
        ),
      ),
      body: _failed
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(context.t.paymentPageFailed, textAlign: TextAlign.center)))
          : Stack(children: [
              WebViewWidget(controller: _web),
              if (_loading) const LinearProgressIndicator(),
            ]),
    );
  }
}
