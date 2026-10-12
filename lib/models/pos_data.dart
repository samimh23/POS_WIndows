typedef Json = Map<String, dynamic>;

class Product {
  Product(this.id, this.name, this.category, this.price, {this.enabled = true});
  String id, name, category;
  int price;
  bool enabled;
  Json toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'price': price,
    'enabled': enabled,
  };
  factory Product.fromJson(Json j) => Product(
    j['id'],
    j['name'],
    j['category'],
    j['price'],
    enabled: j['enabled'],
  );
}

class CafeTable {
  CafeTable(this.id, this.name, this.area);
  String id, name, area;
  Json toJson() => {'id': id, 'name': name, 'area': area};
  factory CafeTable.fromJson(Json j) =>
      CafeTable(j['id'], j['name'], j['area']);
}

class Customer {
  Customer(this.id, this.name, this.phone, {this.points = 0});
  String id, name, phone;
  int points;
  Json toJson() => {'id': id, 'name': name, 'phone': phone, 'points': points};
  factory Customer.fromJson(Json j) =>
      Customer(j['id'], j['name'], j['phone'], points: j['points']);
}

class OrderLine {
  OrderLine(
    this.id,
    this.productId,
    this.name,
    this.price, {
    this.quantity = 1,
    this.round = 0,
    this.note = '',
    this.cancelReason = '',
  });
  String id, productId, name, note, cancelReason;
  int price, quantity, round;
  bool get cancelled => cancelReason.isNotEmpty;
  bool get confirmed => round > 0;
  int get total => cancelled ? 0 : price * quantity;
  Json toJson() => {
    'id': id,
    'productId': productId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'round': round,
    'note': note,
    'cancelReason': cancelReason,
  };
  factory OrderLine.fromJson(Json j) => OrderLine(
    j['id'],
    j['productId'],
    j['name'],
    j['price'],
    quantity: j['quantity'],
    round: j['round'],
    note: j['note'],
    cancelReason: j['cancelReason'],
  );
}

class Bill {
  Bill(
    this.id,
    this.openedAt, {
    this.tableId,
    this.customerId,
    this.label = 'Counter',
    this.status = 'open',
    this.rounds = 0,
    this.discount = 0,
    List<OrderLine>? lines,
  }) : lines = lines ?? [];
  String id, label, status;
  String? tableId, customerId;
  DateTime openedAt;
  int rounds, discount;
  List<OrderLine> lines;
  int get subtotal => lines.fold(0, (a, b) => a + b.total);
  int get total => subtotal - discount;
  bool get hasDraft => lines.any((l) => !l.confirmed && !l.cancelled);
  // A product-free draft is only an editor session, not an occupied table.
  // Keep confirmed/cancelled history active until explicitly settled/cancelled.
  bool get isEmptyDraft => lines.isEmpty && rounds == 0;
  Json toJson() => {
    'id': id,
    'openedAt': openedAt.toIso8601String(),
    'tableId': tableId,
    'customerId': customerId,
    'label': label,
    'status': status,
    'rounds': rounds,
    'discount': discount,
    'lines': lines.map((e) => e.toJson()).toList(),
  };
  factory Bill.fromJson(Json j) => Bill(
    j['id'],
    DateTime.parse(j['openedAt']),
    tableId: j['tableId'],
    customerId: j['customerId'],
    label: j['label'],
    status: j['status'],
    rounds: j['rounds'],
    discount: j['discount'],
    lines: (j['lines'] as List).map((e) => OrderLine.fromJson(e)).toList(),
  );
}

