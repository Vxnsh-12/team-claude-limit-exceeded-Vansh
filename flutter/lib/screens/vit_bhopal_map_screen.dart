import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// VIT Bhopal gamified campus map.
///
/// * Renders POIs (academic blocks, hostels, mess, sports) as tappable pins
/// * Live GPS marker (pulsating) via `geolocator` stream
/// * Bottom sheet with quest info + "Start Route" + "Claim Check-in"
/// * Neon polyline route from user → destination
/// * Check-in enabled only when the user is < 30 m from the target POI
class VITBhopalMapScreen extends StatefulWidget {
  const VITBhopalMapScreen({super.key, this.mapTilerApiKey = 'MAPTILER_API_KEY'});

  final String mapTilerApiKey;

  @override
  State<VITBhopalMapScreen> createState() => _VITBhopalMapScreenState();
}

class _VITBhopalMapScreenState extends State<VITBhopalMapScreen> {
  // --- Campus config ---
  static const LatLng campusCenter = LatLng(23.0775, 76.8513);
  static const double initialZoom = 16.5;
  static const double minZoom = 15.0;
  static const double maxZoom = 19.0;
  static const double checkInRadiusMeters = 30.0;

  static const List<CampusPOI> pois = [
    CampusPOI(
      id: 'ab1',
      name: 'Academic Block 1',
      subtitle: 'AB-1 · Engineering wings',
      position: LatLng(23.0782, 76.8508),
      color: Color(0xFF00E5FF),
      icon: Icons.school_rounded,
      quest: QuestInfo(
        title: 'AB-1 Lecture Marathon',
        description: 'Attend three back-to-back lectures at AB-1.',
        xpReward: 110,
      ),
    ),
    CampusPOI(
      id: 'ab2',
      name: 'Academic Block 2',
      subtitle: 'AB-2 · Design & Innovation',
      position: LatLng(23.0778, 76.8521),
      color: Color(0xFF00E5FF),
      icon: Icons.apartment_rounded,
      quest: QuestInfo(
        title: 'AB-2 Innovation Sprint',
        description: 'Build a working prototype in the AB-2 makerspace.',
        xpReward: 160,
      ),
    ),
    CampusPOI(
      id: 'boys-hostel',
      name: 'Boys Hostels',
      subtitle: 'H-Block Residence',
      position: LatLng(23.0764, 76.8523),
      color: Color(0xFF94A3B8),
      icon: Icons.bed_rounded,
      quest: QuestInfo(
        title: 'Hostel Trivia Night',
        description: 'Organize a group trivia in the Boys Hostel common room.',
        xpReward: 130,
      ),
    ),
    CampusPOI(
      id: 'girls-hostel',
      name: 'Girls Hostels',
      subtitle: 'GH-Block Residence',
      position: LatLng(23.0770, 76.8501),
      color: Color(0xFF94A3B8),
      icon: Icons.bed_rounded,
      quest: QuestInfo(
        title: 'Sunset Stroll',
        description: 'Walk from Girls Hostel to Main Gate as the sun sets.',
        xpReward: 60,
      ),
    ),
    CampusPOI(
      id: 'central-mess',
      name: 'Central Mess',
      subtitle: 'Central Dining Hall',
      position: LatLng(23.0773, 76.8514),
      color: Color(0xFFFF8A3D),
      icon: Icons.restaurant_rounded,
      quest: QuestInfo(
        title: 'Mess Master Chef',
        description: 'Try a Madhya Pradesh regional dish at the Central Mess.',
        xpReward: 60,
      ),
    ),
    CampusPOI(
      id: 'sports-complex',
      name: 'Sports Complex',
      subtitle: 'Gym · Courts · Field',
      position: LatLng(23.0787, 76.8528),
      color: Color(0xFF39FF14),
      icon: Icons.sports_soccer_rounded,
      quest: QuestInfo(
        title: 'Iron Will',
        description: 'Complete a 20-minute workout at the Sports Complex.',
        xpReward: 150,
      ),
    ),
  ];

  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  StreamSubscription<Position>? _positionSub;
  LatLng? _userLocation;
  CampusPOI? _selectedPOI;
  CampusPOI? _routeTarget;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Location handling
  // ---------------------------------------------------------------------------
  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _permissionDenied = true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _permissionDenied = true);
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  void _onPOITap(CampusPOI poi) {
    setState(() => _selectedPOI = poi);
    _showPOISheet(poi);
  }

  void _startRoute(CampusPOI poi) {
    if (_userLocation == null) {
      _snack('Waiting for your location…');
      return;
    }
    setState(() => _routeTarget = poi);
    Navigator.of(context).pop(); // close the sheet
    _mapController.move(poi.position, 17.5);
  }

  Future<void> _claimCheckin(CampusPOI poi) async {
    if (_userLocation == null) {
      _snack('Location unavailable');
      return;
    }
    final meters = _distance.as(LengthUnit.Meter, _userLocation!, poi.position);
    if (meters >= checkInRadiusMeters) {
      _snack('Get within 30 m to claim');
      return;
    }
    Navigator.of(context).pop(); // dismiss sheet
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: poi.color),
            const SizedBox(width: 8),
            const Text('Check-in claimed!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'You earned +${poi.quest.xpReward} XP for reaching ${poi.name}.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nice',
                style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _routeTarget = null);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final tileUrl =
        'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=${widget.mapTilerApiKey}';

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: campusCenter,
              initialZoom: initialZoom,
              minZoom: minZoom,
              maxZoom: maxZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.vitquest.app',
                maxZoom: maxZoom,
                tileProvider: NetworkTileProvider(),
              ),
              if (_routeTarget != null && _userLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_userLocation!, _routeTarget!.position],
                      color: Colors.blueAccent,
                      strokeWidth: 5.0,
                      pattern: const StrokePattern.solid(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ...pois.map(_buildPOIMarker),
                  if (_userLocation != null) _buildUserMarker(_userLocation!),
                ],
              ),
            ],
          ),
          _buildTopBar(),
          if (_permissionDenied) _buildPermissionBanner(),
        ],
      ),
      floatingActionButton: _userLocation == null
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              onPressed: () => _mapController.move(_userLocation!, 17.5),
              child: const Icon(Icons.my_location_rounded),
            ),
    );
  }

  Marker _buildPOIMarker(CampusPOI poi) {
    final isSelected = _selectedPOI?.id == poi.id;
    return Marker(
      point: poi.position,
      width: 56,
      height: 56,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _onPOITap(poi),
        child: _POIPin(poi: poi, highlighted: isSelected),
      ),
    );
  }

  Marker _buildUserMarker(LatLng point) {
    return Marker(
      point: point,
      width: 60,
      height: 60,
      child: const _PulsingDot(),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xCC0F0F13),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.explore_rounded, size: 16, color: Color(0xFF00E5FF)),
                  SizedBox(width: 8),
                  Text('VIT Bhopal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Colors.redAccent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Location permission is required for check-ins and live routing.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
                child: const Text('Enable',
                    style: TextStyle(
                        color: Color(0xFF00E5FF), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom sheet
  // ---------------------------------------------------------------------------
  void _showPOISheet(CampusPOI poi) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _POISheet(
        poi: poi,
        userLocation: _userLocation,
        distance: _distance,
        checkInRadius: checkInRadiusMeters,
        onStartRoute: () => _startRoute(poi),
        onClaimCheckin: () => _claimCheckin(poi),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedPOI = null);
    });
  }
}

