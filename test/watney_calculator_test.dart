import 'package:flutter_test/flutter_test.dart';
import 'package:aroha_polar/core/utils/watney_calculator.dart';
import 'package:aroha_polar/models/comms_message.dart';
import 'package:aroha_polar/models/inventory_item.dart';
import 'package:aroha_polar/models/resource_request.dart';
import 'package:aroha_polar/models/user_role.dart';
import 'package:aroha_polar/services/polar_data_service.dart';

const _maitriStaff = UserProfile(
  uid: 'staff_mtr_01',
  name: 'Dr. Aarav Sharma',
  role: UserRole.stationStaff,
  email: 'aarav.sharma@maitri.ncpor.gov.in',
  linkedStationId: 'maitri',
  linkedPersonId: 'per_mtr_01',
);

const _bharatiStaff = UserProfile(
  uid: 'staff_bhr_01',
  name: 'Dr. Sunita Deshmukh',
  role: UserRole.stationStaff,
  email: 'sunita.deshmukh@bharati.ncpor.gov.in',
  linkedStationId: 'bharati',
  linkedPersonId: 'per_bhr_01',
);

const _family = UserProfile(
  uid: 'fam_demo_01',
  name: 'Priya Sharma',
  role: UserRole.familyMember,
  email: '',
  linkedStationId: 'maitri',
  linkedPersonId: 'per_mtr_01',
);

CommsMessage _message() => CommsMessage(
  id: 'msg_probe',
  senderId: 'probe',
  senderName: 'Probe',
  senderStation: 'Maitri Station',
  recipientId: 'ops',
  recipientName: 'Ops',
  content: 'probe',
  priority: 'routine',
  sentAt: DateTime.now(),
  stationId: 'maitri',
);

ResourceRequest _request({String fromStationId = 'bharati'}) => ResourceRequest(
  id: 'rr_probe',
  fromStationId: fromStationId,
  fromStationName: 'Bharati Station',
  toStationId: 'maitri',
  toStationName: 'Maitri Station',
  requestedItem: 'Probe',
  requestedQuantity: 1,
  unit: 'units',
  urgency: 'routine',
  status: 'pending',
  requestedByUserId: 'probe',
  requestedByName: 'Probe',
  createdAt: DateTime.now(),
);

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

      // Test logging consumption triggers recalculation.
      // Consumption is an attributed operator action, so it now requires a
      // session with edit rights on the owning station.
      final fuelItem = service.inventory.firstWhere(
        (i) => i.id == 'inv_mtr_diesel',
      );
      expect(service.logConsumption(fuelItem.id, 2000.0), isFalse);
      expect(
        service.logConsumption(fuelItem.id, 2000.0, user: _maitriStaff),
        isTrue,
      );

      // Verify quantity decreased
      final updatedFuel = service.inventory.firstWhere(
        (i) => i.id == 'inv_mtr_diesel',
      );
      expect(updatedFuel.currentQuantity, equals(2200.0));
    });

    test('mutations without an attributed session are refused', () {
      final service = PolarDataService();
      final fuel = service.inventory.firstWhere(
        (i) => i.id == 'inv_mtr_diesel',
      );
      final before = fuel.currentQuantity;

      // Null user: previously a silent bypass of the station check.
      expect(service.logConsumption(fuel.id, 10), isFalse);
      // A user with rights on a *different* station.
      expect(service.logConsumption(fuel.id, 10, user: _bharatiStaff), isFalse);
      // A family session can never mutate station stock.
      expect(service.logConsumption(fuel.id, 10, user: _family), isFalse);
      // sendMessage is void-returning; assert on the effect instead.
      final messageCount = service.messages.length;
      service.sendMessage(_message(), user: null);
      service.sendMessage(_message(), user: _family);
      expect(service.messages.length, equals(messageCount));
      service.sendMessage(_message(), user: _maitriStaff);
      expect(service.messages.length, equals(messageCount + 1));
      // A resource request raised "for" a station the session cannot edit.
      expect(
        service.createResourceRequest(
          _request(fromStationId: 'himadri'),
          user: _bharatiStaff,
        ),
        isFalse,
      );
      expect(service.createResourceRequest(_request()), isFalse);
      // The same request from the station it actually belongs to is allowed.
      expect(
        service.createResourceRequest(
          _request(fromStationId: 'bharati'),
          user: _bharatiStaff,
        ),
        isTrue,
      );

      final after = service.inventory
          .firstWhere((i) => i.id == fuel.id)
          .currentQuantity;
      expect(after, equals(before));
    });
  });
}
