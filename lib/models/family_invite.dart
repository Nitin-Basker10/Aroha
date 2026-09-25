/// Family call invite — links one satellite call booking to one family
/// member through a short shareable code. The family portal session is
/// created from this invite, never from open registration, so families
/// can only ever see their own call slot.
class FamilyInvite {
  final String id;
  final String inviteCode; // e.g. "MTR-7Q2X" — shared out-of-band by HQ/crew
  final String bookingId;
  final String stationId;
  final String personId;
  final String personName;
  final String familyContactName;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;

  /// Compliance fields (DPDP Act 2023 / IT Act)
  final bool consentGiven; // family consents to logging/recording
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
    );
  }

  /// Short human-readable code derived from the invite id.
  static String makeCode(String stationId) {
    final prefix = stationId.length >= 3
        ? stationId.substring(0, 3).toUpperCase()
        : stationId.toUpperCase();
    final suffix = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final tail = suffix.length >= 4
        ? suffix.substring(suffix.length - 4)
        : suffix.padLeft(4, 'X');
    return '$prefix-$tail';
  }
}
