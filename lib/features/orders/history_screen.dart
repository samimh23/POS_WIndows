import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pos_controller.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/pos_widgets.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String filter = 'Completed', search = '';
  @override
  Widget build(BuildContext context) {
    final d = ref.watch(posProvider).data;
    bool match(String text) =>
        text.toLowerCase().contains(search.toLowerCase());
    final sales =
        d.sales.reversed
            .where((s) => match('${s.id} ${s.bill.label} ${s.method}'))
            .toList();
    final bills =
        (filter == 'Open bills' ? d.activeBills : d.cancelledBills).reversed
            .where((b) => match('${b.id} ${b.label}'))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Orders & bills',
          'Completed sales, open bills, and preserved cancellations.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final f in ['Completed', 'Open bills', 'Cancelled'])
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '$f · ${f == 'Completed'
                        ? d.sales.length
                        : f == 'Open bills'
                        ? d.activeBills.length
                        : d.cancelledBills.length}',
                  ),
                ),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search by ID, table, or payment method…',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 18),
        Expanded(
          child:
              filter == 'Completed'
                  ? (sales.isEmpty
                      ? const Center(
                        child: EmptyState('No matching completed sales.'),
                      )
                      : ListView.separated(
                        itemCount: sales.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (c, i) {
                          final s = sales[i];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              leading: CircleAvatar(
                                child: Icon(
                                  s.method == 'cash'
                                      ? Icons.payments_outlined
                                      : Icons.credit_card,
                                ),
                              ),
                              title: Text(
                                '${s.bill.label} · ${s.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${stamp(s.paidAt)} · ${s.method.toUpperCase()} · ${s.points} points',
                              ),
                              trailing: Text(
                                money(s.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              onTap:
                                  () => billDetails(context, s.bill, sale: s),
                            ),
                          );
                        },
                      ))
                  : (bills.isEmpty
                      ? Center(
                        child: EmptyState(
                          filter == 'Open bills'
                              ? 'No open bills.'
                              : 'No cancelled bills.',
                        ),
                      )
                      : ListView.separated(
                        itemCount: bills.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (c, i) {
                          final b = bills[i];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              leading: const CircleAvatar(
                                child: Icon(Icons.receipt_long_outlined),
                              ),
                              title: Text(
                                '${b.label} · ${b.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${stamp(b.openedAt)} · ${b.status} · ${b.rounds} rounds',
                              ),
                              trailing: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(
                                    money(b.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'View bill',
                                    onPressed: () => billDetails(context, b),
                                    icon: const Icon(
                                      Icons.receipt_long_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              onTap:
                                  () =>
                                      filter == 'Open bills'
                                          ? widget.onOpen(b.id)
                                          : billDetails(context, b),
                            ),
                          );
                        },
                      )),
        ),
      ],
    );
  }
}
