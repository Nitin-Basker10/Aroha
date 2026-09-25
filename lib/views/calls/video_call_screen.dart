import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/call_booking.dart';

/// Satellite call room — voice + low-res video for crew ↔ family.
///
/// Media path today: local camera/mic preview via flutter_webrtc. The
/// remote leg plugs into the mission signaling relay when deployed
/// (see [_remoteHint]); until then the room runs in monitored-preview
/// mode with recording banner + compliance notice, which matches the
/// confidential-link policy: nothing is peered without HQ relay.
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

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  bool _micOn = true;
  bool _camOn = true;
  bool _mediaReady = false;
  String? _mediaError;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  bool get _isVideo => widget.booking.channelType != 'satellite-voice';

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': _isVideo ? {'facingMode': 'user'} : false,
      });
      if (!mounted) {
        await stream.dispose();
        return;
      }
      setState(() {
        _localStream = stream;
        _localRenderer.srcObject = stream;
        _mediaReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _mediaError = e.toString());
    }
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
    try {
      final tracks = _localStream?.getVideoTracks() ?? [];
      if (tracks.isNotEmpty) {
        await Helper.switchCamera(tracks.first);
      }
    } catch (_) {}
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
    _timer?.cancel();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s / ${widget.booking.durationMinutes}m allotted';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.surfaceLowest,
      appBar: AppBar(
        backgroundColor: context.appColors.canvas,
        title: Text(
          _isVideo
              ? 'SATELLITE VIDEO // MONITORED'
              : 'SATELLITE VOICE // MONITORED',
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
                  'REC',
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
                                'WAITING FOR PEER VIA HQ RELAY…',
                                style: AppTypography.telemetrySm.copyWith(
                                  color: context.appColors.nominal,
                                ),
                              ),
                              Text(
                                widget.isFamilySide
                                    ? widget.booking.personName
                                    : widget.booking.familyContactName,
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
                            child: Text(
                              'LOCAL MEDIA UNAVAILABLE\n$_mediaError',
                              style: AppTypography.telemetryXs.copyWith(
                                color: context.appColors.critical,
                              ),
                              textAlign: TextAlign.center,
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
              'MONITORED GOVT LINK — no research, locations or operations talk.',
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
                ),
                if (_isVideo)
                  _controlButton(
                    icon: _camOn ? Icons.videocam : Icons.videocam_off,
                    label: _camOn ? 'CAM OFF' : 'CAM ON',
                    onTap: _toggleCam,
                  ),
                if (_isVideo)
                  _controlButton(
                    icon: Icons.cameraswitch,
                    label: 'FLIP',
                    onTap: _switchCamera,
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
  }) {
    final buttonColor = background ?? context.appColors.surfaceHigh;
    return InkWell(
      onTap: onTap,
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
              color: foregroundColor ?? context.appColors.onSurface,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.telemetryXs.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
