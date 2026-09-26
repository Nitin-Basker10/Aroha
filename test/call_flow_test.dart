import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aroha_polar/core/theme/app_theme.dart';
import 'package:aroha_polar/models/call_booking.dart';
import 'package:aroha_polar/models/user_role.dart';
import 'package:aroha_polar/services/auth_service.dart';
import 'package:aroha_polar/services/polar_data_service.dart';
import 'package:aroha_polar/views/calls/video_call_screen.dart';
import 'package:aroha_polar/views/comms/comms_hub_screen.dart';

const _maitriStaff = UserProfile(
  uid: 'staff_mtr_01',
  name: 'Dr. Aarav Sharma',
  role: UserRole.stationStaff,
  email: 'aarav.sharma@maitri.ncpor.gov.in',
  linkedStationId: 'maitri',
  linkedPersonId: 'per_mtr_01',
);

/// Wraps a full screen in the same provider stack the real app uses so the
/// widget tree under test resolves the exact same services.
Widget _host(PolarDataService data, AuthService auth, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: auth),
      ChangeNotifierProvider<PolarDataService>.value(value: data),
    ],
    child: MaterialApp(theme: AppTheme.darkTheme, home: child),
  );
}

/// Same, but for body widgets (e.g. CommsHubScreen) that the real app embeds
/// inside MainLayoutScreen's Scaffold and therefore expect a Material ancestor.
Widget _hostBody(PolarDataService data, AuthService auth, Widget child) {
  return _host(data, auth, Scaffold(body: child));
}

