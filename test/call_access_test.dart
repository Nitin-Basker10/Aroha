import 'package:flutter_test/flutter_test.dart';

import 'package:aroha_polar/core/utils/call_access.dart';
import 'package:aroha_polar/models/call_booking.dart';
import 'package:aroha_polar/models/family_invite.dart';
import 'package:aroha_polar/models/user_role.dart';

CallBooking _booking({
  String id = 'call_test',
  String stationId = 'maitri',
  String personId = 'per_mtr_01',
  String status = 'booked',
  bool crewDisclaimerSigned = true,
  bool familyConsentGiven = true,
  bool briefingAcked = true,
  String channelType = 'satellite-voice',
}) {
  return CallBooking(
    id: id,
    stationId: stationId,
    personId: personId,
    personName: 'Dr. Aarav Sharma',
    familyContactName: 'Priya Sharma (Spouse)',
    scheduledSlot: DateTime.now().add(const Duration(minutes: 5)),
    durationMinutes: 15,
    status: status,
    channelType: channelType,
    crewDisclaimerSigned: crewDisclaimerSigned,
    familyConsentGiven: familyConsentGiven,
    briefingAcked: briefingAcked,
  );
}

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

const _hq = UserProfile(
  uid: 'hq_admin_01',
  name: 'Cmdr. Nitin Verma',
  role: UserRole.hqAdmin,
  email: 'nitin.verma@ncpor.res.in',
);

FamilyInvite _invite({
  String id = 'fam_test',
  String bookingId = 'call_test',
  bool disclaimerAccepted = true,
  bool consentGiven = true,
  bool briefingAcked = true,
}) {
  return FamilyInvite(
    id: id,
    inviteCode: 'MTR-TEST',
    bookingId: bookingId,
    stationId: 'maitri',
    personId: 'per_mtr_01',
    personName: 'Dr. Aarav Sharma',
    familyContactName: 'Priya Sharma',
    createdByUserId: 'hq_admin_01',
    createdByName: 'Cmdr. Nitin Verma',
    createdAt: DateTime.now(),
    disclaimerAccepted: disclaimerAccepted,
    consentGiven: consentGiven,
    briefingAcked: briefingAcked,
  );
}

