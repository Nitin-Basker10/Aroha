import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/app_constants.dart';
import '../../models/inventory_item.dart';
import '../../services/polar_data_service.dart';
import '../../services/auth_service.dart';
import '../../core/utils/validators.dart';
import '../widgets/station_selector_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_card.dart';

/// Stitch Screen: Inventory Logistics & Watney Risk Engine
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final station = data.selectedStation;
    final allItems = data.selectedStationInventory;

    // Filter by category and search
    final items = allItems.where((item) {
      final matchesCat =
          _selectedCategory == 'All' ||
          item.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    // Watney Metrics
    final atRiskCount = allItems
        .where((i) => i.isAtRisk(station.daysUntilResupply))
        .length;
    final criticalCount = allItems
        .where((i) => i.isCritical(station.daysUntilResupply))
        .length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Selector Strip
          const StationSelectorBar(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Logistics Telemetry
                Row(
                  children: [
                    Expanded(
                      child: TelemetryCard(
                        label: 'Next Resupply Window',
                        value: '${station.daysUntilResupply}',
                        unit: 'DAYS',
                        subtext: '44-ISEA MV Golovnin',
                        icon: Icons.sailing,
                        accentColor: context.appColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Items At Risk',
                        value: '$atRiskCount',
                        unit: 'CRITICAL',
                        subtext: criticalCount > 0
                            ? '$criticalCount Exhaustion Alarm'
                            : 'Nominal Buffers',
                        icon: Icons.warning_amber_rounded,
                        accentColor: atRiskCount > 0
                            ? context.appColors.critical
                            : context.appColors.nominal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Catalog Items',
                        value: '${allItems.length}',
                        unit: 'ITEMS',
                        subtext: '5 Supply Categories',
                        icon: Icons.inventory_2,
                        accentColor: context.appColors.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Watney Logic Algorithm Explanation Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceLow,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: context.appColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.appColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          Icons.calculate_outlined,
                          color: context.appColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MARK WATNEY RISK PROJECTION ENGINE',
                              style: AppTypography.labelSm.copyWith(
                                color: context.appColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Days-Remaining = (Stock / Daily Burn Rate). When Projected Days < ${station.daysUntilResupply}d Resupply Gap, system triggers an emergency alert.',
                              style: AppTypography.telemetryXs.copyWith(
                                color: context.appColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Search Bar & Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: AppTypography.telemetrySm.copyWith(
                          color: context.appColors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Filter supplies (e.g., diesel, oxygen, rations)...',
                          prefixIcon: Icon(
                            Icons.search,
                            size: 16,
                            color: context.appColors.onSurfaceVariant,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showAddItemDialog(context, data, station.id),
                      icon: Icon(Icons.add, size: 14),
                      label: Text('NEW ITEM'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        textStyle: AppTypography.labelSm,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Category Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AppConstants.inventoryCategories.map((cat) {
                      final isSelected =
                          _selectedCategory.toLowerCase() == cat.toLowerCase();

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            cat.toUpperCase(),
                            style: AppTypography.telemetryXs.copyWith(
                              color: isSelected
                                  ? context.appColors.canvas
                                  : context.appColors.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedCategory = cat);
                          },
                          selectedColor: context.appColors.primary,
                          backgroundColor: context.appColors.surfaceLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                            side: BorderSide(
                              color: isSelected
                                  ? context.appColors.primary
                                  : context.appColors.border,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // Inventory Items List
                Text(
                  'ACTIVE DEPOT INVENTORY (${items.length} ITEMS)',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.2,
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'NO SUPPLIES MATCHING CRITERIA',
                        style: AppTypography.telemetrySm.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...items.map((item) {
                    final daysRemaining = item.daysRemaining;
                    final isAtRisk = item.isAtRisk(station.daysUntilResupply);
                    final isCritical = item.isCritical(
                      station.daysUntilResupply,
                    );
                    final surplusDays =
                        daysRemaining - station.daysUntilResupply;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isCritical
                            ? context.appColors.errorContainer.withValues(
                                alpha: 0.2,
                              )
                            : isAtRisk
                            ? context.appColors.warningContainer.withValues(
                                alpha: 0.15,
                              )
                            : context.appColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCritical
                              ? context.appColors.critical.withValues(
                                  alpha: 0.6,
                                )
                              : isAtRisk
                              ? context.appColors.warning.withValues(alpha: 0.5)
                              : context.appColors.border,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.category.toUpperCase()} // ${item.storageLocation.toUpperCase()}',
                                      style: AppTypography.telemetryXs.copyWith(
                                        color:
                                            context.appColors.onSurfaceVariant,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.name,
                                      style: AppTypography.titleSm.copyWith(
                                        color: context.appColors.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                status: isCritical
                                    ? 'critical'
                                    : isAtRisk
                                    ? 'warning'
                                    : 'nominal',
                                customLabel: isCritical
                                    ? 'CRITICAL DEFICIT'
                                    : isAtRisk
                                    ? 'AT RISK'
                                    : 'NOMINAL',
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Metrics Grid
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.appColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              children: [
                                _buildItemStat(
                                  'CURRENT RESERVE',
                                  '${item.currentQuantity.toStringAsFixed(0)} ${item.unit}',
                                  context.appColors.onSurface,
                                ),
                                _buildItemStat(
                                  'BURN RATE',
                                  '${item.dailyConsumptionRate.toStringAsFixed(1)} ${item.unit}/day',
                                  context.appColors.onSurfaceVariant,
                                ),
                                _buildItemStat(
                                  'PROJECTED RUNOUT',
                                  '${daysRemaining.toStringAsFixed(0)} DAYS',
                                  isCritical
                                      ? context.appColors.critical
                                      : isAtRisk
                                      ? context.appColors.warning
                                      : context.appColors.nominal,
                                ),
                                _buildItemStat(
                                  'RESUPPLY GAP',
                                  '${surplusDays >= 0 ? '+' : ''}${surplusDays.toStringAsFixed(0)}d BUFFER',
                                  surplusDays >= 0
                                      ? context.appColors.nominal
                                      : context.appColors.critical,
                                ),
                              ],
                            ),
                          ),

                          if (item.notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'NOTE: ${item.notes}',
                              style: AppTypography.telemetryXs.copyWith(
                                color: context.appColors.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),

                          // Actions Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showLogUsageDialog(context, data, item),
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  size: 13,
                                ),
                                label: Text('LOG CONSUMPTION'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  textStyle: AppTypography.labelSm,
                                ),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showEditItemDialog(context, data, item),
                                icon: Icon(Icons.edit_outlined, size: 13),
                                label: Text('CALIBRATE'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  textStyle: AppTypography.labelSm,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.telemetryXs.copyWith(
              fontSize: 8.5,
              color: context.appColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.telemetrySm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showLogUsageDialog(
    BuildContext context,
    PolarDataService data,
    InventoryItem item,
  ) {
    final qtyController = TextEditingController(
      text: '${item.dailyConsumptionRate}',
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: context.appColors.surfaceHigh,
              title: Text(
                'LOG SUPPLY CONSUMPTION',
                style: AppTypography.titleMd.copyWith(letterSpacing: 1),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item: ${item.name}',
                    style: AppTypography.bodyMd.copyWith(
                      color: context.appColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Current Reserve: ${item.currentQuantity} ${item.unit}',
                    style: AppTypography.telemetrySm.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'QUANTITY CONSUMED (${item.unit.toUpperCase()})',
                    style: AppTypography.labelSm,
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    style: AppTypography.telemetrySm.copyWith(
                      color: context.appColors.onSurface,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.remove,
                        size: 16,
                        color: context.appColors.primary,
                      ),
                      errorText: errorText,
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDlgState(() => errorText = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final consumed = double.tryParse(qtyController.text);
                    final err = Validators.validateConsumption(
                      consumed,
                      item.currentQuantity,
                    );
                    if (err != null) {
                      setDlgState(() => errorText = err);
                      return;
                    }
                    final auth = context.read<AuthService>();
                    data.logConsumption(
                      item.id,
                      consumed!,
                      user: auth.currentUser,
                    );
                    Navigator.of(ctx).pop();
                  },
                  child: Text('CONFIRM LOG'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddItemDialog(
    BuildContext context,
    PolarDataService data,
    String stationId,
  ) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'liters');
    final burnCtrl = TextEditingController(text: '10');
    final threshCtrl = TextEditingController(text: '500');
    final locCtrl = TextEditingController(text: 'Primary Depot');
    String cat = 'fuel';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: context.appColors.surfaceHigh,
              title: Text(
                'REGISTER NEW SUPPLY ITEM',
                style: AppTypography.titleMd,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Item Name (e.g. Polar Kerosene)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: cat,
                      dropdownColor: context.appColors.surfaceHigh,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items:
                          [
                            'fuel',
                            'food',
                            'medical',
                            'spare-parts',
                            'equipment',
                          ].map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c.toUpperCase()),
                            );
                          }).toList(),
                      onChanged: (v) => setDlgState(() => cat = v ?? 'fuel'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Initial Quantity',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Unit (liters, kg, kits)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: burnCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Daily Burn Rate',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: threshCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reorder Threshold',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Storage Location',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nameErr = Validators.validateRequired(
                      nameCtrl.text,
                      'Item name',
                    );
                    final qtyErr = Validators.validatePositiveNumber(
                      qtyCtrl.text,
                      'Quantity',
                    );
                    final burnErr = Validators.validatePositiveNumber(
                      burnCtrl.text,
                      'Burn rate',
                    );
                    final threshErr = Validators.validatePositiveNumber(
                      threshCtrl.text,
                      'Threshold',
                    );
                    final err = nameErr ?? qtyErr ?? burnErr ?? threshErr;
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err),
                          backgroundColor: context.appColors.critical,
                        ),
                      );
                      return;
                    }
                    final item = InventoryItem(
                      id: const Uuid().v4(),
                      stationId: stationId,
                      name: nameCtrl.text.trim(),
                      category: cat,
                      currentQuantity: double.parse(qtyCtrl.text.trim()),
                      unit: unitCtrl.text.trim().isEmpty
                          ? 'units'
                          : unitCtrl.text.trim(),
                      dailyConsumptionRate: double.parse(burnCtrl.text.trim()),
                      reorderThreshold: double.parse(threshCtrl.text.trim()),
                      lastUpdated: DateTime.now(),
                      storageLocation: locCtrl.text.trim().isEmpty
                          ? 'Primary Depot'
                          : locCtrl.text.trim(),
                    );
                    final auth = context.read<AuthService>();
                    final ok = data.addInventoryItem(
                      item,
                      user: auth.currentUser,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Permission denied or duplicate ID'),
                          backgroundColor: context.appColors.critical,
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: Text('SAVE ITEM'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditItemDialog(
    BuildContext context,
    PolarDataService data,
    InventoryItem item,
  ) {
    final burnCtrl = TextEditingController(
      text: '${item.dailyConsumptionRate}',
    );
    final threshCtrl = TextEditingController(text: '${item.reorderThreshold}');
    final qtyCtrl = TextEditingController(text: '${item.currentQuantity}');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.appColors.surfaceHigh,
          title: Text(
            'CALIBRATE WATNEY PARAMETERS',
            style: AppTypography.titleMd,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: AppTypography.titleSm.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Current Reserve (${item.unit})',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: burnCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Daily Burn Rate (${item.unit}/day)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: threshCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Reorder Safety Threshold (${item.unit})',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final auth = context.read<AuthService>();
                data.deleteInventoryItem(item.id, user: auth.currentUser);
                Navigator.of(ctx).pop();
              },
              child: Text(
                'DELETE',
                style: TextStyle(color: context.appColors.critical),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text);
                final burn = double.tryParse(burnCtrl.text);
                final thresh = double.tryParse(threshCtrl.text);
                if (qty == null ||
                    qty < 0 ||
                    burn == null ||
                    burn < 0 ||
                    thresh == null ||
                    thresh < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Values must be valid non-negative numbers',
                      ),
                      backgroundColor: context.appColors.critical,
                    ),
                  );
                  return;
                }
                final updated = item.copyWith(
                  currentQuantity: qty,
                  dailyConsumptionRate: burn,
                  reorderThreshold: thresh,
                  lastUpdated: DateTime.now(),
                );
                final auth = context.read<AuthService>();
                data.updateInventoryItem(updated, user: auth.currentUser);
                Navigator.of(ctx).pop();
              },
              child: Text('APPLY'),
            ),
          ],
        );
      },
    );
  }
}
