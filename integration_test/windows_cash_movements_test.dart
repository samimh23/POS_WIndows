import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_pos/core/storage/pos_repository.dart';
import 'package:smart_pos/features/orders/pos_controller.dart';
import 'package:smart_pos/features/shifts/shifts_screen.dart';
import 'package:smart_pos/main.dart';
import 'package:smart_pos/models/pos_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native Windows cash withdrawal and return survive restart', (
    tester,
  ) async {
    final path = Platform.environment['SMART_POS_TEST_DIR'];
      if (path == null) {
      throw StateError('Set SMART_POS_TEST_DIR to an isolated directory.');
      }
    final repository = JsonPosRepository(Directory(path));
    await repository.initialize();
    final restart = Platform.environment['SMART_POS_VERIFY_STAGE'] == 'restart';
    final loaded = await repository.load();
      if (!restart && loaded != null) {
      throw StateError('Use an empty directory for the workflow.');
      }
    final pos = PosController(repository, loaded ?? PosData.seed());
    if (!restart) await pos.openShift('Sami', 200000);
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
      final directory = Platform.environment['SMART_POS_PREVIEW_DIR'];
      if (directory == null) return;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final shot = await render.toImage();
      final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      shot.dispose();
    }

    await tap(find.byTooltip('Cashier / Shifts'));
    if (!restart) {
      await tap(find.text('Cash out'));
      await tap(find.byTooltip('Open number pad for Cash out amount (DT)'));
      for (final digit in ['1', '0', '0']) {
        await tap(find.byKey(ValueKey('money-key-$digit')));
      }
      await tap(find.byKey(const ValueKey('money-apply')));
      await screenshot('cash-out-form');
      await tap(find.widgetWithText(FilledButton, 'Record cash out'));
      expect(pos.data.expectedCash(pos.data.activeShift!), 100000);
      await tap(find.text('Cash in / return'));
      await tap(find.byTooltip('Open number pad for Cash in amount (DT)'));
      for (final digit in ['2', '5']) {
        await tap(find.byKey(ValueKey('money-key-$digit')));
      }
      await tap(find.byKey(const ValueKey('money-apply')));
      await tap(find.widgetWithText(FilledButton, 'Record cash in'));
      expect(pos.data.expectedCash(pos.data.activeShift!), 125000);
      await screenshot('cash-movements');
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
      await tap(find.text('Close shift'));
      await tap(find.byTooltip('Open number pad for Counted cash (DT)'));
      for (final digit in ['1', '2', '5']) {
        await tap(find.byKey(ValueKey('money-key-$digit')));
      }
      await tap(find.byKey(const ValueKey('money-apply')));
      await tap(find.widgetWithText(FilledButton, 'Close shift'));
    }
    expect(pos.data.cashMovements.length, 2);
    expect(pos.data.cashMovements.first.amount, 100000);
    expect(pos.data.cashMovements.first.person, 'Owner');
    expect(pos.data.cashMovements.last.reason, 'Returned change');
    expect(pos.data.shifts.single.expectedAtClose, 125000);
    expect(pos.data.shifts.single.counted, 125000);
    expect(pos.data.activeShift, isNull);
    expect(pos.data.sales, isEmpty);
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
    await tap(find.text('Cash movements · 2'));
    expect(find.text('Owner withdrawal · Owner'), findsOneWidget);
    expect(find.text('Returned change · Sami'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.close();
  });
}
