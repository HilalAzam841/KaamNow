import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

/// Every tip customers gave. Tips go wholly to the worker; KaamNow takes no commission.
class AdminTipsScreen extends StatefulWidget {
  const AdminTipsScreen({super.key});
  @override
  State<AdminTipsScreen> createState() => _AdminTipsScreenState();
}

class _AdminTipsScreenState extends State<AdminTipsScreen> {
  String? _status = 'paid';
  final _list = GlobalKey<PagedListState<TipInfo>>();

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Tips',
        body: Column(children: [
          FilterChips(
            options: const [('paid', 'Paid'), ('pending', 'Pending'), ('cancelled', 'Cancelled'), (null, 'All')],
            selected: _status,
            onSelected: (v) {
              setState(() => _status = v);
              WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
            },
          ),
          Expanded(
            child: PagedList<TipInfo>(
              key: _list,
              empty: 'No tips',
              load: (page) => adminApi(context).tips(status: _status, page: page),
              itemBuilder: (context, tip, reload) => Card(
                child: ListTile(
                  key: Key('admin-tip-${tip.id}'),
                  title: Text('${rs(tip.amount)} · ${tip.customerName} → ${tip.workerName}'),
                  subtitle: Text([
                    'Booking #${tip.bookingId}',
                    paymentMethodLabel(tip.method),
                    tip.status,
                    if (tip.createdAt != null) when(tip.createdAt),
                    if (tip.message.isNotEmpty) '“${tip.message}”',
                  ].join(' · ')),
                ),
              ),
            ),
          ),
        ]),
      );
}
