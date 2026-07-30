import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Turn-by-turn walking navigation screen for VIT Bhopal (Kotri Kalan) with:
///   • MapTiler `streets-v2` tiles + camera lock to the campus bounds
///   • OpenRouteService `foot-walking` / `wheelchair` GeoJSON routing
///   • Multilingual instructions (EN / HI / TE)
///   • Live user-reported disruptions (Waze-style, avoided via ORS
///     `avoid_polygons`)
///   • Smart shortcuts: Squad Meetup (midpoint routing) and Next Class
///   • Auto-centre + rotate map to the user's heading
class VITNavigationScreen extends StatefulWidget {
  const VITNavigationScreen({
    super.key,
    required this.destination,
    required this.destinationName,
    this.origin,
    this.orsApiKey = 'ORS_API_KEY',
    this.mapTilerApiKey = '0BNwrOGmOw4HXYKTGrot',
  });

  final LatLng destination;
  final String destinationName;
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
  static const double stepReachedMeters = 10.0;

  // Mock "friend" for squad meetup + fixed "Next Class" venue.
  static const LatLng _friendLocation = LatLng(23.080, 76.852);
  static const LatLng _academicBlock1 = LatLng(23.075, 76.852);
  static const String _academicBlock1Name = 'Academic Block 1';

  // --- Localisation config ---
  static const Map<String, _LangSpec> _languages = {
    'en': _LangSpec(label: 'English', flag: '🇬🇧'),
    'hi': _LangSpec(label: 'हिन्दी', flag: '🇮🇳'),
    'te': _LangSpec(label: 'తెలుగు', flag: '🇮🇳'),
  };
  static const Map<String, Map<String, String>> _i18n = {
    'en': {
      'building_route': 'Building your route…',
      'exit': 'Exit',
      'step': 'Step',
      'route_type_foot': 'Walking',
      'route_type_wheel': 'Wheelchair',
      'route_updated': 'Route updated',
      'report_success': '+50 Quest Points: Path Blocked Reported',
      'waiting_location': 'Waiting for your GPS…',
      'squad_dest': 'Squad Meetup Point',
      'next_class_snack': 'Next class in 8 min · Routing to Academic Block 1',
    },
    'hi': {
      'building_route': 'रास्ता तैयार हो रहा है…',
      'exit': 'बाहर',
      'step': 'चरण',
      'route_type_foot': 'पैदल',
      'route_type_wheel': 'व्हीलचेयर',
      'route_updated': 'रास्ता अपडेट हुआ',
      'report_success': '+50 अंक: रास्ता अवरुद्ध रिपोर्ट किया गया',
      'waiting_location': 'GPS की प्रतीक्षा है…',
      'squad_dest': 'स्क्वाड मिलन बिंदु',
      'next_class_snack': '8 मिनट में अगली क्लास · अकादमिक ब्लॉक 1 की ओर',
    },
    'te': {
      'building_route': 'మార్గం సిద్ధమవుతోంది…',
      'exit': 'నిష్క్రమించు',
      'step': 'దశ',
      'route_type_foot': 'నడక',
      'route_type_wheel': 'వీల్‌చైర్',
      'route_updated': 'మార్గం నవీకరించబడింది',
      'report_success': '+50 పాయింట్లు: మార్గం మూసివేయబడింది నివేదించబడింది',
      'waiting_location': 'GPS కోసం వేచి ఉంది…',
      'squad_dest': 'స్క్వాడ్ మీట్‌అప్ పాయింట్',
      'next_class_snack': '8 నిమిషాల్లో తదుపరి తరగతి · అకడమిక్ బ్లాక్ 1 కి',
    },
  };

  String _t(String key) => _i18n[_language]?[key] ?? _i18n['en']![key]!;

  // --- Core map controllers ---
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  StreamSubscription<Position>? _positionSub;

  // --- Live state ---
  LatLng? _userLocation;
  double _userHeading = 0;

  // --- Route state ---
  List<LatLng> _routeLine = [];
  List<_NavStep> _steps = [];
  int _currentStep = 0;
  double? _distanceToManeuver;

  // --- Destination (mutable — can change for Squad / Next Class) ---
  late LatLng _destination;
  late String _destinationName;

