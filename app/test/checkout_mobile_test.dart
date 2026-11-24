import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnow/core/checkout_launcher.dart';
import 'package:kaamnow/core/checkout_launcher_mobile.dart' as mobile;
import 'package:kaamnow/models/models.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('the in-app checkout page posts the signed fields, escaped', () {
    final html = mobile.checkoutHtml(Checkout(
      url: 'https://sandbox.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/',
      method: 'POST',
      fields: {'pp_Amount': '150000', 'pp_Description': '"><script>alert(1)</script>', 'pp_SecureHash': 'ABC&123'},
    ));
    expect(html, contains('<form method="post" action="https://sandbox.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/">'));
    expect(html, contains('name="pp_Amount" value="150000"'));
    expect(html, contains('value="ABC&amp;123"'));
    expect(html, isNot(contains('<script>')));
    expect(html, contains('document.forms[0].submit()'));
  });

  testWidgets('a gateway URL that is not https is never opened', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final outcome = await mobile.openCheckout(ctx, Checkout(url: 'http://evil.example/pay', method: 'POST', fields: {}));
    expect(outcome, CheckoutOutcome.failed);
  });
}
