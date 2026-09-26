import '../../models/call_booking.dart';
import '../../models/family_invite.dart';
import '../../models/user_role.dart';

/// Central authorization rules for satellite call bookings.
///
/// The UI and [PolarDataService] use the same policy so a cleared button is
/// never the only thing standing between a user and a call room. A booking is
/// joinable only when it is live, both sides have cleared compliance, and the
/// current session is allowed to see that booking's station or invite.
class CallAccessPolicy {
  const CallAccessPolicy._();

  static bool isSupportedChannel(String value) {
    return const {'satellite-voice', 'low-res-video'}.contains(value);
  }

  static bool isValidDuration(int minutes) => minutes > 0 && minutes <= 120;

  static bool isLive(CallBooking booking) {
    return booking.status == 'booked' || booking.status == 'live';
  }

  static bool hasBothClearances(CallBooking booking) {
    return booking.crewDisclaimerSigned &&
        booking.familyConsentGiven &&
        booking.briefingAcked;
  }

  static bool isWithinJoinWindow(CallBooking booking, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final opens = booking.scheduledSlot.subtract(const Duration(minutes: 10));
    final closes = booking.scheduledSlot.add(
      Duration(minutes: booking.durationMinutes + 15),
    );
    return !at.isBefore(opens) && !at.isAfter(closes);
  }

  static bool isJoinable(CallBooking booking, {DateTime? now}) {
    return isLive(booking) &&
        hasBothClearances(booking) &&
        isWithinJoinWindow(booking, now: now);
  }

  static bool canViewAsCrew(UserProfile? user, CallBooking booking) {
    if (user == null || user.role == UserRole.familyMember) return false;
    return user.canAccessStation(booking.stationId);
  }

  static bool canJoinAsCrew(UserProfile? user, CallBooking booking) {
    return canViewAsCrew(user, booking) && isJoinable(booking);
  }

  static bool canJoinAsFamily({
    required UserProfile? user,
    required CallBooking booking,
    required FamilyInvite? invite,
  }) {
    if (user == null || user.role != UserRole.familyMember || invite == null) {
      return false;
    }
    // The invite must actually be the one issued for this booking — an invite
    // for another station/person cannot be used to unlock this call room.
    if (invite.bookingId != booking.id ||
        invite.stationId != booking.stationId ||
        invite.personId != booking.personId) {
      return false;
    }
    if (user.uid != 'fam_${invite.id}' ||
        user.linkedStationId != booking.stationId ||
        user.linkedPersonId != booking.personId) {
      return false;
    }

    return invite.disclaimerAccepted &&
        invite.consentGiven &&
        invite.briefingAcked &&
        isJoinable(booking);
  }

  /// Returns the correct policy for the session role. A family session cannot
  /// masquerade as crew by passing `familySide: false`, and a crew/HQ session
  /// cannot masquerade as family by passing `familySide: true`.
  static bool canJoin({
    required UserProfile? user,
    required CallBooking booking,
    required FamilyInvite? invite,
    required bool familySide,
  }) {
    if (user?.role == UserRole.familyMember) {
      return canJoinAsFamily(user: user, booking: booking, invite: invite);
    }
    return !familySide && canJoinAsCrew(user, booking);
  }
}
