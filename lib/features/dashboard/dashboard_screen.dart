import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/pos_controller.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/pos_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.onTables,
    required this.onQuickSale,
  });
  final VoidCallback onTables, onQuickSale;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(posProvider).data;
    final now = DateTime.now();
    final today =
        d.sales
            .where(
              (s) =>
                  s.paidAt.year == now.year &&
                  s.paidAt.month == now.month &&
                  s.paidAt.day == now.day,
            )
            .toList();
    final occupied = d.activeBills.where((b) => b.tableId != null).length;
    final metrics = <(String, String, IconData)>[
      (
        'Sales today',
        money(today.fold(0, (a, s) => a + s.total)),
        Icons.payments_outlined,
      ),
      ('Completed today', '${today.length}', Icons.check_circle_outline),
      ('Occupied tables', '$occupied', Icons.table_restaurant_outlined),
      (
        'Available tables',
        '${d.tables.length - occupied}',
        Icons.event_seat_outlined,
      ),
      ('Open bills', '${d.activeBills.length}', Icons.receipt_outlined),
      (
        'Cash today',
        money(
          today.where((s) => s.method == 'cash').fold(0, (a, s) => a + s.total),
        ),
        Icons.account_balance_wallet_outlined,
      ),
    ];
    return ListView(
      children: [
        PageHeading(
          'Your café, at a glance',
          '${now.day}/${now.month}/${now.year} · Live local overview',
        ),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF126C62),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 18,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready for the next order.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'One smooth flow, from first coffee to final bill.',
                    style: TextStyle(color: Color(0xFFD1E8E3)),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onTables,
                    icon: const Icon(Icons.table_restaurant),
                    label: const Text('View tables'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF126C62),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onQuickSale,
                    icon: const Icon(Icons.bolt, color: Colors.white),
                    label: const Text(
                      'Quick sale',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder:
              (c, box) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: box.maxWidth >= 850 ? 3 : 2,
                  mainAxisExtent: 132,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (c, i) {
                  final m = metrics[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.$1,
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          c,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Icon(
                                m.$3,
                                color: Theme.of(c).colorScheme.primary,
                              ),
                            ],
                          ),
                          const Spacer(),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              m.$2,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Recent transactions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Card(
          child:
              d.sales.isEmpty
                  ? const EmptyState(
                    'No completed sales today. Open a table or start a quick sale.',
                  )
                  : Column(
                    children: [
                      for (final s in d.sales.reversed.take(6))
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            child: Icon(
                              s.bill.tableId == null
                                  ? Icons.bolt
                                  : Icons.table_restaurant,
                            ),
                          ),
                          title: Text(s.bill.label),
                          subtitle: Text(
                            '${stamp(s.paidAt)} · ${s.method.toUpperCase()} · ${s.id}',
                          ),
                          trailing: Text(
                            money(s.total),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () => billDetails(context, s.bill, sale: s),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }
}
