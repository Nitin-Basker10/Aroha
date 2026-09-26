import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/call_access.dart';
import '../../models/comms_message.dart';
import '../../models/call_booking.dart';
import '../../models/resource_request.dart';
import '../../models/user_role.dart';
import '../../services/polar_data_service.dart';
import '../../services/auth_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_card.dart';
import '../calls/video_call_screen.dart';

/// Communication Hub with Cross-Station Messaging & Resource Requests
class CommsHubScreen extends StatefulWidget {
  const CommsHubScreen({super.key});

  @override
  State<CommsHubScreen> createState() => _CommsHubScreenState();
}

/// Structured recipient target — avoids fragile string parsing of display names.
class _RecipientOption {
  final String id; // 'hq_admin' or station id
  final String displayName;
  final String? stationId; // null for HQ
  const _RecipientOption({
    required this.id,
    required this.displayName,
    this.stationId,
  });
}

class _CommsHubScreenState extends State<CommsHubScreen> {
  final _msgContentCtrl = TextEditingController();
  String _selectedPriority = 'routine';
  _RecipientOption? _selectedRecipient;

  @override
  void dispose() {
    _msgContentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final messages = data.getMessagesForUser(user);
    final bookings = data.getVisibleCallBookings(user);

    // Resource requests for current user's station or all for HQ
    final isHQ = user?.role == UserRole.hqAdmin;
    final userStationId = user?.linkedStationId;
    final resourceRequests = isHQ
        ? data.resourceRequests
        : data.getResourceRequestsForStation(userStationId);

    // Pending incoming requests count (requests sent TO this station that are still pending)
    final pendingIncoming = isHQ
        ? data.resourceRequests.where((r) => r.isPending).length
        : resourceRequests
              .where((r) => r.toStationId == userStationId && r.isPending)
              .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comms Link Telemetry
          Row(
            children: [
              Expanded(
                child: TelemetryCard(
                  label: 'Call Link',
                  value: 'LOCAL',
                  unit: 'PREVIEW',
                  subtext: 'Remote relay not configured',
                  icon: Icons.satellite_alt,
                  accentColor: context.appColors.nominal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TelemetryCard(
                  label: 'Cross-Station',
                  value: '${resourceRequests.length}',
                  unit: 'REQUESTS',
                  subtext: '$pendingIncoming Pending',
                  icon: Icons.swap_horiz,
                  accentColor: pendingIncoming > 0
                      ? context.appColors.warning
                      : context.appColors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TelemetryCard(
                  label: 'Call Bookings',
                  value:
                      '${bookings.where((b) => b.status == 'booked').length}',
                  unit: 'SLOTS',
                  subtext: 'Reserved Time Slots',
                  icon: Icons.calendar_month,
                  accentColor: context.appColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Cross-Station Resource Requests Panel
          _buildResourceRequestsSection(context, data, auth, resourceRequests),

          const SizedBox(height: 16),

          // Message Composer Card
          _buildMessageComposer(context, data, auth),

          const SizedBox(height: 16),

          // Satellite Call Reservation Section
          _buildCallReservations(context, data, auth, bookings),

          const SizedBox(height: 16),

          // Message Log Section
          _buildMessageLog(context, messages, user),
        ],
      ),
    );
  }

  // =====================================================
  // CROSS-STATION RESOURCE REQUESTS SECTION
  // =====================================================
  Widget _buildResourceRequestsSection(
    BuildContext context,
    PolarDataService data,
    AuthService auth,
    List<ResourceRequest> requests,
  ) {
    final user = auth.currentUser;
    final isHQ = user?.role == UserRole.hqAdmin;
    final userStationId = user?.linkedStationId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + action stay on one line on wide screens and stack on a
        // handset, where a 34-character label plus a button cannot fit.
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 14,
                  color: context.appColors.nominal,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'CROSS-STATION RESOURCE REQUESTS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      letterSpacing: 1.2,
                      color: context.appColors.nominal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
            final action = !isHQ
                ? ElevatedButton.icon(
                    onPressed: () =>
                        _showCreateResourceRequestDialog(context, data, auth),
                    icon: Icon(Icons.add, size: 13),
                    label: Text('REQUEST SUPPLIES'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appColors.surfaceHigh,
                      foregroundColor: context.appColors.onSurface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      textStyle: AppTypography.labelSm,
                    ),
                  )
                : null;
            if (action == null) return title;
            if (constraints.maxWidth >= 520) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [title, action],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 8), action],
            );
          },
        ),
        const SizedBox(height: 8),

        if (requests.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: context.appColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 24,
                  color: context.appColors.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  'No cross-station resource requests.',
                  style: AppTypography.bodySm.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Request supplies from another station when running low.',
                  style: AppTypography.telemetryXs.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...requests.map((req) {
            final urgencyColor = context.appColors.status(req.urgency);
            final statusColor = _getRequestStatusColor(req.status);
            final isIncoming = req.toStationId == userStationId;
            final canRespond = isIncoming && req.isPending && !isHQ;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: req.urgency == 'emergency'
                      ? context.appColors.critical.withValues(alpha: 0.5)
                      : context.appColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isIncoming ? Icons.call_received : Icons.call_made,
                        size: 14,
                        color: isIncoming
                            ? context.appColors.nominal
                            : context.appColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: urgencyColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          req.urgency.toUpperCase(),
                          style: AppTypography.telemetryXs.copyWith(
                            color: urgencyColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${req.requestedItem} (${req.requestedQuantity.toStringAsFixed(0)} ${req.unit})',
                          style: AppTypography.titleSm.copyWith(
                            color: context.appColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          req.status.toUpperCase(),
                          style: AppTypography.telemetryXs.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          req.fromStationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.telemetryXs.copyWith(
                            color: context.appColors.primary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 10,
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          req.toStationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.telemetryXs.copyWith(
                            color: context.appColors.nominal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'By: ${req.requestedByName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: AppTypography.telemetryXs.copyWith(
                            color: context.appColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (req.responseNotes != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceLow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 12,
                            color: context.appColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${req.respondedByName}: ${req.responseNotes}',
                              style: AppTypography.telemetryXs.copyWith(
                                color: context.appColors.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (canRespond) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _respondToRequest(
                            context,
                            data,
                            auth,
                            req,
                            'denied',
                          ),
                          icon: Icon(Icons.close, size: 12),
                          label: Text('DENY'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.appColors.critical,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            textStyle: AppTypography.telemetryXs.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(color: context.appColors.critical),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () => _respondToRequest(
                            context,
                            data,
                            auth,
                            req,
                            'approved',
                          ),
                          icon: Icon(Icons.check, size: 12),
                          label: Text('APPROVE'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            textStyle: AppTypography.telemetryXs.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Color _getRequestStatusColor(String status) {
    return context.appColors.status(status);
  }

  void _respondToRequest(
    BuildContext context,
    PolarDataService data,
    AuthService auth,
    ResourceRequest request,
    String status,
  ) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.appColors.surfaceHigh,
          title: Text(
            status == 'approved' ? 'APPROVE REQUEST' : 'DENY REQUEST',
            style: AppTypography.titleMd,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${request.requestedItem} — ${request.requestedQuantity.toStringAsFixed(0)} ${request.unit}',
                style: AppTypography.titleSm.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
              Text(
                'From: ${request.fromStationName}',
                style: AppTypography.telemetryXs.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Response Notes (optional)',
                  hintText: 'e.g., Will dispatch on next logistics run...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                notesCtrl.dispose();
                Navigator.of(ctx).pop();
              },
              child: Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final ok = data.respondToResourceRequest(
                  request.id,
                  status: status,
                  responseNotes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  respondedByName: auth.currentUser?.name ?? 'Station Operator',
                  user: auth.currentUser,
                );
                notesCtrl.dispose();
                Navigator.of(ctx).pop();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Not permitted for your station'),
                      backgroundColor: context.appColors.critical,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'approved'
                    ? context.appColors.nominal
                    : context.appColors.critical,
                foregroundColor: status == 'approved'
                    ? context.appColors.onNominal
                    : context.appColors.onCritical,
              ),
              child: Text(status == 'approved' ? 'APPROVE' : 'DENY'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateResourceRequestDialog(
    BuildContext context,
    PolarDataService data,
    AuthService auth,
  ) {
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'units');
    String urgency = 'routine';
    final user = auth.currentUser;
    final otherStations = data.getOtherStations(user?.linkedStationId);
    String? targetStationId = otherStations.isNotEmpty
        ? otherStations.first.id
        : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: context.appColors.surfaceHigh,
              title: Text(
                'REQUEST SUPPLIES FROM ANOTHER STATION',
                style: AppTypography.titleMd,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: targetStationId,
                      dropdownColor: context.appColors.surfaceHigh,
                      decoration: const InputDecoration(
                        labelText: 'Target Station',
                      ),
                      items: otherStations.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (v) => setDlgState(() => targetStationId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g., Medical Oxygen Cylinders',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              hintText: '0',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              hintText: 'e.g., kg, liters, units',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: urgency,
                      dropdownColor: context.appColors.surfaceHigh,
                      decoration: const InputDecoration(labelText: 'Urgency'),
                      items: ['routine', 'urgent', 'emergency'].map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text(u.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setDlgState(() => urgency = v ?? 'routine'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    itemCtrl.dispose();
                    qtyCtrl.dispose();
                    unitCtrl.dispose();
                    Navigator.of(ctx).pop();
                  },
                  child: Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                    String? err;
                    if (targetStationId == null) {
                      err = 'Select a target station';
                    } else if (itemCtrl.text.trim().isEmpty) {
                      err = 'Item name is required';
                    } else if (qty <= 0) {
                      err = 'Quantity must be greater than 0';
                    }
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err),
                          backgroundColor: context.appColors.critical,
                        ),
                      );
                      return;
                    }
                    final request = ResourceRequest(
                      id: const Uuid().v4(),
                      fromStationId:
                          user?.linkedStationId ?? data.selectedStationId,
                      fromStationName: data.getStationName(
                        user?.linkedStationId ?? data.selectedStationId,
                      ),
                      toStationId: targetStationId!,
                      toStationName: data.getStationName(targetStationId!),
                      requestedItem: itemCtrl.text.trim(),
                      requestedQuantity: qty,
                      unit: unitCtrl.text.trim().isEmpty
                          ? 'units'
                          : unitCtrl.text.trim(),
                      urgency: urgency,
                      status: 'pending',
                      requestedByUserId: user?.uid ?? 'unknown',
                      requestedByName: user?.name ?? 'Station Operator',
                      createdAt: DateTime.now(),
                    );
                    final ok = data.createResourceRequest(request, user: user);
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Not permitted for your station'),
                          backgroundColor: context.appColors.critical,
                        ),
                      );
                      return;
                    }
                    itemCtrl.dispose();
                    qtyCtrl.dispose();
                    unitCtrl.dispose();
                    Navigator.of(ctx).pop();
                  },
                  child: Text('SUBMIT REQUEST'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // MESSAGE COMPOSER
  // =====================================================
  Widget _buildMessageComposer(
    BuildContext context,
    PolarDataService data,
    AuthService auth,
  ) {
    final user = auth.currentUser;
    final isHQ = user?.role == UserRole.hqAdmin;

    // Structured recipient options — id routes correctly via getMessagesForUser
    final recipients = <_RecipientOption>[
      const _RecipientOption(
        id: 'hq_admin',
        displayName: 'NCPOR Goa Operations Center',
        stationId: null,
      ),
    ];
    if (!isHQ) {
      final otherStations = data.getOtherStations(user?.linkedStationId);
      for (final s in otherStations) {
        recipients.add(
          _RecipientOption(
            id: s.id,
            displayName: '${s.name} Ops',
            stationId: s.id,
          ),
        );
      }
    } else {
      for (final s in data.stations) {
        recipients.add(
          _RecipientOption(
            id: s.id,
            displayName: '${s.name} Ops',
            stationId: s.id,
          ),
        );
      }
    }

    // Ensure selected recipient is still valid
    if (_selectedRecipient == null ||
        !recipients.any((r) => r.id == _selectedRecipient!.id)) {
      _selectedRecipient = recipients.first;
    }
    final selected = _selectedRecipient!;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'TACTICAL SATELLITE DISPATCH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.2,
                    color: context.appColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: context.appColors.nominal,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'DEMO CHANNEL — NO E2E SIGNALING',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.telemetryXs.copyWith(
                          color: context.appColors.nominal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Sender identification banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: context.appColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                Icon(Icons.person, size: 14, color: context.appColors.nominal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'TRANSMITTER: ${user?.name ?? "Authorized Operator"} (${user?.role.label ?? "Station Staff"})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.telemetryXs.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Recipient selector
          DropdownButtonFormField<String>(
            initialValue: selected.id,
            dropdownColor: context.appColors.surfaceHigh,
            decoration: InputDecoration(
              labelText: 'RECIPIENT',
              labelStyle: AppTypography.telemetryXs.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            style: AppTypography.bodySm.copyWith(
              color: context.appColors.onSurface,
            ),
            items: recipients.map((r) {
              return DropdownMenuItem(value: r.id, child: Text(r.displayName));
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(
                () => _selectedRecipient = recipients.firstWhere(
                  (r) => r.id == v,
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _msgContentCtrl,
            maxLines: 2,
            style: AppTypography.bodyMd.copyWith(
              color: context.appColors.onSurface,
            ),
            decoration: const InputDecoration(
              hintText:
                  'Enter mission dispatch report, telemetry observation, or crew notification...',
            ),
          ),

          const SizedBox(height: 10),

          // Wrap instead of Row: three priority chips plus a send button do not
          // fit on one line on a handset.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Text('PRIORITY: ', style: AppTypography.labelSm),
              ...['routine', 'urgent', 'emergency'].map((p) {
                final isSel = _selectedPriority == p;
                final col = context.appColors.status(p);

                return ChoiceChip(
                  label: Text(
                    p.toUpperCase(),
                    style: AppTypography.telemetryXs.copyWith(
                      color: isSel ? context.appColors.canvas : col,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: isSel,
                  onSelected: (s) {
                    if (s) setState(() => _selectedPriority = p);
                  },
                  selectedColor: col,
                  backgroundColor: context.appColors.surfaceLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                    side: BorderSide(
                      color: isSel ? col : context.appColors.border,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }),
              ElevatedButton.icon(
                onPressed: () {
                  if (_msgContentCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Message content cannot be empty'),
                        backgroundColor: context.appColors.critical,
                      ),
                    );
                    return;
                  }
                  final currentStation = data.selectedStation;
                  final opt = _selectedRecipient!;
                  final msg = CommsMessage(
                    id: const Uuid().v4(),
                    senderId: user?.uid ?? 'station_op',
                    senderName: user?.name ?? 'Lead Station Operator',
                    senderStation: user?.linkedStationId != null
                        ? currentStation.name
                        : 'NCPOR Goa HQ',
                    recipientId: opt.id,
                    recipientName: opt.displayName,
                    content: _msgContentCtrl.text.trim(),
                    priority: _selectedPriority,
                    sentAt: DateTime.now(),
                    stationId: user?.linkedStationId,
                    recipientStationId: opt.stationId,
                  );
                  data.sendMessage(msg, user: user);
                  _msgContentCtrl.clear();
                },
                icon: Icon(Icons.send, size: 13),
                label: Text('TRANSMIT'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SATELLITE CALL RESERVATIONS
  // =====================================================
  Widget _buildCallReservations(
    BuildContext context,
    PolarDataService data,
    AuthService auth,
    List<CallBooking> bookings,
  ) {
    final currentUser = auth.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'SATELLITE CALL RESERVATIONS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSm.copyWith(
                  letterSpacing: 1.2,
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ElevatedButton.icon(
                onPressed: () => _showBookCallDialog(context, data, auth),
                icon: Icon(Icons.phone_in_talk, size: 13),
                label: Text(
                  'BOOK SATELLITE SLOT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appColors.surfaceHigh,
                  foregroundColor: context.appColors.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: AppTypography.labelSm,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (bookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: context.appColors.border),
            ),
            child: Text(
              'No active satellite call reservations.',
              style: AppTypography.bodySm.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          )
        else
          ...bookings.map((booking) {
            final canInvite =
                currentUser?.canEditStation(booking.stationId) ?? false;
            final invite = data.getInviteForBooking(booking.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: context.appColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        booking.channelType == 'satellite-voice'
                            ? Icons.phone_in_talk
                            : Icons.videocam,
                        size: 16,
                        color: context.appColors.nominal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    booking.personName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.titleSm,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '-> ${booking.familyContactName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySm.copyWith(
                                      color: context.appColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Duration: ${booking.durationMinutes}m | Channel: ${booking.channelType}',
                              style: AppTypography.telemetryXs.copyWith(
                                color: context.appColors.onSurfaceVariant,
                              ),
                            ),
                            if (booking.familyConsentGiven)
                              Text(
                                'FAMILY CONSENT ON FILE',
                                style: AppTypography.telemetryXs.copyWith(
                                  color: context.appColors.nominal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            Text(
                              booking.crewDisclaimerSigned
                                  ? 'CREW DISCLAIMER SIGNED: ${booking.crewDisclaimerBy}'
                                  : 'CREW DISCLAIMER: PENDING',
                              style: AppTypography.telemetryXs.copyWith(
                                color: booking.crewDisclaimerSigned
                                    ? context.appColors.nominal
                                    : context.appColors.critical,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: booking.status),
                    ],
                  ),
                  // Wrap: sign / join / invite controls plus a disabled-state
                  // label do not fit on one line on a handset.
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!booking.crewDisclaimerSigned && canInvite)
                        OutlinedButton.icon(
                          onPressed: () => _showCrewDisclaimer(
                            context,
                            data,
                            auth,
                            booking.id,
                          ),
                          icon: Icon(Icons.gavel_outlined, size: 13),
                          label: Text('SIGN DISCLAIMER'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.appColors.critical,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            textStyle: AppTypography.telemetryXs.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(color: context.appColors.critical),
                          ),
                        ),
                      OutlinedButton.icon(
                        // Both sides must clear compliance before either
                        // joins: crew disclaimer + family consent + live slot.
                        onPressed: _canJoinBooking(auth, booking)
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => VideoCallScreen(
                                      booking: booking,
                                      displayName:
                                          auth.currentUser?.name ??
                                          'Station Operator',
                                    ),
                                  ),
                                );
                              }
                            : null,
                        icon: Icon(
                          booking.channelType == 'satellite-voice'
                              ? Icons.phone_in_talk
                              : Icons.videocam,
                          size: 13,
                        ),
                        label: Text(
                          _canJoinBooking(auth, booking)
                              ? (booking.channelType == 'satellite-voice'
                                    ? 'JOIN VOICE'
                                    : 'JOIN VIDEO')
                              : _joinBlockedLabel(booking),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          textStyle: AppTypography.telemetryXs.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (canInvite)
                        if (invite != null)
                          InkWell(
                            onTap: () =>
                                _showInviteCode(context, invite.inviteCode),
                            child: Text(
                              'INVITE: ${invite.inviteCode} (TAP TO VIEW)',
                              style: AppTypography.telemetryXs.copyWith(
                                color: context.appColors.nominal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: currentUser == null
                                ? null
                                : () {
                                    final created = data.createFamilyInvite(
                                      bookingId: booking.id,
                                      createdBy: currentUser,
                                    );
                                    if (created != null && context.mounted) {
                                      _showInviteCode(
                                        context,
                                        created.inviteCode,
                                      );
                                    }
                                  },
                            icon: Icon(Icons.family_restroom, size: 13),
                            label: Text('INVITE FAMILY'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              textStyle: AppTypography.telemetryXs.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showCrewDisclaimer(
    BuildContext context,
    PolarDataService data,
    AuthService auth,
    String bookingId,
  ) {
    final signer = auth.currentUser;
    if (signer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in again before signing')),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: signer.name);
    bool readChecked = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: context.appColors.surfaceHigh,
              title: Text('CREW CALL DISCLAIMER', style: AppTypography.titleMd),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. This is an official Government of India satellite link.\n\n'
                      '2. The operator may monitor this session under station policy; this MVP does not record media.\n\n'
                      '3. You shall NOT discuss research, locations, equipment, personnel movements or operations. Family/personal matters only.\n\n'
                      '4. Breach will lead to disciplinary action under service rules.',
                      style: AppTypography.bodyMd.copyWith(
                        color: context.appColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: AppTypography.telemetrySm.copyWith(
                        color: context.appColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Sign with your full name',
                        errorText: error,
                      ),
                      onChanged: (_) {
                        if (error != null) setDlgState(() => error = null);
                      },
                    ),
                    CheckboxListTile(
                      value: readChecked,
                      onChanged: (v) =>
                          setDlgState(() => readChecked = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'I have read and accept every clause.',
                        style: AppTypography.bodyMd.copyWith(
                          color: context.appColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty || !readChecked) {
                      setDlgState(
                        () =>
                            error = 'Type your name and tick the box to sign.',
                      );
                      return;
                    }
                    final ok = data.signCrewDisclaimer(
                      bookingId: bookingId,
                      signedBy: signer,
                      signatoryName: nameCtrl.text,
                      readConfirmed: readChecked,
                    );
                    if (!ok) {
                      setDlgState(
                        () => error =
                            'Signing failed — station edit rights required.',
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appColors.critical,
                    foregroundColor: context.appColors.onCritical,
                  ),
                  child: Text('SIGN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _canJoinBooking(AuthService auth, CallBooking booking) {
    return CallAccessPolicy.canJoinAsCrew(auth.currentUser, booking);
  }

  /// Explains *why* a join button is disabled — a greyed-out button with no
  /// reason reads like a broken feature during a judge demo.
  String _joinBlockedLabel(CallBooking booking) {
    if (!CallAccessPolicy.isLive(booking)) return 'SLOT CLOSED';
    if (!CallAccessPolicy.hasBothClearances(booking)) {
      return 'CLEARANCE PENDING';
    }
    if (!CallAccessPolicy.isWithinJoinWindow(booking)) {
      return 'OPENS 10 MIN BEFORE SLOT';
    }
    return 'CLEARANCE PENDING';
  }

  void _showInviteCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.appColors.surfaceHigh,
          title: Text('FAMILY INVITE CODE', style: AppTypography.titleMd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share this code with the family member out-of-band (HQ call / email). It unlocks ONLY their call slot.',
                style: AppTypography.bodyMd.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: context.appColors.nominal),
                ),
                child: Text(
                  code,
                  style: AppTypography.telemetryLg.copyWith(
                    color: context.appColors.nominal,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('DONE'),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // MESSAGE LOG
  // =====================================================
  Widget _buildMessageLog(
    BuildContext context,
    List<CommsMessage> messages,
    UserProfile? user,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'DISPATCH LOG & COMMS RELAY (${messages.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSm.copyWith(
                  letterSpacing: 1.2,
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (messages.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.appColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox,
                  size: 28,
                  color: context.appColors.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'No dispatched transmissions in your queue.',
                  style: AppTypography.bodySm.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...messages.map((msg) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: msg.priority == 'emergency'
                      ? context.appColors.critical
                      : context.appColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            StatusBadge(status: msg.priority),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                msg.senderStation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: context.appColors.nominal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                ':: ${msg.senderName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!msg.read)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.appColors.primary.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            'NEW',
                            style: AppTypography.telemetryXs.copyWith(
                              color: context.appColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg.content,
                    style: AppTypography.bodyMd.copyWith(
                      color: context.appColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'To: ${msg.recipientName}',
                        style: AppTypography.telemetryXs.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${msg.sentAt.hour}:${msg.sentAt.minute.toString().padLeft(2, '0')} UTC',
                        style: AppTypography.telemetryXs.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // =====================================================
  // BOOK CALL DIALOG
  // =====================================================
  void _showBookCallDialog(
    BuildContext context,
    PolarDataService data,
    AuthService auth,
  ) {
    final contactCtrl = TextEditingController();
    String channel = 'satellite-voice';
    int dur = 15;
    // Join window opens 10 minutes before the slot, so "start now" is what a
    // crew member uses on shift. Later slots are genuinely not joinable yet.
    int startOffsetMinutes = 0;
    final user = auth.currentUser;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: context.appColors.surfaceHigh,
              title: Text(
                'RESERVE SATELLITE CALL SLOT',
                style: AppTypography.titleMd,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: contactCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Family Contact / Participant Name',
                      hintText: 'e.g. Priya Sharma (Spouse)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: channel,
                    dropdownColor: context.appColors.surfaceHigh,
                    decoration: const InputDecoration(
                      labelText: 'Channel Type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'satellite-voice',
                        child: Text('Satellite Voice Link'),
                      ),
                      DropdownMenuItem(
                        value: 'low-res-video',
                        child: Text('Low-Resolution Video Feed'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDlgState(() => channel = v ?? 'satellite-voice'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: dur,
                    dropdownColor: context.appColors.surfaceHigh,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: [10, 15, 20, 30].map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text('$d Minutes (Sat-Allotment)'),
                      );
                    }).toList(),
                    onChanged: (v) => setDlgState(() => dur = v ?? 15),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: startOffsetMinutes,
                    dropdownColor: context.appColors.surfaceHigh,
                    decoration: const InputDecoration(
                      labelText: 'Slot Start',
                      helperText:
                          'Join unlocks 10 minutes before the start time',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Start Now (On Shift)'),
                      ),
                      DropdownMenuItem(
                        value: 480,
                        child: Text('In 8 Hours (Next Allotment)'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDlgState(() => startOffsetMinutes = v ?? 0),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    contactCtrl.dispose();
                    Navigator.of(ctx).pop();
                  },
                  child: Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (contactCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Family contact name is required'),
                          backgroundColor: context.appColors.critical,
                        ),
                      );
                      return;
                    }
                    final booking = CallBooking(
                      id: const Uuid().v4(),
                      stationId:
                          user?.linkedStationId ?? data.selectedStationId,
                      personId: user?.linkedPersonId ?? user?.uid ?? 'unknown',
                      personName: user?.name ?? 'Station Crew Member',
                      familyContactName: contactCtrl.text.trim(),
                      scheduledSlot: DateTime.now().add(
                        Duration(minutes: startOffsetMinutes),
                      ),
                      durationMinutes: dur,
                      status: 'booked',
                      channelType: channel,
                    );
                    final ok = data.bookCallSlot(booking, user: user);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Not permitted for your station'),
                          backgroundColor: context.appColors.critical,
                        ),
                      );
                      return;
                    }
                    contactCtrl.dispose();
                    Navigator.of(ctx).pop();
                  },
                  child: Text('RESERVE SLOT'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
