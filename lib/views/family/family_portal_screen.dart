import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/family_invite.dart';
import '../../models/call_booking.dart';
import '../../services/polar_data_service.dart';
import '../../services/auth_service.dart';
import '../calls/video_call_screen.dart';

/// Invite-only family portal — deliberately minimal.
///
/// A family member sees ONLY their own scheduled call: crew name, slot,
/// consent + briefing acknowledgement, and the join button. No station
/// telemetry, no inventory, no roster, no station switcher. Research
/// confidentiality is preserved by construction.
class FamilyPortalScreen extends StatefulWidget {
  const FamilyPortalScreen({super.key});

  @override
  State<FamilyPortalScreen> createState() => _FamilyPortalScreenState();
}

class _FamilyPortalScreenState extends State<FamilyPortalScreen> {
  bool _consentChecked = false;
  bool _briefingChecked = false;

  FamilyInvite? _resolveInvite(PolarDataService data, String uid) {
    // Family sessions use uid 'fam_<inviteId>' (see _FamilyInviteForm).
    final inviteId = uid.startsWith('fam_') ? uid.substring(4) : uid;
    for (final invite in data.familyInvites) {
      if (invite.id == inviteId) return invite;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    if (user == null) {
      return const Center(child: Text('SESSION EXPIRED — PLEASE LOG IN AGAIN'));
    }

    final invite = _resolveInvite(data, user.uid);
    if (invite == null) {
      return Center(
        child: Text(
          'INVITE NOT FOUND // CONTACT HQ',
          style: AppTypography.telemetrySm.copyWith(
            color: context.appColors.critical,
          ),
        ),
      );
    }

    // Entry gate: disclaimer must be signed BEFORE any call access.
    if (!invite.disclaimerAccepted) {
      return _disclaimerGate(context, data, invite);
    }

    final booking = data.getBookingById(invite.bookingId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(invite),
          const SizedBox(height: 12),
          if (booking != null) _callCard(context, data, invite, booking),
          const SizedBox(height: 12),
          _briefingCard(),
          const SizedBox(height: 12),
          _consentCard(context, data, invite),
        ],
      ),
    );
  }

  Widget _headerCard(FamilyInvite invite) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: context.appColors.nominal.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.appColors.nominal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.appColors.nominal),
            ),
            child: Icon(
              Icons.family_restroom,
              color: context.appColors.nominal,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HELLO, ${invite.familyContactName.toUpperCase()}',
                  style: AppTypography.titleMd.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
                Text(
                  'Call with ${invite.personName}',
                  style: AppTypography.telemetrySm.copyWith(
                    color: context.appColors.nominal,
                  ),
                ),
                Text(
                  'INVITE ${invite.inviteCode}',
                  style: AppTypography.telemetryXs.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _callCard(
    BuildContext context,
    PolarDataService data,
    FamilyInvite invite,
    CallBooking booking,
  ) {
    final slot = booking.scheduledSlot;
    final slotLabel =
        '${slot.day}/${slot.month}/${slot.year} ${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')} UTC';
    final isVideo = booking.channelType != 'satellite-voice';
    final consented = invite.consentGiven && invite.briefingAcked;
    // Mutual clearance: family consent + crew disclaimer + live slot.
    final crewCleared = booking.crewDisclaimerSigned;
    final live = booking.status == 'booked' || booking.status == 'live';
    final joinable = consented && crewCleared && live;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR SCHEDULED CALL',
            style: AppTypography.labelSm.copyWith(
              letterSpacing: 1.2,
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _row('CREW MEMBER', invite.personName),
          _row('SLOT', slotLabel),
          _row('DURATION', '${booking.durationMinutes} minutes'),
          _row(
            'CHANNEL',
            isVideo ? 'Video (low-res satellite)' : 'Satellite voice',
          ),
          _row('STATUS', booking.status.toUpperCase()),
          _row(
            'CREW DISCLAIMER',
            crewCleared
                ? 'SIGNED BY ${(booking.crewDisclaimerBy ?? 'CREW').toUpperCase()}'
                : 'PENDING — CREW MUST SIGN FIRST',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: joinable
                  ? () => _joinCall(context, booking, invite)
                  : null,
              icon: Icon(
                isVideo ? Icons.videocam : Icons.phone_in_talk,
                size: 16,
              ),
              label: Text(
                joinable
                    ? (isVideo ? 'JOIN VIDEO CALL' : 'JOIN VOICE CALL')
                    : 'WAITING FOR CLEARANCE',
              ),
            ),
          ),
          if (!joinable)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                !consented
                    ? 'Confirm consent below to proceed.'
                    : !crewCleared
                    ? 'The crew member must sign their disclaimer before you can join.'
                    : 'This slot is no longer live. Contact HQ.',
                style: AppTypography.telemetryXs.copyWith(
                  color: context.appColors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.telemetryXs.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMd.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _briefingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surfaceLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: context.appColors.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: context.appColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'CALL BRIEFING — PLEASE READ',
                style: AppTypography.labelSm.copyWith(
                  color: context.appColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• This call is on an official Government of India satellite link.\n'
            '• Calls are logged and may be recorded for security (DPDP Act 2023).\n'
            '• Please do not ask about research work, locations, equipment or operations — crew cannot discuss them.\n'
            '• Keep the conversation to family and personal matters.',
            style: AppTypography.bodyMd.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _consentCard(
    BuildContext context,
    PolarDataService data,
    FamilyInvite invite,
  ) {
    if (invite.consentGiven && invite.briefingAcked) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: context.appColors.nominal.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.verified_outlined,
              size: 16,
              color: context.appColors.nominal,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CONSENT RECORDED — HQ has your acknowledgement on file.',
                style: AppTypography.bodyMd.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: context.appColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONSENT & ACKNOWLEDGEMENT',
            style: AppTypography.labelSm.copyWith(
              letterSpacing: 1.2,
              color: context.appColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          CheckboxListTile(
            value: _consentChecked,
            onChanged: (v) => setState(() => _consentChecked = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'I consent to this call being logged and recorded for security.',
              style: AppTypography.bodyMd.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          CheckboxListTile(
            value: _briefingChecked,
            onChanged: (v) => setState(() => _briefingChecked = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'I have read the briefing and will not ask about research or operations.',
              style: AppTypography.bodyMd.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_consentChecked && _briefingChecked)
                  ? () {
                      data.confirmFamilyConsent(invite.id);
                      setState(() {});
                    }
                  : null,
              child: Text('CONFIRM & UNLOCK JOIN'),
            ),
          ),
        ],
      ),
    );
  }

  void _joinCall(
    BuildContext context,
    CallBooking booking,
    FamilyInvite invite,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          booking: booking,
          displayName: invite.familyContactName,
          isFamilySide: true,
        ),
      ),
    );
  }

  /// Blocking entry gate — full disclaimer text, typed signature matching
  /// the invited name, plus read-confirmation. Nothing else renders first.
  Widget _disclaimerGate(
    BuildContext context,
    PolarDataService data,
    FamilyInvite invite,
  ) {
    final nameCtrl = TextEditingController();
    bool readChecked = false;
    String? error;

    return StatefulBuilder(
      builder: (context, setGateState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.appColors.critical.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: context.appColors.critical,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.gavel_outlined,
                    color: context.appColors.critical,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'CALL DISCLAIMER — SIGN TO ENTER',
                  style: AppTypography.headlineSm.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.critical,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Text(
                  '1. This is an official Government of India satellite link to an Antarctic/Arctic research station.\n\n'
                  '2. All calls are logged and may be recorded for security under the DPDP Act 2023 and the IT Act 2000.\n\n'
                  '3. Research work, station locations, equipment, personnel movements and operations are CONFIDENTIAL. Do not ask about them; crew are forbidden from discussing them.\n\n'
                  '4. Keep the conversation strictly to family and personal matters.\n\n'
                  '5. Misuse of this access (recording, relaying or publishing call contents) will lead to permanent withdrawal of call privileges and may invite legal action.\n\n'
                  'Invite: ${invite.inviteCode}  •  Crew: ${invite.personName}',
                  style: AppTypography.bodyMd.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'TYPE YOUR FULL NAME AS SIGNATURE',
                style: AppTypography.labelSm.copyWith(
                  letterSpacing: 0.8,
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: AppTypography.telemetrySm.copyWith(
                  color: context.appColors.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Type your full name',
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setGateState(() => error = null);
                },
              ),
              CheckboxListTile(
                value: readChecked,
                onChanged: (v) => setGateState(() => readChecked = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'I have read the disclaimer above and agree to every clause.',
                  style: AppTypography.bodyMd.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final ok = data.acceptFamilyDisclaimer(
                      inviteId: invite.id,
                      signedName: nameCtrl.text,
                      readConfirmed: readChecked,
                    );
                    if (!ok) {
                      setGateState(
                        () =>
                            error = 'Type your name and tick the box to enter.',
                      );
                      return;
                    }
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appColors.critical,
                    foregroundColor: context.appColors.onCritical,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('SIGN & ENTER CALL ACCESS'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
