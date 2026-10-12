import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pos/core/storage/pos_repository.dart';
import 'package:smart_pos/core/utils/money.dart';
import 'package:smart_pos/features/orders/pos_controller.dart';
import 'package:smart_pos/models/pos_data.dart';

class MemoryRepository implements PosRepository {
  PosData? stored;
  bool fail = false;
  Completer<void>? gate;
  @override
  String? get warning => null;
  @override
  Future<PosData?> load() async =>
      stored == null ? null : PosData.fromJson(stored!.toJson());
  @override
  Future<void> save(PosData data) async {
    if (fail) {
      throw const FileSystemException('Disk full');
    }
    if (gate != null) {
      await gate!.future;
    }
    stored = PosData.fromJson(data.toJson());
  }
}

void main() {
  late PosController pos;
  late MemoryRepository repo;
  String product(String name) =>
      pos.data.products.firstWhere((p) => p.name == name).id;
  String table(String name) =>
      pos.data.tables.firstWhere((t) => t.name == name).id;
  Future<String> readyBill({bool counter = false}) async {
    final id =
        counter ? await pos.quickSale() : await pos.openTable(table('Table 7'));
    await pos.addProduct(id, product('Espresso'));
    await pos.confirm(id);
    await pos.checkout(id);
    return id;
  }

  setUp(() {
    repo = MemoryRepository();
    pos = PosController(repo, PosData.seed());
  });
  tearDown(() => pos.dispose());
  test('opening and leaving an empty table never occupies it', () async {
    final t = table('Table 7');
    final id = await pos.openTable(t);
    expect(pos.data.tableBill(t), isNull);
    expect(pos.data.activeBills, isEmpty);
    expect(await pos.openTable(t), id);
    expect(pos.data.bills.length, 1);
    await pos.releaseEmptyBills();
    expect(pos.data.bills, isEmpty);
    expect((await repo.load())!.bills, isEmpty);
    expect(pos.data.cancelledBills, isEmpty);
    expect(pos.data.sales, isEmpty);
  });
  test(
    'last draft removal releases table while other draft orders survive',
    () async {
      final t = table('Table 7');
      final id = await pos.openTable(t);
      await pos.addProduct(id, product('Espresso'));
      expect(pos.data.tableBill(t)!.total, 3000);
      await pos.quantity(id, pos.data.bills.single.lines.single.id, -1);
      expect(pos.data.tableBill(t), isNull);
      final other = await pos.openTable(table('Table 11'));
      await pos.addProduct(other, product('Capucin'));
      await pos.releaseEmptyBills();
      expect(pos.data.bills.single.id, other);
      expect(pos.data.bills.single.hasDraft, true);
      expect((await repo.load())!.tableBill(table('Table 11'))!.total, 3500);
    },
  );
  test(
    'restart cleanup removes old empty bills but preserves cancellation audit',
    () async {
      final empty = await pos.openTable(table('Table 1'));
      final counter = await pos.quickSale();
      final active = await pos.openTable(table('Table 7'));
      await pos.addProduct(active, product('Espresso'));
      await pos.confirm(active);
      await pos.cancelLine(
        active,
        pos.data.tableBill(table('Table 7'))!.lines.single.id,
        'Wrong drink',
      );
      final restarted = PosController(repo, (await repo.load())!);
      try {
        expect(restarted.data.activeBills.single.id, active);
        expect(restarted.data.tableBill(table('Table 1')), isNull);
        await restarted.releaseEmptyBills();
        final saved = (await repo.load())!;
        expect(saved.bills.any((b) => b.id == empty || b.id == counter), false);
        expect(saved.bills.single.id, active);
        expect(saved.bills.single.lines.single.cancelReason, 'Wrong drink');
        expect(saved.bills.single.total, 0);
      } finally {
        restarted.dispose();
      }
    },
  );
  test('failed empty-bill cleanup preserves data and can be retried', () async {
    await pos.openTable(table('Table 7'));
    repo.fail = true;
    await expectLater(
      pos.releaseEmptyBills(),
      throwsA(isA<FileSystemException>()),
    );
    expect(pos.data.bills.length, 1);
    expect(pos.data.activeBills, isEmpty);
    expect(pos.busy, false);
    repo.fail = false;
    await pos.releaseEmptyBills();
    expect(pos.data.bills, isEmpty);
  });
  test('unused empty tables can be edited and removed safely', () async {
    final t1 = table('Table 1'), t2 = table('Table 2');
    await pos.openTable(t1);
    await pos.saveTable(t1, 'Window table', 'Inside');
    await pos.openTable(t2);
    await pos.removeTable(t2);
    final saved = (await repo.load())!;
    expect(saved.bills, isEmpty);
    expect(saved.tables.any((t) => t.id == t2), false);
    expect(saved.tables.firstWhere((t) => t.id == t1).name, 'Window table');
    saved.validate();
  });
  test('money parses exactly and rejects fractions beyond millimes', () {
    expect(parseMoney('20.000'), 20000);
    expect(parseMoney('3,5'), 3500);
    expect(money(12500), '12.500 DT');
    expect(money(-500), '-0.500 DT');
    for (final invalid in ['-1', 'NaN', '1.0001', '', '1e3']) {
      expect(() => parseMoney(invalid), throwsFormatException);
    }
  });
  test(
    'Table 7 two rounds, payment, loyalty, restart and idempotence',
    () async {
      await pos.openShift('Sami', 50000);
      final t = table('Table 7');
      final id = await pos.openTable(t);
      final customer = pos.data.customers.first.id;
      await pos.customer(id, customer);
      await pos.addProduct(id, product('Espresso'));
      await pos.addProduct(id, product('Espresso'));
      await pos.addProduct(id, product('Capucin'));
      await pos.confirm(id);
      expect(pos.data.tableBill(t)!.total, 9500);
      expect(await pos.openTable(t), id);
      await pos.addProduct(id, product('Espresso'));
      await pos.confirm(id);
      expect(pos.data.tableBill(t)!.rounds, 2);
      expect(pos.data.tableBill(t)!.total, 12500);
      await pos.checkout(id);
      final sale = await pos.pay(id, 'cash', 20000);
      expect(sale.change, 7500);
      expect(pos.data.tableBill(t), isNull);
      expect(pos.data.sales.length, 1);
      expect(pos.data.customers.first.points, 12);
      expect(pos.data.expectedCash(pos.data.activeShift!), 62500);
      expect((await pos.pay(id, 'cash', 20000)).id, sale.id);
      expect(pos.data.sales.length, 1);
      expect(pos.data.customers.first.points, 12);
      final restarted = PosController(repo, (await repo.load())!);
      expect(restarted.data.sales.single.total, 12500);
      expect(restarted.data.tables.length, 20);
      expect(restarted.data.tableBill(t), isNull);
      expect(restarted.data.products.length, 11);
      expect(restarted.data.customers.first.points, 12);
      restarted.dispose();
    },
  );
  test(
    'unpaid draft, confirmed item protection and cancellation audit',
    () async {
      final id = await pos.openTable(table('Table 7'));
      await pos.addProduct(id, product('Espresso'));
      await expectLater(pos.checkout(id), throwsStateError);
      expect(pos.data.customers.first.points, 0);
      await pos.confirm(id);
      final line = pos.data.bills.single.lines.single.id;
      await expectLater(pos.quantity(id, line, -1), throwsStateError);
      await expectLater(pos.cancelLine(id, line, ''), throwsStateError);
      await pos.cancelLine(id, line, 'Wrong drink');
      expect(pos.data.bills.single.lines.single.cancelReason, 'Wrong drink');
      expect(pos.data.bills.single.total, 0);
      await pos.discardBill(id, 'Customer left');
      expect(
        pos.data.cancelledBills.single.lines.single.cancelReason,
        'Wrong drink',
      );
      expect(pos.data.bills, isEmpty);
    },
  );
  test('draft quantity, notes and removal work', () async {
    final id = await pos.quickSale();
    await pos.addProduct(id, product('Espresso'));
    final line = pos.data.bills.single.lines.single.id;
    await pos.note(id, line, 'No sugar');
    await pos.quantity(id, line, 1);
    expect(pos.data.bills.single.total, 6000);
    await pos.quantity(id, line, -2);
    expect(pos.data.bills.single.lines, isEmpty);
  });
  test(
    'insufficient cash, missing shift and unconfirmed card are rejected',
    () async {
      final id = await readyBill();
      await expectLater(pos.pay(id, 'cash', 20000), throwsStateError);
      await pos.openShift('Sami', 0);
      await expectLater(pos.pay(id, 'cash', 2999), throwsStateError);
      await expectLater(pos.pay(id, 'card', 3000), throwsStateError);
      expect(pos.data.sales, isEmpty);
      expect(pos.data.tableBill(table('Table 7'))!.status, 'pending');
    },
  );
  test('counter card sale and discount loyalty use final amount', () async {
    await pos.openShift('Amira', 10000);
    final id = await readyBill(counter: true);
    await pos.customer(id, pos.data.customers.first.id);
    await pos.discount(id, 500);
    final sale = await pos.pay(id, 'card', 0, cardConfirmed: true);
    expect(sale.total, 2500);
    expect(sale.points, 2);
    expect(pos.data.expectedCash(pos.data.activeShift!), 10000);
    expect(pos.data.sales.single.bill.tableId, isNull);
  });
  test('disabled loyalty preserves existing points and awards none', () async {
    await pos.openShift('Sami', 0);
    final settings = PosSettings.fromJson(pos.data.settings.toJson())
      ..loyalty = false;
    await pos.settings(settings);
    final id = await readyBill();
    await pos.customer(id, pos.data.customers.first.id);
    expect((await pos.pay(id, 'cash', 3000)).points, 0);
    expect(pos.data.customers.first.points, 0);
  });
  test('repeated concurrent payments cannot duplicate a transaction', () async {
    await pos.openShift('Sami', 0);
    final id = await readyBill();
    repo.gate = Completer<void>();
    final first = pos.pay(id, 'cash', 3000);
    await expectLater(pos.pay(id, 'cash', 3000), throwsStateError);
    repo.gate!.complete();
    await first;
    expect(pos.data.sales.length, 1);
    expect((await pos.pay(id, 'cash', 3000)).billId, id);
  });
  test(
    'failed storage commit leaves order, cash and loyalty unchanged',
    () async {
      await pos.openShift('Sami', 0);
      final id = await readyBill();
      await pos.customer(id, pos.data.customers.first.id);
      repo.fail = true;
      await expectLater(
        pos.pay(id, 'cash', 3000),
        throwsA(isA<FileSystemException>()),
      );
      expect(pos.data.sales, isEmpty);
      expect(pos.data.customers.first.points, 0);
      expect(pos.data.bills.single.status, 'pending');
      expect(pos.busy, false);
      repo.fail = false;
      await pos.pay(id, 'cash', 3000);
      expect(pos.data.sales.length, 1);
    },
  );
  test(
    'move across zones preserves bill and prevents deleting active tables',
    () async {
      final t7 = table('Table 7'), t11 = table('Table 11');
      final id = await pos.openTable(t7);
      await pos.addProduct(id, product('Espresso'));
      await pos.confirm(id);
      await expectLater(pos.removeTable(t7), throwsStateError);
      await expectLater(
        pos.saveTable(t7, 'New name', 'Inside'),
        throwsStateError,
      );
      await pos.move(id, t11);
      expect(pos.data.tableBill(t7), isNull);
      expect(pos.data.tableBill(t11)!.total, 3000);
      expect(pos.data.tableBill(t11)!.id, id);
      await pos.openTable(t7);
      // Visiting an empty destination does not reserve it.
      await pos.move(id, t7);
      expect(pos.data.bills.single.id, id);
      expect(pos.data.tableBill(t11), isNull);
      final occupied = await pos.openTable(t11);
      await pos.addProduct(occupied, product('Water'));
      await expectLater(pos.move(id, t11), throwsStateError);
    },
  );
  test('catalog price changes do not rewrite order snapshots', () async {
    final id = await pos.quickSale();
    final p = pos.data.products.first;
    await pos.addProduct(id, p.id);
    await pos.confirm(id);
    await pos.saveProduct(p.id, 'New espresso', 'Coffee', 4000, true);
    await pos.addProduct(id, p.id);
    expect(pos.data.bills.single.total, 7000);
    expect(pos.data.bills.single.lines.first.name, 'Espresso');
  });
  test(
    'settings, category, table and area edits survive repository reload',
    () async {
      await pos.saveArea(null, 'Garden');
      await pos.saveTable(null, 'Table 21', 'Garden');
      await pos.saveArea('Garden', 'Patio');
      await pos.saveCategory(null, 'Dessert');
      await pos.saveProduct(null, 'Cake', 'Dessert', 6000, true);
      await pos.saveCategory('Dessert', 'Sweets');
      final s =
          PosSettings.fromJson(pos.data.settings.toJson())
            ..dark = true
            ..cafe = 'My café'
            ..defaultArea = 'Patio'
            ..zoneMode = 'Assigned';
      await pos.settings(s);
      final d = (await repo.load())!;
      expect(d.settings.cafe, 'My café');
      expect(d.settings.dark, true);
      expect(d.tables.last.area, 'Patio');
      expect(d.products.last.category, 'Sweets');
      await expectLater(pos.removeArea('Patio'), throwsStateError);
      await expectLater(pos.removeCategory('Sweets'), throwsStateError);
    },
  );
  test('cash shift closing records stable expected and discrepancy', () async {
    await pos.openShift('Sami', 50000);
    final id = await readyBill();
    await pos.pay(id, 'cash', 10000);
    await pos.closeShift(52000);
    expect(pos.data.activeShift, isNull);
    expect(pos.data.shifts.single.expectedAtClose, 53000);
    expect(
      pos.data.shifts.single.counted! - pos.data.shifts.single.expectedAtClose!,
      -1000,
    );
    await pos.openShift('Amira', 20000);
    expect(pos.data.expectedCash(pos.data.activeShift!), 20000);
  });
  test('empty bill and invalid discount cannot be paid', () async {
    final id = await pos.quickSale();
    await expectLater(pos.checkout(id), throwsStateError);
    await pos.addProduct(id, product('Water'));
    await expectLater(pos.discount(id, 1500), throwsStateError);
    await expectLater(pos.discount(id, -1), throwsStateError);
  });
  test(
    'JSON generations reload, recover corruption and preserve edits',
    () async {
      final dir = await Directory.systemTemp.createTemp('smart-pos-test-');
      final repository = JsonPosRepository(dir);
      try {
        await repository.initialize();
        expect(await repository.load(), isNull);
        final data = PosData.seed();
        await repository.save(data);
        data.settings.cafe = 'Persisted café';
        await repository.save(data);
        data.settings.dark = true;
        await repository.save(data);
        await repository.close();
        final restarted = JsonPosRepository(dir);
        await restarted.initialize();
        expect((await restarted.load())!.settings.dark, true);
        await restarted.close();
        final files =
            dir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.json'))
                .toList()
              ..sort((a, b) => b.path.compareTo(a.path));
        await files.first.writeAsString('{broken');
        final recovered = JsonPosRepository(dir);
        await recovered.initialize();
        expect((await recovered.load())!.settings.cafe, 'Persisted café');
        expect(recovered.warning, isNotNull);
        expect(await files.first.readAsString(), '{broken');
        await recovered.close();
      } finally {
        await repository.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test('all malformed snapshots fail without silently reseeding', () async {
    final dir = await Directory.systemTemp.createTemp('smart-pos-corrupt-');
    final repository = JsonPosRepository(dir);
    try {
      await File(
        '${dir.path}/state-000000000001.json',
      ).writeAsString(jsonEncode({'schema': 999}));
      await repository.initialize();
      await expectLater(repository.load(), throwsStateError);
      expect(
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .length,
        1,
      );
    } finally {
      await repository.close();
      await dir.delete(recursive: true);
    }
  });
}
