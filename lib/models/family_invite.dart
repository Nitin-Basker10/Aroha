import 'dart:math';

/// Family call invite — links one satellite call booking to one family
/// member through a short shareable code. The family portal session is
/// created from this invite, never from open registration, so families
/// can only ever see their own call slot.
class FamilyInvite {
  final String id;
  final String
  inviteCode; // e.g. "MTR-7Q2X4K9P" — shared out-of-band by HQ/crew
  final String bookingId;
  final String stationId;
  final String personId;
  final String personName;
  final String familyContactName;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;

  /// Compliance fields (DPDP Act 2023 / IT Act)
  final bool consentGiven; // family consents to the monitored-call briefing
  final DateTime? consentAt;
  final bool briefingAcked; // family acked "no research disclosure" briefing

  /// Entry disclaimer — signed BEFORE the portal unlocks.
  final bool disclaimerAccepted;
  final String? disclaimerSignedName;
  final DateTime? disclaimerSignedAt;
  final String disclaimerVersion;

  const FamilyInvite({
    required this.id,
    required this.inviteCode,
    required this.bookingId,
    required this.stationId,
    required this.personId,
    required this.personName,
    required this.familyContactName,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
    this.consentGiven = false,
    this.consentAt,
    this.briefingAcked = false,
    this.disclaimerAccepted = false,
    this.disclaimerSignedName,
    this.disclaimerSignedAt,
    this.disclaimerVersion = 'v1',
  });

  FamilyInvite copyWith({
    bool? consentGiven,
    DateTime? consentAt,
    bool? briefingAcked,
    bool? disclaimerAccepted,
    String? disclaimerSignedName,
    DateTime? disclaimerSignedAt,
    String? disclaimerVersion,
  }) {
    return FamilyInvite(
      id: id,
      inviteCode: inviteCode,
      bookingId: bookingId,
      stationId: stationId,
      personId: personId,
      personName: personName,
      familyContactName: familyContactName,
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      createdAt: createdAt,
      consentGiven: consentGiven ?? this.consentGiven,
      consentAt: consentAt ?? this.consentAt,
      briefingAcked: briefingAcked ?? this.briefingAcked,
      disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
      disclaimerSignedName: disclaimerSignedName ?? this.disclaimerSignedName,
      disclaimerSignedAt: disclaimerSignedAt ?? this.disclaimerSignedAt,
      disclaimerVersion: disclaimerVersion ?? this.disclaimerVersion,
    );
  }

  /// Human-readable code with a cryptographically random suffix. Codes are
  /// shared out-of-band, so they must not be predictable from the clock.
  static String makeCode(String stationId) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final suffix = List.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    final prefix = stationId.length >= 3
        ? stationId.substring(0, 3).toUpperCase()
        : stationId.toUpperCase();
    return '$prefix-$suffix';
  }
}
