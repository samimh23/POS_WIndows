import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/pos_controller.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/pos_widgets.dart';

class TablesScreen extends ConsumerStatefulWidget {
  const TablesScreen({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;
  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  String? area;
  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(posProvider);
    final d = pos.data;
    final selected = d.areas.contains(area) ? area! : d.settings.defaultArea;
    final visibleAreas =
        d.settings.zoneMode == 'Assigned' ? [d.settings.defaultArea] : d.areas;
    final activeArea =
        visibleAreas.contains(selected) ? selected : visibleAreas.first;
    final tables = d.tables.where((t) => t.area == activeArea).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Table service',
          'Choose a table to start or continue its shared bill.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            StatusPill('Available', Color(0xFF147D70)),
            StatusPill('Occupied', Color(0xFFAF7719)),
            StatusPill('Payment pending', Color(0xFF6857BB)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final a in visibleAreas)
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    '$a · ${d.tables.where((t) => t.area == a).length}',
                  ),
                ),
                selected: activeArea == a,
                onSelected: (_) => setState(() => area = a),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Expanded(
          child:
              tables.isEmpty
                  ? const Center(
                    child: EmptyState(
                      'No tables in this area. Add tables in Settings.',
                      icon: Icons.table_restaurant_outlined,
                    ),
                  )
                  : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 245,
                          mainAxisExtent: 196,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: tables.length,
                    itemBuilder: (c, i) {
                      final t = tables[i];
                      final b = d.tableBill(t.id);
                      final color =
                          b == null
                              ? const Color(0xFF147D70)
                              : b.status == 'pending'
                              ? const Color(0xFF6857BB)
                              : const Color(0xFFAF7719);
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap:
                              pos.busy
                                  ? null
                                  : () async {
                                    final id = await perform(
                                      context,
                                      () => pos.openTable(t.id),
                                    );
                                    if (id != null) {
                                      widget.onOpen(id);
                                    }
                                  },
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.table_restaurant_outlined,
                                      color: color,
                                      size: 30,
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.north_east,
                                      size: 18,
                                      color: color,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t.name,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                StatusPill(
                                  b == null
                                      ? 'Available'
                                      : b.status == 'pending'
                                      ? 'Payment pending'
                                      : 'Occupied',
                                  color,
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        b == null
                                            ? 'Tap to open'
                                            : money(b.total),
                                        style: TextStyle(
                                          fontWeight:
                                              b == null
                                                  ? FontWeight.w400
                                                  : FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (b != null)
                                      Text(
                                        '${DateTime.now().difference(b.openedAt).inMinutes} min',
                                        style: Theme.of(c).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
