import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('electric')) return Icons.electrical_services;
  if (n.contains('plumb')) return Icons.plumbing;
  if (n.startsWith('ac ') || n.contains('air cond')) return Icons.ac_unit;
  if (n.contains('washing')) return Icons.local_laundry_service;
  if (n.contains('refrigerator') || n.contains('fridge') || n.contains('appliance')) return Icons.kitchen;
  if (n.contains('furniture')) return Icons.chair;
  if (n.contains('carpent')) return Icons.carpenter;
  if (n.contains('paint')) return Icons.format_paint;
  if (n.contains('clean')) return Icons.cleaning_services;
  if (n.contains('mechanic') || n.contains('car ')) return Icons.car_repair;
  if (n.contains('cctv') || n.contains('camera')) return Icons.videocam;
  if (n.contains('pest')) return Icons.pest_control;
  return Icons.home_repair_service;
}

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Salam, ${session.user?.firstName ?? ''}')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-request'),
        onPressed: () => context.push('/requests/new'),
        icon: const Icon(Icons.add),
        label: const Text('Post a job'),
      ),
      body: Loader<List<ServiceCategory>>(
        load: session.api.categories,
        builder: (context, cats, reload) => RefreshIndicator(
          onRefresh: reload,
          child: PageBody(
            maxWidth: 960,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('What do you need help with?', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('Describe the job, get prices from nearby verified workers, and pick the one you like.'),
              if (session.config.emergencyEnabled) ...[
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.bolt),
                    title: const Text('Urgent? Mark your job as an emergency'),
                    subtitle: Text('Shown first to workers. Adds a ${_fee(session.config.emergencyFee)} fee.'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (cats.isEmpty)
                const EmptyView(icon: Icons.category, title: 'No services yet')
              else
                GridView.extent(
                  maxCrossAxisExtent: 180,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final c in cats)
                      Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push('/requests/new?category=${c.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(categoryIcon(c.name), size: 36, color: theme.colorScheme.primary),
                              const SizedBox(height: 8),
                              Text(c.name, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ),
    );
  }

  static String _fee(String fee) => 'Rs ${double.tryParse(fee)?.round() ?? fee}';
}
