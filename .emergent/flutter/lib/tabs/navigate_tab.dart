import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// The Navigate tab of the VIT Quest super-app.
///
/// * Owns ALL routing / GPS / disruption state — the map is deliberately kept
///   free of any overlays, floating buttons, banners or drawers.
/// * Exposes a public `NavigateTabState` via a `GlobalKey` so the outer app
///   shell can push disruption reports into the map (from the global AppBar).
/// * `language` and destination changes come in via widget props and trigger
///   an automatic route re-fetch through `didUpdateWidget`.
class NavigateTab extends StatefulWidget {
  const NavigateTab({
    super.key,
    required this.language,
    required this.orsApiKey,
    required this.mapTilerApiKey,
    this.destination = const LatLng(23.075, 76.852),
    this.destinationName = 'Academic Block 1',
  });

  final String language;
  final String orsApiKey;
  final String mapTilerApiKey;
  final LatLng destination;
  final String destinationName;

  @override
  State<NavigateTab> createState() => NavigateTabState();
}

class NavigateTabState extends State<NavigateTab> {
  // --- Campus bounds & zoom ---
  static final LatLngBounds campusBounds = LatLngBounds(
    const LatLng(23.065, 76.840),
    const LatLng(23.090, 76.865),
  );
  static const double minZoom = 16.0;
  static const double followZoom = 18.0;

  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  StreamSubscription<Position>? _positionSub;
  LatLng? _userLocation;
  double _userHeading = 0;

  List<LatLng> _routeLine = [];
  final List<LatLng> _reportedDisruptions = [];

  // Kept in state (even though not rendered) so the routing engine still
  // consumes the maneuver list – future speech / haptic layers can hook in.
  List<_NavStep> _steps = [];
  int _currentStep = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant NavigateTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.destination != widget.destination) {
      _recomputeRoute();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public getters / methods exposed via GlobalKey
  // ---------------------------------------------------------------------------
  LatLng? get userLocation => _userLocation;

  /// Called by the outer app shell when a disruption is reported.  Adds the
  /// user's current location to the avoid list and refetches the route.
  Future<bool> reportDisruptionAtCurrentLocation() async {
    if (_userLocation == null) return false;
    setState(() => _reportedDisruptions.add(_userLocation!));
    await _recomputeRoute();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Bootstrap
  // ---------------------------------------------------------------------------
  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _userLocation ?? await _resolveCurrentLocation();
      if (!mounted) return;
      setState(() => _userLocation = start);
      await _fetchRoute(start, widget.destination);
      if (_positionSub == null) _startTracking();
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
  // Routing
  // ---------------------------------------------------------------------------
  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    setState(() => _loading = true);
    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson',
    );

    final body = <String, dynamic>{
      'coordinates': [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
      'instructions': true,
      'language': widget.language,
    };

    if (_reportedDisruptions.isNotEmpty) {
      body['options'] = {'avoid_polygons': _buildAvoidPolygonsGeoJson()};
    }

    final resp = await http.post(
      uri,
      headers: {
        'Authorization': widget.orsApiKey,
        'Content-Type': 'application/json',
        'Accept':
            'application/json, application/geo+json, application/gpx+xml;charset=UTF-8',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw 'Routing failed (${resp.statusCode}): ${resp.body}';
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final feature = (json['features'] as List).first as Map<String, dynamic>;

    final coords = (feature['geometry']['coordinates'] as List)
        .map<LatLng>((c) =>
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final segments = feature['properties']['segments'] as List;
    final rawSteps =
        (segments.first as Map<String, dynamic>)['steps'] as List;
    final steps = rawSteps.map<_NavStep>((raw) {
      final s = raw as Map<String, dynamic>;
      final wp = (s['way_points'] as List).cast<num>();
      final maneuverIdx = wp.last.toInt().clamp(0, coords.length - 1);
      return _NavStep(
        instruction: s['instruction'] as String,
        distanceMeters: (s['distance'] as num).toDouble(),
        type: (s['type'] as num).toInt(),
        maneuverPoint: coords[maneuverIdx],
      );
    }).toList();

    if (!mounted) return;
    setState(() {
      _routeLine = coords;
      _steps = steps;
      _currentStep = 0;
      _loading = false;
    });

    Future.delayed(const Duration(milliseconds: 250), _fitRoute);
  }

  Map<String, dynamic> _buildAvoidPolygonsGeoJson() {
    const double d = 0.00015; // ~16 m
    final polygons = _reportedDisruptions.map<List<List<List<double>>>>((p) {
      final lon = p.longitude;
      final lat = p.latitude;
      return [
        [
          [lon - d, lat - d],
          [lon + d, lat - d],
          [lon + d, lat + d],
          [lon - d, lat + d],
          [lon - d, lat - d],
        ],
      ];
    }).toList();
    return {'type': 'MultiPolygon', 'coordinates': polygons};
  }

  Future<void> _recomputeRoute() async {
    if (_userLocation == null) return;
    try {
      await _fetchRoute(_userLocation!, widget.destination);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _fitRoute() {
    if (_routeLine.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routeLine);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GPS tracking
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
    final heading = pos.heading.isNaN ? _userHeading : pos.heading;

    if (!mounted) return;
    setState(() {
      _userLocation = user;
      _userHeading = heading;
      // Step progression – kept for downstream consumers (voice / haptics)
      if (_steps.isNotEmpty && _currentStep < _steps.length) {
        while (_currentStep < _steps.length - 1 &&
            _distance.as(LengthUnit.Meter, user,
                    _steps[_currentStep].maneuverPoint) <
                10) {
          _currentStep += 1;
        }
      }
    });

    _mapController.moveAndRotate(user, followZoom, -heading);
  }

  // ---------------------------------------------------------------------------
  // Build — CLEAN MAP.  No FABs, no banners, no overlays.
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final tileUrl =
        'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=${widget.mapTilerApiKey}';

    return FlutterMap(
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
                strokeWidth: 6,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            ..._reportedDisruptions.map(
              (p) => Marker(
                point: p,
                width: 32,
                height: 32,
                child: const _DisruptionPin(),
              ),
            ),
            Marker(
              point: widget.destination,
              width: 40,
              height: 40,
              child: const _DestinationPin(),
            ),
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 60,
                height: 60,
                child: const _UserPuck(),
              ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Nav step model (kept for downstream extensions)
// -----------------------------------------------------------------------------
class _NavStep {
  const _NavStep({
    required this.instruction,
    required this.distanceMeters,
    required this.type,
    required this.maneuverPoint,
  });

  final String instruction;
  final double distanceMeters;
  final int type;
  final LatLng maneuverPoint;
}

// -----------------------------------------------------------------------------
// Markers
// -----------------------------------------------------------------------------
class _UserPuck extends StatelessWidget {
  const _UserPuck();

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}

class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

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
              BoxShadow(
                  color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.place_rounded, color: Colors.white, size: 18),
        ),
        Container(width: 2, height: 6, color: const Color(0xFFDC2626)),
      ],
    );
  }
}

class _DisruptionPin extends StatelessWidget {
  const _DisruptionPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.warning_amber_rounded,
          color: Colors.white, size: 18),
    );
  }
}
