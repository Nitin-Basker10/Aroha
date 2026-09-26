import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/call_access.dart';
import '../../models/call_booking.dart';
import '../../services/auth_service.dart';
import '../../services/polar_data_service.dart';

/// Satellite call room — voice + low-res video for crew ↔ family.
///
/// The current MVP build demonstrates booking authorization, consent gates,
/// and local camera/microphone preview through flutter_webrtc. A remote
/// signaling/relay leg is not deployed yet, so the room never claims that a
/// peer is connected when it is not.
class VideoCallScreen extends StatefulWidget {
  final CallBooking booking;
  final String displayName;
  final bool isFamilySide;

  const VideoCallScreen({
    super.key,
    required this.booking,
    required this.displayName,
    this.isFamilySide = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with WidgetsBindingObserver {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  bool _micOn = true;
  bool _camOn = true;
  bool _mediaReady = false;
  bool _mediaInitializing = false;
  String? _mediaError;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  CallBooking? _activeBooking;
  bool _accessResolved = false;
  bool _accessGranted = false;
  String? _accessMessage;

  CallBooking get _booking => _activeBooking ?? widget.booking;
  bool get _isVideo => _booking.channelType != 'satellite-voice';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Resolve authorization before requesting camera/microphone access. A
    // route is not a security boundary; the current session and current
    // booking must both authorize the call.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAccess());
  }

  Future<void> _resolveAccess() async {
    if (!mounted || _accessResolved) return;
    try {
      final auth = context.read<AuthService>();
      final data = context.read<PolarDataService>();
      final current = data.getBookingById(widget.booking.id);
      final invite = data.getInviteForBooking(widget.booking.id);
      final allowed =
          current != null &&
          CallAccessPolicy.canJoin(
            user: auth.currentUser,
            booking: current,
            invite: invite,
            familySide: widget.isFamilySide,
          );
      if (!mounted) return;
      setState(() {
        _activeBooking = current;
        _accessGranted = allowed;
        _accessResolved = true;
        if (!allowed) {
          _accessMessage = widget.isFamilySide
              ? 'This family invite is no longer cleared for this call.'
              : 'Your session is not cleared for this call slot.';
        }
      });
      if (!allowed) return;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
        if (_elapsed.inMinutes >= _booking.durationMinutes) {
          unawaited(_hangUp());
        }
      });
      await _initRenderers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accessGranted = false;
        _accessResolved = true;
        _accessMessage = 'Call authorization could not be verified.';
      });
    }
  }

  Future<void> _initRenderers() async {
    if (_mediaInitializing) return;
    _mediaInitializing = true;
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      MediaStream? stream;
      Object? mediaFailure;
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': _isVideo ? {'facingMode': 'user'} : false,
        });
      } catch (error) {
        mediaFailure = error;
        // A camera-less or camera-denied device must not lose the audio leg.
        if (_isVideo) {
          try {
            stream = await navigator.mediaDevices.getUserMedia({
              'audio': true,
              'video': false,
            });
            mediaFailure = null;
          } catch (audioError) {
            mediaFailure = audioError;
          }
        }
      }

      if (!mounted) {
        await stream?.dispose();
        return;
      }
      if (stream == null) {
        setState(() {
          _mediaError = _friendlyMediaError(mediaFailure);
          _mediaReady = false;
          _micOn = false;
          _camOn = false;
        });
        return;
      }

      final acquiredStream = stream;
      final hasVideo = acquiredStream.getVideoTracks().isNotEmpty;
      setState(() {
        _localStream = acquiredStream;
        _localRenderer.srcObject = acquiredStream;
        _mediaReady = true;
        _mediaError = hasVideo
            ? null
            : 'Camera unavailable — continuing with voice preview.';
        _micOn = acquiredStream.getAudioTracks().isNotEmpty;
        _camOn = hasVideo;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _mediaError = _friendlyMediaError(error);
          _mediaReady = false;
        });
      }
    } finally {
      _mediaInitializing = false;
    }
  }

  String _friendlyMediaError(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';
    if (text.contains('notallowed') || text.contains('permission')) {
      return 'Camera/microphone permission denied. Allow access in browser or device settings, then retry.';
    }
    if (text.contains('notfound') || text.contains('devicesnotfound')) {
      return 'No camera or microphone was found on this device.';
    }
    if (text.contains('insecure') || text.contains('secure context')) {
      return 'Media access requires HTTPS (or localhost) and browser permission.';
    }
    if (text.contains('notreadable') || text.contains('in use')) {
      return 'The camera or microphone is already in use by another application.';
    }
    return 'Local media could not be started. Check device permissions and retry.';
  }

  Future<void> _retryMedia() async {
    if (_mediaInitializing || _mediaReady) return;
    setState(() => _mediaError = null);
    await _initRenderers();
  }

  void _toggleMic() {
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return;
    setState(() {
      _micOn = !_micOn;
      for (final t in tracks) {
        t.enabled = _micOn;
      }
    });
  }

  void _toggleCam() {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    setState(() {
      _camOn = !_camOn;
      for (final t in tracks) {
        t.enabled = _camOn;
      }
    });
  }

  Future<void> _switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (error) {
      if (mounted) setState(() => _mediaError = _friendlyMediaError(error));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_pauseMedia());
    }
  }

  Future<void> _pauseMedia() async {
    final stream = _localStream;
    _localStream = null;
    _localRenderer.srcObject = null;
    try {
      await stream?.dispose();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _mediaReady = false;
        _micOn = false;
        _camOn = false;
        _mediaError = 'Call media paused. Retry when you are ready.';
      });
    }
  }

  Future<void> _hangUp() async {
    _timer?.cancel();
    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    final stream = _localStream;
    _localStream = null;
    if (stream != null) unawaited(stream.dispose());
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s / ${_booking.durationMinutes}m allotted';
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      appBar: AppBar(title: const Text('CALL ACCESS DENIED')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _accessMessage ?? 'This call is not available for your session.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessResolved) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: context.appColors.primary),
        ),
      );
    }
    if (!_accessGranted) return _buildAccessDenied();

    return Scaffold(
      backgroundColor: context.appColors.surfaceLowest,
      appBar: AppBar(
        backgroundColor: context.appColors.canvas,
        title: Text(
          _isVideo
              ? 'SATELLITE VIDEO // PREVIEW'
              : 'SATELLITE VOICE // PREVIEW',
          style: AppTypography.labelSm.copyWith(
            color: context.appColors.critical,
            letterSpacing: 1,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.appColors.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: context.appColors.critical),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.appColors.critical,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'PREVIEW',
                  style: AppTypography.telemetryXs.copyWith(
                    color: context.appColors.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Remote peer (HQ relay leg plugs in here in production)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.surfaceLow,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.appColors.border),
              ),
              child: Stack(
                children: [
                  Center(
                    child: _remoteRenderer.srcObject != null
                        ? RTCVideoView(_remoteRenderer)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.satellite_alt,
                                size: 40,
                                color: context.appColors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'REMOTE RELAY NOT CONFIGURED',
                                style: AppTypography.telemetrySm.copyWith(
                                  color: context.appColors.warning,
                                ),
                              ),
                              Text(
                                'This MVP demonstrates local media and call clearance only.',
                                textAlign: TextAlign.center,
                                style: AppTypography.telemetryXs.copyWith(
                                  color: context.appColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                widget.isFamilySide
                                    ? _booking.personName
                                    : _booking.familyContactName,
                                style: AppTypography.telemetryXs.copyWith(
                                  color: context.appColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        _elapsedLabel,
                        style: AppTypography.telemetryXs.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Local preview
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: context.appColors.nominal.withValues(alpha: 0.4),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: _mediaError != null
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LOCAL MEDIA UNAVAILABLE\n$_mediaError',
                                  style: AppTypography.telemetryXs.copyWith(
                                    color: context.appColors.critical,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _mediaInitializing
                                      ? null
                                      : _retryMedia,
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('RETRY MEDIA'),
                                ),
                              ],
                            ),
                          )
                        : !_mediaReady
                        ? CircularProgressIndicator(
                            color: context.appColors.primary,
                          )
                        : (_isVideo && _camOn
                              ? RTCVideoView(_localRenderer, mirror: true)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mic,
                                      size: 32,
                                      color: context.appColors.nominal,
                                    ),
                                    Text(
                                      'VOICE MODE // $_elapsedLabel',
                                      style: AppTypography.telemetryXs.copyWith(
                                        color:
                                            context.appColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'YOU // ${widget.displayName}',
                        style: AppTypography.telemetryXs.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Compliance strip
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.appColors.surfaceLow,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: context.appColors.warning.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'CALL COMPLIANCE GATE ACTIVE — REMOTE RELAY NOT DEPLOYED IN THIS MVP.',
              style: AppTypography.telemetryXs.copyWith(
                color: context.appColors.warning,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Controls
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlButton(
                  icon: _micOn ? Icons.mic : Icons.mic_off,
                  label: _micOn ? 'MUTE' : 'UNMUTE',
                  onTap: _toggleMic,
                  enabled: _localStream?.getAudioTracks().isNotEmpty ?? false,
                ),
                if (_isVideo)
                  _controlButton(
                    icon: _camOn ? Icons.videocam : Icons.videocam_off,
                    label: _camOn ? 'CAM OFF' : 'CAM ON',
                    onTap: _toggleCam,
                    enabled: _localStream?.getVideoTracks().isNotEmpty ?? false,
                  ),
                if (_isVideo)
                  _controlButton(
                    icon: Icons.cameraswitch,
                    label: 'FLIP',
                    onTap: _switchCamera,
                    enabled: _localStream?.getVideoTracks().isNotEmpty ?? false,
                  ),
                _controlButton(
                  icon: Icons.call_end,
                  label: 'END',
                  background: context.appColors.critical,
                  foregroundColor: context.appColors.onCritical,
                  onTap: _hangUp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? background,
    Color? foregroundColor,
    bool enabled = true,
  }) {
    final buttonColor = background ?? context.appColors.surfaceHigh;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
              border: Border.all(color: context.appColors.border),
            ),
            child: Icon(
              icon,
              color: enabled
                  ? (foregroundColor ?? context.appColors.onSurface)
                  : context.appColors.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.telemetryXs.copyWith(
              color: enabled
                  ? context.appColors.onSurfaceVariant
                  : context.appColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}