void main() {
  group('CallAccessPolicy', () {
    test('requires both clearances and a live booking', () {
      expect(CallAccessPolicy.isJoinable(_booking()), isTrue);
      expect(
        CallAccessPolicy.isJoinable(_booking(crewDisclaimerSigned: false)),
        isFalse,
      );
      expect(
        CallAccessPolicy.isJoinable(_booking(familyConsentGiven: false)),
        isFalse,
      );
      expect(
        CallAccessPolicy.isJoinable(_booking(briefingAcked: false)),
        isFalse,
      );
      expect(
        CallAccessPolicy.isJoinable(_booking(status: 'completed')),
        isFalse,
      );
      expect(
        CallAccessPolicy.isJoinable(_booking(status: 'cancelled')),
        isFalse,
      );
    });

    test('join window opens shortly before the slot and closes after it', () {
      final booking = _booking();
      expect(CallAccessPolicy.isWithinJoinWindow(booking), isTrue);
      final future = CallBooking(
        id: 'call_future',
        stationId: 'maitri',
        personId: 'per_mtr_01',
        personName: 'Dr. Aarav Sharma',
        familyContactName: 'Priya Sharma',
        scheduledSlot: DateTime.now().add(const Duration(hours: 2)),
        durationMinutes: 15,
        status: 'booked',
        crewDisclaimerSigned: true,
        familyConsentGiven: true,
        briefingAcked: true,
      );
      expect(CallAccessPolicy.isJoinable(future), isFalse);
    });

    test('station scope prevents cross-station crew joins', () {
      final booking = _booking(stationId: 'bharati', personId: 'per_bhr_01');
      expect(CallAccessPolicy.canJoinAsCrew(_maitriStaff, booking), isFalse);
      expect(CallAccessPolicy.canJoinAsCrew(_bharatiStaff, booking), isTrue);
      expect(CallAccessPolicy.canJoinAsCrew(_hq, booking), isTrue);
    });

    test('family join requires the exact invite and family session', () {
      final booking = _booking();
      final invite = _invite();
      final family = UserProfile(
        uid: 'fam_${invite.id}',
        name: 'Priya Sharma',
        role: UserRole.familyMember,
        email: '',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_01',
      );

      expect(
        CallAccessPolicy.canJoin(
          user: family,
          booking: booking,
          invite: invite,
          familySide: true,
        ),
        isTrue,
      );
      expect(
        CallAccessPolicy.canJoin(
          user: _maitriStaff,
          booking: booking,
          invite: invite,
          familySide: true,
        ),
        isFalse,
      );
      expect(
        CallAccessPolicy.canJoin(
          user: family,
          booking: booking,
          invite: _invite(consentGiven: false),
          familySide: true,
        ),
        isFalse,
      );
      expect(
        CallAccessPolicy.canJoin(
          user: family,
          booking: booking,
          invite: _invite(disclaimerAccepted: false),
          familySide: true,
        ),
        isFalse,
      );
    });

    test('only supported channels and bounded durations are bookable', () {
      expect(CallAccessPolicy.isSupportedChannel('satellite-voice'), isTrue);
      expect(CallAccessPolicy.isSupportedChannel('low-res-video'), isTrue);
      expect(CallAccessPolicy.isSupportedChannel('iridium-patch'), isFalse);
      expect(CallAccessPolicy.isValidDuration(1), isTrue);
      expect(CallAccessPolicy.isValidDuration(120), isTrue);
      expect(CallAccessPolicy.isValidDuration(0), isFalse);
      expect(CallAccessPolicy.isValidDuration(121), isFalse);
    });

    test('an invite for a different person cannot unlock this booking', () {
      final booking = _booking();
      final family = UserProfile(
        uid: 'fam_fam_test',
        name: 'Priya Sharma',
        role: UserRole.familyMember,
        email: '',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_01',
      );
      // Same invite code, but the invite is bound to another crew member.
      final wrongPerson = FamilyInvite(
        id: 'fam_test',
        inviteCode: 'MTR-TEST',
        bookingId: 'call_test',
        stationId: 'maitri',
        personId: 'per_mtr_99',
        personName: 'Eng. Tenzing Norbu',
        familyContactName: 'Priya Sharma',
        createdByUserId: 'hq_admin_01',
        createdByName: 'Cmdr. Nitin Verma',
        createdAt: DateTime.now(),
        disclaimerAccepted: true,
        consentGiven: true,
        briefingAcked: true,
      );
      expect(
        CallAccessPolicy.canJoinAsFamily(
          user: family,
          booking: booking,
          invite: wrongPerson,
        ),
        isFalse,
      );
    });

    test('no user at all is never joinable', () {
      final booking = _booking();
      final invite = _invite();
      expect(CallAccessPolicy.canJoinAsCrew(null, booking), isFalse);
      expect(
        CallAccessPolicy.canJoinAsFamily(
          user: null,
          booking: booking,
          invite: invite,
        ),
        isFalse,
      );
      expect(CallAccessPolicy.canViewAsCrew(null, booking), isFalse);
    });
  });

  group('Role and profile fail-closed behaviour', () {
    test('unknown role ids are rejected instead of defaulting to HQ', () {
      expect(UserRole.fromId('hq-admin'), UserRole.hqAdmin);
      expect(UserRole.fromId('station-staff'), UserRole.stationStaff);
      expect(UserRole.fromId('family-member'), UserRole.familyMember);
      expect(() => UserRole.fromId('admin'), throwsA(isA<FormatException>()));
      expect(
        () => UserRole.fromId('HQ-ADMIN'),
        throwsA(isA<FormatException>()),
      );
      expect(() => UserRole.fromId(''), throwsA(isA<FormatException>()));
    });

    test('a profile with no role claim never becomes an HQ admin', () {
      expect(
        () => UserProfile.fromMap('u1', {'name': 'No Role'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => UserProfile.fromMap('u1', {'name': 'Bad Role', 'role': 42}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => UserProfile.fromMap('u1', {'name': 'Bad Role', 'role': 'root'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('a valid role claim round-trips', () {
      final profile = UserProfile.fromMap('u2', {
        'name': 'Dr. Aarav Sharma',
        'role': 'station-staff',
        'email': 'aarav.sharma@maitri.ncpor.gov.in',
        'linkedStationId': 'maitri',
        'linkedPersonId': 'per_mtr_01',
      });
      expect(profile.role, UserRole.stationStaff);
      expect(profile.canAccessStation('maitri'), isTrue);
      expect(profile.canAccessStation('bharati'), isFalse);
    });

    test('family role can never reach station data or writes', () {
      const family = UserProfile(
        uid: 'fam_x',
        name: 'Priya Sharma',
        role: UserRole.familyMember,
        email: '',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_01',
      );
      expect(family.canAccessStation('maitri'), isFalse);
      expect(family.canAccessStation('bharati'), isFalse);
      expect(family.canEditStation('maitri'), isFalse);
      expect(family.canViewMedical('maitri'), isFalse);
      expect(
        family.hasPermission(Permission.viewOperationalTelemetry),
        isFalse,
      );
      expect(family.hasPermission(Permission.viewPersonnelMedical), isFalse);
      expect(family.hasPermission(Permission.accessFamilyPortal), isTrue);
    });
  });

  group('FamilyInvite integrity', () {
    test('copyWith preserves the disclaimer version', () {
      final invite = _invite().copyWith(
        disclaimerVersion: 'v2',
        consentGiven: true,
      );
      expect(invite.disclaimerVersion, 'v2');
      expect(invite.consentGiven, isTrue);
      expect(invite.inviteCode, 'MTR-TEST');
      // A later copyWith that does not mention the version must not reset it.
      expect(invite.copyWith(briefingAcked: true).disclaimerVersion, 'v2');
    });

    test('invite codes are prefixed and unpredictable', () {
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final codes = <String>{};
      for (var i = 0; i < 200; i++) {
        final code = FamilyInvite.makeCode('mtr');
        expect(code.startsWith('MTR-'), isTrue);
        final suffix = code.substring(4);
        expect(suffix.length, 8);
        for (final ch in suffix.split('')) {
          expect(alphabet.contains(ch), isTrue, reason: 'ambiguous char "$ch"');
        }
        codes.add(code);
      }
      // No collisions across 200 draws from a 32^8 space.
      expect(codes.length, 200);
    });
  });
}