/// The tactical screens are laid out for a real handset, so the default
/// 800x600 test surface produces spurious RenderFlex overflow noise. Give the
/// tree the actual target viewport instead of weakening the assertions.
void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Runs a widget-test body with real service instances and guarantees they are
/// torn down *inside* the test body.
///
/// This is not cosmetic: [AuthService] owns a 30-minute session timer and
/// [PolarDataService] can own poll/retry timers. `addTearDown` fires too late
/// — the binding asserts "no pending timers" before teardowns run — so cleanup
/// has to happen in a `finally` here or every test fails on timer bookkeeping
/// instead of on the behaviour being tested.
Future<void> _withSession(
  Future<void> Function(PolarDataService data, AuthService auth) body,
) async {
  final data = PolarDataService(enableCloudSync: false);
  final auth = AuthService();
  try {
    await body(data, auth);
  } finally {
    auth.dispose();
    data.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Satellite call flow through the real UI', () {
    testWidgets('a not-yet-cleared booking renders ACCESS DENIED, not a room', (
      tester,
    ) async {
      _usePhoneViewport(tester);
      await _withSession((data, auth) async {
        auth.startSession(_maitriStaff);

        // Fresh service: the seeded call_01 has no crew disclaimer and no
        // family consent yet, so the room must refuse to open.
        final booking = data.getBookingById('call_01')!;
        expect(booking.crewDisclaimerSigned, isFalse);
        expect(booking.familyConsentGiven, isFalse);
        expect(booking.briefingAcked, isFalse);

        await tester.pumpWidget(
          _host(
            data,
            auth,
            VideoCallScreen(booking: booking, displayName: _maitriStaff.name),
          ),
        );
        // The access check runs in a post-frame callback, so one pump is
        // enough; pumpAndSettle would never settle because the granted room
        // runs a 1 Hz call timer.
        await tester.pump();

        expect(find.text('CALL ACCESS DENIED'), findsOneWidget);
        // The room itself must never build.
        expect(find.textContaining('PREVIEW'), findsNothing);
        expect(
          find.textContaining('REMOTE RELAY NOT CONFIGURED'),
          findsNothing,
        );
      });
    });

    testWidgets('a fully cleared, in-window booking opens the call room', (
      tester,
    ) async {
      _usePhoneViewport(tester);
      await _withSession((data, auth) async {
        auth.startSession(_maitriStaff);

        final booking = data.getBookingById('call_01')!;
        final invite = data.getInviteForBooking(booking.id)!;
        final family = UserProfile(
          uid: 'fam_${invite.id}',
          name: invite.familyContactName,
          role: UserRole.familyMember,
          email: '',
          linkedStationId: invite.stationId,
          linkedPersonId: invite.personId,
        );
        expect(
          data.signCrewDisclaimer(
            bookingId: booking.id,
            signedBy: _maitriStaff,
            signatoryName: _maitriStaff.name,
            readConfirmed: true,
          ),
          isTrue,
        );
        expect(
          data.acceptFamilyDisclaimer(
            inviteId: invite.id,
            signedName: invite.familyContactName,
            readConfirmed: true,
            user: family,
          ),
          isTrue,
        );
        expect(data.confirmFamilyConsent(invite.id, user: family), isTrue);

        await tester.pumpWidget(
          _host(
            data,
            auth,
            VideoCallScreen(booking: booking, displayName: _maitriStaff.name),
          ),
        );
        await tester.pump();

        expect(find.text('CALL ACCESS DENIED'), findsNothing);
        expect(find.text('SATELLITE VIDEO // PREVIEW'), findsOneWidget);
        // Honest labelling: never claim a peer, recorder or encryption.
        expect(find.text('PREVIEW'), findsOneWidget);
        expect(find.text('REMOTE RELAY NOT CONFIGURED'), findsOneWidget);
      });
    });

    testWidgets('a cleared, in-window booking is joinable as the right crew', (
      tester,
    ) async {
      _usePhoneViewport(tester);
      await _withSession((data, auth) async {
        auth.startSession(_maitriStaff);

        final booking = data.getBookingById('call_01')!;
        expect(booking.stationId, 'maitri');

        // Same person clears their own side.
        final signed = data.signCrewDisclaimer(
          bookingId: booking.id,
          signedBy: _maitriStaff,
          signatoryName: _maitriStaff.name,
          readConfirmed: true,
        );
        expect(signed, isTrue);

        // Family side clears consent via the bound invite.
        final invite = data.getInviteForBooking(booking.id)!;
        final family = UserProfile(
          uid: 'fam_${invite.id}',
          name: invite.familyContactName,
          role: UserRole.familyMember,
          email: '',
          linkedStationId: invite.stationId,
          linkedPersonId: invite.personId,
        );
        expect(
          data.acceptFamilyDisclaimer(
            inviteId: invite.id,
            signedName: invite.familyContactName,
            readConfirmed: true,
            user: family,
          ),
          isTrue,
        );
        expect(data.confirmFamilyConsent(invite.id, user: family), isTrue);

        // Now the policy must allow the crew join.
        expect(
          data
              .getVisibleCallBookings(_maitriStaff)
              .any((b) => b.id == booking.id),
          isTrue,
        );
      });
    });

    testWidgets('a station never sees or joins another station\'s booking', (
      tester,
    ) async {
      _usePhoneViewport(tester);
      await _withSession((data, auth) async {
        const bharatiStaff = UserProfile(
          uid: 'staff_bhr_01',
          name: 'Dr. Sunita Deshmukh',
          role: UserRole.stationStaff,
          email: 'sunita.deshmukh@bharati.ncpor.gov.in',
          linkedStationId: 'bharati',
          linkedPersonId: 'per_bhr_01',
        );
        auth.startSession(bharatiStaff);

        final visible = data.getVisibleCallBookings(auth.currentUser);
        expect(visible, isNotEmpty);
        expect(
          visible.every((b) => b.stationId == 'bharati'),
          isTrue,
          reason: 'station staff must not see other stations\' bookings',
        );
        expect(
          visible.any((b) => b.stationId == 'maitri'),
          isFalse,
          reason: 'cross-station booking leak',
        );

        await tester.pumpWidget(_hostBody(data, auth, const CommsHubScreen()));
        await tester.pump();
        // The rendered reservations list must contain no Maitri booking.
        expect(find.textContaining('call_01'), findsNothing);
      });
    });

    testWidgets('family session sees no station data at all', (tester) async {
      _usePhoneViewport(tester);
      await _withSession((data, auth) async {
        final invite = data.getInviteForBooking('call_01')!;
        final family = UserProfile(
          uid: 'fam_${invite.id}',
          name: invite.familyContactName,
          role: UserRole.familyMember,
          email: '',
          linkedStationId: invite.stationId,
          linkedPersonId: invite.personId,
        );
        auth.startSession(family);

        expect(data.getVisibleCallBookings(auth.currentUser), isEmpty);
        expect(data.getMessagesForUser(auth.currentUser), isEmpty);
        expect(data.getVisibleStations(auth.currentUser), isEmpty);
        expect(data.getVisibleInventory(auth.currentUser), isEmpty);
        expect(data.getVisiblePersonnel(auth.currentUser), isEmpty);
        expect(data.getVisibleAlerts(auth.currentUser), isEmpty);
        expect(data.getVisibleResourceRequests(auth.currentUser), isEmpty);
      });
    });

    test('staff cannot sign a disclaimer for another crew member', () async {
      final data = PolarDataService(enableCloudSync: false);
      try {
        const himadriStaff = UserProfile(
          uid: 'staff_hmd_01',
          name: 'Dr. Alok Sengupta',
          role: UserRole.stationStaff,
          email: 'alok.sengupta@himadri.ncpor.gov.in',
          linkedStationId: 'himadri',
          linkedPersonId: 'per_hmd_01',
        );
        // Himadri staff has no rights on the Maitri call.
        expect(
          data.signCrewDisclaimer(
            bookingId: 'call_01',
            signedBy: himadriStaff,
            signatoryName: 'Dr. Alok Sengupta',
            readConfirmed: true,
          ),
          isFalse,
        );
        // The booked Maitri crew member may sign their own call.
        expect(
          data.signCrewDisclaimer(
            bookingId: 'call_01',
            signedBy: _maitriStaff,
            signatoryName: _maitriStaff.name,
            readConfirmed: true,
          ),
          isTrue,
        );
        // A signature cannot be silently overwritten by a different signatory.
        const otherMaitriCrew = UserProfile(
          uid: 'staff_mtr_02',
          name: 'Eng. Tenzing Norbu',
          role: UserRole.stationStaff,
          email: 'tenzing.norbu@maitri.ncpor.gov.in',
          linkedStationId: 'maitri',
          linkedPersonId: 'per_mtr_02',
        );
        expect(
          data.signCrewDisclaimer(
            bookingId: 'call_01',
            signedBy: otherMaitriCrew,
            signatoryName: 'Eng. Tenzing Norbu',
            readConfirmed: true,
          ),
          isFalse,
          reason: 'a different crew member must not sign this booking',
        );
      } finally {
        data.dispose();
      }
    });

    test('family consent cannot be forged by crew or by another family', () {
      final data = PolarDataService(enableCloudSync: false);
      try {
        final invite = data.getInviteForBooking('call_01')!;

        // Crew cannot sign the family disclaimer.
        expect(
          data.acceptFamilyDisclaimer(
            inviteId: invite.id,
            signedName: invite.familyContactName,
            readConfirmed: true,
            user: _maitriStaff,
          ),
          isFalse,
        );
        // A different family session cannot sign it.
        const otherFamily = UserProfile(
          uid: 'fam_someone_else',
          name: 'Priya Sharma',
          role: UserRole.familyMember,
          email: '',
          linkedStationId: 'maitri',
          linkedPersonId: 'per_mtr_01',
        );
        expect(
          data.acceptFamilyDisclaimer(
            inviteId: invite.id,
            signedName: invite.familyContactName,
            readConfirmed: true,
            user: otherFamily,
          ),
          isFalse,
        );
        // A family session cannot confirm consent before signing the
        // disclaimer.
        final realFamily = UserProfile(
          uid: 'fam_${invite.id}',
          name: invite.familyContactName,
          role: UserRole.familyMember,
          email: '',
          linkedStationId: invite.stationId,
          linkedPersonId: invite.personId,
        );
        expect(data.confirmFamilyConsent(invite.id, user: realFamily), isFalse);
        // A wrong signature name is rejected.
        expect(
          data.acceptFamilyDisclaimer(
            inviteId: invite.id,
            signedName: 'Someone Else',
            readConfirmed: true,
            user: realFamily,
          ),
          isFalse,
        );
        // Only the exact invited name unlocks it.
        expect(
          data.acceptFamilyDisclaimer(
            inviteId: invite.id,
            signedName: invite.familyContactName,
            readConfirmed: true,
            user: realFamily,
          ),
          isTrue,
        );
        // Consent now succeeds, and is idempotent — a second grant is refused
        // so a signature/consent cannot be rewritten after the fact.
        expect(data.confirmFamilyConsent(invite.id, user: realFamily), isTrue);
        expect(
          data.confirmFamilyConsent(invite.id, user: realFamily),
          isFalse,
          reason: 'consent must not be re-granted once recorded',
        );
        // The signature itself is immutable.
        expect(
          data.acceptFamilyDisclaimer(
            inviteId: invite.id,
            signedName: 'Someone Else',
            readConfirmed: true,
            user: realFamily,
          ),
          isFalse,
        );
      } finally {
        data.dispose();
      }
    });
  });

  group('Booking CRUD guards', () {
    test('duplicate, past, and unauthorised bookings are rejected', () {
      final data = PolarDataService(enableCloudSync: false);
      try {
        CallBooking make(String id, {Duration offset = Duration.zero}) =>
            CallBooking(
              id: id,
              stationId: 'maitri',
              personId: 'per_mtr_01',
              personName: 'Dr. Aarav Sharma',
              familyContactName: 'Priya Sharma',
              scheduledSlot: DateTime.now().add(offset),
              durationMinutes: 15,
              status: 'booked',
              channelType: 'satellite-voice',
            );

        // Duplicate id.
        expect(data.bookCallSlot(make('call_01'), user: _maitriStaff), isFalse);
        // Slot in the past.
        expect(
          data.bookCallSlot(
            make('call_past', offset: const Duration(hours: -2)),
            user: _maitriStaff,
          ),
          isFalse,
        );
        // Wrong station.
        expect(
          data.bookCallSlot(
            CallBooking(
              id: 'call_x',
              stationId: 'bharati',
              personId: 'per_bhr_01',
              personName: 'Dr. Sunita Deshmukh',
              familyContactName: 'Rohan Deshmukh',
              scheduledSlot: DateTime.now().add(const Duration(minutes: 5)),
              durationMinutes: 15,
              status: 'booked',
              channelType: 'satellite-voice',
            ),
            user: _maitriStaff,
          ),
          isFalse,
        );
        // Unsupported channel.
        expect(
          data.bookCallSlot(
            CallBooking(
              id: 'call_y',
              stationId: 'maitri',
              personId: 'per_mtr_01',
              personName: 'Dr. Aarav Sharma',
              familyContactName: 'Priya Sharma',
              scheduledSlot: DateTime.now().add(const Duration(minutes: 5)),
              durationMinutes: 15,
              status: 'booked',
              channelType: 'iridium-patch',
            ),
            user: _maitriStaff,
          ),
          isFalse,
        );
        // No session.
        expect(data.bookCallSlot(make('call_z')), isFalse);

        // A legitimate booking for your own station works.
        expect(
          data.bookCallSlot(
            make('call_ok', offset: const Duration(minutes: 5)),
            user: _maitriStaff,
          ),
          isTrue,
        );
      } finally {
        data.dispose();
      }
    });

    test('terminal bookings cannot be reopened', () {
      final data = PolarDataService(enableCloudSync: false);
      try {
        final completed = data.getBookingById('call_03')!;
        expect(completed.status, 'completed');
        // A closed slot cannot be resurrected.
        expect(
          data.updateBookingStatus(completed.id, 'booked', user: _maitriStaff),
          isFalse,
        );
        // Only known statuses are accepted.
        expect(
          data.updateBookingStatus(
            completed.id,
            'made-up-status',
            user: _maitriStaff,
          ),
          isFalse,
        );
        // No session, no mutation.
        final live = data.getBookingById('call_01')!;
        expect(data.updateBookingStatus(live.id, 'cancelled'), isFalse);
        // A station cannot cancel another station's call.
        expect(
          data.updateBookingStatus('call_02', 'cancelled', user: _maitriStaff),
          isFalse,
        );
      } finally {
        data.dispose();
      }
    });
  });
}
