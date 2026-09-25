import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/app_constants.dart';
import '../../models/personnel.dart';
import '../../services/polar_data_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_role.dart';
import '../../core/utils/validators.dart';
import '../widgets/station_selector_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_card.dart';
import '../widgets/tactical_avatar.dart';

/// Stitch Screen: Personnel Roster
class PersonnelScreen extends StatefulWidget {
  const PersonnelScreen({super.key});

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  String _selectedRole = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final station = data.selectedStation;
    final allPersonnel = data.selectedStationPersonnel;
    final canEdit = user?.canEditStation(station.id) ?? false;
    final canViewMedical = user?.canViewMedical(station.id) ?? false;

    final filtered = allPersonnel.where((p) {
      final matchesRole =
          _selectedRole == 'All' ||
          p.role.toLowerCase() == _selectedRole.toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.specialization.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesRole && matchesSearch;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Selector Strip
          const StationSelectorBar(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personnel Telemetry
                Row(
                  children: [
                    Expanded(
                      child: TelemetryCard(
                        label: 'Station Roster',
                        value: '${allPersonnel.length}',
                        unit: 'MEMBERS',
                        subtext: '44th Wintering Team',
                        icon: Icons.groups,
                        accentColor: context.appColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Medical Clearance',
                        value: '100%',
                        unit: 'PASSED',
                        subtext: 'NCPOR Medical Protocol',
                        icon: Icons.health_and_safety_outlined,
                        accentColor: context.appColors.nominal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Active On-Duty',
                        value:
                            '${allPersonnel.where((p) => p.status == 'on-station').length}',
                        unit: 'ON-SITE',
                        subtext: 'Zero Evacuations',
                        icon: Icons.verified_user_outlined,
                        accentColor: context.appColors.nominal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Search & Add Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: AppTypography.telemetrySm.copyWith(
                          color: context.appColors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search crew by name or discipline...',
                          prefixIcon: Icon(
                            Icons.search,
                            size: 16,
                            color: context.appColors.onSurfaceVariant,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (canEdit) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddPersonDialog(
                          context,
                          data,
                          station.id,
                          user,
                        ),
                        icon: Icon(Icons.person_add, size: 14),
                        label: Text('ENROLL CREW'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          textStyle: AppTypography.labelSm,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Role Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AppConstants.personnelRoles.map((role) {
                      final isSelected =
                          _selectedRole.toLowerCase() == role.toLowerCase();

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            role.toUpperCase(),
                            style: AppTypography.telemetryXs.copyWith(
                              color: isSelected
                                  ? context.appColors.canvas
                                  : context.appColors.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedRole = role);
                          },
                          selectedColor: context.appColors.primary,
                          backgroundColor: context.appColors.surfaceLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                            side: BorderSide(
                              color: isSelected
                                  ? context.appColors.primary
                                  : context.appColors.border,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // Crew List
                Text(
                  'EXPEDITION ROSTER (${filtered.length} MEMBERS)',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.2,
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'NO PERSONNEL RECORD FOUND',
                        style: AppTypography.telemetrySm.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...filtered.map((person) {
                    final daysOnStation = DateTime.now()
                        .difference(person.arrivalDate)
                        .inDays;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: context.appColors.border),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TacticalAvatar(
                                imageUrl: person.avatarUrl,
                                name: person.name,
                                radius: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          person.name,
                                          style: AppTypography.titleMd.copyWith(
                                            color: context.appColors.onSurface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        StatusBadge(
                                          status: person.status,
                                          isPill: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${person.role.toUpperCase()} • ${person.specialization}',
                                      style: AppTypography.telemetryXs.copyWith(
                                        color: context.appColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.appColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'DEPLOYMENT DURATION',
                                        style: AppTypography.telemetryXs
                                            .copyWith(
                                              color: context
                                                  .appColors
                                                  .onSurfaceVariant,
                                              fontSize: 8.5,
                                            ),
                                      ),
                                      Text(
                                        '$daysOnStation Days on Station',
                                        style: AppTypography.telemetrySm
                                            .copyWith(
                                              color:
                                                  context.appColors.onSurface,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'BLOOD GROUP',
                                        style: AppTypography.telemetryXs
                                            .copyWith(
                                              color: context
                                                  .appColors
                                                  .onSurfaceVariant,
                                              fontSize: 8.5,
                                            ),
                                      ),
                                      Text(
                                        canViewMedical
                                            ? person.bloodGroup
                                            : 'RESTRICTED',
                                        style: AppTypography.telemetrySm
                                            .copyWith(
                                              color: canViewMedical
                                                  ? context.appColors.nominal
                                                  : context
                                                        .appColors
                                                        .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MED-CLEARANCE',
                                        style: AppTypography.telemetryXs
                                            .copyWith(
                                              color: context
                                                  .appColors
                                                  .onSurfaceVariant,
                                              fontSize: 8.5,
                                            ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: context.appColors.nominal,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'CLEARED',
                                            style: AppTypography.telemetryXs
                                                .copyWith(
                                                  color:
                                                      context.appColors.nominal,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 6),
                          Text(
                            canViewMedical
                                ? 'EMERGENCY CONTACT: ${person.emergencyContact}'
                                : 'EMERGENCY CONTACT: [CONFIDENTIAL - HQ ONLY]',
                            style: AppTypography.telemetryXs.copyWith(
                              color: context.appColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPersonDialog(
    BuildContext context,
    PolarDataService data,
    String stationId,
    UserProfile? user,
  ) {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final contactCtrl = TextEditingController(text: '+91 98');
    String role = 'researcher';
    String blood = 'O+';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: context.appColors.surfaceHigh,
              title: Text(
                'ENROLL EXPEDITION MEMBER',
                style: AppTypography.titleMd,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name & Title',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      dropdownColor: context.appColors.surfaceHigh,
                      decoration: const InputDecoration(
                        labelText: 'Operational Role',
                      ),
                      items:
                          [
                            'researcher',
                            'crew',
                            'medical',
                            'logistics',
                            'station-lead',
                          ].map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(r.toUpperCase()),
                            );
                          }).toList(),
                      onChanged: (v) =>
                          setDlgState(() => role = v ?? 'researcher'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: specCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Scientific Specialization / Trade',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: blood,
                            dropdownColor: context.appColors.surfaceHigh,
                            decoration: const InputDecoration(
                              labelText: 'Blood Group',
                            ),
                            items:
                                [
                                  'O+',
                                  'O-',
                                  'A+',
                                  'A-',
                                  'B+',
                                  'B-',
                                  'AB+',
                                  'AB-',
                                ].map((b) {
                                  return DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  );
                                }).toList(),
                            onChanged: (v) =>
                                setDlgState(() => blood = v ?? 'O+'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: contactCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Emergency Contact',
                            ),
                          ),
                        ),
                      ],
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
                    final nameErr = Validators.validateRequired(
                      nameCtrl.text,
                      'Full Name',
                    );
                    if (nameErr != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(nameErr),
                          backgroundColor: context.appColors.critical,
                        ),
                      );
                      return;
                    }
                    final person = Personnel(
                      id: const Uuid().v4(),
                      stationId: stationId,
                      name: nameCtrl.text.trim(),
                      role: role,
                      specialization: specCtrl.text.trim().isEmpty
                          ? 'General Operations'
                          : specCtrl.text.trim(),
                      arrivalDate: DateTime.now(),
                      status: 'on-station',
                      bloodGroup: blood,
                      emergencyContact: contactCtrl.text.trim(),
                      avatarUrl:
                          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
                      medicalCleared: true,
                    );
                    final success = data.addPersonnel(person, user: user);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Expedition crew enrolled successfully'
                              : 'Permission denied or duplicate ID',
                          style: TextStyle(
                            color: success
                                ? context.appColors.onNominalContainer
                                : context.appColors.onCritical,
                          ),
                        ),
                        backgroundColor: success
                            ? context.appColors.nominalContainer
                            : context.appColors.critical,
                      ),
                    );
                  },
                  child: Text('ENROLL'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
