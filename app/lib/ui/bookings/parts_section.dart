import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../worker/portfolio_screen.dart' show PhotoPicker;

/// What the worker typed in the add part dialog.
class NewPart {
  NewPart({required this.name, required this.quantity, required this.unitPrice, this.receipt});
  final String name;
  final int quantity;
  final String unitPrice;
  final UploadFile? receipt;
}

/// Parts and materials on a booking.
///
/// The worker adds what they bought for the job (with an optional receipt photo) once they have
/// arrived. The customer approves or rejects each part before paying; only approved parts are
/// added to the bill. Admins see the list, read only. Receipts are private and downloaded with
/// the viewer's login.
class PartsSection extends StatefulWidget {
  const PartsSection({
    super.key,
    required this.load,
    required this.loadReceipt,
    this.add,
    this.delete,
    this.approve,
    this.reject,
    this.picker,
    this.onChanged,
  });

  final Future<(PartsSummary, List<JobPart>)> Function() load;
  final Future<Uint8List> Function(JobPart part) loadReceipt;

  /// Set for the worker.
  final Future<JobPart> Function(NewPart part)? add;
  final Future<void> Function(JobPart part)? delete;

  /// Set for the customer.
  final Future<JobPart> Function(JobPart part)? approve;
  final Future<JobPart> Function(JobPart part, String reason)? reject;
  final PhotoPicker? picker;

  /// Called after a change, so the booking total can be reloaded.
  final VoidCallback? onChanged;

  @override
  State<PartsSection> createState() => _PartsSectionState();
}

