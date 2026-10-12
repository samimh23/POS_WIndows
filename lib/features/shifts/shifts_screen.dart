import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/pos_controller.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/pos_widgets.dart';
import 'cash_movements.dart';

Future<void> showOpenShift(BuildContext context, PosController pos) =>
    editDialog(
      context,
      'Open cashier shift',
      [
        FieldSpec(
          'employee',
          'Demo employee',
          'Sami',
          options: ['Sami', 'Amira', 'Youssef'],
        ),
        FieldSpec('opening', 'Opening cash (DT)', '0.000', numeric: true),
      ],
      (v) => pos.openShift(v['employee']!, parseMoney(v['opening']!)),
      button: 'Open shift',
      help: 'A simple local employee selector. This is not authentication.',
    );

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(posProvider);
    final d = pos.data;
    final shift = d.activeShift;
    final transactions =
        shift == null
            ? d.sales.where((_) => false).toList()
            : d.sales.where((s) => s.shiftId == shift.id).toList();
    final movements =
        d.cashMovements.where((m) => m.shiftId == shift?.id).toList();
    return ListView(
      children: [
        PageHeading(
          'Cashier & shifts',
          'Track sales, cash withdrawals, money returned, and closing discrepancies.',
          action:
              shift == null
                  ? FilledButton.icon(
                    onPressed:
                        pos.busy ? null : () => showOpenShift(context, pos),
                    icon: const Icon(Icons.add),
                    label: const Text('Open shift'),
                  )
                  : OutlinedButton.icon(
                    onPressed:
                        pos.busy
                            ? null
                            : () => editDialog(
                              context,
                              'Close cashier shift',
                              [
                                FieldSpec(
                                  'counted',
                                  'Counted cash (DT)',
                                  '',
                                  numeric: true,
                                ),
                              ],
                              (v) => pos.closeShift(parseMoney(v['counted']!)),
                              button: 'Close shift',
                              help:
                                  'Expected cash: ${money(d.expectedCash(shift))}. Open bills remain saved and can be settled during the next shift.',
                            ),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Close shift'),
                  ),
        ),
        Card(
          child:
              shift == null
                  ? const EmptyState(
                    'No shift is open. Open a shift before accepting payment.',
                    icon: Icons.account_balance_wallet_outlined,
                  )
                  : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${shift.employee} · Active shift',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            StatusPill(
                              'Open',
                              Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                        Text('${shift.id} · Opened ${stamp(shift.openedAt)}'),
                        const Divider(),
                        amountRow('Opening cash', shift.opening),
                        amountRow(
                          'Cash sales',
                          transactions
                              .where((s) => s.method == 'cash')
                              .fold(0, (a, s) => a + s.total),
                        ),
                        amountRow(
                          'Card sales',
                          transactions
                              .where((s) => s.method == 'card')
                              .fold(0, (a, s) => a + s.total),
                        ),
                        amountRow(
                          'Cash withdrawn',
                          -d.cashMovementTotal(shift.id, 'out'),
                        ),
                        amountRow(
                          'Cash added / returned',
                          d.cashMovementTotal(shift.id, 'in'),
                        ),
                        const Divider(),
                        amountRow(
                          'Expected cash',
                          d.expectedCash(shift),
                          bold: true,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed:
                                  pos.busy
                                      ? null
                                      : () => showCashMovement(
                                        context,
                                        pos,
                                        cashOut: true,
                                      ),
                              icon: const Icon(Icons.call_made),
                              label: const Text('Cash out'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  pos.busy
                                      ? null
                                      : () => showCashMovement(
                                        context,
                                        pos,
                                        cashOut: false,
                                      ),
                              icon: const Icon(Icons.call_received),
                              label: const Text('Cash in / return'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Cash movements in current shift',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Card(
          child:
              movements.isEmpty
                  ? const EmptyState(
                    'No cash movements recorded in the current shift.',
                  )
                  : Column(
                    children: [
                      for (final m in movements.reversed) CashMovementTile(m),
                    ],
                  ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Transactions in current shift',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Card(
          child:
              transactions.isEmpty
                  ? const EmptyState(
                    'No completed transactions in the current shift.',
                  )
                  : Column(
                    children: [
                      for (final s in transactions.reversed)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          title: Text('${s.bill.label} · ${s.id}'),
                          subtitle: Text(
                            '${stamp(s.paidAt)} · ${s.method.toUpperCase()}',
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
        const SizedBox(height: 24),
        const Text(
          'Closed shifts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        if (d.shifts.where((s) => s.closedAt != null).isEmpty)
          const Card(child: EmptyState('No closed shifts yet.'))
        else
          for (final s in d.shifts.reversed.where((s) => s.closedAt != null))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.employee} · ${s.id}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('${stamp(s.openedAt)} → ${stamp(s.closedAt!)}'),
                      const SizedBox(height: 12),
                      amountRow('Expected at closing', s.expectedAtClose!),
                      amountRow('Counted cash', s.counted!),
                      amountRow(
                        'Discrepancy',
                        s.counted! - s.expectedAtClose!,
                        bold: true,
                      ),
                      if (d.cashMovements.any((m) => m.shiftId == s.id))
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            'Cash movements · ${d.cashMovements.where((m) => m.shiftId == s.id).length}',
                          ),
                          children: [
                            for (final m in d.cashMovements.reversed.where(
                              (m) => m.shiftId == s.id,
                            ))
                              CashMovementTile(m),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
