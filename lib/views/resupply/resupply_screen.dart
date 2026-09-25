import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/cargo_item.dart';
import '../../services/polar_data_service.dart';
import '../../services/auth_service.dart';
import '../widgets/station_selector_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_card.dart';

/// Stitch Screen: Resupply Planning & Cargo Manifest
class ResupplyScreen extends StatelessWidget {
  const ResupplyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final auth = context.watch<AuthService>();
    final station = data.selectedStation;
    final cycles = data.resupplyCycles
        .where((c) => c.stationId == station.id)
        .toList();
    final canEdit = auth.currentUser?.canEditStation(station.id) ?? false;

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
                // Resupply Voyage Telemetry
                Row(
                  children: [
                    Expanded(
                      child: TelemetryCard(
                        label: 'Voyage ETA',
                        value: '${station.daysUntilResupply}',
                        unit: 'DAYS',
                        subtext: '44-ISEA Vessel Schedule',
                        icon: Icons.sailing,
                        accentColor: context.appColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Scheduled Voyages',
                        value: '${cycles.length}',
                        unit: 'EXPEDITIONS',
                        subtext: 'Icebreaker & Airlift',
                        icon: Icons.route_outlined,
                        accentColor: context.appColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Total Manifest Payload',
                        value: cycles.isNotEmpty
                            ? (cycles.first.totalPayloadWeightKg / 1000)
                                  .toStringAsFixed(1)
                            : '0',
                        unit: 'TONS',
                        subtext: 'Gross Manifest Weight',
                        icon: Icons.scale_outlined,
                        accentColor: context.appColors.nominal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Resupply Cycles List
                Text(
                  'ACTIVE EXPEDITION RESUPPLY CYCLES',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.2,
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                if (cycles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'NO RESUPPLY VOYAGES SCHEDULED FOR THIS OUTPOST',
                        style: AppTypography.telemetrySm.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...cycles.map((cycle) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: context.appColors.border),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cycle.expeditionCode.toUpperCase(),
                                    style: AppTypography.telemetryXs.copyWith(
                                      color: context.appColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cycle.vesselName,
                                    style: AppTypography.titleSm.copyWith(
                                      color: context.appColors.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              StatusBadge(status: cycle.status),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Route Details
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.appColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'DEPARTURE PORT',
                                        style: AppTypography.telemetryXs
                                            .copyWith(
                                              color: context
                                                  .appColors
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      Text(
                                        cycle.departurePort,
                                        style: AppTypography.telemetrySm
                                            .copyWith(
                                              color:
                                                  context.appColors.onSurface,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: context.appColors.border,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'DESTINATION ETA',
                                        style: AppTypography.telemetryXs
                                            .copyWith(
                                              color: context
                                                  .appColors
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      Text(
                                        '${cycle.daysUntilArrival} Days (${cycle.scheduledDate.day}/${cycle.scheduledDate.month}/${cycle.scheduledDate.year})',
                                        style: AppTypography.telemetrySm
                                            .copyWith(
                                              color: context.appColors.nominal,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Cargo Manifest Sub-section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CARGO MANIFEST ITEMS (${cycle.cargoItems.length})',
                                style: AppTypography.labelSm.copyWith(
                                  color: context.appColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${cycle.packedItemsCount}/${cycle.cargoItems.length} PACKED / SHIPPED',
                                style: AppTypography.telemetryXs.copyWith(
                                  color: context.appColors.nominal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          ...cycle.cargoItems.map((cargo) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: context.appColors.surfaceLow,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: context.appColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cargo.itemName,
                                          style: AppTypography.bodyMd.copyWith(
                                            color: context.appColors.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${cargo.quantity} ${cargo.unit} • ${cargo.weightKg} kg • ${cargo.recipientSection}',
                                          style: AppTypography.telemetryXs
                                              .copyWith(
                                                color: context
                                                    .appColors
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    enabled: canEdit,
                                    onSelected: (newStatus) {
                                      data.updateCargoStatus(
                                        cycle.id,
                                        cargo.id,
                                        newStatus,
                                        user: auth.currentUser,
                                      );
                                    },
                                    color: context.appColors.surfaceHigh,
                                    child: StatusBadge(status: cargo.status),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'pending',
                                        child: Text('Pending'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'packed',
                                        child: Text('Packed'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'shipped',
                                        child: Text('Shipped'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delivered',
                                        child: Text('Delivered'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 8),

                          // Add Cargo button
                          if (canEdit)
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => _showAddCargoDialog(
                                  context,
                                  data,
                                  cycle.id,
                                ),
                                icon: Icon(Icons.add, size: 14),
                                label: Text('ADD MANIFEST PAYLOAD'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  textStyle: AppTypography.labelSm,
                                ),
                              ),
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

  void _showAddCargoDialog(
    BuildContext context,
    PolarDataService data,
    String cycleId,
  ) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '10');
    final unitCtrl = TextEditingController(text: 'units');
    final weightCtrl = TextEditingController(text: '150');
    final sectionCtrl = TextEditingController(text: 'Logistics Command');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.appColors.surfaceHigh,
          title: Text(
            'ADD ITEM TO CARGO MANIFEST',
            style: AppTypography.titleMd,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cargo Item Name',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sectionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Outpost Section',
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
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cargo item name is required'),
                      backgroundColor: context.appColors.critical,
                    ),
                  );
                  return;
                }
                final cargo = CargoItem(
                  id: const Uuid().v4(),
                  cycleId: cycleId,
                  itemName: nameCtrl.text.trim(),
                  category: 'spare-parts',
                  quantity: double.tryParse(qtyCtrl.text) ?? 1,
                  unit: unitCtrl.text.trim().isEmpty
                      ? 'units'
                      : unitCtrl.text.trim(),
                  weightKg: double.tryParse(weightCtrl.text) ?? 50,
                  status: 'packed',
                  recipientSection: sectionCtrl.text.trim().isEmpty
                      ? 'General Logistics'
                      : sectionCtrl.text.trim(),
                );
                final auth = context.read<AuthService>();
                final ok = data.addCargoItem(
                  cycleId,
                  cargo,
                  user: auth.currentUser,
                );
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Permission denied or duplicate cargo'),
                      backgroundColor: context.appColors.critical,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
              },
              child: Text('ADD TO VOYAGE'),
            ),
          ],
        );
      },
    );
  }
}
