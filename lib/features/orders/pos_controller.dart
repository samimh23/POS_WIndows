import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/pos_repository.dart';
import '../../models/pos_data.dart';

final posProvider = ChangeNotifierProvider<PosController>(
  (ref) => throw StateError('Repository not initialized.'),
);

/// All writes, including settlement + loyalty + shift cash, commit as one snapshot.
/// The UI receives a fresh state only after persistence succeeds.
class PosController extends ChangeNotifier {
  PosController(this.repository, this.data);
  final PosRepository repository;
  PosData data;
  bool busy = false;
  Future<T> _commit<T>(T Function(PosData) action) async {
    if (busy) {
      throw StateError('A save is in progress. Please try again.');
    }
    busy = true;
    notifyListeners();
    try {
      final next = PosData.fromJson(data.toJson());
      final result = action(next);
      await repository.save(next);
      data = next;
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Bill _bill(PosData d, String id) => d.bills.firstWhere(
    (b) => b.id == id,
    orElse: () => throw StateError('This bill is no longer open.'),
  );
  String _text(String s) {
    final v = s.trim();
    if (v.isEmpty || v.length > 120) {
      throw StateError('Enter a name or reason (1–120 characters).');
    }
    return v;
  }

  Future<String> openTable(String tableId) async {
    final existing = data.tableBill(tableId, includeEmpty: true);
    if (existing != null) {
      return existing.id;
    }
    return _commit((d) {
      final t = d.tables.firstWhere((t) => t.id == tableId);
      final b = Bill(
        d.nextId('bill'),
        DateTime.now(),
        tableId: t.id,
        label: t.name,
      );
      d.bills.add(b);
      return b.id;
    });
  }

  Future<String> quickSale() async {
    for (final b in data.bills) {
      if (b.tableId == null) {
        return b.id;
      }
    }
    return _commit((d) {
      final b = Bill(d.nextId('bill'), DateTime.now());
      d.bills.add(b);
      return b.id;
    });
  }

  /// Release abandoned editor sessions, including empty drafts from older builds.
  /// Draft products and all confirmed/cancelled history remain untouched.
  Future<void> releaseEmptyBills() async {
    if (!data.bills.any((b) => b.isEmptyDraft)) {
      return;
    }
    await _commit((d) => d.bills.removeWhere((b) => b.isEmptyDraft));
  }

  Future<void> addProduct(String billId, String productId) => _commit((d) {
    final b = _bill(d, billId);
    final p = d.products.firstWhere((p) => p.id == productId);
    if (!p.enabled) {
      throw StateError('Product is disabled.');
    }
    if (b.isEmptyDraft) {
      b.openedAt = DateTime.now();
    }
    final matches = b.lines.where(
      (l) =>
          !l.confirmed &&
          !l.cancelled &&
          l.productId == p.id &&
          l.price == p.price &&
          l.note.isEmpty,
    );
    if (matches.isEmpty) {
      b.lines.add(OrderLine(d.nextId('line'), p.id, p.name, p.price));
    } else {
      matches.first.quantity++;
    }
    b.status = 'open';
  });
  Future<void> quantity(String billId, String lineId, int delta) => _commit((
    d,
  ) {
    final b = _bill(d, billId);
    final l = b.lines.firstWhere((l) => l.id == lineId);
    if (l.confirmed || l.cancelled) {
      throw StateError('Confirmed items require cancellation with a reason.');
    }
    if (l.quantity + delta <= 0) {
      b.lines.remove(l);
    } else {
      l.quantity += delta;
    }
    if (b.discount > b.subtotal) {
      b.discount = 0;
    }
    b.status = 'open';
  });
  Future<void> note(String billId, String lineId, String note) => _commit((d) {
    final l = _bill(d, billId).lines.firstWhere((l) => l.id == lineId);
    if (l.confirmed) {
      throw StateError('Notes are locked after confirmation.');
    }
    if (note.length > 240) {
      throw StateError('Notes are limited to 240 characters.');
    }
    l.note = note.trim();
  });
  Future<void> confirm(String id) => _commit((d) {
    final b = _bill(d, id);
    if (!b.hasDraft) {
      throw StateError('No new items to confirm.');
    }
    b.rounds++;
    for (final l in b.lines.where((l) => !l.confirmed && !l.cancelled)) {
      l.round = b.rounds;
    }
  });
  Future<void> cancelLine(String id, String lineId, String reason) =>
      _commit((d) {
        final b = _bill(d, id);
        final l = b.lines.firstWhere((l) => l.id == lineId);
        if (!l.confirmed || l.cancelled) {
          throw StateError('Item cannot be cancelled.');
        }
        l.cancelReason = _text(reason);
        b.discount = 0;
        b.status = 'open';
      });
  Future<void> discardBill(String id, String reason) => _commit((d) {
    final b = _bill(d, id);
    final r = _text(reason);
    for (final l in b.lines) {
      if (!l.cancelled) {
        l.cancelReason = r;
      }
    }
    b.status = 'cancelled';
    b.discount = 0;
    d.bills.remove(b);
    d.cancelledBills.add(b);
  });
  Future<void> customer(String id, String? customerId) => _commit((d) {
    if (customerId != null && !d.customers.any((c) => c.id == customerId)) {
      throw StateError('Customer does not exist.');
    }
    _bill(d, id).customerId = customerId;
  });
  Future<void> move(String id, String targetId) => _commit((d) {
    final b = _bill(d, id);
    if (b.tableId == null) {
      throw StateError('Counter sales cannot be moved to a table.');
    }
    if (d.tableBill(targetId) != null) {
      throw StateError('Destination table is occupied.');
    }
    final t = d.tables.firstWhere((t) => t.id == targetId);
    d.bills.removeWhere(
      (other) =>
          other.id != b.id && other.tableId == targetId && other.isEmptyDraft,
    );
    b.tableId = t.id;
    b.label = t.name;
  });
  Future<void> checkout(String id) => _commit((d) {
    final b = _bill(d, id);
    if (b.hasDraft || b.total <= 0) {
      throw StateError(
        'Confirm all new items and ensure the total is positive.',
      );
    }
    b.status = 'pending';
  });
  Future<void> discount(String id, int amount) => _commit((d) {
    final b = _bill(d, id);
    if (amount < 0 || amount >= b.subtotal) {
      throw StateError('Discount must be less than the subtotal.');
    }
    b.discount = amount;
  });
  Future<Sale> pay(
    String id,
    String method,
    int received, {
    bool cardConfirmed = false,
  }) async {
    final existing = data.sales.where((s) => s.billId == id);
    if (existing.isNotEmpty) {
      return existing.first;
    }
    return _commit((d) {
      final b = _bill(d, id);
      final shift = d.activeShift;
      if (shift == null) {
        throw StateError('Open a cashier shift before accepting payment.');
      }
      if (b.status != 'pending' || b.hasDraft || b.total <= 0) {
        throw StateError('Bill is not ready for payment.');
      }
      if (!['cash', 'card'].contains(method)) {
        throw StateError('Unknown payment method.');
      }
      if (method == 'cash' && received < b.total) {
        throw StateError('Received cash is insufficient.');
      }
      if (method == 'card' && !cardConfirmed) {
        throw StateError('Confirm the simulated card payment manually.');
      }
      final points =
          d.settings.loyalty && b.customerId != null ? b.total ~/ 1000 : 0;
      if (b.customerId != null) {
        d.customers.firstWhere((c) => c.id == b.customerId).points += points;
      }
      b.status = 'paid';
      final sale = Sale(
        d.nextId('sale'),
        b.id,
        b,
        DateTime.now(),
        method,
        method == 'cash' ? received : b.total,
        shift.id,
        points,
      );
      d.sales.add(sale);
      d.bills.remove(b);
      return sale;
    });
  }

  Future<void> openShift(String employee, int opening) => _commit((d) {
    if (d.activeShift != null || opening < 0) {
      throw StateError('Check the opening cash or close the current shift.');
    }
    d.shifts.add(
      Shift(d.nextId('shift'), _text(employee), DateTime.now(), opening),
    );
  });
  Future<void> closeShift(int counted) => _commit((d) {
    final s = d.activeShift;
    if (s == null || counted < 0) {
      throw StateError('No active shift or invalid counted cash.');
    }
    s.expectedAtClose = d.expectedCash(s);
    s.counted = counted;
    s.closedAt = DateTime.now();
  });
  Future<void> settings(PosSettings value) => _commit((d) {
    _text(value.cafe);
    _text(value.station);
    if (value.businessInfo.length > 500 ||
        !d.areas.contains(value.defaultArea) ||
        !['Shared', 'Assigned'].contains(value.zoneMode)) {
      throw StateError(
        'Check the station area, zone mode, and business information (up to 500 characters).',
      );
    }
    d.settings = PosSettings.fromJson(value.toJson());
  });
  Future<void> saveArea(String? old, String name) => _commit((d) {
    final n = _text(name);
    if (d.areas.any((a) => a.toLowerCase() == n.toLowerCase() && a != old)) {
      throw StateError('Area already exists.');
    }
    if (old == null) {
      d.areas.add(n);
    } else {
      d.areas[d.areas.indexOf(old)] = n;
      for (final t in d.tables.where((t) => t.area == old)) {
        t.area = n;
      }
      if (d.settings.defaultArea == old) {
        d.settings.defaultArea = n;
      }
    }
  });
  Future<void> removeArea(String area) => _commit((d) {
    if (d.areas.length <= 1 || d.tables.any((t) => t.area == area)) {
      throw StateError(
        'Move or remove all tables first. Keep at least one area.',
      );
    }
    d.areas.remove(area);
    if (d.settings.defaultArea == area) {
      d.settings.defaultArea = d.areas.first;
    }
  });
  Future<void> saveTable(String? id, String name, String area) => _commit((d) {
    final n = _text(name);
    if (!d.areas.contains(area)) {
      throw StateError('Choose an existing area.');
    }
    if (d.tables.any(
      (t) => t.id != id && t.name.toLowerCase() == n.toLowerCase(),
    )) {
      throw StateError('Table name already exists.');
    }
    if (id == null) {
      d.tables.add(CafeTable(d.nextId('table'), n, area));
    } else {
      if (d.tableBill(id) != null) {
        throw StateError(
          'Settle or move the active order before editing this table.',
        );
      }
      final t = d.tables.firstWhere((t) => t.id == id);
      d.bills.removeWhere((b) => b.tableId == id && b.isEmptyDraft);
      t.name = n;
      t.area = area;
    }
  });
  Future<void> removeTable(String id) => _commit((d) {
    if (d.tableBill(id) != null) {
      throw StateError('Settle or move the active order first.');
    }
    d.bills.removeWhere((b) => b.tableId == id && b.isEmptyDraft);
    d.tables.removeWhere((t) => t.id == id);
  });
  Future<void> saveCategory(String? old, String name) => _commit((d) {
    final n = _text(name);
    if (d.categories.any(
      (c) => c != old && c.toLowerCase() == n.toLowerCase(),
    )) {
      throw StateError('Category already exists.');
    }
    if (old == null) {
      d.categories.add(n);
    } else {
      d.categories[d.categories.indexOf(old)] = n;
      for (final p in d.products.where((p) => p.category == old)) {
        p.category = n;
      }
    }
  });
  Future<void> removeCategory(String category) => _commit((d) {
    if (d.categories.length <= 1 ||
        d.products.any((p) => p.category == category)) {
      throw StateError('Move all products first. Keep at least one category.');
    }
    d.categories.remove(category);
  });
  Future<void> saveProduct(
    String? id,
    String name,
    String category,
    int price,
    bool enabled,
  ) => _commit((d) {
    final n = _text(name);
    if (price <= 0 || !d.categories.contains(category)) {
      throw StateError('Choose a category and a positive price.');
    }
    if (d.products.any(
      (p) => p.id != id && p.name.toLowerCase() == n.toLowerCase(),
    )) {
      throw StateError('Product name already exists.');
    }
    if (id == null) {
      d.products.add(
        Product(d.nextId('product'), n, category, price, enabled: enabled),
      );
    } else {
      final p = d.products.firstWhere((p) => p.id == id);
      p.name = n;
      p.category = category;
      p.price = price;
      p.enabled = enabled;
    }
  });
}
