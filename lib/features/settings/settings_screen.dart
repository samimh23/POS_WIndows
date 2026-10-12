import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/pos_controller.dart';
import '../../core/utils/money.dart';
import '../../models/pos_data.dart';
import '../../shared/widgets/pos_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String tab = 'Business';
  Future<void> change(
    PosController pos,
    void Function(PosSettings) update,
  ) async {
    final s = PosSettings.fromJson(pos.data.settings.toJson());
    update(s);
    await pos.settings(s);
  }

  Widget section(String title, List<Widget> children, {Widget? action}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
  Future<void> editProduct(PosController pos, Product? p) => editDialog(
    context,
    p == null ? 'Add product' : 'Edit product',
    [
      FieldSpec('name', 'Product name', p?.name ?? ''),
      FieldSpec(
        'category',
        'Category',
        p?.category ?? pos.data.categories.first,
        options: pos.data.categories,
      ),
      FieldSpec(
        'price',
        'Price (DT)',
        p == null ? '' : moneyInput(p.price),
        numeric: true,
      ),
      FieldSpec(
        'enabled',
        'Availability',
        p?.enabled == false ? 'Disabled' : 'Enabled',
        options: ['Enabled', 'Disabled'],
      ),
    ],
    (v) => pos.saveProduct(
      p?.id,
      v['name']!,
      v['category']!,
      parseMoney(v['price']!),
      v['enabled'] == 'Enabled',
    ),
    help: 'Existing bill lines keep their original names and prices.',
  );
  Future<void> editTable(PosController pos, CafeTable? t) => editDialog(
    context,
    t == null ? 'Add table' : 'Edit table',
    [
      FieldSpec('name', 'Table name', t?.name ?? ''),
      FieldSpec(
        'area',
        'Area',
        t?.area ?? pos.data.settings.defaultArea,
        options: pos.data.areas,
      ),
    ],
    (v) => pos.saveTable(t?.id, v['name']!, v['area']!),
  );
  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(posProvider);
    final d = pos.data;
    final s = d.settings;
    final panels = <Widget>[];
    if (tab == 'Business') {
      panels.add(
        section(
          'Business profile',
          [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.cafe),
              subtitle: Text(
                s.businessInfo.isEmpty
                    ? 'No additional business information'
                    : s.businessInfo,
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Currency'),
              subtitle: Text('TND · Tunisian dinar · 3 decimal places'),
            ),
            const Divider(),
            const Text(
              'Local Windows prototype. Payments are simulated. This application is not a production-certified fiscal cash register.',
            ),
          ],
          action: OutlinedButton.icon(
            onPressed:
                () => editDialog(
                  context,
                  'Business profile',
                  [
                    FieldSpec('name', 'Café name', s.cafe),
                    FieldSpec(
                      'info',
                      'Business information',
                      s.businessInfo,
                      required: false,
                    ),
                  ],
                  (v) => change(pos, (s) {
                    s.cafe = v['name']!.trim();
                    s.businessInfo = v['info']!.trim();
                  }),
                ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ),
      );
    }
    if (tab == 'POS') {
      panels.add(
        section('Station & zones', [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.station),
            subtitle: Text(
              'Default area: ${s.defaultArea} · ${s.zoneMode} zones',
            ),
          ),
          const Text(
            'Shared mode shows all areas. Assigned mode shows this station’s default area in Tables. Orders remain accessible from Orders / Bills.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed:
                () => editDialog(
                  context,
                  'Station configuration',
                  [
                    FieldSpec('name', 'Station name', s.station),
                    FieldSpec(
                      'area',
                      'Default table area',
                      s.defaultArea,
                      options: d.areas,
                    ),
                    FieldSpec(
                      'zone',
                      'Zone mode',
                      s.zoneMode,
                      options: ['Shared', 'Assigned'],
                    ),
                  ],
                  (v) => change(pos, (s) {
                    s.station = v['name']!.trim();
                    s.defaultArea = v['area']!;
                    s.zoneMode = v['zone']!;
                  }),
                ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit station'),
          ),
        ]),
      );
    }
    if (tab == 'Tables') {
      panels.add(
        section('Bill behavior', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Multiple bills per table · Coming later'),
            subtitle: const Text(
              'Preference is saved for a future release. This version always uses one shared bill; splitting is unavailable.',
            ),
            value: s.multipleBills,
            onChanged:
                pos.busy
                    ? null
                    : (v) => perform(
                      context,
                      () => change(pos, (s) => s.multipleBills = v),
                    ),
          ),
        ]),
      );
      panels.add(
        section(
          'Areas',
          [
            for (final a in d.areas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.layers_outlined),
                title: Text(a),
                subtitle: Text(
                  '${d.tables.where((t) => t.area == a).length} tables',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Rename $a',
                      onPressed:
                          () => editDialog(context, 'Rename area', [
                            FieldSpec('name', 'Area name', a),
                          ], (v) => pos.saveArea(a, v['name']!)),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove $a',
                      onPressed: () async {
                        if (await confirmDialog(
                          context,
                          'Remove $a?',
                          'Only an empty area can be removed.',
                        )) {
                          if (context.mounted) {
                            await perform(context, () => pos.removeArea(a));
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
          action: OutlinedButton.icon(
            onPressed:
                () => editDialog(context, 'Add area', [
                  FieldSpec('name', 'Area name', ''),
                ], (v) => pos.saveArea(null, v['name']!)),
            icon: const Icon(Icons.add),
            label: const Text('Add area'),
          ),
        ),
      );
      panels.add(
        section(
          'Tables',
          [
            if (d.tables.isEmpty)
              const EmptyState('No tables. Add one to begin.'),
            for (final t in d.tables)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.table_restaurant_outlined),
                title: Text(t.name),
                subtitle: Text(
                  '${t.area}${d.tableBill(t.id) == null ? '' : ' · Active order'}',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Edit ${t.name}',
                      onPressed:
                          d.tableBill(t.id) != null
                              ? null
                              : () => editTable(pos, t),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove ${t.name}',
                      onPressed:
                          d.tableBill(t.id) != null
                              ? null
                              : () async {
                                if (await confirmDialog(
                                  context,
                                  'Remove ${t.name}?',
                                  'The table will be removed from its area.',
                                )) {
                                  if (context.mounted) {
                                    await perform(
                                      context,
                                      () => pos.removeTable(t.id),
                                    );
                                  }
                                }
                              },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
          action: OutlinedButton.icon(
            onPressed: () => editTable(pos, null),
            icon: const Icon(Icons.add),
            label: const Text('Add table'),
          ),
        ),
      );
    }
    if (tab == 'Products') {
      panels.add(
        section(
          'Categories',
          [
            for (final cat in d.categories)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(cat),
                subtitle: Text(
                  '${d.products.where((p) => p.category == cat).length} products',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Rename $cat',
                      onPressed:
                          () => editDialog(
                            context,
                            'Rename category',
                            [FieldSpec('name', 'Category name', cat)],
                            (v) => pos.saveCategory(cat, v['name']!),
                          ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove $cat',
                      onPressed: () async {
                        if (await confirmDialog(
                          context,
                          'Remove $cat?',
                          'Move all products to another category first.',
                        )) {
                          if (context.mounted) {
                            await perform(
                              context,
                              () => pos.removeCategory(cat),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
          action: OutlinedButton.icon(
            onPressed:
                () => editDialog(context, 'Add category', [
                  FieldSpec('name', 'Category name', ''),
                ], (v) => pos.saveCategory(null, v['name']!)),
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          ),
        ),
      );
      panels.add(
        section(
          'Product catalog',
          [
            for (final p in d.products)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(p.enabled ? Icons.restaurant_menu : Icons.block),
                title: Text(p.name),
                subtitle: Text(
                  '${p.category} · ${money(p.price)} · ${p.enabled ? 'Enabled' : 'Disabled'}',
                ),
                trailing: IconButton(
                  tooltip: 'Edit ${p.name}',
                  onPressed: () => editProduct(pos, p),
                  icon: const Icon(Icons.edit_outlined),
                ),
                onTap: () => editProduct(pos, p),
              ),
          ],
          action: FilledButton.icon(
            onPressed: () => editProduct(pos, null),
            icon: const Icon(Icons.add),
            label: const Text('Add product'),
          ),
        ),
      );
    }
    if (tab == 'Loyalty') {
      panels.add(
        section('Demo loyalty', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable loyalty points'),
            subtitle: const Text(
              'Every 1.000 DT of final paid spending earns 1 point. Rounded down per sale. Only purchases with a selected customer are eligible.',
            ),
            value: s.loyalty,
            onChanged:
                pos.busy
                    ? null
                    : (v) => perform(
                      context,
                      () => change(pos, (s) => s.loyalty = v),
                    ),
          ),
          const Divider(),
          const Text(
            'Existing points are preserved when earning is disabled. No redemption, rewards, SMS, or authentication in this version.',
          ),
        ]),
      );
    }
    if (tab == 'Appearance') {
      panels.add(
        section('Appearance', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark mode'),
            subtitle: const Text('Saved locally for the next launch.'),
            value: s.dark,
            onChanged:
                pos.busy
                    ? null
                    : (v) =>
                        perform(context, () => change(pos, (s) => s.dark = v)),
          ),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Settings',
          'Manage your café, station, and local catalog.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in [
              'Business',
              'POS',
              'Tables',
              'Products',
              'Loyalty',
              'Appearance',
            ])
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: Text(t),
                ),
                selected: tab == t,
                onSelected: (_) => setState(() => tab = t),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: panels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 18),
            itemBuilder: (_, i) => panels[i],
          ),
        ),
      ],
    );
  }
}
