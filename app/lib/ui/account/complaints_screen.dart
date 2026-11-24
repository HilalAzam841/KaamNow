import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../../l10n/l10n.dart';

Map<String, String> complaintCategories(AppLocalizations t) => {
      'service_quality': t.ccServiceQuality,
      'no_show': t.ccNoShow,
      'overcharging': t.ccOvercharging,
      'behaviour': t.ccBehaviour,
      'payment': t.ccPayment,
      'damage': t.ccDamage,
      'fraud': t.ccFraud,
      'app_issue': t.ccAppIssue,
      'other': t.ccOther,
    };

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.helpAndComplaints)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/complaints/new'),
        icon: const Icon(Icons.add),
        label: Text(context.t.reportProblem),
      ),
      body: Loader<Paged<Complaint>>(
        load: api.complaints,
        builder: (context, page, reload) {
          if (page.results.isEmpty) {
            return EmptyView(icon: Icons.support_agent, title: context.t.noComplaints,
                subtitle: context.t.noComplaintsHint);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: PageBody(
              child: ListView(padding: const EdgeInsets.all(12), children: [
                for (final c in page.results)
                  Card(
                    child: ListTile(
                      title: Text(c.subject),
                      subtitle: Text([
                        complaintCategories(context.t)[c.category] ?? humanize(c.category),
                        if (c.bookingId != null) context.t.bookingNumber(c.bookingId!),
                        day(c.createdAt),
                        if (c.resolution.isNotEmpty) context.t.kaamnowReply(c.resolution),
                      ].join(' · ')),
                      trailing: StatusChip(c.status),
                    ),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class NewComplaintScreen extends StatefulWidget {
  const NewComplaintScreen({super.key, this.bookingId});
  final int? bookingId;
  @override
  State<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends State<NewComplaintScreen> {
  final _form = GlobalKey<FormState>();
  String _category = 'service_quality';
  final _subject = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final c = await runAction(
      context,
      () => context.read<Session>().api.createComplaint(
          bookingId: widget.bookingId, category: _category, subject: _subject.text.trim(), description: _description.text.trim()),
      success: context.t.thanksWillReview,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (c != null) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.bookingId == null ? context.t.reportProblem : context.t.reportBooking(widget.bookingId!))),
        body: PageBody(
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(labelText: context.t.whatWentWrong),
                items: [for (final e in complaintCategories(context.t).entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subject,
                decoration: InputDecoration(labelText: context.t.subject),
                validator: (v) => (v ?? '').trim().length < 5 ? context.t.atLeast5 : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 5,
                decoration: InputDecoration(labelText: context.t.tellUsWhatHappened, alignLabelWithHint: true),
                validator: (v) => (v ?? '').trim().length < 20 ? context.t.moreDetail : null,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _submit, child: Text(context.t.sendReport)),
            ]),
          ),
        ),
      );
}
