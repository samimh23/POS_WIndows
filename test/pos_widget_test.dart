import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pos/main.dart';
import 'package:smart_pos/models/pos_data.dart';
import 'package:smart_pos/features/orders/pos_controller.dart';
import 'package:smart_pos/features/shifts/shifts_screen.dart';
import 'pos_controller_test.dart' show MemoryRepository;

void main() {
  Future<PosController> launch(
    WidgetTester tester,
    Size size, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final d = PosData.seed()..settings.dark = dark;
    final pos = PosController(MemoryRepository(), d);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [posProvider.overrideWith((ref) => pos)],
        child: const SmartPosApp(),
      ),
    );
    await tester.pumpAndSettle();
    return pos;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cash out, returned change, and closed-shift audit work with touch amounts',
    (tester) async {
      final pos = await launch(tester, const Size(1366, 768));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pos.openShift('Sami', 200000);
      await tap(tester, find.byTooltip('Cashier / Shifts'));
      await tap(tester, find.text('Cash out'));
      await tap(
        tester,
        find.byTooltip('Open number pad for Cash out amount (DT)'),
      );
      for (final digit in ['1', '0', '0']) {
        await tap(tester, find.byKey(ValueKey('money-key-$digit')));
      }
      await tap(tester, find.byKey(const ValueKey('money-apply')));
      await tap(
        tester,
        find.widgetWithText(DropdownButtonFormField<String>, 'Reason'),
      );
      await tap(tester, find.text('Business purchase').last);
      await tap(
        tester,
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Who took the cash?',
        ),
      );
      await tap(tester, find.text('Sami').last);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Approved by (optional)'),
        'Owner',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Details (required for Other)'),
        'Buy coffee beans',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Record cash out'));
      expect(pos.data.cashMovements.single.amount, 100000);
      expect(pos.data.cashMovements.single.person, 'Sami');
      expect(pos.data.cashMovements.single.approvedBy, 'Owner');
      expect(pos.data.expectedCash(pos.data.activeShift!), 100000);
      expect(find.text('Business purchase · Sami'), findsOneWidget);
      await tap(tester, find.text('Business purchase · Sami'));
      expect(find.text('Approved by (recorded note): Owner'), findsOneWidget);
      await tap(tester, find.text('Done'));
      await tap(tester, find.text('Cash in / return'));
      await tap(
        tester,
        find.byTooltip('Open number pad for Cash in amount (DT)'),
      );
      await tap(tester, find.byKey(const ValueKey('money-key-2')));
      await tap(tester, find.byKey(const ValueKey('money-key-5')));
      await tap(tester, find.byKey(const ValueKey('money-apply')));
      await tap(tester, find.widgetWithText(FilledButton, 'Record cash in'));
      expect(pos.data.expectedCash(pos.data.activeShift!), 125000);
      expect(pos.data.sales, isEmpty);
      await tester.scrollUntilVisible(
        find.text('Close shift'),
        -300,
        scrollable:
            find
                .descendant(
                  of: find.byType(ShiftsScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await tap(tester, find.text('Close shift'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Counted cash (DT)'),
        '125.000',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Close shift'));
      expect(pos.data.activeShift, isNull);
      expect(pos.data.shifts.single.expectedAtClose, 125000);
      await tester.scrollUntilVisible(
        find.text('Cash movements · 2'),
        300,
        scrollable:
            find
                .descendant(
                  of: find.byType(ShiftsScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await tap(tester, find.text('Cash movements · 2'));
      expect(find.text('Business purchase · Sami'), findsOneWidget);
      expect(find.text('Returned change · Sami'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cash out above available drawer cash shows error and saves nothing',
    (tester) async {
      final pos = await launch(tester, const Size(1366, 768));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pos.openShift('Sami', 50000);
      await tap(tester, find.byTooltip('Cashier / Shifts'));
      await tap(tester, find.text('Cash out'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cash out amount (DT)'),
        '100.000',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Record cash out'));
      expect(
        find.text('Cash out exceeds the expected drawer balance (50.000 DT).'),
        findsOneWidget,
      );
      expect(pos.data.cashMovements, isEmpty);
      await tap(tester, find.text('Cancel'));
      expect(pos.data.expectedCash(pos.data.activeShift!), 50000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'empty table visits and removing the last item leave it available',
    (tester) async {
      final pos = await launch(tester, const Size(1366, 768));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tap(tester, find.byTooltip('Tables'));
      for (final name in ['Table 1', 'Table 2', 'Table 3']) {
        await tap(tester, find.text(name));
        await tap(tester, find.byTooltip('Back to tables / bills'));
        expect(pos.data.bills, isEmpty);
        expect(find.text('Occupied'), findsOneWidget); // Legend only.
      }
      await tap(tester, find.text('Table 7'));
      await tap(tester, find.text('Espresso'));
      await tap(tester, find.byTooltip('Back to tables / bills'));
      expect(find.text('Occupied'), findsNWidgets(2));
      await tap(tester, find.text('Table 7'));
      expect(pos.data.bills.single.total, 3000);
      await tap(tester, find.byTooltip('Remove Espresso'));
      await tap(tester, find.byTooltip('Back to tables / bills'));
      expect(find.text('Occupied'), findsOneWidget);
      expect(pos.data.bills, isEmpty);
      await tap(tester, find.byTooltip('Orders / Bills'));
      expect(find.text('Open bills · 0'), findsOneWidget);
      await tap(tester, find.text('Open bills · 0'));
      expect(find.text('No open bills.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'sidebar navigation releases empty bills and keeps draft products',
    (tester) async {
      final pos = await launch(tester, const Size(1366, 768));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tap(tester, find.byTooltip('Tables'));
      await tap(tester, find.text('Table 7'));
      await tap(tester, find.byTooltip('Dashboard'));
      expect(pos.data.bills, isEmpty);
      final availableCard = find.ancestor(
        of: find.text('Available tables'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: availableCard, matching: find.text('20')),
        findsOneWidget,
      );
      await tap(tester, find.byTooltip('Tables'));
      await tap(tester, find.text('Table 7'));
      await tap(tester, find.text('Espresso'));
      await tap(tester, find.byTooltip('Customers'));
      expect(pos.data.bills.single.total, 3000);
      await tap(tester, find.byTooltip('Tables'));
      await tap(tester, find.text('Table 7'));
      expect(pos.data.bills.single.hasDraft, true);
      expect(find.text('1'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('touch-only cash checkout and shift entry require no keyboard', (
    tester,
  ) async {
    final pos = await launch(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tap(tester, find.text('Open shift'));
    await tap(tester, find.text('Open shift').last);
    await tap(tester, find.byTooltip('Open number pad for Opening cash (DT)'));
    await tap(tester, find.byKey(const ValueKey('money-key-5')));
    await tap(tester, find.byKey(const ValueKey('money-key-0')));
    await tap(tester, find.byKey(const ValueKey('money-apply')));
    await tap(tester, find.widgetWithText(FilledButton, 'Open shift'));
    expect(pos.data.activeShift!.opening, 50000);
    await tap(tester, find.byTooltip('Quick Sale'));
    await tap(tester, find.text('Espresso'));
    await tap(tester, find.text('Confirm order'));
    await tap(tester, find.text('Checkout · 3.000 DT'));
    await tap(tester, find.widgetWithText(TextField, 'Amount received (DT)'));
    await tap(tester, find.byKey(const ValueKey('money-key-5')));
    await tap(tester, find.byKey(const ValueKey('money-apply')));
    expect(pos.data.sales, isEmpty);
    expect(find.text('2.000 DT'), findsOneWidget);
    // An abandoned edit must not replace the amount already applied.
    await tap(tester, find.text('Enter cash on screen'));
    await tap(tester, find.byKey(const ValueKey('money-preset-20000')));
    await tap(tester, find.text('Cancel'));
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Amount received (DT)'),
          )
          .controller!
          .text,
      '5.000',
    );
    await tap(tester, find.text('Confirm payment'));
    expect(pos.data.sales.single.received, 5000);
    expect(pos.data.sales.single.change, 2000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'complete Table 7 two-round cash flow updates history and dashboard',
    (tester) async {
      final pos = await launch(tester, const Size(1366, 768));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tap(tester, find.text('Open shift'));
      await tap(tester, find.text('Open shift').last);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening cash (DT)'),
        '50.000',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Open shift'));
      await tap(tester, find.text('Tables'));
      await tap(tester, find.text('Table 7'));
      await tap(tester, find.text('Espresso'));
      await tap(tester, find.text('Espresso'));
      await tap(tester, find.text('Capucin'));
      await tap(tester, find.text('Confirm order'));
      expect(pos.data.bills.single.total, 9500);
      await tap(tester, find.byTooltip('Back to tables / bills'));
      expect(find.text('Occupied'), findsNWidgets(2));
      await tap(tester, find.text('Terrace · 10'));
      await tap(tester, find.text('Inside · 10'));
      await tap(tester, find.text('Table 7'));
      await tap(tester, find.text('Espresso'));
      await tap(tester, find.text('Confirm order'));
      await tap(tester, find.text('Checkout · 12.500 DT'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount received (DT)'),
        '10.000',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text('Confirm payment'),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount received (DT)'),
        '20.000',
      );
      await tester.pumpAndSettle();
      expect(find.text('7.500 DT'), findsOneWidget);
      await tap(tester, find.text('Confirm payment'));
      expect(pos.data.sales.single.total, 12500);
      expect(pos.data.bills, isEmpty);
      await tap(tester, find.text('Orders / Bills'));
      expect(find.text('12.500 DT'), findsOneWidget);
      await tap(tester, find.text('Dashboard'));
      expect(find.text('12.500 DT'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Quick Sale cash workflow saves a counter transaction', (
    tester,
  ) async {
    final pos = await launch(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pos.openShift('Sami', 0);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Quick Sale'));
    await tap(tester, find.text('Water'));
    await tap(tester, find.text('Confirm order'));
    await tap(tester, find.text('Checkout · 1.500 DT'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount received (DT)'),
      '2.000',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Confirm payment'));
    expect(pos.data.sales.single.bill.tableId, isNull);
    expect(pos.data.sales.single.change, 500);
    expect(pos.data.bills, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [
    const Size(1366, 768),
    const Size(1920, 1080),
    const Size(1000, 650),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'all sections and ordering fit ${size.width} x ${size.height}, dark=$dark',
        (tester) async {
          await launch(tester, size, dark: dark);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Finder navigation(String label) => find.byTooltip(label);
          for (final label in [
            'Tables',
            'Orders / Bills',
            'Customers',
            'Cashier / Shifts',
            'Settings',
          ]) {
            await tap(tester, navigation(label));
            expect(tester.takeException(), isNull, reason: label);
          }
          for (final label in [
            'POS',
            'Tables',
            'Products',
            'Loyalty',
            'Appearance',
            'Business',
          ]) {
            await tap(tester, find.widgetWithText(ChoiceChip, label));
            expect(tester.takeException(), isNull, reason: 'Settings $label');
          }
          await tap(tester, navigation('Quick Sale'));
          await tap(tester, find.text('Espresso'));
          await tap(tester, find.text('Confirm order'));
          expect(tester.takeException(), isNull, reason: 'Ordering');
          await tap(tester, find.text('Checkout · 3.000 DT'));
          expect(tester.takeException(), isNull, reason: 'Checkout');
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
