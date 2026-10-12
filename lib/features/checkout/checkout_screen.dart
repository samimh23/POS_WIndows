import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/pos_controller.dart';
import '../shifts/shifts_screen.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/pos_widgets.dart';
import '../../shared/widgets/money_keypad.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.billId,
    required this.onBack,
    required this.onPaid,
  });
  final String billId;
  final VoidCallback onBack, onPaid;
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String method = 'cash';
  bool cardConfirmed = false, submitting = false;
  final cash = TextEditingController();
  bool keypadOpen = false;

  Future<void> enterCash(int due) async {
    if (submitting || keypadOpen || ref.read(posProvider).busy) {
      return;
    }
    keypadOpen = true;
    final value = await showMoneyKeypad(
      context,
      title: 'Cash received',
      initialValue: cash.text,
      amountDue: due,
    );
    if (!mounted) {
      return;
    }
    keypadOpen = false;
    if (value != null) {
      setState(() => cash.text = moneyInput(value));
    }
  }

  @override
  void dispose() {
    cash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(posProvider);
    final matches = pos.data.bills.where((b) => b.id == widget.billId);
    if (matches.isEmpty) {
      return const EmptyState('Payment recorded. This bill is closed.');
    }
    final b = matches.first;
    int? received;
    try {
      received = parseMoney(cash.text);
    } catch (_) {
      received = null;
    }
    final canPay =
        !pos.busy &&
        !submitting &&
        pos.data.activeShift != null &&
        (method == 'cash'
            ? received != null && received >= b.total
            : cardConfirmed);
    final summary = Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${b.label} · Bill summary',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('${b.id} · ${b.rounds} ordering rounds'),
            const Divider(),
            for (final l in b.lines.where((l) => !l.cancelled))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l.quantity} × ${l.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (l.note.isNotEmpty)
                            Text(
                              l.note,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    Text(money(l.total)),
                  ],
                ),
              ),
            const Divider(),
            amountRow('Subtotal', b.subtotal),
            amountRow('Discount', b.discount),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  pos.busy
                      ? null
                      : () => editDialog(
                        context,
                        'Bill discount',
                        [
                          FieldSpec(
                            'amount',
                            'Discount (DT)',
                            moneyInput(b.discount),
                            numeric: true,
                          ),
                        ],
                        (v) => pos.discount(b.id, parseMoney(v['amount']!)),
                        help:
                            'Fixed discount in TND. Loyalty points use the final paid total.',
                      ),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Edit discount'),
            ),
            const Divider(),
            amountRow('Amount to pay', b.total, bold: true),
          ],
        ),
      ),
    );
    final payment = Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complete payment',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Simulation only. No funds are transferred.'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'cash',
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Cash'),
                  ),
                  ButtonSegment(
                    value: 'card',
                    icon: Icon(Icons.credit_card),
                    label: Text('Bank card'),
                  ),
                ],
                selected: {method},
                onSelectionChanged:
                    submitting ? null : (v) => setState(() => method = v.first),
              ),
            ),
            const SizedBox(height: 24),
            if (method == 'cash') ...[
              TextField(
                controller: cash,
                enabled: !pos.busy && !submitting,
                onTap: () => enterCash(b.total),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount received (DT)',
                  hintText: '20.000',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Open cash number pad',
                    onPressed:
                        pos.busy || submitting
                            ? null
                            : () => enterCash(b.total),
                    icon: const Icon(Icons.dialpad),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      pos.busy || submitting ? null : () => enterCash(b.total),
                  icon: const Icon(Icons.dialpad),
                  label: const Text('Enter cash on screen'),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: amountRow(
                  'Change',
                  received == null || received < b.total
                      ? 0
                      : received - b.total,
                  bold: true,
                ),
              ),
              if (cash.text.isNotEmpty &&
                  (received == null || received < b.total))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    received == null
                        ? 'Enter a valid amount with up to 3 decimals.'
                        : 'Cash received is insufficient.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ] else
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: cardConfirmed,
                onChanged:
                    submitting
                        ? null
                        : (v) => setState(() => cardConfirmed = v!),
                title: const Text('I confirm this simulated card payment'),
                subtitle: const Text(
                  'Manual confirmation · no payment provider',
                ),
              ),
            const SizedBox(height: 24),
            if (pos.data.activeShift == null) ...[
              const Text('Open a cashier shift to record this payment.'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showOpenShift(context, pos),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Open shift'),
              ),
              const SizedBox(height: 18),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    canPay
                        ? () async {
                          setState(() => submitting = true);
                          final sale = await perform(
                            context,
                            () => pos.pay(
                              b.id,
                              method,
                              received ?? b.total,
                              cardConfirmed: cardConfirmed,
                            ),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          if (sale != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Payment saved · ${money(sale.total)}${method == 'cash' ? ' · Change ${money(sale.change)}' : ''}',
                                ),
                              ),
                            );
                            widget.onPaid();
                          } else {
                            setState(() => submitting = false);
                          }
                        }
                        : null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(submitting ? 'Saving payment…' : 'Confirm payment'),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'The table closes after the complete bill is settled.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to order',
              onPressed: submitting ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Checkout',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder:
                  (c, box) =>
                      box.maxWidth > 850
                          ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: summary),
                              const SizedBox(width: 24),
                              SizedBox(width: 410, child: payment),
                            ],
                          )
                          : Column(
                            children: [
                              summary,
                              const SizedBox(height: 20),
                              payment,
                            ],
                          ),
            ),
          ),
        ),
      ],
    );
  }
}
