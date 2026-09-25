/// User roles defined in PRD Section 3 & 4
/// Family portal removed — HQ contacts families directly outside the app
enum UserRole {
  hqAdmin(
    'hq-admin',
    'HQ Command Admin',
    'National Centre for Polar and Ocean Research (Goa HQ)',
  ),
  stationStaff(
    'station-staff',
    'Research Center Crew',
    'Maitri / Bharati / Himadri Expedition Staff',
  ),
  familyMember(
    'family-member',
    'Family Member',
    'Invite-only family call access — own slot only, no station data',
  );

  final String id;
  final String label;
  final String description;

  const UserRole(this.id, this.label, this.description);

  static UserRole fromId(String id) {
    return UserRole.values.firstWhere(
      (role) => role.id == id,
      orElse: () => UserRole.hqAdmin,
    );
  }

  /// Check if this role has a specific permission
  bool hasPermission(Permission perm) {
    return _rolePermissions[this]?.contains(perm) ?? false;
  }
}

/// Granular permission flags for role-based access control
enum Permission {
  viewAllStations,
  viewOwnStation,
  editInventory,
  editPersonnel,
  viewPersonnelMedical,
  resolveAlerts,
  accessCommandCenter,
  accessStationDetail,
  accessInventory,
  accessResupply,
  accessPersonnel,
  accessComms,
  sendMessages,
  crossStationComms,
  viewOperationalTelemetry,
  accessFamilyPortal,
}

/// Role → Permission matrix
const Map<UserRole, Set<Permission>> _rolePermissions = {
  UserRole.hqAdmin: {
    Permission.viewAllStations,
    Permission.viewOwnStation,
    Permission.editInventory,
    Permission.editPersonnel,
    Permission.viewPersonnelMedical,
    Permission.resolveAlerts,
    Permission.accessCommandCenter,
    Permission.accessStationDetail,
    Permission.accessInventory,
    Permission.accessResupply,
    Permission.accessPersonnel,
    Permission.accessComms,
    Permission.sendMessages,
    Permission.crossStationComms,
    Permission.viewOperationalTelemetry,
  },
  UserRole.stationStaff: {
    Permission.viewOwnStation,
    Permission.editInventory,
    Permission.editPersonnel,
    Permission.viewPersonnelMedical,
    Permission.resolveAlerts,
    Permission.accessStationDetail,
    Permission.accessInventory,
    Permission.accessResupply,
    Permission.accessPersonnel,
    Permission.accessComms,
    Permission.sendMessages,
    Permission.crossStationComms,
    Permission.viewOperationalTelemetry,
  },
  UserRole.familyMember: {Permission.accessFamilyPortal},
};

class UserProfile {
  final String uid;
  final String name;
  final UserRole role;
  final String email;
  final String? linkedStationId;
  final String? linkedPersonId;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.role,
    required this.email,
    this.linkedStationId,
    this.linkedPersonId,
  });

  /// Check if this user has a specific permission
  bool hasPermission(Permission perm) => role.hasPermission(perm);

  /// Check if user can access data for a given station.
  /// Family sessions are invite-scoped to one call slot and can never
  /// access station data, even for their linked station.
  bool canAccessStation(String stationId) {
    if (role == UserRole.familyMember) return false;
    if (role.hasPermission(Permission.viewAllStations)) return true;
    return linkedStationId == stationId;
  }

  /// Check if user can write/modify data for a given station.
  /// Family members can never edit, even for their linked station.
  bool canEditStation(String stationId) {
    if (role == UserRole.hqAdmin) return true;
    if (role != UserRole.stationStaff) return false;
    return linkedStationId == stationId;
  }

  /// Check if user can view medical records for personnel at a station
  bool canViewMedical(String stationId) {
    if (role == UserRole.hqAdmin) return true;
    return linkedStationId == stationId &&
        hasPermission(Permission.viewPersonnelMedical);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'role': role.id,
      'email': email,
      'linkedStationId': linkedStationId,
      'linkedPersonId': linkedPersonId,
    };
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] ?? '',
      role: UserRole.fromId(map['role'] ?? 'hq-admin'),
      email: map['email'] ?? '',
      linkedStationId: map['linkedStationId'],
      linkedPersonId: map['linkedPersonId'],
    );
  }
}
