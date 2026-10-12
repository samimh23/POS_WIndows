import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/pos_controller.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/pos_widgets.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final d = ref.watch(posProvider).data;
    final customers =
        d.customers
            .where(
              (c) => '${c.name} ${c.phone}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
            )
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Customers',
          'Demo loyalty · ${d.settings.loyalty ? '1 point for every 1.000 DT paid' : 'Earning is disabled in Settings'}',
        ),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search customers or phone numbers…',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 20),
        Expanded(
          child:
              customers.isEmpty
                  ? const Center(
                    child: EmptyState(
                      'No matching customers.',
                      icon: Icons.people_outline,
                    ),
                  )
                  : ListView.separated(
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final c = customers[i];
                      final history =
                          d.sales
                              .where((s) => s.bill.customerId == c.id)
                              .toList();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    child: Text(
                                      c.name[0],
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          c.phone.isEmpty
                                              ? 'No phone number'
                                              : c.phone,
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusPill(
                                    '${c.points} points',
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 36,
                                runSpacing: 12,
                                children: [
                                  Text(
                                    'Total spending  ${money(history.fold(0, (a, s) => a + s.total))}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text('${history.length} completed purchases'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed:
                                    () => showDialog<void>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: Text(
                                              '${c.name} · Purchases',
                                            ),
                                            content: SizedBox(
                                              width: 540,
                                              height: 350,
                                              child:
                                                  history.isEmpty
                                                      ? const EmptyState(
                                                        'No completed purchases yet.',
                                                      )
                                                      : ListView(
                                                        children: [
                                                          for (final s
                                                              in history
                                                                  .reversed)
                                                            ListTile(
                                                              title: Text(
                                                                '${s.bill.label} · ${money(s.total)}',
                                                              ),
                                                              subtitle: Text(
                                                                '${stamp(s.paidAt)} · ${s.points} points',
                                                              ),
                                                              onTap:
                                                                  () =>
                                                                      billDetails(
                                                                        ctx,
                                                                        s.bill,
                                                                        sale: s,
                                                                      ),
                                                            ),
                                                        ],
                                                      ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(ctx),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                    ),
                                icon: const Icon(Icons.history),
                                label: const Text('Purchase history'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