class _PartsSectionState extends State<PartsSection> {
  PartsSummary _summary = const PartsSummary();
  List<JobPart> _parts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final (summary, parts) = await widget.load();
      if (mounted) {
        setState(() {
          _summary = summary;
          _parts = parts;
        });
      }
    } catch (_) {
      // The rest of the booking still works; the section just stays empty.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changed(Object? result) async {
    if (result == null) return;
    await _reload();
    widget.onChanged?.call();
  }

  Future<void> _add() async {
    final part = await showDialog<NewPart>(context: context, builder: (_) => AddPartDialog(picker: widget.picker));
    if (part == null || !mounted) return;
    await _changed(await runAction(context, () => widget.add!(part), success: context.t.partAdded));
  }

  Future<void> _delete(JobPart p) async {
    if (!await confirm(context, context.t.removePartQ, p.name, ok: context.t.remove)) return;
    if (!mounted) return;
    await _changed(await runAction(context, () async {
      await widget.delete!(p);
      return true;
    }));
  }

  Future<void> _approve(JobPart p) async =>
      _changed(await runAction(context, () => widget.approve!(p), success: context.t.partApproved));

  Future<void> _reject(JobPart p) async {
    final reason = await promptText(context, context.t.rejectPartTitle(p.name),
        label: context.t.rejectPartReason, ok: context.t.reject, required: true);
    if (reason == null || !mounted) return;
    await _changed(await runAction(context, () => widget.reject!(p, reason), success: context.t.partRejected));
  }

  void _openReceipt(JobPart p) {
    showDialog<void>(
      context: context,
      builder: (d) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              child: FutureBuilder<Uint8List>(
                future: widget.loadReceipt(p),
                builder: (_, snap) => snap.hasData
                    ? Image.memory(snap.data!, fit: BoxFit.contain)
                    : snap.hasError
                    ? const Icon(Icons.broken_image, color: Colors.white, size: 48)
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: d.t.close,
              color: Colors.white,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(d),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.add != null && _summary.canAdd;
    if (_loading || (_parts.isEmpty && !canAdd)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final canDecide = widget.approve != null && _summary.canDecide;
    return Card(
      key: const Key('job-parts'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.t.partsAndMaterials, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(widget.add != null ? context.t.partsWorkerHint : context.t.partsCustomerHint,
              style: theme.textTheme.bodySmall),
          if (canDecide && _summary.pending > 0) ...[
            const SizedBox(height: 8),
            Text(context.t.partsPendingBeforePay(_summary.pending),
                key: const Key('parts-pending'), style: TextStyle(color: theme.colorScheme.error)),
          ],
          for (final p in _parts) _row(context, p, canDecide: canDecide),
          if (_parts.isNotEmpty) ...[
            const Divider(height: 20),
            Row(children: [
              Expanded(child: Text(context.t.partsApprovedTotal, style: theme.textTheme.labelLarge)),
              Text(rs(_summary.approvedTotal), key: const Key('parts-total'), style: theme.textTheme.labelLarge),
            ]),
          ],
          if (canAdd)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('add-part'),
                onPressed: _add,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(context.t.addPart),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, JobPart p, {required bool canDecide}) {
    final theme = Theme.of(context);
    final (label, color) = switch (p.status) {
      'approved' => (context.t.partStatusApproved, theme.colorScheme.primary),
      'rejected' => (context.t.partStatusRejected, theme.colorScheme.error),
      _ => (context.t.partStatusPending, theme.colorScheme.tertiary),
    };
    final open = widget.add != null ? _summary.canAdd : _summary.canDecide;
    return Padding(
      key: Key('part-${p.id}'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.quantity > 1 ? '${p.name} × ${p.quantity}' : p.name, style: theme.textTheme.bodyLarge),
              Text(
                p.quantity > 1 ? context.t.partEach(rs(p.unitPrice)) : label,
                style: theme.textTheme.bodySmall?.copyWith(color: p.quantity > 1 ? null : color),
              ),
              if (p.quantity > 1) Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
            ]),
          ),
          Text(rs(p.total), style: theme.textTheme.bodyLarge),
        ]),
        if (p.status == 'rejected' && p.rejectReason.isNotEmpty)
          Text(context.t.partRejectedBecause(p.rejectReason), style: theme.textTheme.bodySmall),
        Wrap(spacing: 4, children: [
          if (p.receiptUrl != null)
            TextButton.icon(
              key: Key('part-receipt-${p.id}'),
              onPressed: () => _openReceipt(p),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: Text(context.t.partReceipt),
            ),
          if (p.isPending && open && widget.delete != null)
            TextButton(
              key: Key('remove-part-${p.id}'),
              onPressed: () => _delete(p),
              child: Text(context.t.remove),
            ),
          if (p.isPending && canDecide) ...[
            FilledButton.tonal(
              key: Key('approve-part-${p.id}'),
              onPressed: () => _approve(p),
              child: Text(context.t.approve),
            ),
            TextButton(
              key: Key('reject-part-${p.id}'),
              onPressed: () => _reject(p),
              child: Text(context.t.reject),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// The worker types a part's name, quantity and price, and can attach a receipt photo.
class AddPartDialog extends StatefulWidget {
  const AddPartDialog({super.key, this.picker});
  final PhotoPicker? picker;

  @override
  State<AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends State<AddPartDialog> {
  final _name = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  UploadFile? _receipt;

  int? get _quantity {
    final q = int.tryParse(_qty.text.trim());
    return q != null && q >= 1 && q <= 50 ? q : null;
  }

  double? get _unit {
    final v = double.tryParse(_price.text.trim());
    return v != null && v >= 1 && v <= 50000 ? v : null;
  }

  bool get _valid => _name.text.trim().isNotEmpty && _quantity != null && _unit != null;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await widget.picker?.call();
    if (f != null && mounted) setState(() => _receipt = f);
  }

  @override
  Widget build(BuildContext context) {
    final total = _valid ? (_quantity! * _unit!).toStringAsFixed(2) : null;
    return AlertDialog(
      title: Text(context.t.addPart),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            key: const Key('part-name'),
            controller: _name,
            autofocus: true,
            maxLength: 100,
            decoration: InputDecoration(labelText: context.t.partName, hintText: context.t.partNameHint),
            onChanged: (_) => setState(() {}),
          ),
          Row(children: [
            SizedBox(
              width: 90,
              child: TextField(
                key: const Key('part-qty'),
                controller: _qty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: context.t.partQuantity),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('part-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: context.t.partUnitPrice, prefixText: 'Rs '),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          if (total != null) ...[
            const SizedBox(height: 8),
            Text(context.t.partTotalIs(rs(total)), key: const Key('part-dialog-total')),
          ],
          const SizedBox(height: 8),
          if (widget.picker != null)
            OutlinedButton.icon(
              key: const Key('part-pick-receipt'),
              onPressed: _pick,
              icon: Icon(_receipt == null ? Icons.add_a_photo : Icons.check),
              label: Text(_receipt == null ? context.t.partAddReceipt : context.t.partReceiptAdded),
            ),
          const SizedBox(height: 4),
          Text(context.t.partApprovalNote, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.cancel)),
        FilledButton(
          key: const Key('part-submit'),
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  NewPart(
                      name: _name.text.trim(), quantity: _quantity!, unitPrice: _unit!.toStringAsFixed(2), receipt: _receipt),
                )
              : null,
          child: Text(context.t.addPart),
        ),
      ],
    );
  }
}
