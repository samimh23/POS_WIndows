import 'package:flutter/material.dart';
import '../../core/utils/money.dart';
import '../../models/pos_data.dart';
import 'money_keypad.dart';

Future<T?> perform<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? success,
}) async {
  try {
    final result = await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    }
    return result;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
    return null;
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.message, {
    super.key,
    this.icon = Icons.receipt_long_outlined,
  });
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class FieldSpec {
  FieldSpec(
    this.key,
    this.label,
    this.initial, {
    this.options,
    this.optionLabels,
    this.numeric = false,
    this.required = true,
  });
  final String key, label, initial;
  final List<String>? options;
  final Map<String, String>? optionLabels;
  final bool numeric, required;
}

Future<void> editDialog(
  BuildContext context,
  String title,
  List<FieldSpec> fields,
  Future<void> Function(Map<String, String>) save, {
  String button = 'Save',
  String? help,
}) => showDialog<void>(
  context: context,
  builder: (_) => _Editor(title, fields, save, button, help),
);

class _Editor extends StatefulWidget {
  const _Editor(this.title, this.fields, this.save, this.button, this.help);
  final String title, button;
  final String? help;
  final List<FieldSpec> fields;
  final Future<void> Function(Map<String, String>) save;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final form = GlobalKey<FormState>();
  late final controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(text: f.initial),
  };
  String? error;
  bool saving = false;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (saving || !form.currentState!.validate()) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.save({
        for (final e in controllers.entries) e.key: e.value.text,
      });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Bad state: ', '');
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.help != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(widget.help!),
                ),
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child:
                      f.options == null
                          ? TextFormField(
                            controller: controllers[f.key],
                            enabled: !saving,
                            decoration: InputDecoration(
                              labelText: f.label,
                              suffixIcon:
                                  f.numeric
                                      ? IconButton(
                                        tooltip:
                                            'Open number pad for ${f.label}',
                                        onPressed:
                                            saving
                                                ? null
                                                : () async {
                                                  final value =
                                                      await showMoneyKeypad(
                                                        context,
                                                        title: f.label,
                                                        initialValue:
                                                            controllers[f.key]!
                                                                .text,
                                                      );
                                                  if (!mounted ||
                                                      value == null) {
                                                    return;
                                                  }
                                                  setState(
                                                    () =>
                                                        controllers[f.key]!
                                                            .text = moneyInput(
                                                          value,
                                                        ),
                                                  );
                                                },
                                        icon: const Icon(Icons.dialpad),
                                      )
                                      : null,
                            ),
                            keyboardType:
                                f.numeric
                                    ? const TextInputType.numberWithOptions(
                                      decimal: true,
                                    )
                                    : TextInputType.text,
                            validator:
                                (s) =>
                                    f.required &&
                                            (s == null || s.trim().isEmpty)
                                        ? 'This field is required.'
                                        : null,
                          )
                          : DropdownButtonFormField<String>(
                            value: f.initial,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: f.label),
                            items:
                                f.options!
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          f.optionLabels?[s] ?? s,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                saving
                                    ? null
                                    : (s) => controllers[f.key]!.text = s!,
                          ),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : submit,
        child: Text(saving ? 'Saving…' : widget.button),
      ),
    ],
  );
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String description,
) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(title),
            content: Text(description),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Remove'),
              ),
            ],
          ),
    ) ??
    false;

Future<void> billDetails(
  BuildContext context,
  Bill bill, {
  Sale? sale,
}) => showDialog<void>(
  context: context,
  builder:
      (c) => AlertDialog(
        title: Text('${bill.label} · ${sale == null ? 'Bill' : 'Sale'}'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale?.id ?? bill.id),
                Text('Opened ${stamp(bill.openedAt)}'),
                if (sale != null)
                  Text(
                    'Paid ${stamp(sale.paidAt)} · ${sale.method.toUpperCase()} · ${sale.points} loyalty points',
                  ),
                const Divider(),
                for (final l in bill.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${l.quantity} × ${l.name}',
                                style: TextStyle(
                                  decoration:
                                      l.cancelled
                                          ? TextDecoration.lineThrough
                                          : null,
                                ),
                              ),
                            ),
                            Text(money(l.total)),
                          ],
                        ),
                        Text(
                          l.cancelled
                              ? 'Cancelled: ${l.cancelReason}'
                              : l.confirmed
                              ? 'Round ${l.round}${l.note.isEmpty ? '' : ' · ${l.note}'}'
                              : 'Unconfirmed${l.note.isEmpty ? '' : ' · ${l.note}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                amountRow('Subtotal', bill.subtotal),
                amountRow('Discount', bill.discount),
                amountRow('Total', bill.total, bold: true),
                if (sale != null && sale.method == 'cash') ...[
                  amountRow('Received', sale.received),
                  amountRow('Change', sale.change),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Demonstration only · Payment simulation',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
);

Widget amountRow(String label, int amount, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(fontWeight: bold ? FontWeight.w700 : null),
        ),
      ),
      Text(
        money(amount),
        style: TextStyle(
          fontSize: bold ? 22 : 14,
          fontWeight: bold ? FontWeight.w700 : null,
        ),
      ),
    ],
  ),
);
