import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aroha_polar/core/theme/app_theme.dart';
import 'package:aroha_polar/core/theme/theme_provider.dart';
import 'package:aroha_polar/models/user_role.dart';
import 'package:aroha_polar/services/auth_service.dart';
import 'package:aroha_polar/services/notification_service.dart';
import 'package:aroha_polar/services/polar_data_service.dart';
import 'package:aroha_polar/views/auth/login_router_screen.dart';
import 'package:aroha_polar/views/command_center/hq_command_screen.dart';
import 'package:aroha_polar/views/comms/comms_hub_screen.dart';
import 'package:aroha_polar/views/family/family_portal_screen.dart';
import 'package:aroha_polar/views/inventory/inventory_screen.dart';
import 'package:aroha_polar/views/personnel/personnel_screen.dart';
import 'package:aroha_polar/views/resupply/resupply_screen.dart';
import 'package:aroha_polar/views/station_detail/station_detail_screen.dart';

/// Every screen must lay out on a real handset without clipping content.
///
/// A RenderFlex overflow is reported as a test failure, so simply pumping each
/// screen at the target width and letting it settle is the assertion. The app's
/// tactical rows are dense — a long station code next to a status badge, two
/// full-width action labels side by side — and they silently regressed at
/// 412px before this sweep existed.
///
/// Width is what matters here, so height is deliberately left at the default
/// 600px; a tall-enough surface only means more list items render, which is
/// strictly better for catching overflow further down a scrolling body.
const _handset = Size(412, 915);

const _hq = UserProfile(
  uid: 'hq_01',
  name: 'Dr. Nitin Basker',
  role: UserRole.hqAdmin,
  email: 'nitin.basker@ncpor.gov.in',
  linkedStationId: null,
  linkedPersonId: null,
);

const _maitriStaff = UserProfile(
  uid: 'staff_mtr_01',
  name: 'Dr. Aarav Sharma',
  role: UserRole.stationStaff,
  email: 'aarav.sharma@maitri.ncpor.gov.in',
  linkedStationId: 'maitri',
  linkedPersonId: 'per_mtr_01',
);

/// The provider stack the real app installs in `main.dart`, so screens resolve
/// the same services they do in production.
Widget _host(PolarDataService data, AuthService auth, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: auth),
      ChangeNotifierProvider<PolarDataService>.value(value: data),
      ChangeNotifierProvider<NotificationService>(
        create: (_) => NotificationService(),
      ),
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(platformBrightness: Brightness.dark),
      ),
    ],
    child: MaterialApp(theme: AppTheme.darkTheme, home: child),
  );
}

void _useHandset(WidgetTester tester) {
  tester.view.physicalSize = _handset;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pumps [build] at handset width as [user].
///
/// [body] wraps the screen in a Scaffold, matching how `MainLayoutScreen`
/// hosts every tab. Tab bodies rely on that ancestor for Material, so omitting
/// it fails on "No Material widget found" long before layout is exercised.
///
/// Services are disposed inside the test body: `AuthService` owns a session
/// timer and `PolarDataService` can own poll timers, and `addTearDown` fires
/// too late for the binding's pending-timer assertion.
Future<void> _pumpAtHandset(
  WidgetTester tester,
  UserProfile user,
  Widget Function() build, {
  bool body = false,
}) async {
  _useHandset(tester);
  final data = PolarDataService(enableCloudSync: false);
  final auth = AuthService();
  try {
    auth.startSession(user);
    var child = build();
    if (body) child = Scaffold(body: child);
    await tester.pumpWidget(_host(data, auth, child));
    await tester.pump(const Duration(milliseconds: 100));
  } finally {
    auth.dispose();
    data.dispose();
  }
}

void main() {
  group('Every screen lays out at 412px without overflowing', () {
    testWidgets('login terminal', (tester) async {
      _useHandset(tester);
      final auth = AuthService();
      final data = PolarDataService(enableCloudSync: false);
      try {
        await tester.pumpWidget(
          _host(data, auth, LoginRouterScreen(onAuthenticated: () {})),
        );
        await tester.pump(const Duration(milliseconds: 100));
      } finally {
        auth.dispose();
        data.dispose();
      }
    });

    testWidgets('HQ command centre', (tester) async {
      await _pumpAtHandset(
        tester,
        _hq,
        () => const HqCommandScreen(),
        body: true,
      );
    });

    testWidgets('inventory', (tester) async {
      await _pumpAtHandset(
        tester,
        _hq,
        () => const InventoryScreen(),
        body: true,
      );
    });

    testWidgets('resupply', (tester) async {
      await _pumpAtHandset(
        tester,
        _hq,
        () => const ResupplyScreen(),
        body: true,
      );
    });

    testWidgets('personnel roster', (tester) async {
      await _pumpAtHandset(
        tester,
        _hq,
        () => const PersonnelScreen(),
        body: true,
      );
    });

    testWidgets('comms hub', (tester) async {
      await _pumpAtHandset(
        tester,
        _maitriStaff,
        () => const CommsHubScreen(),
        body: true,
      );
    });

    testWidgets('station detail', (tester) async {
      await _pumpAtHandset(
        tester,
        _hq,
        () => const StationDetailScreen(),
        body: true,
      );
    });

    testWidgets('family portal', (tester) async {
      _useHandset(tester);
      final data = PolarDataService(enableCloudSync: false);
      final auth = AuthService();
      try {
        // Family sessions are keyed `fam_<inviteId>`; resolve the seeded
        // invite so the portal finds its own call slot.
        final invite = data.getInviteForBooking('call_01')!;
        final family = UserProfile(
          uid: 'fam_${invite.id}',
          name: invite.familyContactName,
          role: UserRole.familyMember,
          email: '',
          linkedStationId: invite.stationId,
          linkedPersonId: invite.personId,
        );
        auth.startSession(family);
        await tester.pumpWidget(
          _host(data, auth, const Scaffold(body: FamilyPortalScreen())),
        );
        await tester.pump(const Duration(milliseconds: 100));
      } finally {
        auth.dispose();
        data.dispose();
      }
    });
  });
}
