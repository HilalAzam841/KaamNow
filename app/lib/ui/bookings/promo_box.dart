import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';

/// What the customer chose to take off the booking before paying.
class DiscountChoice {
  const DiscountChoice({this.promoCode = '', this.useCredit = false, this.quote});
  final String promoCode;
  final bool useCredit;
  final PaymentQuote? quote;
}

/// Promo code field and "use my credit" switch above the pay buttons. The server works out every
/// amount (`POST promos/check/`); this only shows it.
class PromoBox extends StatefulWidget {
  const PromoBox({super.key, required this.bookingId, required this.onChanged});
  final int bookingId;
  final ValueChanged<DiscountChoice> onChanged;

  @override
  State<PromoBox> createState() => _PromoBoxState();
}

class _PromoBoxState extends State<PromoBox> {
  final _code = TextEditingController();
  PaymentQuote? _quote;
  String _applied = '';
  bool _useCredit = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check('', false, initial: true);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check(String code, bool useCredit, {bool initial = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final q = await context.read<Session>().api.checkPromo(widget.bookingId, promoCode: code, useCredit: useCredit);
      if (!mounted) return;
      setState(() {
        _quote = q;
        _applied = q.promoCode;
        _useCredit = useCredit;
      });
      widget.onChanged(DiscountChoice(promoCode: q.promoCode, useCredit: useCredit, quote: q));
    } on ApiException catch (e) {
      if (mounted && !initial) setState(() => _error = e.displayMessage);
    } catch (_) {
      // The box is optional: paying the full amount still works.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final q = _quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_applied.isEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('promo-code'),
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: t.promoCode, errorText: _error, isDense: true),
                  onSubmitted: (v) => v.trim().isEmpty ? null : _check(v.trim(), _useCredit),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('promo-apply'),
                onPressed: _busy ? null : () {
                  if (_code.text.trim().isNotEmpty) _check(_code.text.trim(), _useCredit);
                },
                child: Text(t.applyPromo),
              ),
            ],
          )
        else
          Row(
            children: [
              const Icon(Icons.local_offer, size: 18, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.promoApplied(_applied, rs(q?.promoDiscount)),
                  key: const Key('promo-applied'),
                  style: TextStyle(color: Colors.green.shade800),
                ),
              ),
              TextButton(
                key: const Key('promo-remove'),
                onPressed: _busy
                    ? null
                    : () {
                        _code.clear();
                        _check('', _useCredit);
                      },
                child: Text(t.removePromo),
              ),
            ],
          ),
        if (q != null && q.hasCredit)
          CheckboxListTile(
            key: const Key('use-credit'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _useCredit,
            onChanged: _busy ? null : (v) => _check(_applied, v ?? false),
            title: Text(t.useCredit(rs(q.creditBalance))),
            subtitle: q.usesCredit ? Text(t.creditApplied(rs(q.creditUsed))) : null,
          ),
        if (q != null && q.hasDiscount) ...[
          const SizedBox(height: 4),
          Text(t.youPay(rs(q.amount)), key: const Key('promo-you-pay'), style: theme.textTheme.titleMedium),
          Text(t.discountNote, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