  // --- Hackathon features state ---
  String _routingProfile = 'foot-walking'; // toggles with 'wheelchair'
  String _language = 'en'; // 'en' | 'hi' | 'te'
  final List<LatLng> _reportedDisruptions = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _destination = widget.destination;
    _destinationName = widget.destinationName;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _userLocation ??
          widget.origin ??
          await _resolveCurrentLocation();
      if (!mounted) return;
      setState(() => _userLocation = start);
      await _fetchRoute(start, _destination);
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
  // OpenRouteService — dynamic profile + language + avoid_polygons
  // ---------------------------------------------------------------------------
  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    setState(() => _loading = true);
    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/$_routingProfile/geojson',
    );

    final body = <String, dynamic>{
      'coordinates': [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
      'instructions': true,
      'language': _language,
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
    final rawSteps = (segments.first as Map<String, dynamic>)['steps'] as List;
    final steps = rawSteps.map<_NavStep>((raw) {
      final s = raw as Map<String, dynamic>;
      final wp = (s['way_points'] as List).cast<num>();
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
      _distanceToManeuver = steps.isNotEmpty
          ? _distance.as(LengthUnit.Meter, start, steps.first.maneuverPoint)
          : null;
      _loading = false;
    });

    Future.delayed(const Duration(milliseconds: 200), _fitRoute);
  }

  /// Convert every reported disruption LatLng into a small GeoJSON polygon
  /// (bounding box ~15 m per side).  ORS `avoid_polygons` expects a
  /// MultiPolygon geometry.
  Map<String, dynamic> _buildAvoidPolygonsGeoJson() {
    const double d = 0.00015; // ~16 m in decimal degrees near the equator
    final polygons = _reportedDisruptions.map<List<List<List<double>>>>((p) {
      final lon = p.longitude;
      final lat = p.latitude;
      // GeoJSON polygon = list of linear rings; first is exterior, closed ring.
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
    if (_userLocation == null) {
      _showSnack(_t('waiting_location'));
      return;
    }
    try {
      await _fetchRoute(_userLocation!, _destination);
      _showSnack(_t('route_updated'));
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
        padding: const EdgeInsets.fromLTRB(40, 200, 40, 240),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Live GPS tracking + step progression + rotation
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
      if (_steps.isNotEmpty && _currentStep < _steps.length) {
        _distanceToManeuver = _distance.as(
          LengthUnit.Meter,
          user,
          _steps[_currentStep].maneuverPoint,
        );
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

    _mapController.moveAndRotate(user, followZoom, -heading);
  }

  // ---------------------------------------------------------------------------
  // Hackathon actions
  // ---------------------------------------------------------------------------
  void _toggleAccessibility() {
    setState(() {
      _routingProfile =
          _routingProfile == 'foot-walking' ? 'wheelchair' : 'foot-walking';
    });
    _showSnack(_routingProfile == 'wheelchair'
        ? _t('route_type_wheel')
        : _t('route_type_foot'));
    _recomputeRoute();
  }

  void _reportDisruption() {
    if (_userLocation == null) {
      _showSnack(_t('waiting_location'));
      return;
    }
    setState(() => _reportedDisruptions.add(_userLocation!));
    _showSnack(_t('report_success'));
    _recomputeRoute();
  }

  void _squadMeetup() {
    if (_userLocation == null) {
      _showSnack(_t('waiting_location'));
      return;
    }
    final mid = LatLng(
      (_userLocation!.latitude + _friendLocation.latitude) / 2,
      (_userLocation!.longitude + _friendLocation.longitude) / 2,
    );
    setState(() {
      _destination = mid;
      _destinationName = _t('squad_dest');
    });
    _recomputeRoute();
  }

  void _nextClass() {
    setState(() {
      _destination = _academicBlock1;
      _destinationName = _academicBlock1Name;
    });
    _showSnack(_t('next_class_snack'));
    _recomputeRoute();
  }

  void _onLanguageChanged(String? lang) {
    if (lang == null || lang == _language) return;
    setState(() => _language = lang);
    _bootstrap();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF1F2A44),
        duration: const Duration(seconds: 2),
      ));
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
              initialCenter: _destination,
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
                  // Reported disruption pins
                  ..._reportedDisruptions.map(
                    (p) => Marker(
                      point: p,
                      width: 32,
                      height: 32,
                      child: const _DisruptionPin(),
                    ),
                  ),
                  // Destination
                  Marker(
                    point: _destination,
                    width: 40,
                    height: 40,
                    child: const _DestinationPin(),
                  ),
                  // Live user puck
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
          ),

          // Top language pill (top-right, above the banner)
          _TopLanguageBar(
            language: _language,
            languages: _languages,
            onChanged: _onLanguageChanged,
            profile: _routingProfile,
            profileFootLabel: _t('route_type_foot'),
            profileWheelLabel: _t('route_type_wheel'),
          ),

          if (_loading) const _CenteredLoader(),
          if (_error != null) _ErrorBanner(message: _error!, onRetry: _bootstrap),

          if (!_loading && _error == null && _steps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 52), // room for lang pill
              child: _InstructionBanner(
                step: _steps[_currentStep],
                distanceToManeuver: _distanceToManeuver,
                stepIndex: _currentStep,
                totalSteps: _steps.length,
                destinationName: _destinationName,
                stepLabel: _t('step'),
              ),
            ),

          // Right-side FAB column (accessibility, disruption, squad, next class)
          _ActionColumn(
            profile: _routingProfile,
            onToggleAccessibility: _toggleAccessibility,
            onReportDisruption: _reportDisruption,
            onSquadMeetup: _squadMeetup,
            onNextClass: _nextClass,
          ),

          if (!_loading && _steps.isNotEmpty)
            _BottomProgress(
              steps: _steps,
              currentStep: _currentStep,
              exitLabel: _t('exit'),
              onExit: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
      floatingActionButton: (_userLocation != null && !_loading)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 92),
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A73E8),
                onPressed: () => _mapController.moveAndRotate(
                    _userLocation!, followZoom, -_userHeading),
                child: const Icon(Icons.navigation_rounded),
              ),
            )
          : null,
    );
  }
}

