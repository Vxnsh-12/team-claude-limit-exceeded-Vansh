import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Turn-by-turn walking navigation screen for VIT Bhopal (Kotri Kalan).
///
/// * Uses MapTiler `streets-v2` raster tiles for the base map
/// * Calls OpenRouteService `v2/directions/foot-walking` and parses both the
///   full geometry (for the route polyline) and `segments[0].steps` (for
///   turn-by-turn maneuvers)
/// * Floating Google-Maps-style instruction banner at the top
/// * Listens to `Geolocator.getPositionStream`, uses `latlong2` `Distance()`
///   to advance to the next step when < 10 m from the current maneuver
/// * Auto-centres + rotates the map to match the user's heading via
///   `MapController.moveAndRotate()`
class VITNavigationScreen extends StatefulWidget {
  const VITNavigationScreen({
    super.key,
    required this.destination,
    required this.destinationName,
    this.origin,
    this.orsApiKey = 'ORS_API_KEY',
    this.mapTilerApiKey = '0BNwrOGmOw4HXYKTGrot',
  });

  /// End point of the walking route.
  final LatLng destination;

  /// Human-readable label shown in the banner subtitle.
  final String destinationName;

  /// Optional starting point.  When null, the user's current location is used.
  final LatLng? origin;

  final String orsApiKey;
  final String mapTilerApiKey;

  @override
  State<VITNavigationScreen> createState() => _VITNavigationScreenState();
}

