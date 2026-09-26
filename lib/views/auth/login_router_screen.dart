import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/user_role.dart';
import '../../models/user_credentials.dart';
import '../../services/auth_service.dart';
import '../../services/polar_data_service.dart';
import '../widgets/theme_toggle.dart';

/// Login Router — presents 3 distinct login portals:
/// 1. HQ Command Login (NCPOR Goa)
/// 2. Research Center Login (Station Staff)
/// 3. Family Welfare Portal Login
class LoginRouterScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const LoginRouterScreen({super.key, required this.onAuthenticated});

  @override
  State<LoginRouterScreen> createState() => _LoginRouterScreenState();
}

class _LoginRouterScreenState extends State<LoginRouterScreen>
    with SingleTickerProviderStateMixin {
  UserRole? _selectedPortal;
  bool _familySelected = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _selectPortal(UserRole role) {
    setState(() {
      _selectedPortal = role;
      _familySelected = false;
    });
    _animController.forward(from: 0);
  }

  void _selectFamily() {
    setState(() {
      _familySelected = true;
      _selectedPortal = null;
    });
    _animController.forward(from: 0);
  }

  void _goBack() {
    _animController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _selectedPortal = null;
        _familySelected = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _selectedPortal == null
                        ? (_familySelected
                              ? FadeTransition(
                                  opacity: _fadeAnim,
                                  child: _FamilyInviteForm(
                                    onBack: _goBack,
                                    onAuthenticated: widget.onAuthenticated,
                                  ),
                                )
                              : _buildPortalSelector())
                        : FadeTransition(
                            opacity: _fadeAnim,
                            child: _PortalLoginForm(
                              role: _selectedPortal!,
                              onBack: _goBack,
                              onAuthenticated: widget.onAuthenticated,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 8,
              right: 12,
              child: ThemeToggleButton(showLabel: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mission Header
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.appColors.surfaceHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.appColors.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: context.appColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(
              Icons.ac_unit,
              color: context.appColors.primary,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'AROHA',
            style: AppTypography.headlineLg.copyWith(
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Center(
          child: Text(
            'POLAR EXPEDITION MISSION COMMAND',
            style: AppTypography.labelSm.copyWith(
              letterSpacing: 1.5,
              color: context.appColors.nominal,
            ),
          ),
        ),
        Center(
          child: Text(
            'SIH26062 // National Centre for Polar and Ocean Research',
            style: AppTypography.telemetryXs.copyWith(
              color: context.appColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Portal Selection Header
        Center(
          child: Text(
            'SELECT ACCESS TERMINAL',
            style: AppTypography.labelSm.copyWith(
              letterSpacing: 1.5,
              color: context.appColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3 Portal Cards
        _buildPortalCard(
          role: UserRole.hqAdmin,
          icon: Icons.admin_panel_settings,
          title: 'HQ COMMAND CENTER',
          subtitle: 'NCPOR Goa Headquarters',
          description:
              'Mission oversight, multi-station monitoring, fleet logistics & expedition command.',
          accentColor: context.appColors.primary,
          badgeText: 'CLASSIFIED ACCESS',
        ),
        const SizedBox(height: 10),
        _buildPortalCard(
          role: UserRole.stationStaff,
          icon: Icons.cell_tower,
          title: 'RESEARCH CENTER LOGIN',
          subtitle: 'Station Expedition Crew',
          description:
              'Inventory management, crew operations, station telemetry & field reporting.',
          accentColor: context.appColors.warning,
          badgeText: 'STATION CREW',
        ),
        const SizedBox(height: 10),
        _buildFamilyCard(),

        // The former "System Status Footer" (green dot + "MVP LINK: LOCAL
        // DEMO SESSION" / "DEMO SESSION") was removed here. It carried no
        // information beyond the demo caveat, and the green dot implied a
        // live link that this build does not have.
      ],
    );
  }

  Widget _buildPortalCard({
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Color accentColor,
    required String badgeText,
  }) {
    return InkWell(
      onTap: () => _selectPortal(role),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.titleSm.copyWith(
                            color: context.appColors.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: AppTypography.telemetryXs.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.telemetryXs.copyWith(
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTypography.bodySm.copyWith(
                      color: context.appColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: accentColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  /// Invite-only family card — no credentials, just a call invite code.
  Widget _buildFamilyCard() {
    final accentColor = context.appColors.nominal;
    return InkWell(
      onTap: _selectFamily,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: accentColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.family_restroom, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'FAMILY CALL ACCESS',
                          style: AppTypography.titleSm.copyWith(
                            color: context.appColors.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'INVITE ONLY',
                          style: AppTypography.telemetryXs.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Family Members of Expedition Crew',
                    style: AppTypography.telemetryXs.copyWith(
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View your scheduled satellite call, give recording consent and join — no station data visible.',
                    style: AppTypography.bodySm.copyWith(
                      color: context.appColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: accentColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual portal login form
class _PortalLoginForm extends StatefulWidget {
  final UserRole role;
  final VoidCallback onBack;
  final VoidCallback onAuthenticated;

  const _PortalLoginForm({
    required this.role,
    required this.onBack,
    required this.onAuthenticated,
  });

  @override
  State<_PortalLoginForm> createState() => _PortalLoginFormState();
}

class _PortalLoginFormState extends State<_PortalLoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill with hint email for demo convenience
    final hints = UserCredentialStore.getEmailsForRole(widget.role);
    if (hints.isNotEmpty) {
      _emailController.text = hints.first;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.role) {
      case UserRole.hqAdmin:
        return context.appColors.primary;
      case UserRole.stationStaff:
        return context.appColors.warning;
      case UserRole.familyMember:
        return context.appColors.nominal;
    }
  }

  IconData get _portalIcon {
    switch (widget.role) {
      case UserRole.hqAdmin:
        return Icons.admin_panel_settings;
      case UserRole.stationStaff:
        return Icons.cell_tower;
      case UserRole.familyMember:
        return Icons.family_restroom;
    }
  }

  String get _portalTitle {
    switch (widget.role) {
      case UserRole.hqAdmin:
        return 'HQ COMMAND LOGIN';
      case UserRole.stationStaff:
        return 'RESEARCH CENTER LOGIN';
      case UserRole.familyMember:
        return 'FAMILY CALL ACCESS';
    }
  }

  String get _portalSubtitle {
    switch (widget.role) {
      case UserRole.hqAdmin:
        return 'NCPOR Goa Headquarters — Mission Oversight';
      case UserRole.stationStaff:
        return 'Expedition Station — Field Operations';
      case UserRole.familyMember:
        return 'Invite-only family call terminal';
    }
  }

  String get _demoPassword {
    switch (widget.role) {
      case UserRole.hqAdmin:
        return 'admin@ncpor2026';
      case UserRole.stationStaff:
        return 'maitri@2026 / bharati@2026 / himadri@2026';
      case UserRole.familyMember:
        return 'invite code shared by HQ (e.g. MTR-2026)';
    }
  }

  void _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final authService = context.read<AuthService>();
    final error = authService.login(
      email: _emailController.text,
      password: _passwordController.text,
      expectedRole: widget.role,
    );

    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      widget.onAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.appColors.surfaceLow,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: context.appColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 14,
                    color: context.appColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ALL TERMINALS',
                    style: AppTypography.telemetryXs.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Portal Identity Header
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _accentColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(_portalIcon, color: _accentColor, size: 28),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            _portalTitle,
            style: AppTypography.headlineSm.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: _accentColor,
            ),
          ),
        ),
        Center(
          child: Text(
            _portalSubtitle,
            style: AppTypography.telemetryXs.copyWith(
              color: context.appColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Error message
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appColors.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: context.appColors.critical.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: context.appColors.critical,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.bodySm.copyWith(
                      color: context.appColors.critical,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Email Field
        Text(
          'OPERATOR CALLSIGN / EMAIL',
          style: AppTypography.labelSm.copyWith(
            letterSpacing: 0.8,
            color: context.appColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          style: AppTypography.telemetrySm.copyWith(
            color: context.appColors.onSurface,
          ),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.badge_outlined,
              size: 18,
              color: context.appColors.onSurfaceVariant,
            ),
            hintText: 'callsign@ncpor.res.in',
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _accentColor),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          onChanged: (_) => setState(() => _errorMessage = null),
        ),

        const SizedBox(height: 12),

        // Password Field
        Text(
          'CRYPTOGRAPHIC ACCESS KEY',
          style: AppTypography.labelSm.copyWith(
            letterSpacing: 0.8,
            color: context.appColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: AppTypography.telemetrySm.copyWith(
            color: context.appColors.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.key_outlined,
              size: 18,
              color: context.appColors.onSurfaceVariant,
            ),
            hintText: 'Access token',
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _accentColor),
              borderRadius: BorderRadius.circular(4),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: context.appColors.onSurfaceVariant,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onChanged: (_) => setState(() => _errorMessage = null),
          onSubmitted: (_) => _handleSignIn(),
        ),

        const SizedBox(height: 8),

        // Demo credentials hint
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.surfaceLow,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 12,
                color: context.appColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Demo key: $_demoPassword',
                  style: AppTypography.telemetryXs.copyWith(
                    color: context.appColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Authenticate Button
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSignIn,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: _accentColor,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.appColors.canvas,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_open,
                      size: 16,
                      color: context.appColors.canvas,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'INITIALIZE SESSION',
                      style: AppTypography.titleSm.copyWith(
                        color: context.appColors.canvas,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 14),

        // Security Footer
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.surfaceLow,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: context.appColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ROLE: ${widget.role.label.toUpperCase()}',
                    style: AppTypography.telemetryXs.copyWith(
                      color: _accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Invite-code login for family members. Resolves the code against
/// PolarDataService and starts a tightly-scoped family session —
/// no email/password, no open registration.
class _FamilyInviteForm extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onAuthenticated;

  const _FamilyInviteForm({
    required this.onBack,
    required this.onAuthenticated,
  });

  @override
  State<_FamilyInviteForm> createState() => _FamilyInviteFormState();
}

class _FamilyInviteFormState extends State<_FamilyInviteForm> {
  final _codeController = TextEditingController(text: 'MTR-2026');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleJoin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final data = context.read<PolarDataService>();
    final invite = data.getInviteByCode(_codeController.text);
    if (invite == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Invalid invite code. Use the code shared by HQ / crew (e.g. MTR-2026).';
      });
      return;
    }

    final auth = context.read<AuthService>();
    auth.startSession(
      UserProfile(
        uid: 'fam_${invite.id}',
        name: invite.familyContactName,
        role: UserRole.familyMember,
        email: '',
        linkedStationId: invite.stationId,
        linkedPersonId: invite.personId,
      ),
    );
    setState(() => _isLoading = false);
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.nominal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.appColors.surfaceLow,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: context.appColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 14,
                    color: context.appColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ALL TERMINALS',
                    style: AppTypography.telemetryXs.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent, width: 1.5),
            ),
            child: Icon(Icons.family_restroom, color: accent, size: 28),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'FAMILY CALL ACCESS',
            style: AppTypography.headlineSm.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ),
        Center(
          child: Text(
            'Invite-only — your scheduled call, nothing else',
            style: AppTypography.telemetryXs.copyWith(
              color: context.appColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appColors.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: context.appColors.critical.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: context.appColors.critical,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.bodySm.copyWith(
                      color: context.appColors.critical,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'CALL INVITE CODE',
          style: AppTypography.labelSm.copyWith(
            letterSpacing: 0.8,
            color: context.appColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _codeController,
          style: AppTypography.telemetrySm.copyWith(
            color: context.appColors.onSurface,
          ),
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.confirmation_number_outlined,
              size: 18,
              color: context.appColors.onSurfaceVariant,
            ),
            hintText: 'e.g. MTR-2026',
          ),
          onChanged: (_) => setState(() => _errorMessage = null),
          onSubmitted: (_) => _handleJoin(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleJoin,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: accent,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.appColors.canvas,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_call_outlined,
                      size: 16,
                      color: context.appColors.canvas,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'JOIN CALL TERMINAL',
                      style: AppTypography.titleSm.copyWith(
                        color: context.appColors.canvas,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
