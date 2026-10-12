import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pos/core/theme/pos_theme.dart';
import 'package:smart_pos/shared/widgets/money_keypad.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    List<int?> results, {
    int? due,
    String initial = '',
    Size size = const Size(1366, 768),
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: posTheme(dark),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      results.add(
                        await showMoneyKeypad(
                          context,
                          title: 'Cash received',
                          initialValue: initial,
                          amountDue: due,
                        ),
                      );
                    },
                    child: const Text('Open keypad'),
                  ),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Open keypad'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  String display(WidgetTester tester) =>
      tester
          .widget<TextField>(find.byKey(const ValueKey('money-keypad-display')))
          .controller!
          .text;

  testWidgets(
    'touch digits calculate change and insufficient cash cannot apply',
    (tester) async {
      final results = <int?>[];
      await open(tester, results, due: 15800);
      await tap(tester, 'money-key-1');
      await tap(tester, 'money-key-0');
      expect(find.text('Cash received is insufficient.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('money-apply')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'money-clear');
      await tap(tester, 'money-key-2');
      await tap(tester, 'money-key-0');
      expect(find.text('Change 4.200 DT'), findsOneWidget);
      expect(
        results,
        isEmpty,
      ); // Entering an amount doesn't confirm any payment.
      await tap(tester, 'money-apply');
      expect(results, [20000]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fractional millimes, backspace and clear work without a keyboard',
    (tester) async {
      final results = <int?>[];
      await open(tester, results);
      for (final key in ['.', '1', '2', '5', '9']) {
        await tap(tester, 'money-key-$key');
      }
      expect(display(tester), '0.125'); // A fourth fractional digit is ignored.
      await tap(tester, 'money-key-backspace');
      await tap(tester, 'money-key-9');
      expect(display(tester), '0.129');
      await tap(tester, 'money-clear');
      expect(display(tester), '');
      await tap(tester, 'money-key-3');
      await tap(tester, 'money-key-.');
      await tap(tester, 'money-key-5');
      await tap(tester, 'money-apply');
      expect(results, [3500]);
    },
  );
  testWidgets('cash presets, exact amount and replacing old input', (
    tester,
  ) async {
    final results = <int?>[];
    await open(tester, results, due: 12500, initial: '50.000');
    await tap(tester, 'money-key-2');
    await tap(tester, 'money-key-0');
    expect(display(tester), '20');
    await tap(tester, 'money-preset-100000');
    expect(find.text('Change 87.500 DT'), findsOneWidget);
    await tap(tester, 'money-preset-50000');
    expect(find.text('Change 37.500 DT'), findsOneWidget);
    await tap(tester, 'money-preset-20000');
    expect(find.text('Change 7.500 DT'), findsOneWidget);
    await tap(tester, 'money-exact');
    expect(display(tester), '12.500');
    expect(find.text('Change 0.000 DT'), findsOneWidget);
    await tap(tester, 'money-apply');
    expect(results, [12500]);
  });
  testWidgets(
    'cancelling does not apply edited cash; malformed input is recoverable',
    (tester) async {
      final results = <int?>[];
      await open(tester, results, initial: 'invalid', due: 12500);
      expect(display(tester), '');
      await tap(tester, 'money-preset-20000');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    },
  );
  for (final size in [
    const Size(1366, 768),
    const Size(1920, 1080),
    const Size(1000, 650),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('touch keypad fits $size, dark=$dark', (tester) async {
        await open(tester, <int?>[], size: size, dark: dark, due: 15800);
        await tap(tester, 'money-key-1');
        expect(tester.takeException(), isNull);
        for (final name in [
          'money-key-1',
          'money-key-0',
          'money-key-backspace',
          'money-apply',
        ]) {
          final target = find.byKey(ValueKey(name));
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