class _VITNavigationScreenState extends State<VITNavigationScreen>
    with TickerProviderStateMixin {
  // --- Campus bounds & zoom ---
  static final LatLngBounds campusBounds = LatLngBounds(
    const LatLng(23.065, 76.840),
    const LatLng(23.090, 76.865),
  );
  static const double minZoom = 16.0;
  static const double followZoom = 18.0;

  // --- Step progression threshold ---
  static const double stepReachedMeters = 10.0;

  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  StreamSubscription<Position>? _positionSub;
  LatLng? _userLocation;
  double _userHeading = 0;

  List<LatLng> _routeLine = [];
  List<_NavStep> _steps = [];
  int _currentStep = 0;
  double? _distanceToManeuver;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Bootstrap: permission → location → route → tracking
  // ---------------------------------------------------------------------------
  Future<void> _bootstrap() async {
    try {
      final start = widget.origin ?? await _resolveCurrentLocation();
      if (!mounted) return;
      setState(() => _userLocation = start);
      await _fetchRoute(start, widget.destination);
      _startTracking();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<LatLng> _resolveCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are disabled';
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Location permission denied';
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  // ---------------------------------------------------------------------------
  // OpenRouteService — foot-walking directions
  // ---------------------------------------------------------------------------
  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    setState(() => _loading = true);
    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson',
    );
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': widget.orsApiKey,
        'Content-Type': 'application/json',
        'Accept':
            'application/json, application/geo+json, application/gpx+xml;charset=UTF-8',
      },
      body: jsonEncode({
        'coordinates': [
          [start.longitude, start.latitude],
          [end.longitude, end.latitude],
        ],
        'instructions': true,
        'language': 'en',
      }),
    );

    if (resp.statusCode != 200) {
      throw 'Routing failed (${resp.statusCode}): ${resp.body}';
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final feature = (json['features'] as List).first as Map<String, dynamic>;

    // Geometry — LineString of [lon, lat]
    final coords = (feature['geometry']['coordinates'] as List)
        .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    // Steps — segments[0].steps
    final segments = feature['properties']['segments'] as List;
    final rawSteps = (segments.first as Map<String, dynamic>)['steps'] as List;
    final steps = rawSteps.map<_NavStep>((raw) {
      final s = raw as Map<String, dynamic>;
      final wp = (s['way_points'] as List).cast<num>();
      // The maneuver happens at the END of the current step (== start of the next).
      final maneuverIdx = wp.last.toInt().clamp(0, coords.length - 1);
      return _NavStep(
        instruction: s['instruction'] as String,
        distanceMeters: (s['distance'] as num).toDouble(),
        durationSec: (s['duration'] as num).toDouble(),
        type: (s['type'] as num).toInt(),
        name: (s['name'] as String?) ?? '',
        maneuverPoint: coords[maneuverIdx],
      );
    }).toList();

    if (!mounted) return;
    setState(() {
      _routeLine = coords;
      _steps = steps;
      _currentStep = 0;
      _distanceToManeuver =
          steps.isNotEmpty ? _distance.as(LengthUnit.Meter, start, steps.first.maneuverPoint) : null;
      _loading = false;
    });

    // Fit the entire route on the map on first load
    Future.delayed(const Duration(milliseconds: 200), _fitRoute);
  }

  void _fitRoute() {
    if (_routeLine.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routeLine);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 140, 40, 220),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Live GPS tracking + step progression + map rotate/centre
  // ---------------------------------------------------------------------------
  void _startTracking() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position pos) {
    final user = LatLng(pos.latitude, pos.longitude);
    // `heading` is degrees clockwise from north.  flutter_map wants clockwise
    // rotation to align the map with that heading, so we pass -heading.
    final heading = pos.heading.isNaN ? _userHeading : pos.heading;

    if (!mounted) return;
    setState(() {
      _userLocation = user;
      _userHeading = heading;
      if (_steps.isNotEmpty && _currentStep < _steps.length) {
        _distanceToManeuver = _distance.as(
          LengthUnit.Meter,
          user,
          _steps[_currentStep].maneuverPoint,
        );
        // Auto-advance when the user is within `stepReachedMeters` of the
        // current maneuver point.
        while (_currentStep < _steps.length - 1 &&
            (_distanceToManeuver ?? double.infinity) < stepReachedMeters) {
          _currentStep += 1;
          _distanceToManeuver = _distance.as(
            LengthUnit.Meter,
            user,
            _steps[_currentStep].maneuverPoint,
          );
        }
      }
    });

    // Keep the map locked to the user, oriented in their walking direction.
    _mapController.moveAndRotate(user, followZoom, -heading);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final tileUrl =
        'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=${widget.mapTilerApiKey}';

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.destination,
              initialZoom: 17.0,
              minZoom: minZoom,
              maxZoom: 19,
              cameraConstraint: CameraConstraint.contain(bounds: campusBounds),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.vitquest.app',
                maxZoom: 19,
                tileProvider: NetworkTileProvider(),
              ),
              if (_routeLine.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeLine,
                      color: const Color(0xFF1A73E8),
                      strokeWidth: 6.0,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.destination,
                    width: 40,
                    height: 40,
                    child: _DestinationPin(),
                  ),
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 60,
                      height: 60,
                      child: _UserPuck(headingDeg: _userHeading),
                    ),
                ],
              ),
            ],
          ),

          if (_loading) const _CenteredLoader(),
          if (_error != null) _ErrorBanner(message: _error!, onRetry: _bootstrap),

          if (!_loading && _error == null && _steps.isNotEmpty)
            _InstructionBanner(
              step: _steps[_currentStep],
              distanceToManeuver: _distanceToManeuver,
              stepIndex: _currentStep,
              totalSteps: _steps.length,
              destinationName: widget.destinationName,
            ),

          if (!_loading && _steps.isNotEmpty)
            _BottomProgress(
              steps: _steps,
              currentStep: _currentStep,
              onExit: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
      floatingActionButton: (_userLocation != null && !_loading)
          ? FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A73E8),
              onPressed: () =>
                  _mapController.moveAndRotate(_userLocation!, followZoom, -_userHeading),
              child: const Icon(Icons.navigation_rounded),
            )
          : null,
    );
  }
}