// -----------------------------------------------------------------------------
// Models
// -----------------------------------------------------------------------------
class CampusPOI {
  const CampusPOI({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.position,
    required this.color,
    required this.icon,
    required this.quest,
  });

  final String id;
  final String name;
  final String subtitle;
  final LatLng position;
  final Color color;
  final IconData icon;
  final QuestInfo quest;
}

class QuestInfo {
  const QuestInfo({
    required this.title,
    required this.description,
    required this.xpReward,
  });

  final String title;
  final String description;
  final int xpReward;
}

// -----------------------------------------------------------------------------
// POI pin
// -----------------------------------------------------------------------------
class _POIPin extends StatelessWidget {
  const _POIPin({required this.poi, required this.highlighted});

  final CampusPOI poi;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F13),
            shape: BoxShape.circle,
            border: Border.all(
              color: poi.color.withOpacity(highlighted ? 1.0 : 0.75),
              width: highlighted ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(color: poi.color.withOpacity(0.45), blurRadius: 14),
            ],
          ),
          child: Icon(poi.icon, size: 20, color: poi.color),
        ),
        const SizedBox(height: 2),
        Container(
          width: 2,
          height: 8,
          color: poi.color.withOpacity(0.6),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pulsing live-location dot
// -----------------------------------------------------------------------------
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final ringSize = 20 + (t * 34);
        final ringOpacity = (1.0 - t).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withOpacity(ringOpacity * 0.35),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF00E5FF), blurRadius: 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom sheet
