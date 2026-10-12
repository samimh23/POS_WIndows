import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pos_controller.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/pos_widgets.dart';

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({
    super.key,
    required this.billId,
    required this.onBack,
    required this.onCheckout,
  });
  final String billId;
  final VoidCallback onBack, onCheckout;
  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  String search = '', category = 'All';
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  IconData categoryIcon(String c) => switch (c) {
    'Coffee' => Icons.coffee_outlined,
    'Tea' => Icons.emoji_food_beverage_outlined,
    'Cold Drinks' => Icons.local_drink_outlined,
    'Food' => Icons.bakery_dining_outlined,
    _ => Icons.restaurant_menu,
  };
  Future<void> cancelBill(PosController pos) async {
    await editDialog(
      context,
      'Cancel ${pos.data.bills.firstWhere((b) => b.id == widget.billId).label}',
      [FieldSpec('reason', 'Cancellation reason', '')],
      (v) async {
        await pos.discardBill(widget.billId, v['reason']!);
        widget.onBack();
      },
      button: 'Cancel bill',
      help:
          'Confirmed items remain in the cancellation history. No payment or loyalty points will be recorded.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(posProvider);
    final d = pos.data;
    final matches = d.bills.where((b) => b.id == widget.billId);
    if (matches.isEmpty) {
      return const EmptyState('This bill has been closed.');
    }
    final b = matches.first;
    final products =
        d.products
            .where(
              (p) =>
                  p.enabled &&
                  (category == 'All' || category == p.category) &&
                  p.name.toLowerCase().contains(search.toLowerCase()),
            )
            .toList();
    final catalog = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Search products…',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in ['All', ...d.categories])
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Text(cat),
                ),
                selected: category == cat,
                onSelected: (_) => setState(() => category = cat),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child:
              products.isEmpty
                  ? const Center(
                    child: EmptyState(
                      'No matching enabled products.',
                      icon: Icons.search_off,
                    ),
                  )
                  : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 205,
                          mainAxisExtent: 164,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: products.length,
                    itemBuilder: (c, i) {
                      final p = products[i];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap:
                              pos.busy
                                  ? null
                                  : () => perform(
                                    context,
                                    () => pos.addProduct(b.id, p.id),
                                  ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(c)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: .55),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        categoryIcon(p.category),
                                        color: Theme.of(c).colorScheme.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.add, size: 20),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  money(p.price),
                                  style: TextStyle(
                                    color: Theme.of(c).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
    final order = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Current bill',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'View full bill',
                  onPressed: () => billDetails(context, b),
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
              ],
            ),
            Text(
              '${b.id} · ${b.rounds} confirmed rounds',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: b.customerId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Customer'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Walk-in customer'),
                ),
                for (final c in d.customers)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged:
                  pos.busy
                      ? null
                      : (id) => perform(
                        context,
                        () => pos.customer(b.id, id == '' ? null : id),
                      ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  b.lines.isEmpty
                      ? const Center(
                        child: EmptyState(
                          'Tap a product to add it to this order.',
                          icon: Icons.coffee_outlined,
                        ),
                      )
                      : ListView.separated(
                        itemCount: b.lines.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (c, i) {
                          final l = b.lines[i];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${l.quantity} × ${l.name}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        decoration:
                                            l.cancelled
                                                ? TextDecoration.lineThrough
                                                : null,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    money(l.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${money(l.price)} each${l.note.isEmpty ? '' : ' · ${l.note}'}',
                                style: Theme.of(c).textTheme.bodySmall,
                              ),
                              if (l.cancelled)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Cancelled: ${l.cancelReason}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(c).colorScheme.error,
                                    ),
                                  ),
                                )
                              else if (l.confirmed)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Confirmed · Round ${l.round}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Theme.of(c).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed:
                                          pos.busy
                                              ? null
                                              : () => editDialog(
                                                context,
                                                'Cancel ${l.name}',
                                                [
                                                  FieldSpec(
                                                    'reason',
                                                    'Cancellation reason',
                                                    '',
                                                  ),
                                                ],
                                                (v) => pos.cancelLine(
                                                  b.id,
                                                  l.id,
                                                  v['reason']!,
                                                ),
                                                button: 'Cancel item',
                                                help:
                                                    'This cancels all ${l.quantity} units on this line and preserves the reason.',
                                              ),
                                      child: const Text('Cancel item'),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Decrease ${l.name}',
                                      onPressed:
                                          pos.busy
                                              ? null
                                              : () => perform(
                                                context,
                                                () => pos.quantity(
                                                  b.id,
                                                  l.id,
                                                  -1,
                                                ),
                                              ),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text(
                                      '${l.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Increase ${l.name}',
                                      onPressed:
                                          pos.busy
                                              ? null
                                              : () => perform(
                                                context,
                                                () =>
                                                    pos.quantity(b.id, l.id, 1),
                                              ),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Note for ${l.name}',
                                      onPressed:
                                          pos.busy
                                              ? null
                                              : () => editDialog(
                                                context,
                                                'Product note',
                                                [
                                                  FieldSpec(
                                                    'note',
                                                    'Optional note',
                                                    l.note,
                                                    required: false,
                                                  ),
                                                ],
                                                (v) => pos.note(
                                                  b.id,
                                                  l.id,
                                                  v['note']!,
                                                ),
                                              ),
                                      icon: const Icon(Icons.edit_note),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove ${l.name}',
                                      onPressed:
                                          pos.busy
                                              ? null
                                              : () => perform(
                                                context,
                                                () => pos.quantity(
                                                  b.id,
                                                  l.id,
                                                  -l.quantity,
                                                ),
                                              ),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                            ],
                          );
                        },
                      ),
            ),
            const Divider(),
            amountRow('Total', b.total, bold: true),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    pos.busy || !b.hasDraft
                        ? null
                        : () => perform(
                          context,
                          () => pos.confirm(b.id),
                          success: 'Ordering round confirmed and saved.',
                        ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm order'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    pos.busy || b.hasDraft || b.total <= 0
                        ? null
                        : () async {
                          final ok = await perform(context, () async {
                            await pos.checkout(b.id);
                            return true;
                          });
                          if (ok == true) {
                            widget.onCheckout();
                          }
                        },
                icon: const Icon(Icons.payments_outlined),
                label: Text('Checkout · ${money(b.total)}'),
              ),
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
              tooltip: 'Back to tables / bills',
              onPressed: pos.busy ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.label,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'One shared bill · ${stamp(b.openedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (b.tableId != null)
              OutlinedButton.icon(
                onPressed:
                    pos.busy
                        ? null
                        : () {
                          final available =
                              d.tables
                                  .where(
                                    (t) =>
                                        t.id != b.tableId &&
                                        d.tableBill(t.id) == null,
                                  )
                                  .toList();
                          if (available.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No available destination tables.',
                                ),
                              ),
                            );
                            return;
                          }
                          editDialog(
                            context,
                            'Move open order',
                            [
                              FieldSpec(
                                'target',
                                'Destination table',
                                available.first.id,
                                options: available.map((t) => t.id).toList(),
                                optionLabels: {
                                  for (final t in available)
                                    t.id: '${t.name} · ${t.area}',
                                },
                              ),
                            ],
                            (v) => pos.move(b.id, v['target']!),
                            help:
                                'The accumulated bill moves with the order. The source table becomes available.',
                          );
                        },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Move table'),
              ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Cancel bill / release table',
              onPressed: pos.busy ? null : () => cancelBill(pos),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: LayoutBuilder(
            builder:
                (c, box) =>
                    box.maxWidth >= 800
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: catalog),
                            const SizedBox(width: 20),
                            SizedBox(width: 370, child: order),
                          ],
                        )
                        : Column(
                          children: [
                            Expanded(child: catalog),
                            const SizedBox(height: 12),
                            SizedBox(height: 390, child: order),
                          ],
                        ),
          ),
        ),
      ],
    );
  }
}
