import 'package:flutter_test/flutter_test.dart';
import 'package:aroha_polar/models/call_booking.dart';
import 'package:aroha_polar/models/family_invite.dart';
import 'package:aroha_polar/models/user_role.dart';
import 'package:aroha_polar/services/auth_service.dart';
import 'package:aroha_polar/services/polar_data_service.dart';

UserProfile _hq() => const UserProfile(
  uid: 'hq_admin_01',
  name: 'Cmdr. Nitin Verma',
  role: UserRole.hqAdmin,
  email: 'nitin.verma@ncpor.res.in',
);

UserProfile _familyFor(FamilyInvite invite) => UserProfile(
  uid: 'fam_${invite.id}',
  name: invite.familyContactName,
  role: UserRole.familyMember,
  email: '',
  linkedStationId: invite.stationId,
  linkedPersonId: invite.personId,
);

void main() {
  group('Family invite + consent flow', () {
    test('HQ can create invite for a booking, code is linked', () {
      final data = PolarDataService();
      final invite = data.createFamilyInvite(
        bookingId: 'call_01',
        createdBy: _hq(),
      );
      // call_01 already has the seeded demo invite
      expect(invite, isNotNull);
      expect(invite!.bookingId, equals('call_01'));
      expect(
        data.getBookingById('call_01')?.inviteCode,
        equals(invite.inviteCode),
      );
    });

    test('invite code resolves case-insensitively', () {
      final data = PolarDataService();
      expect(data.getInviteByCode('mtr-2026')?.bookingId, equals('call_01'));
      expect(
        data.getInviteByCode('  MTR-2026  ')?.bookingId,
        equals('call_01'),
      );
      expect(data.getInviteByCode('WRONG-CODE'), isNull);
      expect(data.getInviteByCode(''), isNull);
    });

    test('family session profile carries no operational permissions', () {
      final data = PolarDataService();
      final invite = data.getInviteByCode('MTR-2026')!;
      final profile = UserProfile(
        uid: 'fam_${invite.id}',
        name: invite.familyContactName,
        role: UserRole.familyMember,
        email: '',
        linkedStationId: invite.stationId,
        linkedPersonId: invite.personId,
      );
      expect(profile.hasPermission(Permission.accessFamilyPortal), isTrue);
      expect(profile.hasPermission(Permission.accessCommandCenter), isFalse);
      expect(profile.hasPermission(Permission.accessInventory), isFalse);
      expect(profile.hasPermission(Permission.accessComms), isFalse);
      expect(profile.canEditStation(invite.stationId), isFalse);

      final auth = AuthService();
      auth.startSession(profile);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentRole, equals(UserRole.familyMember));
    });

    test('consent requires signed entry disclaimer first', () {
      final data = PolarDataService();
      final invite = data.getInviteByCode('MTR-2026')!;
      final family = _familyFor(invite);
      // Fresh service: disclaimer unsigned → consent refused
      expect(invite.disclaimerAccepted, isFalse);
      expect(data.confirmFamilyConsent(invite.id, user: family), isFalse);
      expect(data.getInviteByCode('MTR-2026')!.consentGiven, isFalse);
      // After signing disclaimer → consent accepted
      expect(
        data.acceptFamilyDisclaimer(
          inviteId: invite.id,
          signedName: 'Priya Sharma',
          readConfirmed: true,
          user: family,
        ),
        isTrue,
      );
      expect(data.confirmFamilyConsent(invite.id, user: family), isTrue);
      expect(data.getInviteByCode('MTR-2026')!.consentGiven, isTrue);
    });

    test('consent mirrors onto booking for HQ audit', () {
      final data = PolarDataService();
      final invite = data.getInviteByCode('MTR-2026')!;
      final family = _familyFor(invite);
      expect(
        data.acceptFamilyDisclaimer(
          inviteId: invite.id,
          signedName: 'Priya Sharma',
          readConfirmed: true,
          user: family,
        ),
        isTrue,
      );
      expect(invite.consentGiven, isFalse);
      expect(data.confirmFamilyConsent(invite.id, user: family), isTrue);
      expect(data.getInviteByCode('MTR-2026')!.consentGiven, isTrue);
      expect(data.getInviteByCode('MTR-2026')!.briefingAcked, isTrue);
      final booking = data.getBookingById('call_01')!;
      expect(booking.familyConsentGiven, isTrue);
      expect(booking.briefingAcked, isTrue);
      expect(data.confirmFamilyConsent('nope', user: family), isFalse);
    });

    test('station staff can invite for own station only', () {
      final data = PolarDataService();
      const maitriStaff = UserProfile(
        uid: 'staff_mtr_01',
        name: 'Dr. Aarav Sharma',
        role: UserRole.stationStaff,
        email: 'aarav.sharma@maitri.ncpor.gov.in',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_01',
      );
      // call_02 belongs to bharati — maitri staff must be refused
      expect(
        data.createFamilyInvite(bookingId: 'call_02', createdBy: maitriStaff),
        isNull,
      );
    });

    test('family disclaimer gate: typed name + tick required', () {
      final data = PolarDataService();
      final invite = data.getInviteByCode('MTR-2026')!;
      final family = _familyFor(invite);
      expect(invite.disclaimerAccepted, isFalse);
      // Empty name / wrong name / unticked box rejected
      expect(
        data.acceptFamilyDisclaimer(
          inviteId: invite.id,
          signedName: '   ',
          readConfirmed: true,
          user: family,
        ),
        isFalse,
      );
      expect(
        data.acceptFamilyDisclaimer(
          inviteId: invite.id,
          signedName: 'Wrong Name',
          readConfirmed: true,
          user: family,
        ),
        isFalse,
      );
      expect(
        data.acceptFamilyDisclaimer(
          inviteId: invite.id,
          signedName: 'Priya Sharma',
          readConfirmed: false,
          user: family,
        ),
        isFalse,
      );
      expect(data.getInviteByCode('MTR-2026')!.disclaimerAccepted, isFalse);
      // Matching typed name + ticked box accepted, name recorded
      expect(
        data.acceptFamilyDisclaimer(
          inviteId: invite.id,
          signedName: 'Priya Sharma',
          readConfirmed: true,
          user: family,
        ),
        isTrue,
      );
      final updated = data.getInviteByCode('MTR-2026')!;
      expect(updated.disclaimerAccepted, isTrue);
      expect(updated.disclaimerSignedName, equals('Priya Sharma'));
      expect(updated.disclaimerSignedAt, isNotNull);
      // A signed disclaimer cannot be silently overwritten.
      expect(
        data.acceptFamilyDisclaimer(
          inviteId: invite.id,
          signedName: 'Priya Sharma',
          readConfirmed: true,
          user: family,
        ),
        isFalse,
      );
      expect(
        data.acceptFamilyDisclaimer(
          inviteId: 'nope',
          signedName: 'x',
          readConfirmed: true,
          user: family,
        ),
        isFalse,
      );
    });

    test('crew disclaimer: edit rights + typed name required', () {
      final data = PolarDataService();
      const maitriStaff = UserProfile(
        uid: 'staff_mtr_01',
        name: 'Dr. Aarav Sharma',
        role: UserRole.stationStaff,
        email: 'aarav.sharma@maitri.ncpor.gov.in',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_01',
      );
      // call_01 is maitri — empty name / unticked rejected
      expect(
        data.signCrewDisclaimer(
          bookingId: 'call_01',
          signedBy: maitriStaff,
          signatoryName: '  ',
          readConfirmed: true,
        ),
        isFalse,
      );
      expect(
        data.signCrewDisclaimer(
          bookingId: 'call_01',
          signedBy: maitriStaff,
          signatoryName: 'Dr. Aarav Sharma',
          readConfirmed: false,
        ),
        isFalse,
      );
      // cross-station signing refused
      expect(
        data.signCrewDisclaimer(
          bookingId: 'call_02',
          signedBy: maitriStaff,
          signatoryName: 'Dr. Aarav Sharma',
          readConfirmed: true,
        ),
        isFalse,
      );
      expect(
        data.signCrewDisclaimer(
          bookingId: 'call_01',
          signedBy: maitriStaff,
          signatoryName: 'Dr. Aarav Sharma',
          readConfirmed: true,
        ),
        isTrue,
      );
      final booking = data.getBookingById('call_01')!;
      expect(booking.crewDisclaimerSigned, isTrue);
      expect(booking.crewDisclaimerBy, equals('Dr. Aarav Sharma'));
      expect(booking.crewDisclaimerAt, isNotNull);
    });

    test('crew disclaimer: only booked crew or HQ may sign', () {
      final data = PolarDataService();
      // Maitri staff linked to per_mtr_02 signs call_01 (booked for per_mtr_01)
      const otherStaff = UserProfile(
        uid: 'staff_mtr_02',
        name: 'Sqn Ldr Rajesh Varma',
        role: UserRole.stationStaff,
        email: 'rajesh.varma@maitri.ncpor.gov.in',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_02',
      );
      expect(
        data.signCrewDisclaimer(
          bookingId: 'call_01',
          signedBy: otherStaff,
          signatoryName: 'Sqn Ldr Rajesh Varma',
          readConfirmed: true,
        ),
        isFalse,
      );
      // HQ oversight countersign allowed
      expect(
        data.signCrewDisclaimer(
          bookingId: 'call_01',
          signedBy: _hq(),
          signatoryName: 'Cmdr. Nitin Verma (HQ oversight)',
          readConfirmed: true,
        ),
        isTrue,
      );
      // Completed booking can no longer be signed
      expect(
        data.signCrewDisclaimer(
          bookingId: 'call_03',
          signedBy: _hq(),
          signatoryName: 'Cmdr. Nitin Verma',
          readConfirmed: true,
        ),
        isFalse,
      );
    });

    test('invites only for joinable bookings', () {
      final data = PolarDataService();
      // call_03 is completed → refused
      expect(
        data.createFamilyInvite(bookingId: 'call_03', createdBy: _hq()),
        isNull,
      );
    });

    test('mutations enforce station permissions', () {
      final data = PolarDataService();
      const maitriStaff = UserProfile(
        uid: 'staff_mtr_01',
        name: 'Dr. Aarav Sharma',
        role: UserRole.stationStaff,
        email: 'aarav.sharma@maitri.ncpor.gov.in',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_01',
      );
      const family = UserProfile(
        uid: 'fam_x',
        name: 'Priya Sharma (Spouse)',
        role: UserRole.familyMember,
        email: '',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_01',
      );
      // Family can never mutate, even for the linked station
      expect(
        data.bookCallSlot(data.getBookingById('call_01')!, user: family),
        isFalse,
      );
      expect(
        data.updateBookingStatus('call_01', 'cancelled', user: family),
        isFalse,
      );
      // Cross-station booking refused for staff
      final bharatiBooking = data.getBookingById('call_02')!;
      expect(data.bookCallSlot(bharatiBooking, user: maitriStaff), isFalse);
      // Own-station booking allowed
      final newMaitriBooking = CallBooking(
        id: 'call_new_maitri',
        stationId: 'maitri',
        personId: 'per_mtr_01',
        personName: 'Dr. Aarav Sharma',
        familyContactName: 'Priya Sharma (Spouse)',
        scheduledSlot: DateTime.now().add(const Duration(hours: 2)),
        durationMinutes: 15,
        status: 'booked',
        channelType: 'satellite-voice',
      );
      expect(data.bookCallSlot(newMaitriBooking, user: maitriStaff), isTrue);
    });
  });
}
