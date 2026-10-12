import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pos_data.dart';
import '../../features/orders/pos_controller.dart';
import '../../features/orders/order_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/tables/tables_screen.dart';
import '../../features/orders/history_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/shifts/shifts_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/widgets/pos_widgets.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int section = 0;
  String? billId;
  bool checkingOut = false;
  static const labels = [
    'Dashboard',
    'Tables',
    'Quick Sale',
    'Orders / Bills',
    'Customers',
    'Cashier / Shifts',
    'Settings',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.table_restaurant_outlined,
    Icons.bolt_outlined,
    Icons.receipt_long_outlined,
    Icons.people_outline,
    Icons.account_balance_wallet_outlined,
    Icons.settings_outlined,
  ];
  Future<void> navigate(int index) async {
    final pos = ref.read(posProvider);
    if (pos.busy) {
      return;
    }
    final ready = await perform(context, () async {
      await pos.releaseEmptyBills();
      return true;
    });
    if (ready != true || !mounted) {
      return;
    }
    if (index == 2) {
      final id = await perform(
        context,
        () => ref.read(posProvider).quickSale(),
      );
      if (id == null || !mounted) {
        return;
      }
      setState(() {
        section = index;
        billId = id;
        checkingOut = false;
      });
    } else {
      setState(() {
        section = index;
        billId = null;
        checkingOut = false;
      });
    }
  }

  void openBill(String id) {
    setState(() {
      billId = id;
      checkingOut = false;
    });
  }

  void leaveBill() {
    navigate(section == 2 ? 3 : section);
  }

  Widget page() {
    if (billId != null) {
      if (checkingOut) {
        return CheckoutScreen(
          billId: billId!,
          onBack: () => setState(() => checkingOut = false),
          onPaid: () {
            final counter =
                ref.read(posProvider).data.sales.last.bill.tableId == null;
            setState(() {
              billId = null;
              checkingOut = false;
              section = counter ? 3 : 1;
            });
          },
        );
      }
      return OrderScreen(
        billId: billId!,
        onBack: leaveBill,
        onCheckout: () => setState(() => checkingOut = true),
      );
    }
    switch (section) {
      case 1:
        return TablesScreen(onOpen: openBill);
      case 3:
        return HistoryScreen(onOpen: openBill);
      case 4:
        return const CustomersScreen();
      case 5:
        return const ShiftsScreen();
      case 6:
        return const SettingsScreen();
      default:
        return DashboardScreen(
          onTables: () => navigate(1),
          onQuickSale: () => navigate(2),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(posProvider);
    final d = pos.data;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1120;
        return Scaffold(
          body: Row(
            children: [
              Container(
                width: compact ? 84 : 220,
                color: colors.surface,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 24,
                          vertical: 28,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.point_of_sale,
                                color: colors.onPrimary,
                              ),
                            ),
                            if (!compact)
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Text(
                                    'Smart POS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (var i = 0; i < labels.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Tooltip(
                                  message: labels[i],
                                  child: Material(
                                    color:
                                        section == i
                                            ? colors.primaryContainer
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => navigate(i),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 17,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              compact
                                                  ? MainAxisAlignment.center
                                                  : MainAxisAlignment.start,
                                          children: [
                                            Icon(
                                              icons[i],
                                              size: 23,
                                              color:
                                                  section == i
                                                      ? colors.primary
                                                      : colors.onSurfaceVariant,
                                            ),
                                            if (!compact) ...[
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  labels[i],
                                                  style: TextStyle(
                                                    fontWeight:
                                                        section == i
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child:
                            compact
                                ? const Icon(Icons.offline_pin_outlined)
                                : const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LOCAL DEMO',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Offline ready · Windows',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Simulated payments',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: colors.outlineVariant),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 76,
                      color: colors.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.settings.cafe,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '${d.settings.station} · TND',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (pos.busy)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () => navigate(5),
                            icon: const Icon(Icons.badge_outlined, size: 18),
                            label: Text(
                              d.activeShift == null
                                  ? 'Open shift'
                                  : d.activeShift!.employee,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            tooltip: 'Toggle light / dark mode',
                            onPressed:
                                pos.busy
                                    ? null
                                    : () => perform(context, () {
                                      final s = PosSettings.fromJson(
                                        d.settings.toJson(),
                                      );
                                      s.dark = !s.dark;
                                      return pos.settings(s);
                                    }),
                            icon: Icon(
                              d.settings.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pos.repository.warning != null)
                      MaterialBanner(
                        content: Text(pos.repository.warning!),
                        actions: const [SizedBox.shrink()],
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: page(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
