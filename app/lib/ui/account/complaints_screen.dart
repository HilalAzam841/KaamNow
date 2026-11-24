import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

const complaintCategories = {
  'service_quality': 'Poor service quality',
  'no_show': 'Did not show up',
  'overcharging': 'Overcharging',
  'behaviour': 'Behaviour',
  'payment': 'Payment problem',
  'damage': 'Damage to property',
  'fraud': 'Fraud',
  'app_issue': 'Problem with the app',
  'other': 'Something else',
};

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Help and complaints')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/complaints/new'),
        icon: const Icon(Icons.add),
        label: const Text('Report a problem'),
      ),
      body: Loader<Paged<Complaint>>(
        load: api.complaints,
        builder: (context, page, reload) {
          if (page.results.isEmpty) {
            return const EmptyView(icon: Icons.support_agent, title: 'No complaints',
                subtitle: 'If something goes wrong with a job, report it here and KaamNow will look into it.');
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
                        complaintCategories[c.category] ?? humanize(c.category),
                        if (c.bookingId != null) 'Booking #${c.bookingId}',
                        day(c.createdAt),
                        if (c.resolution.isNotEmpty) 'KaamNow: ${c.resolution}',
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
      success: 'Thanks. KaamNow will review your report.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (c != null) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.bookingId == null ? 'Report a problem' : 'Report booking #${widget.bookingId}')),
        body: PageBody(
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'What went wrong?'),
                items: [for (final e in complaintCategories.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) => (v ?? '').trim().length < 5 ? 'At least 5 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Tell us what happened', alignLabelWithHint: true),
                validator: (v) => (v ?? '').trim().length < 20 ? 'Please give a bit more detail (20+ characters)' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _submit, child: const Text('Send report')),
            ]),
          ),
        ),
      );
}
