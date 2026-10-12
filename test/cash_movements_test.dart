import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pos/core/storage/pos_repository.dart';
import 'package:smart_pos/features/orders/pos_controller.dart';
import 'package:smart_pos/models/pos_data.dart';
import 'pos_controller_test.dart' show MemoryRepository;

void main() {
  late MemoryRepository repo;
  late PosController pos;
  setUp(() {
    repo = MemoryRepository();
    pos = PosController(repo, PosData.seed());
  });
  tearDown(() => pos.dispose());
  Future<CashMovement> record({
    String request = 'request-1',
    String? shiftId,
    String direction = 'out',
    int amount = 100000,
    String person = 'Owner',
    String reason = 'Owner withdrawal',
    String note = '',
    String approvedBy = '',
  }) => pos.recordCashMovement(
    requestId: request,
    shiftId: shiftId ?? pos.data.activeShift?.id ?? 'missing-shift',
    direction: direction,
    amount: amount,
    person: person,
    reason: reason,
    note: note,
    approvedBy: approvedBy,
  );

  test(
    '100 DT withdrawal and returned change update cash without changing sales or loyalty',
    () async {
      await pos.openShift('Sami', 200000);
      final bill = await pos.quickSale();
      await pos.customer(bill, pos.data.customers.first.id);
      await pos.addProduct(bill, pos.data.products.first.id);
      await pos.confirm(bill);
      await pos.checkout(bill);
      await pos.pay(bill, 'cash', 10000);
      expect(pos.data.expectedCash(pos.data.activeShift!), 203000);
      final withdrawal = await record(
        person: 'Youssef',
        reason: 'Business purchase',
        note: 'Buy coffee beans',
        approvedBy: 'Owner',
      );
      expect(withdrawal.amount, 100000);
      expect(withdrawal.recordedBy, 'Sami');
      expect(withdrawal.approvedBy, 'Owner');
      expect(pos.data.expectedCash(pos.data.activeShift!), 103000);
      await record(
        request: 'return-1',
        direction: 'in',
        amount: 25000,
        person: 'Youssef',
        reason: 'Returned change',
        note: 'Unused purchase cash',
      );
      expect(pos.data.expectedCash(pos.data.activeShift!), 128000);
      expect(
        pos.data.cashMovementTotal(pos.data.activeShift!.id, 'out'),
        100000,
      );
      expect(pos.data.cashMovementTotal(pos.data.activeShift!.id, 'in'), 25000);
      expect(pos.data.sales.single.total, 3000);
      expect(pos.data.customers.first.points, 3);
      expect((await repo.load())!.cashMovements.length, 2);
    },
  );

  test(
    'rejects invalid cash entries and withdrawals above drawer balance',
    () async {
      await expectLater(record(), throwsStateError);
      await pos.openShift('Sami', 50000);
      await expectLater(record(), throwsStateError);
      await expectLater(record(amount: 0), throwsStateError);
      await expectLater(record(amount: -1000), throwsStateError);
      await expectLater(record(amount: 1000, person: '  '), throwsStateError);
      await expectLater(
        record(amount: 1000, reason: 'Other cash out'),
        throwsStateError,
      );
      await expectLater(
        record(amount: 1000, reason: 'Unknown'),
        throwsStateError,
      );
      await expectLater(
        record(amount: 1000, direction: 'wrong'),
        throwsStateError,
      );
      await expectLater(record(amount: 1000, request: ''), throwsStateError);
      expect(pos.data.cashMovements, isEmpty);
      expect(pos.data.expectedCash(pos.data.activeShift!), 50000);
      await record(amount: 50000);
      expect(pos.data.expectedCash(pos.data.activeShift!), 0);
    },
  );

  test('completed requests remain idempotent after a shift closes', () async {
    await pos.openShift('Sami', 200000);
    final shift = pos.data.activeShift!.id;
    final first = await record();
    expect((await record()).id, first.id);
    await expectLater(record(amount: 50000), throwsStateError);
    await pos.closeShift(100000);
    expect((await record(shiftId: shift)).id, first.id);
    expect(pos.data.cashMovements.length, 1);
    expect(pos.data.shifts.single.expectedAtClose, 100000);
    await pos.openShift('Amira', 20000);
    expect(pos.data.expectedCash(pos.data.activeShift!), 20000);
    await expectLater(
      record(request: 'new-request', shiftId: shift, amount: 1000),
      throwsStateError,
    );
  });

  test('concurrent repeated save cannot record cash twice', () async {
    await pos.openShift('Sami', 200000);
    repo.gate = Completer<void>();
    final first = record();
    await expectLater(record(), throwsStateError);
    repo.gate!.complete();
    await first;
    await record();
    expect(pos.data.cashMovements.length, 1);
    expect(pos.data.expectedCash(pos.data.activeShift!), 100000);
  });

  test(
    'failed storage leaves cash unchanged and retries save only once',
    () async {
      await pos.openShift('Sami', 200000);
      repo.fail = true;
      await expectLater(record(), throwsA(isA<FileSystemException>()));
      expect(pos.data.expectedCash(pos.data.activeShift!), 200000);
      expect(pos.data.cashMovements, isEmpty);
      repo.fail = false;
      await record();
      await record();
      expect(pos.data.cashMovements.length, 1);
      expect(pos.data.expectedCash(pos.data.activeShift!), 100000);
    },
  );

  test('closing discrepancy includes withdrawals and cash added', () async {
    await pos.openShift('Sami', 200000);
    await record();
    await record(
      request: 'top-up',
      direction: 'in',
      amount: 15000,
      reason: 'Cash top-up',
    );
    await pos.closeShift(110000);
    final shift = pos.data.shifts.single;
    expect(shift.expectedAtClose, 115000);
    expect(shift.counted! - shift.expectedAtClose!, -5000);
    await expectLater(record(request: 'after-close'), throwsStateError);
  });

  test(
    'legacy JSON loads and cash audit survives a real repository restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('smart-pos-cash-');
      final repository = JsonPosRepository(dir);
      final data = PosData.seed();
      data.shifts.add(
        Shift(data.nextId('shift'), 'Sami', DateTime.now(), 200000),
      );
      final legacy = data.toJson()..remove('cashMovements');
      await File(
        '${dir.path}/state-000000000001.json',
      ).writeAsString(jsonEncode(legacy));
      try {
        await repository.initialize();
        final controller = PosController(
          repository,
          (await repository.load())!,
        );
        try {
          expect(controller.data.cashMovements, isEmpty);
          await controller.recordCashMovement(
            requestId: 'persisted-withdrawal',
            shiftId: controller.data.activeShift!.id,
            direction: 'out',
            amount: 100000,
            person: 'Youssef',
            reason: 'Business purchase',
            note: 'Buy supplies',
            approvedBy: 'Owner',
          );
          await controller.closeShift(100000);
        } finally {
          controller.dispose();
        }
        await repository.close();
        final restarted = JsonPosRepository(dir);
        await restarted.initialize();
        try {
          final saved = (await restarted.load())!;
          expect(saved.cashMovements.single.person, 'Youssef');
          expect(saved.cashMovements.single.note, 'Buy supplies');
          expect(saved.cashMovements.single.approvedBy, 'Owner');
          expect(saved.cashMovements.single.recordedBy, 'Sami');
          expect(saved.shifts.single.expectedAtClose, 100000);
          expect(saved.expectedCash(saved.shifts.single), 100000);
        } finally {
          await restarted.close();
        }
      } finally {
        await repository.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
