import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_pos/core/storage/pos_repository.dart';
import 'package:smart_pos/features/orders/pos_controller.dart';
import 'package:smart_pos/main.dart';
import 'package:smart_pos/models/pos_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native Windows workflow and persistent restart', (tester) async {
    final path = Platform.environment['SMART_POS_TEST_DIR'];
    if (path == null) {
      throw StateError('Set SMART_POS_TEST_DIR to an isolated test directory.');
    }
    final restart = Platform.environment['SMART_POS_VERIFY_STAGE'] == 'restart';
    final repository = JsonPosRepository(Directory(path));
    await repository.initialize();
    final loaded = await repository.load();
    if (!restart && loaded != null) {
      throw StateError(
        'Use an empty directory for workflow stage. No existing test files were changed.',
      );
    }
    final data = loaded ?? PosData.seed();
    if (loaded == null) {
      await repository.save(data);
    }
    final pos = PosController(repository, data);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [posProvider.overrideWith((ref) => pos)],
        child: RepaintBoundary(key: boundary, child: const SmartPosApp()),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> screenshot(String name) async {
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      final output = Platform.environment['SMART_POS_PREVIEW_DIR'];
      if (output == null) {
        return;
      }
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final shot = await render.toImage(pixelRatio: 1);
      final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      shot.dispose();
    }

    if (restart) {
      expect(pos.data.sales.length, 2);
      expect(pos.data.sales.first.total, 12500);
      expect(pos.data.sales.first.change, 7500);
      expect(pos.data.sales.last.bill.tableId, isNull);
      expect(pos.data.customers.first.points, 13);
      expect(pos.data.settings.station, 'Verified station');
      expect(pos.data.products.last.name, 'Demo cake');
      expect(pos.data.tables.length, 21);
      expect(pos.data.bills, isEmpty);
      await screenshot('dashboard');
      await tap(find.byTooltip('Tables'));
      await screenshot('tables');
      await tap(find.text('Table 7'));
      await tap(find.text('Espresso'));
      await screenshot('ordering');
      await pos.discardBill(pos.data.bills.single.id, 'End of verification');
      await tester.pumpAndSettle();
    } else {
      await tap(find.text('Open shift'));
      await tap(find.text('Open shift').last);
      await tap(find.byTooltip('Open number pad for Opening cash (DT)'));
      await tap(find.byKey(const ValueKey('money-key-5')));
      await tap(find.byKey(const ValueKey('money-key-0')));
      await tap(find.byKey(const ValueKey('money-apply')));
      await tap(find.widgetWithText(FilledButton, 'Open shift'));
      await tap(find.byTooltip('Tables'));
      await tap(find.text('Table 1'));
      await tap(find.byTooltip('Back to tables / bills'));
      expect(pos.data.bills, isEmpty);
      expect(find.text('Occupied'), findsOneWidget);
      await tap(find.text('Table 2'));
      await tap(find.byTooltip('Dashboard'));
      expect(pos.data.bills, isEmpty);
      await tap(find.byTooltip('Tables'));
      await tap(find.text('Table 7'));
      await tap(find.text('Espresso'));
      await tap(find.byTooltip('Remove Espresso'));
      await tap(find.byTooltip('Back to tables / bills'));
      expect(pos.data.bills, isEmpty);
      expect(find.text('Occupied'), findsOneWidget);
      await screenshot('empty-tables');
      await tap(find.text('Table 7'));
      await tap(find.text('Espresso'));
      await tap(find.text('Espresso'));
      await tap(find.text('Capucin'));
      await tap(find.text('Confirm order'));
      await tap(find.byTooltip('Back to tables / bills'));
      expect(find.text('Occupied'), findsNWidgets(2));
      await tap(find.text('Terrace · 10'));
      await tap(find.text('Inside · 10'));
      await tap(find.text('Table 7'));
      await tap(find.text('Espresso'));
      await tap(find.text('Confirm order'));
      final bill = pos.data.bills.single;
      await pos.customer(bill.id, pos.data.customers.first.id);
      await tester.pumpAndSettle();
      await tap(find.text('Checkout · 12.500 DT'));
      await tap(find.text('Enter cash on screen'));
      await tap(find.byKey(const ValueKey('money-key-2')));
      await tap(find.byKey(const ValueKey('money-key-0')));
      await screenshot('cash-keypad');
      await tap(find.byKey(const ValueKey('money-apply')));
      await tester.pumpAndSettle();
      expect(find.text('7.500 DT'), findsOneWidget);
      await screenshot('checkout');
      await tap(find.text('Confirm payment'));
      expect(pos.data.bills, isEmpty);
      expect(pos.data.sales.single.total, 12500);
      expect(pos.data.customers.first.points, 12);
      await pos.pay(bill.id, 'cash', 20000);
      expect(pos.data.sales.length, 1);
      await tap(find.byTooltip('Orders / Bills'));
      expect(find.text('12.500 DT'), findsOneWidget);
      await tap(find.byTooltip('Quick Sale'));
      await tap(find.text('Water'));
      await tap(find.text('Confirm order'));
      final quick = pos.data.bills.single.id;
      await pos.customer(quick, pos.data.customers.first.id);
      await tester.pumpAndSettle();
      await tap(find.text('Checkout · 1.500 DT'));
      await tap(find.text('Enter cash on screen'));
      await tap(find.byKey(const ValueKey('money-key-2')));
      await tap(find.byKey(const ValueKey('money-apply')));
      await tester.pumpAndSettle();
      await tap(find.text('Confirm payment'));
      final settings = PosSettings.fromJson(pos.data.settings.toJson())
        ..station = 'Verified station';
      await pos.settings(settings);
      await pos.saveProduct(null, 'Demo cake', 'Food', 6000, true);
      await pos.saveTable(null, 'Table 21', 'Terrace');
      await tester.pumpAndSettle();
      await tap(find.byTooltip('Dashboard'));
      expect(find.text('14.000 DT'), findsWidgets);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.close();
  });
}
