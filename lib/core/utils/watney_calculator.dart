import '../../models/inventory_item.dart';
import '../../models/alert_item.dart';

/// The Core "Mark Watney" Logistics Risk Engine
/// Implements PRD §3 days-remaining formula:
/// const daysRemaining = currentQuantity / dailyConsumptionRate;
/// if (daysRemaining < daysUntilNextResupply) -> flag as AT RISK
class WatneyCalculator {
  WatneyCalculator._();

  /// Basic days remaining calculation
  static double calculateDaysRemaining(
    double currentQuantity,
    double dailyConsumptionRate,
  ) {
    if (dailyConsumptionRate <= 0 ||
        dailyConsumptionRate.isNaN ||
        dailyConsumptionRate.isInfinite) {
      return 999.0;
    }
    if (currentQuantity <= 0 ||
        currentQuantity.isNaN ||
        currentQuantity.isInfinite) {
      return 0.0;
    }
    final res = currentQuantity / dailyConsumptionRate;
    return (res.isNaN || res.isInfinite) ? 999.0 : res;
  }

  /// Evaluates risk category of an item
  /// Returns: 'nominal', 'warning', or 'critical'
  static String getRiskLevel(InventoryItem item, int daysUntilResupply) {
    final daysRemaining = item.daysRemaining;
    if (daysRemaining <= 0 || item.currentQuantity <= 0) {
      return 'critical';
    }
    if (daysRemaining < daysUntilResupply * 0.4 ||
        item.currentQuantity <= (item.reorderThreshold * 0.5)) {
      return 'critical';
    }
    if (daysRemaining < daysUntilResupply ||
        item.currentQuantity <= item.reorderThreshold) {
      return 'warning';
    }
    return 'nominal';
  }

  /// Calculates safety buffer in days (how many surplus days stock lasts past resupply)
  static double calculateSurplusDeficitDays(
    InventoryItem item,
    int daysUntilResupply,
  ) {
    return item.daysRemaining - daysUntilResupply;
  }

  /// Generates proactive alerts for items exceeding safe thresholds
  static List<AlertItem> generateStockAlerts({
    required List<InventoryItem> items,
    required int daysUntilResupply,
    required String stationId,
  }) {
    final alerts = <AlertItem>[];

    for (final item in items) {
      final risk = getRiskLevel(item, daysUntilResupply);
      final daysRem = item.daysRemaining;

      if (risk == 'critical') {
        alerts.add(
          AlertItem(
            id: 'watney_crit_${item.id}',
            stationId: stationId,
            type: 'low-stock',
            severity: 'critical',
            message:
                'CRITICAL RUNOUT RISK: ${item.name} (${item.currentQuantity.toStringAsFixed(0)} ${item.unit}) projected to exhaust in ${daysRem.toStringAsFixed(0)} days, BEFORE $daysUntilResupply-day resupply window!',
            createdAt: DateTime.now(),
            itemId: item.id,
          ),
        );
      } else if (risk == 'warning') {
        alerts.add(
          AlertItem(
            id: 'watney_warn_${item.id}',
            stationId: stationId,
            type: 'low-stock',
            severity: 'warning',
            message:
                'LOW STOCK PROJECTION: ${item.name} reserve (${daysRem.toStringAsFixed(0)} days) tight against $daysUntilResupply-day next resupply gap.',
            createdAt: DateTime.now(),
            itemId: item.id,
          ),
        );
      }
    }

    return alerts;
  }
}
