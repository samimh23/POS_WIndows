import 'package:flutter/material.dart';
import '../../core/utils/money.dart';
import '../../models/pos_data.dart';
import '../../shared/widgets/pos_widgets.dart';
import '../orders/pos_controller.dart';

Future<void> showCashMovement(
  BuildContext context,
  PosController pos, {
  required bool cashOut,
}) async {
  final shift = pos.data.activeShift;
  if (shift == null) return;
  // Keep the request stable across save retries; a saved entry cannot duplicate.
  final requestId =
      'cash-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey()}';
  final reasons = cashOut ? CashMovement.outReasons : CashMovement.inReasons;
  final people = {'Owner', shift.employee, 'Sami', 'Amira', 'Youssef'}.toList();
  await editDialog(
    context,
    cashOut ? 'Record cash out' : 'Record cash in',
    [
      FieldSpec(
        'amount',
        cashOut ? 'Cash out amount (DT)' : 'Cash in amount (DT)',
        '',
        numeric: true,
      ),
      FieldSpec('reason', 'Reason', reasons.first, options: reasons),
      FieldSpec(
        'person',
        cashOut ? 'Who took the cash?' : 'Who returned / added cash?',
        cashOut ? 'Owner' : shift.employee,
        options: people,
      ),
      FieldSpec('approvedBy', 'Approved by (optional)', '', required: false),
      FieldSpec('note', 'Details (required for Other)', '', required: false),
    ],
    (v) async {
      await pos.recordCashMovement(
        requestId: requestId,
        shiftId: shift.id,
        direction: cashOut ? 'out' : 'in',
        amount: parseMoney(v['amount']!),
        person: v['person']!,
        reason: v['reason']!,
        approvedBy: v['approvedBy']!,
        note: v['note']!,
      );
    },
    button: cashOut ? 'Record cash out' : 'Record cash in',
    help:
        cashOut
            ? 'Expected drawer cash: ${money(pos.data.expectedCash(shift))}. Record owner withdrawals or business purchases here. Sales stay unchanged.'
            : 'Use Returned change when a worker brings back unused money. This adds cash to the drawer without recording a sale.',
  );
}

class CashMovementTile extends StatelessWidget {
  const CashMovementTile(this.movement, {super.key});
  final CashMovement movement;

  @override
  Widget build(BuildContext context) {
    final m = movement;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(
        m.isOut ? Icons.call_made : Icons.call_received,
        color:
            m.isOut
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        '${m.reason} · ${m.person}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${stamp(m.at)} · Recorded by ${m.recordedBy}${m.note.isEmpty ? '' : '\n${m.note}'}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 126,
        child: FittedBox(
          alignment: Alignment.centerRight,
          fit: BoxFit.scaleDown,
          child: Text(
            '${m.isOut ? '' : '+'}${money(m.signedAmount)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
      onTap:
          () => showDialog<void>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(
                    m.isOut ? 'Cash withdrawal' : 'Cash added / returned',
                  ),
                  content: SizedBox(
                    width: 440,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          amountRow('Amount', m.amount, bold: true),
                          Text('Reason: ${m.reason}'),
                          Text('Person: ${m.person}'),
                          Text('Recorded by: ${m.recordedBy}'),
                          if (m.approvedBy.isNotEmpty)
                            Text(
                              'Approved by (recorded note): ${m.approvedBy}',
                            ),
                          Text('Date: ${stamp(m.at)}'),
                          Text('Shift: ${m.shiftId} · ${m.id}'),
                          if (m.note.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(m.note),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
          ),
    );
  }
}