class Sale {
  Sale(
    this.id,
    this.billId,
    this.bill,
    this.paidAt,
    this.method,
    this.received,
    this.shiftId,
    this.points,
  );
  String id, billId, method, shiftId;
  Bill bill;
  DateTime paidAt;
  int received, points;
  int get total => bill.total;
  int get change => method == 'cash' ? received - total : 0;
  Json toJson() => {
    'id': id,
    'billId': billId,
    'bill': bill.toJson(),
    'paidAt': paidAt.toIso8601String(),
    'method': method,
    'received': received,
    'shiftId': shiftId,
    'points': points,
  };
  factory Sale.fromJson(Json j) => Sale(
    j['id'],
    j['billId'],
    Bill.fromJson(j['bill']),
    DateTime.parse(j['paidAt']),
    j['method'],
    j['received'],
    j['shiftId'],
    j['points'],
  );
}

class Shift {
  Shift(
    this.id,
    this.employee,
    this.openedAt,
    this.opening, {
    this.closedAt,
    this.counted,
    this.expectedAtClose,
  });
  String id, employee;
  DateTime openedAt;
  DateTime? closedAt;
  int opening;
  int? counted, expectedAtClose;
  Json toJson() => {
    'id': id,
    'employee': employee,
    'openedAt': openedAt.toIso8601String(),
    'opening': opening,
    'closedAt': closedAt?.toIso8601String(),
    'counted': counted,
    'expectedAtClose': expectedAtClose,
  };
  factory Shift.fromJson(Json j) => Shift(
    j['id'],
    j['employee'],
    DateTime.parse(j['openedAt']),
    j['opening'],
    closedAt: j['closedAt'] == null ? null : DateTime.parse(j['closedAt']),
    counted: j['counted'],
    expectedAtClose: j['expectedAtClose'],
  );
}

class CashMovement {
  CashMovement(
    this.id,
    this.requestId,
    this.shiftId,
    this.at,
    this.direction,
    this.amount,
    this.person,
    this.reason,
    this.recordedBy, {
    this.note = '',
    this.approvedBy = '',
  });
  static const outReasons = [
    'Owner withdrawal',
    'Business purchase',
    'Supplier payment',
    'Other cash out',
  ];
  static const inReasons = ['Returned change', 'Cash top-up', 'Other cash in'];
  final String id, requestId, shiftId, direction, person, reason, recordedBy;
  final String note, approvedBy;
  final DateTime at;
  final int amount;
  bool get isOut => direction == 'out';
  int get signedAmount => isOut ? -amount : amount;
  Json toJson() => {
    'id': id,
    'requestId': requestId,
    'shiftId': shiftId,
    'at': at.toIso8601String(),
    'direction': direction,
    'amount': amount,
    'person': person,
    'reason': reason,
    'recordedBy': recordedBy,
    'note': note,
    'approvedBy': approvedBy,
  };
  factory CashMovement.fromJson(Json j) => CashMovement(
    j['id'],
    j['requestId'],
    j['shiftId'],
    DateTime.parse(j['at']),
    j['direction'],
    j['amount'],
    j['person'],
    j['reason'],
    j['recordedBy'],
    note: j['note'],
    approvedBy: j['approvedBy'],
  );
}

class PosSettings {
  String cafe = 'Café Jasmin',
      businessInfo = 'Tunis, Tunisia',
      station = 'Main counter',
      defaultArea = 'Inside',
      zoneMode = 'Shared';
  bool loyalty = true, dark = false, multipleBills = false;
  Json toJson() => {
    'cafe': cafe,
    'businessInfo': businessInfo,
    'station': station,
    'defaultArea': defaultArea,
    'zoneMode': zoneMode,
    'loyalty': loyalty,
    'dark': dark,
    'multipleBills': multipleBills,
  };
  factory PosSettings.fromJson(Json j) =>
      PosSettings()
        ..cafe = j['cafe']
        ..businessInfo = j['businessInfo']
        ..station = j['station']
        ..defaultArea = j['defaultArea']
        ..zoneMode = j['zoneMode']
        ..loyalty = j['loyalty']
        ..dark = j['dark']
        ..multipleBills = j['multipleBills'];
  PosSettings();
}