// -----------------------------------------------------------------------------
// Language spec
// -----------------------------------------------------------------------------
class _LangSpec {
  const _LangSpec({required this.label, required this.flag});
  final String label;
  final String flag;
}

// -----------------------------------------------------------------------------
// Top language + profile pill
// -----------------------------------------------------------------------------
class _TopLanguageBar extends StatelessWidget {
  const _TopLanguageBar({
    required this.language,
    required this.languages,
    required this.onChanged,
    required this.profile,
    required this.profileFootLabel,
    required this.profileWheelLabel,
  });

  final String language;
  final Map<String, _LangSpec> languages;
  final ValueChanged<String?> onChanged;
  final String profile;
  final String profileFootLabel;
  final String profileWheelLabel;

  @override
  Widget build(BuildContext context) {
    final isWheel = profile == 'wheelchair';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            // Route profile pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isWheel
                        ? Icons.accessible_forward_rounded
                        : Icons.directions_walk_rounded,
                    size: 16,
                    color: const Color(0xFF1A73E8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isWheel ? profileWheelLabel : profileFootLabel,
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Language dropdown pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded,
                      size: 16, color: Color(0xFF1F2A44)),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: language,
                      onChanged: onChanged,
                      icon: const Icon(Icons.expand_more_rounded,
                          size: 18, color: Color(0xFF1F2A44)),
                      isDense: true,
                      style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      items: languages.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(e.value.flag,
                                        style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      e.value.label,
                                      style: const TextStyle(
                                        color: Color(0xFF1F2A44),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    required this.stepLabel,
  });

  final _NavStep step;
  final double? distanceToManeuver;
  final int stepIndex;
  final int totalSteps;
  final String destinationName;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final remaining = distanceToManeuver ?? step.distanceMeters;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                    offset: Offset(0, 8)),
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
                            '$stepLabel ${stepIndex + 1} / $totalSteps',
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
// Action column (right side)
// -----------------------------------------------------------------------------
class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.profile,
    required this.onToggleAccessibility,
    required this.onReportDisruption,
    required this.onSquadMeetup,
    required this.onNextClass,
  });

  final String profile;
  final VoidCallback onToggleAccessibility;
  final VoidCallback onReportDisruption;
  final VoidCallback onSquadMeetup;
  final VoidCallback onNextClass;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      top: MediaQuery.of(context).size.height * 0.35,
      child: Column(
        children: [
          _ActionFab(
            heroTag: 'access',
            icon: profile == 'wheelchair'
                ? Icons.accessible_forward_rounded
                : Icons.directions_walk_rounded,
            color: const Color(0xFF7C3AED),
            tooltip: 'Toggle Accessibility',
            onPressed: onToggleAccessibility,
          ),
          const SizedBox(height: 10),
          _ActionFab(
            heroTag: 'disrupt',
            icon: Icons.report_gmailerrorred_rounded,
            color: const Color(0xFFDC2626),
            tooltip: 'Report Disruption',
            onPressed: onReportDisruption,
          ),
          const SizedBox(height: 10),
          _ActionFab(
            heroTag: 'squad',
            icon: Icons.groups_2_rounded,
            color: const Color(0xFF16A34A),
            tooltip: 'Squad Meetup',
            onPressed: onSquadMeetup,
          ),
          const SizedBox(height: 10),
          _ActionFab(
            heroTag: 'nextclass',
            icon: Icons.schedule_rounded,
            color: const Color(0xFF0EA5E9),
            tooltip: 'Next Class',
            onPressed: onNextClass,
          ),
        ],
      ),
    );
  }
}

class _ActionFab extends StatelessWidget {
  const _ActionFab({
    required this.heroTag,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      backgroundColor: Colors.white,
      foregroundColor: color,
      elevation: 3,
      tooltip: tooltip,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom progress / exit bar
// -----------------------------------------------------------------------------
class _BottomProgress extends StatelessWidget {
  const _BottomProgress({
    required this.steps,
    required this.currentStep,
    required this.exitLabel,
    required this.onExit,
  });

  final List<_NavStep> steps;
  final int currentStep;
  final String exitLabel;
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
                  color: Color(0x22000000),
                  blurRadius: 18,
                  offset: Offset(0, 8)),
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
                child: Text(exitLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
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
          BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.warning_amber_rounded,
          color: Colors.white, size: 18),
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
            BoxShadow(
                color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Color(0xFF1A73E8)),
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
                BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 20,
                    offset: Offset(0, 6)),
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
                          color: Color(0xFF1A73E8),
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