// -----------------------------------------------------------------------------
// Nav step model
// -----------------------------------------------------------------------------
class _NavStep {
  const _NavStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSec,
    required this.type,
    required this.name,
    required this.maneuverPoint,
  });

  final String instruction;
  final double distanceMeters;
  final double durationSec;
  final int type;
  final String name;
  final LatLng maneuverPoint;

  /// Map ORS step `type` (0..13) to a Material icon.
  IconData get icon {
    switch (type) {
      case 0:
        return Icons.turn_left_rounded;
      case 1:
        return Icons.turn_right_rounded;
      case 2:
        return Icons.turn_sharp_left_rounded;
      case 3:
        return Icons.turn_sharp_right_rounded;
      case 4:
        return Icons.turn_slight_left_rounded;
      case 5:
        return Icons.turn_slight_right_rounded;
      case 6:
        return Icons.straight_rounded;
      case 7:
      case 8:
        return Icons.roundabout_left_rounded;
      case 9:
        return Icons.u_turn_left_rounded;
      case 10:
        return Icons.flag_rounded;
      case 11:
        return Icons.play_arrow_rounded;
      case 12:
        return Icons.fork_left_rounded;
      case 13:
        return Icons.fork_right_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }
}

// -----------------------------------------------------------------------------
// Instruction banner (top)
// -----------------------------------------------------------------------------
class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({
    required this.step,
    required this.distanceToManeuver,
    required this.stepIndex,
    required this.totalSteps,
    required this.destinationName,
  });

  final _NavStep step;
  final double? distanceToManeuver;
  final int stepIndex;
  final int totalSteps;
  final String destinationName;

  @override
  Widget build(BuildContext context) {
    final remaining = distanceToManeuver ?? step.distanceMeters;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(step.icon, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMeters(remaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.instruction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Step ${stepIndex + 1} / $totalSteps',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              destinationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
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
        ),
      ),
    );
  }

  static String _formatMeters(double m) {
    if (m < 20) return 'Now';
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }
}

// -----------------------------------------------------------------------------
// Bottom progress / exit bar
// -----------------------------------------------------------------------------
class _BottomProgress extends StatelessWidget {
  const _BottomProgress({
    required this.steps,
    required this.currentStep,
    required this.onExit,
  });

  final List<_NavStep> steps;
  final int currentStep;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final remaining = steps
        .sublist(currentStep)
        .fold<double>(0, (a, s) => a + s.distanceMeters);
    final progress = currentStep / steps.length;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_walk_rounded,
                            size: 18, color: Color(0xFF1A73E8)),
                        const SizedBox(width: 6),
                        Text(
                          _formatDistance(remaining),
                          style: const TextStyle(
                            color: Color(0xFF1F2A44),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ~ ${(remaining / 1.35 / 60).toStringAsFixed(0)} min',
                          style: const TextStyle(
                            color: Color(0xFF1F2A44),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1A73E8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onExit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  elevation: 0,
                ),
                child: const Text('Exit',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDistance(double m) {
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(2)} km';
  }
}

// -----------------------------------------------------------------------------
// User "puck" marker with heading indicator
// -----------------------------------------------------------------------------
class _UserPuck extends StatelessWidget {
  const _UserPuck({required this.headingDeg});

  final double headingDeg;

  @override
  Widget build(BuildContext context) {
    // The map is rotated by -heading so that the user faces "up" on screen;
    // the puck itself therefore does NOT need extra rotation.
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A73E8).withOpacity(0.15),
          ),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A73E8),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x661A73E8), blurRadius: 12),
            ],
          ),
        ),
        Positioned(
          top: 6,
          child: Container(
            width: 0,
            height: 0,
            decoration: const BoxDecoration(),
            child: CustomPaint(
              size: const Size(14, 10),
              painter: _ArrowPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// Destination pin
// -----------------------------------------------------------------------------
class _DestinationPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.place_rounded, color: Colors.white, size: 18),
        ),
        Container(width: 2, height: 6, color: const Color(0xFFDC2626)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Loader + error
// -----------------------------------------------------------------------------
class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1A73E8)),
            ),
            SizedBox(height: 12),
            Text('Building your route…',
                style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.35)),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                        color: Color(0xFF1F2A44), fontSize: 12, height: 1.4),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry',
                      style: TextStyle(
                          color: Color(0xFF1A73E8), fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