class PosData {
  PosData();
  int sequence = 0;
  PosSettings settings = PosSettings();
  List<String> areas = [], categories = [];
  List<Product> products = [];
  List<CafeTable> tables = [];
  List<Customer> customers = [];
  List<Bill> bills = [], cancelledBills = [];
  List<Sale> sales = [];
  List<Shift> shifts = [];
  List<CashMovement> cashMovements = [];
  String nextId(String prefix) => '$prefix-${++sequence}';
  List<Bill> get activeBills => bills.where((b) => !b.isEmptyDraft).toList();
  Bill? tableBill(String id, {bool includeEmpty = false}) {
    for (final b in bills) {
      if (b.tableId == id && (includeEmpty || !b.isEmptyDraft)) {
        return b;
      }
    }
    return null;
  }

  Shift? get activeShift {
    for (final s in shifts) {
      if (s.closedAt == null) {
        return s;
      }
    }
    return null;
  }

  int expectedCash(Shift shift) =>
      shift.opening +
      sales
          .where((s) => s.shiftId == shift.id && s.method == 'cash')
          .fold<int>(0, (a, s) => a + s.total) +
      cashMovements
          .where((m) => m.shiftId == shift.id)
          .fold<int>(0, (a, m) => a + m.signedAmount);
  int cashMovementTotal(String shiftId, String direction) => cashMovements
      .where((m) => m.shiftId == shiftId && m.direction == direction)
      .fold(0, (a, m) => a + m.amount);
  Json toJson() => {
    'schema': 1,
    'sequence': sequence,
    'settings': settings.toJson(),
    'areas': areas,
    'categories': categories,
    'products': products.map((e) => e.toJson()).toList(),
    'tables': tables.map((e) => e.toJson()).toList(),
    'customers': customers.map((e) => e.toJson()).toList(),
    'bills': bills.map((e) => e.toJson()).toList(),
    'cancelledBills': cancelledBills.map((e) => e.toJson()).toList(),
    'sales': sales.map((e) => e.toJson()).toList(),
    'shifts': shifts.map((e) => e.toJson()).toList(),
    'cashMovements': cashMovements.map((e) => e.toJson()).toList(),
  };
  factory PosData.fromJson(Json j) {
    if (j['schema'] != 1) {
      throw const FormatException('Unsupported data version.');
    }
    final d =
        PosData()
          ..sequence = j['sequence']
          ..settings = PosSettings.fromJson(j['settings'])
          ..areas = List<String>.from(j['areas'])
          ..categories = List<String>.from(j['categories'])
          ..products =
              (j['products'] as List).map((e) => Product.fromJson(e)).toList()
          ..tables =
              (j['tables'] as List).map((e) => CafeTable.fromJson(e)).toList()
          ..customers =
              (j['customers'] as List).map((e) => Customer.fromJson(e)).toList()
          ..bills = (j['bills'] as List).map((e) => Bill.fromJson(e)).toList()
          ..cancelledBills =
              (j['cancelledBills'] as List)
                  .map((e) => Bill.fromJson(e))
                  .toList()
          ..sales = (j['sales'] as List).map((e) => Sale.fromJson(e)).toList()
          ..shifts =
              (j['shifts'] as List).map((e) => Shift.fromJson(e)).toList()
          ..cashMovements =
              ((j['cashMovements'] ?? []) as List)
                  .map((e) => CashMovement.fromJson(e))
                  .toList();
    d.validate();
    return d;
  }
  void validate() {
    void unique(Iterable<String> ids) {
      if (ids.toSet().length != ids.length) {
        throw const FormatException('Duplicate identifiers.');
      }
    }

    unique(products.map((e) => e.id));
    unique(tables.map((e) => e.id));
    unique(customers.map((e) => e.id));
    unique(bills.map((e) => e.id));
    unique(sales.map((e) => e.billId));
    unique(shifts.map((e) => e.id));
    unique(cashMovements.map((e) => e.id));
    unique(cashMovements.map((e) => e.requestId));
    unique(bills.where((e) => e.tableId != null).map((e) => e.tableId!));
    if (sequence < 0 ||
        areas.isEmpty ||
        areas.toSet().length != areas.length ||
        categories.isEmpty ||
        categories.toSet().length != categories.length ||
        !areas.contains(settings.defaultArea) ||
        shifts.where((s) => s.closedAt == null).length > 1) {
      throw const FormatException('Invalid configuration.');
    }
    for (final p in products) {
      if (p.price <= 0 ||
          p.name.trim().isEmpty ||
          !categories.contains(p.category)) {
        throw const FormatException('Invalid product.');
      }
    }
    for (final t in tables) {
      if (!areas.contains(t.area) || t.name.trim().isEmpty) {
        throw const FormatException('Invalid table.');
      }
    }
    for (final b in [
      ...bills,
      ...cancelledBills,
      ...sales.map((s) => s.bill),
    ]) {
      if (b.discount < 0 ||
          b.discount > b.subtotal ||
          b.lines.any((l) => l.quantity < 1 || l.price < 1 || l.round < 0)) {
        throw const FormatException('Invalid bill amounts.');
      }
    }
    for (final b in bills) {
      if ((b.tableId != null && !tables.any((t) => t.id == b.tableId)) ||
          (b.customerId != null &&
              !customers.any((c) => c.id == b.customerId)) ||
          sales.any((s) => s.billId == b.id)) {
        throw const FormatException('Invalid open bill.');
      }
    }
    for (final s in sales) {
      if (s.bill.hasDraft ||
          s.total <= 0 ||
          !shifts.any((x) => x.id == s.shiftId) ||
          !['cash', 'card'].contains(s.method) ||
          s.received < s.total) {
        throw const FormatException('Invalid transaction.');
      }
    }
    for (final m in cashMovements) {
      final reasons =
          m.isOut ? CashMovement.outReasons : CashMovement.inReasons;
      if (!shifts.any((s) => s.id == m.shiftId) ||
          !['out', 'in'].contains(m.direction) ||
          m.amount <= 0 ||
          m.requestId.trim().isEmpty ||
          m.requestId.length > 120 ||
          m.person.trim().isEmpty ||
          m.person.length > 120 ||
          m.recordedBy.trim().isEmpty ||
          m.recordedBy.length > 120 ||
          !reasons.contains(m.reason) ||
          m.note.length > 240 ||
          m.approvedBy.length > 120 ||
          (m.reason.startsWith('Other') && m.note.trim().isEmpty)) {
        throw const FormatException('Invalid cash movement.');
      }
    }
  }

