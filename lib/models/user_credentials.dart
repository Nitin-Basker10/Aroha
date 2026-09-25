import '../models/user_role.dart';

/// Mock user credential store for authentication
/// In production, this would be backed by Firebase Auth / Firestore
class UserCredentialStore {
  UserCredentialStore._();

  /// All registered users in the system
  static final List<_UserCredential> _credentials = [
    // HQ Admin accounts (Goa HQ)
    _UserCredential(
      email: 'nitin.verma@ncpor.res.in',
      passwordHash: _hashPassword('admin@ncpor2026'),
      profile: const UserProfile(
        uid: 'hq_admin_01',
        name: 'Cmdr. Nitin Verma',
        role: UserRole.hqAdmin,
        email: 'nitin.verma@ncpor.res.in',
        linkedStationId: null,
        linkedPersonId: null,
      ),
    ),
    _UserCredential(
      email: 'ritu.kapoor@ncpor.res.in',
      passwordHash: _hashPassword('ops@ncpor2026'),
      profile: const UserProfile(
        uid: 'hq_admin_02',
        name: 'Dr. Ritu Kapoor',
        role: UserRole.hqAdmin,
        email: 'ritu.kapoor@ncpor.res.in',
        linkedStationId: null,
        linkedPersonId: null,
      ),
    ),

    // Station Staff accounts (Research Center crew)
    _UserCredential(
      email: 'aarav.sharma@maitri.ncpor.gov.in',
      passwordHash: _hashPassword('maitri@2026'),
      profile: const UserProfile(
        uid: 'staff_mtr_01',
        name: 'Dr. Aarav Sharma',
        role: UserRole.stationStaff,
        email: 'aarav.sharma@maitri.ncpor.gov.in',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_01',
      ),
    ),
    _UserCredential(
      email: 'rajesh.varma@maitri.ncpor.gov.in',
      passwordHash: _hashPassword('maitri@2026'),
      profile: const UserProfile(
        uid: 'staff_mtr_02',
        name: 'Sqn Ldr Rajesh Varma',
        role: UserRole.stationStaff,
        email: 'rajesh.varma@maitri.ncpor.gov.in',
        linkedStationId: 'maitri',
        linkedPersonId: 'per_mtr_02',
      ),
    ),
    _UserCredential(
      email: 'sunita.deshmukh@bharati.ncpor.gov.in',
      passwordHash: _hashPassword('bharati@2026'),
      profile: const UserProfile(
        uid: 'staff_bhr_01',
        name: 'Dr. Sunita Deshmukh',
        role: UserRole.stationStaff,
        email: 'sunita.deshmukh@bharati.ncpor.gov.in',
        linkedStationId: 'bharati',
        linkedPersonId: 'per_bhr_01',
      ),
    ),
    _UserCredential(
      email: 'alok.sengupta@himadri.ncpor.gov.in',
      passwordHash: _hashPassword('himadri@2026'),
      profile: const UserProfile(
        uid: 'staff_hmd_01',
        name: 'Dr. Alok Sengupta',
        role: UserRole.stationStaff,
        email: 'alok.sengupta@himadri.ncpor.gov.in',
        linkedStationId: 'himadri',
        linkedPersonId: 'per_hmd_01',
      ),
    ),
  ];

  /// Authenticate user by email, password, and expected role category
  /// Returns null if credentials are invalid or role doesn't match
  static UserProfile? authenticate({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final hash = _hashPassword(password);

    for (final cred in _credentials) {
      if (cred.email.toLowerCase() == normalizedEmail &&
          cred.passwordHash == hash &&
          cred.profile.role == expectedRole) {
        return cred.profile;
      }
    }
    return null;
  }

  /// Simple hash function for mock purposes
  /// In production, use Firebase Auth / bcrypt
  static String _hashPassword(String password) {
    // Simple deterministic hash for demo — NOT cryptographically secure
    int hash = 0;
    for (int i = 0; i < password.length; i++) {
      hash = ((hash << 5) - hash) + password.codeUnitAt(i);
      hash = hash & 0x7FFFFFFF; // Convert to 31-bit integer
    }
    return 'mock_hash_$hash';
  }

  /// Get all emails registered for a specific role (for login hints)
  static List<String> getEmailsForRole(UserRole role) {
    return _credentials
        .where((c) => c.profile.role == role)
        .map((c) => c.email)
        .toList();
  }
}

class _UserCredential {
  final String email;
  final String passwordHash;
  final UserProfile profile;

  const _UserCredential({
    required this.email,
    required this.passwordHash,
    required this.profile,
  });
}
