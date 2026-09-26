/// Call Booking model matching PRD §3 `callBookings/{bookingId}`
class CallBooking {
  final String id;
  final String stationId;
  final String personId;
  final String personName;
  final String familyContactName;
  final DateTime scheduledSlot;
  final int durationMinutes;
  final String status; // booked / completed / cancelled / live
  final String channelType; // satellite-voice / low-res-video / irridium-patch

  /// Compliance (confidential research — DPDP Act 2023 / IT Act)
  final bool familyConsentGiven;
  final bool briefingAcked;

  /// Optional pointer to a recording held by an external, access-controlled
  /// recorder. This build deploys no recorder, so it stays null; schema-only.
  final String? recordingRef;
  final String? inviteCode; // family portal invite linked to this booking

  /// Crew undertaking — signed by station-side signatory before joining.
  final bool crewDisclaimerSigned;
  final String? crewDisclaimerBy;
  final DateTime? crewDisclaimerAt;

  const CallBooking({
    required this.id,
    required this.stationId,
    required this.personId,
    required this.personName,
    required this.familyContactName,
    required this.scheduledSlot,
    required this.durationMinutes,
    required this.status,
    this.channelType = 'satellite-voice',
    this.familyConsentGiven = false,
    this.briefingAcked = false,
    this.recordingRef,
    this.inviteCode,
    this.crewDisclaimerSigned = false,
    this.crewDisclaimerBy,
    this.crewDisclaimerAt,
  });

  CallBooking copyWith({
    String? stationId,
    String? personId,
    String? personName,
    String? familyContactName,
    DateTime? scheduledSlot,
    int? durationMinutes,
    String? status,
    String? channelType,
    bool? familyConsentGiven,
    bool? briefingAcked,
    String? recordingRef,
    String? inviteCode,
    bool? crewDisclaimerSigned,
    String? crewDisclaimerBy,
    DateTime? crewDisclaimerAt,
  }) {
    return CallBooking(
      id: id,
      stationId: stationId ?? this.stationId,
      personId: personId ?? this.personId,
      personName: personName ?? this.personName,
      familyContactName: familyContactName ?? this.familyContactName,
      scheduledSlot: scheduledSlot ?? this.scheduledSlot,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      channelType: channelType ?? this.channelType,
      familyConsentGiven: familyConsentGiven ?? this.familyConsentGiven,
      briefingAcked: briefingAcked ?? this.briefingAcked,
      recordingRef: recordingRef ?? this.recordingRef,
      inviteCode: inviteCode ?? this.inviteCode,
      crewDisclaimerSigned: crewDisclaimerSigned ?? this.crewDisclaimerSigned,
      crewDisclaimerBy: crewDisclaimerBy ?? this.crewDisclaimerBy,
      crewDisclaimerAt: crewDisclaimerAt ?? this.crewDisclaimerAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stationId': stationId,
      'personId': personId,
      'personName': personName,
      'familyContactName': familyContactName,
      'scheduledSlot': scheduledSlot.toIso8601String(),
      'durationMinutes': durationMinutes,
      'status': status,
      'channelType': channelType,
      'familyConsentGiven': familyConsentGiven,
      'briefingAcked': briefingAcked,
      'recordingRef': recordingRef,
      'inviteCode': inviteCode,
      'crewDisclaimerSigned': crewDisclaimerSigned,
      'crewDisclaimerBy': crewDisclaimerBy,
      'crewDisclaimerAt': crewDisclaimerAt?.toIso8601String(),
    };
  }

  factory CallBooking.fromMap(String id, Map<String, dynamic> map) {
    return CallBooking(
      id: id,
      stationId: map['stationId'] ?? '',
      personId: map['personId'] ?? '',
      personName: map['personName'] ?? 'Station Personnel',
      familyContactName: map['familyContactName'] ?? 'Family Contact',
      scheduledSlot: map['scheduledSlot'] != null
          ? DateTime.parse(map['scheduledSlot'])
          : DateTime.now().add(const Duration(hours: 4)),
      durationMinutes: map['durationMinutes'] ?? 15,
      status: map['status'] ?? 'booked',
      channelType: map['channelType'] ?? 'satellite-voice',
      familyConsentGiven: map['familyConsentGiven'] ?? false,
      briefingAcked: map['briefingAcked'] ?? false,
      recordingRef: map['recordingRef'],
      inviteCode: map['inviteCode'],
      crewDisclaimerSigned: map['crewDisclaimerSigned'] ?? false,
      crewDisclaimerBy: map['crewDisclaimerBy'],
      crewDisclaimerAt: map['crewDisclaimerAt'] != null
          ? DateTime.tryParse(map['crewDisclaimerAt'])
          : null,
    );
  }
}