  factory PosData.seed() {
    final d =
        PosData()
          ..areas = ['Inside', 'Terrace']
          ..categories = ['Coffee', 'Tea', 'Cold Drinks', 'Food'];
    final catalog = <(String, String, int)>[
      ('Espresso', 'Coffee', 3000),
      ('Capucin', 'Coffee', 3500),
      ('Direct', 'Coffee', 2800),
      ('Cappuccino', 'Coffee', 5000),
      ('Tea', 'Tea', 2500),
      ('Mint Tea', 'Tea', 3000),
      ('Water', 'Cold Drinks', 1500),
      ('Coca-Cola', 'Cold Drinks', 3500),
      ('Orange Juice', 'Cold Drinks', 5000),
      ('Croissant', 'Food', 2500),
      ('Sandwich', 'Food', 7000),
    ];
    d.products =
        catalog
            .map((p) => Product(d.nextId('product'), p.$1, p.$2, p.$3))
            .toList();
    d.tables = List.generate(
      20,
      (i) => CafeTable(
        d.nextId('table'),
        'Table ${i + 1}',
        i < 10 ? 'Inside' : 'Terrace',
      ),
    );
    d.customers = [
      Customer(d.nextId('customer'), 'Amira Ben Ali', '20 123 456'),
      Customer(d.nextId('customer'), 'Youssef Trabelsi', '22 987 654'),
      Customer(d.nextId('customer'), 'Lina Mansour', ''),
    ];
    return d;
  }
}
