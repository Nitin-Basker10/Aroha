import 'package:flutter_test/flutter_test.dart';
import 'package:aroha_polar/models/user_role.dart';
import 'package:aroha_polar/services/auth_service.dart';

void main() {
  test('AuthService starts logged out and authenticates properly', () {
    final auth = AuthService();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUser, isNull);

    // Test invalid password
    final failResult = auth.login(
      email: 'nitin.verma@ncpor.res.in',
      password: 'wrongpassword',
      expectedRole: UserRole.hqAdmin,
    );
    expect(failResult, isNotNull);
    expect(auth.isAuthenticated, isFalse);

    // Test valid HQ login
    final successResult = auth.login(
      email: 'nitin.verma@ncpor.res.in',
      password: 'admin@ncpor2026',
      expectedRole: UserRole.hqAdmin,
    );
    expect(successResult, isNull);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentRole, equals(UserRole.hqAdmin));
    expect(auth.hasPermission(Permission.viewAllStations), isTrue);

    // Logout
    auth.logout();
    expect(auth.isAuthenticated, isFalse);

    // Test valid Station Staff login
    final staffResult = auth.login(
      email: 'aarav.sharma@maitri.ncpor.gov.in',
      password: 'maitri@2026',
      expectedRole: UserRole.stationStaff,
    );
    expect(staffResult, isNull);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentRole, equals(UserRole.stationStaff));
    expect(auth.hasPermission(Permission.viewAllStations), isFalse);
    expect(auth.currentUser?.linkedStationId, equals('maitri'));

    // Verify station staff has cross-station comms permission
    expect(auth.hasPermission(Permission.crossStationComms), isTrue);
    // Verify station staff cannot view all stations
    expect(auth.hasPermission(Permission.accessCommandCenter), isFalse);
  });
}
