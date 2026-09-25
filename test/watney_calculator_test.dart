import 'package:flutter_test/flutter_test.dart';
import 'package:aroha_polar/core/utils/watney_calculator.dart';
import 'package:aroha_polar/models/inventory_item.dart';
import 'package:aroha_polar/services/polar_data_service.dart';

void main() {
  group('Watney Logistics Risk Engine Tests', () {
    test('calculateDaysRemaining calculates correctly', () {
      final days = WatneyCalculator.calculateDaysRemaining(4200.0, 35.0);
      expect(days, equals(120.0));
    });

    test('calculateDaysRemaining handles zero consumption safely', () {
      final days = WatneyCalculator.calculateDaysRemaining(4200.0, 0.0);
      expect(days, equals(999.0));
    });

    test('item is flagged critical when days remaining < resupply gap', () {
      final item = InventoryItem(
        id: 'test_diesel',
        stationId: 'maitri',
        name: 'Diesel Fuel',
        category: 'fuel',
        currentQuantity: 1000.0,
        unit: 'liters',
        dailyConsumptionRate: 50.0, // 20 days remaining
        reorderThreshold: 500.0,
        lastUpdated: DateTime.now(),
      );

      // Next resupply is in 60 days -> 20d remaining is critical risk
      final risk = WatneyCalculator.getRiskLevel(item, 60);
      expect(risk, equals('critical'));

      final alerts = WatneyCalculator.generateStockAlerts(
        items: [item],
        daysUntilResupply: 60,
        stationId: 'maitri',
      );
      expect(alerts.length, equals(1));
      expect(alerts.first.severity, equals('critical'));
    });

    test('PolarDataService initializes with stations and seeds properly', () {
      final service = PolarDataService();
      expect(service.stations.length, equals(3));
      expect(service.inventory.isNotEmpty, isTrue);
      expect(service.personnel.isNotEmpty, isTrue);
      expect(service.resupplyCycles.isNotEmpty, isTrue);
      expect(service.alerts.isNotEmpty, isTrue);

      // Test logging consumption triggers recalculation
      final fuelItem = service.inventory.firstWhere(
        (i) => i.id == 'inv_mtr_diesel',
      );
      service.logConsumption(fuelItem.id, 2000.0);

      // Verify quantity decreased
      final updatedFuel = service.inventory.firstWhere(
        (i) => i.id == 'inv_mtr_diesel',
      );
      expect(updatedFuel.currentQuantity, equals(2200.0));
    });
  });
}
