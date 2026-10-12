import 'package:flutter/material.dart';
import '../../core/utils/money.dart';

/// Touch entry for TND amounts. Opening/applying the keypad never makes a payment.
Future<int?> showMoneyKeypad(
  BuildContext context, {
  required String title,
  String initialValue = '',
  int? amountDue,
}) => showDialog<int>(
  context: context,
  builder:
      (_) => MoneyKeypad(
        title: title,
        initialValue: initialValue,
        amountDue: amountDue,
      ),
);

class MoneyKeypad extends StatefulWidget {
  const MoneyKeypad({
    super.key,
    required this.title,
    this.initialValue = '',
    this.amountDue,
  });
  final String title, initialValue;
  final int? amountDue;

  @override
  State<MoneyKeypad> createState() => _MoneyKeypadState();
}

class _MoneyKeypadState extends State<MoneyKeypad> {
  late final TextEditingController input;
  bool replaceNextDigit = false;

  @override
  void initState() {
    super.initState();
    String initial = '';
    try {
      initial = moneyInput(parseMoney(widget.initialValue));
    } on FormatException {
      /* Invalid existing input can be corrected on screen. */
    }
    input = TextEditingController(text: initial);
    replaceNextDigit = initial.isNotEmpty;
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  int? get amount {
    try {
      final text = input.text;
      return parseMoney(text.endsWith('.') ? '${text}0' : text);
    } on FormatException {
      return null;
    }
  }

  void setAmount(int value) {
    setState(() {
      input.text = moneyInput(value);
      replaceNextDigit = true;
    });
  }

  void key(String value) {
    var text = input.text;
    if (value == 'backspace') {
      if (text.isNotEmpty) {
        text = text.substring(0, text.length - 1);
      }
    } else {
      if (replaceNextDigit) {
        text = '';
      }
      if (value == '.') {
        if (text.contains('.')) {
          return;
        }
        text = text.isEmpty ? '0.' : '$text.';
      } else {
        text = text == '0' ? value : '$text$value';
      }
      if (!RegExp(r'^\d{1,8}(\.\d{0,3})?$').hasMatch(text)) {
        return;
      }
    }
    setState(() {
      input.text = text;
      replaceNextDigit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = amount;
    final due = widget.amountDue;
    final insufficient = due != null && current != null && current < due;
    final canApply = current != null && !insufficient;
    final buttons = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '.',
      '0',
      'backspace',
    ];
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('money-keypad-display'),
                controller: input,
                readOnly: true,
                showCursor: false,
                enableInteractiveSelection: false,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: '0.000',
                  suffixText: 'DT',
                ),
              ),
              if (due != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Due ${money(due)}')),
                    Text(
                      'Change ${money(current == null || current < due ? 0 : current - due)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final value in [20000, 50000, 100000]) ...[
                      if (value != 20000) const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: ValueKey('money-preset-$value'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => setAmount(value),
                          child: Text('${value ~/ 1000} DT'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (due != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('money-exact'),
                        onPressed: () => setAmount(due),
                        icon: const Icon(Icons.done),
                        label: const Text('Exact amount'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('money-clear'),
                      onPressed:
                          () => setState(() {
                            input.clear();
                            replaceNextDigit = false;
                          }),
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: buttons.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 52,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final value = buttons[index];
                  return FilledButton.tonal(
                    key: ValueKey('money-key-$value'),
                    onPressed: () => key(value),
                    child:
                        value == 'backspace'
                            ? const Tooltip(
                              message: 'Backspace',
                              child: Icon(Icons.backspace_outlined),
                            )
                            : Text(
                              value,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (insufficient)
                Text(
                  'Cash received is insufficient.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('money-apply'),
          onPressed: canApply ? () => Navigator.pop(context, current) : null,
          child: const Text('Use amount'),
        ),
      ],
    );
  }
}