// -----------------------------------------------------------------------------
class _POISheet extends StatefulWidget {
  const _POISheet({
    required this.poi,
    required this.userLocation,
    required this.distance,
    required this.checkInRadius,
    required this.onStartRoute,
    required this.onClaimCheckin,
  });

  final CampusPOI poi;
  final LatLng? userLocation;
  final Distance distance;
  final double checkInRadius;
  final VoidCallback onStartRoute;
  final VoidCallback onClaimCheckin;

  @override
  State<_POISheet> createState() => _POISheetState();
}

class _POISheetState extends State<_POISheet> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh distance display every 2 s while sheet is open
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    final meters = widget.userLocation == null
        ? null
        : widget.distance
            .as(LengthUnit.Meter, widget.userLocation!, poi.position);
    final canCheckIn = meters != null && meters < widget.checkInRadius;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F13),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: poi.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: poi.color.withOpacity(0.5)),
                ),
                child: Icon(poi.icon, color: poi.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poi.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(poi.subtitle,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (meters != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: canCheckIn
                        ? const Color(0xFF39FF14).withOpacity(0.12)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: canCheckIn
                          ? const Color(0xFF39FF14).withOpacity(0.6)
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    '${meters.toStringAsFixed(0)} m',
                    style: TextStyle(
                      color: canCheckIn ? const Color(0xFF39FF14) : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Quest card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_rounded,
                        size: 14, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 6),
                    const Text('ACTIVE QUEST',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w800,
                        )),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF39FF14).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: const Color(0xFF39FF14).withOpacity(0.5)),
                      ),
                      child: Text('+${poi.quest.xpReward} XP',
                          style: const TextStyle(
                              color: Color(0xFF39FF14),
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(poi.quest.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(poi.quest.description,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13, height: 1.4)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      foregroundColor: Colors.blueAccent,
                    ),
                    onPressed: widget.onStartRoute,
                    icon: const Icon(Icons.route_rounded, size: 18),
                    label: const Text('Start Route',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canCheckIn
                          ? const Color(0xFF39FF14)
                          : Colors.white12,
                      foregroundColor:
                          canCheckIn ? Colors.black : Colors.white38,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      elevation: canCheckIn ? 6 : 0,
                      shadowColor: const Color(0xFF39FF14).withOpacity(0.6),
                    ),
                    onPressed: canCheckIn ? widget.onClaimCheckin : null,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Claim Check-in',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),

          if (meters != null && !canCheckIn) ...[
            const SizedBox(height: 10),
            Text(
              'Move within ${widget.checkInRadius.toStringAsFixed(0)} m to claim your check-in.',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
