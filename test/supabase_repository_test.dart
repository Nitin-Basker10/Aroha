import 'package:flutter_test/flutter_test.dart';
import 'package:aroha_polar/models/station.dart';
import 'package:aroha_polar/models/inventory_item.dart';
import 'package:aroha_polar/models/call_booking.dart';
import 'package:aroha_polar/models/family_invite.dart';
import 'package:aroha_polar/services/supabase_repository.dart';

void main() {
  group('Supabase row mappers', () {
    test('station round-trips through row format', () {
      final station = Station(
        id: 'maitri',
        name: 'Maitri Station',
        code: 'MTR-01',
        location: 'Schirmacher Oasis',
        coordinates: '70°S 11°E',
        status: 'active',
        lastContact: DateTime.utc(2026, 1, 5, 12),
        powerLevel: 88,
        temperature: -24.8,
        windSpeed: 22.4,
        satLinkSignal: 99.8,
        sectorLiveCamUrl: '',
        activePersonnelCount: 24,
        nextResupplyDate: DateTime.utc(2026, 5, 1),
      );
      final row = stationToRow(station);
      expect(row['station_id'], isNull); // id is top-level, not in toFirestore
      expect(row['id'], equals('maitri'));
      expect(row['power_level'], equals(88));
      expect(row['next_resupply_date'], contains('2026-05-01'));
      final back = stationFromRow(row);
      expect(back.id, equals('maitri'));
      expect(back.powerLevel, equals(88));
      expect(back.temperature, equals(-24.8));
    });

    test('inventory row maps quantities and burn rate', () {
      final item = InventoryItem(
        id: 'inv_x',
        stationId: 'maitri',
        name: 'Diesel',
        category: 'fuel',
        currentQuantity: 4200,
        unit: 'liters',
        dailyConsumptionRate: 48,
        reorderThreshold: 2000,
        lastUpdated: DateTime.utc(2026, 1, 5),
      );
      final row = inventoryToRow(item);
      expect(row['current_quantity'], equals(4200.0));
      expect(row['daily_consumption_rate'], equals(48.0));
      final back = inventoryFromRow(row);
      expect(back.daysRemaining, closeTo(87.5, 0.01));
      expect(back.isAtRisk(114), isTrue);
    });

    test('booking row carries compliance columns', () {
      final booking = CallBooking(
        id: 'call_01',
        stationId: 'maitri',
        personId: 'per_mtr_01',
        personName: 'Dr. Aarav Sharma',
        familyContactName: 'Priya Sharma (Spouse)',
        scheduledSlot: DateTime.utc(2026, 2, 1, 10),
        durationMinutes: 20,
        status: 'booked',
        channelType: 'low-res-video',
        familyConsentGiven: true,
        briefingAcked: true,
        inviteCode: 'MTR-2026',
        crewDisclaimerSigned: true,
        crewDisclaimerBy: 'Dr. Aarav Sharma',
        crewDisclaimerAt: DateTime.utc(2026, 1, 20),
      );
      final row = bookingToRow(booking);
      expect(row['family_consent_given'], isTrue);
      expect(row['crew_disclaimer_by'], equals('Dr. Aarav Sharma'));
      final back = bookingFromRow(row);
      expect(back.familyConsentGiven, isTrue);
      expect(back.crewDisclaimerSigned, isTrue);
      expect(back.inviteCode, equals('MTR-2026'));
    });

    test('booking row tolerates null compliance columns', () {
      final back = bookingFromRow({
        'id': 'b1',
        'station_id': 'maitri',
        'person_id': 'p1',
        'person_name': 'Crew',
        'family_contact_name': 'Family',
        'scheduled_slot': '2026-02-01T10:00:00.000Z',
        'duration_minutes': 15,
        'status': 'booked',
        'channel_type': 'satellite-voice',
        'family_consent_given': false,
        'briefing_acked': false,
        'recording_ref': null,
        'invite_code': null,
        'crew_disclaimer_signed': false,
        'crew_disclaimer_by': null,
        'crew_disclaimer_at': null,
      });
      expect(back.recordingRef, isNull);
      expect(back.crewDisclaimerAt, isNull);
    });

    test('invite row maps disclaimer audit fields', () {
      final invite = FamilyInvite(
        id: 'fam_1',
        inviteCode: 'MTR-AB12',
        bookingId: 'call_01',
        stationId: 'maitri',
        personId: 'per_mtr_01',
        personName: 'Dr. Aarav Sharma',
        familyContactName: 'Priya Sharma (Spouse)',
        createdByUserId: 'hq_admin_01',
        createdByName: 'Cmdr. Nitin Verma',
        createdAt: DateTime.utc(2026, 1, 10),
        disclaimerAccepted: true,
        disclaimerSignedName: 'Priya Sharma',
        disclaimerSignedAt: DateTime.utc(2026, 1, 11),
      );
      final row = inviteToRow(invite);
      expect(row['disclaimer_accepted'], isTrue);
      expect(row['disclaimer_signed_name'], equals('Priya Sharma'));
      final back = inviteFromRow(row);
      expect(back.disclaimerAccepted, isTrue);
      expect(back.inviteCode, equals('MTR-AB12'));
    });
  });
}
