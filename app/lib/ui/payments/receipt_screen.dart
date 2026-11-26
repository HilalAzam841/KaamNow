import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/file_saver.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../worker/earnings_report_screen.dart' show SaveFile;

/// Signed amount, e.g. -Rs 200 for a discount.
String signedRs(String amount) {
  final v = double.tryParse(amount) ?? 0;
  return v < 0 ? '-${rs('${-v}')}' : rs(amount);
}

/// A payment's receipt, with a PDF download in the app's language.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.paymentId, this.save = saveBytes});
  final int paymentId;
  final SaveFile save;
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _downloading = false;

  Future<void> _download(Receipt r) async {
    final t = context.t;
    final lang = Localizations.localeOf(context).languageCode == 'ur' ? 'ur' : 'en';
    setState(() => _downloading = true);
    final api = context.read<Session>().api;
    final ok = await runAction(context, () async {
      final (bytes, type) = await api.receiptPdf(widget.paymentId, lang);
      return widget.save(bytes, 'kaamnow-receipt-${r.number}.pdf', type);
    });
    if (!mounted) return;
    setState(() => _downloading = false);
    if (ok == true) showInfo(context, t.receiptDownloaded);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(t.receiptTitle), actions: const [LanguageButton()]),
      body: PageBody(
        child: Loader<Receipt>(
          // Reloads when the language changes, so the server's labels follow it.
          key: ValueKey(Localizations.localeOf(context).languageCode),
          load: () => api.receipt(widget.paymentId),
          builder: (context, r, reload) {
            final theme = Theme.of(context);
            Widget row(String label, String value, {bool bold = false, Key? key}) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(label, style: bold ? theme.textTheme.titleSmall : null)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(value,
                          key: key, textAlign: TextAlign.end, style: bold ? theme.textTheme.titleSmall : null),
                    ),
                  ]),
                );
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                key: const Key('receipt-card'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(r.company, style: theme.textTheme.titleLarge),
                    if (r.companyAddress.isNotEmpty) Text(r.companyAddress, style: theme.textTheme.bodySmall),
                    if (r.taxNumber.isNotEmpty) Text(t.receiptTaxNumber(r.taxNumber), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Text(r.status == 'refunded' ? t.receiptRefundedTitle : t.receiptTitle,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    row(t.receiptNumber, ltr(r.number)),
                    row(t.receiptDate, when(r.issuedAt)),
                    if (r.bookingId != null) row(t.receiptBooking, '${r.bookingId}'),
                    row(t.receiptBilledTo, r.billedTo),
                    if (r.worker.isNotEmpty) row(t.receiptWorkDoneBy, r.worker),
                    if (r.service.isNotEmpty) row(t.receiptService, r.service),
                    if (r.title.isNotEmpty && r.bookingId != null) row(t.receiptJob, r.title),
                    const Divider(height: 24),
                    for (final l in r.lines) row(l.label, signedRs(l.amount)),
                    const Divider(height: 24),
                    row(t.receiptTotalPaid, rs(r.total), bold: true, key: const Key('receipt-total')),
                    row(t.receiptPaidBy, r.methodLabel),
                    if (r.transactionId.isNotEmpty) row(t.receiptTransactionId, ltr(r.transactionId)),
                    if (r.refunds.isNotEmpty) ...[
                      const Divider(height: 24),
                      for (final f in r.refunds) row(t.receiptRefundOn(day(f.date)), '-${rs(f.amount)}'),
                      row(t.receiptPaidAfterRefunds, rs(r.netPaid), bold: true, key: const Key('receipt-net')),
                    ],
                    const SizedBox(height: 12),
                    Text(t.receiptFooter, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('receipt-pdf'),
                onPressed: _downloading ? null : () => _download(r),
                icon: _downloading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(t.downloadReceiptPdf),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
