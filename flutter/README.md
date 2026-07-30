# VIT Bhopal Map — Flutter Widget

A high-detail, production-ready `flutter_map` widget for VIT Bhopal campus
navigation with quest-based gamification.

## Files
- `lib/screens/vit_bhopal_map_screen.dart` — the `VITBhopalMapScreen` widget
- `lib/screens/vit_navigation_screen.dart` — the `VITNavigationScreen` widget (turn-by-turn walking directions)

## Add these deps to your `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_map: ^6.0.0
  latlong2: ^0.9.1
  geolocator: ^11.0.0
  http: ^1.2.0
```

Then run:
```bash
flutter pub get
```

## Platform permissions

### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS — `ios/Runner/Info.plist`
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>VIT Quest uses your location to unlock check-ins on campus.</string>
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'screens/vit_bhopal_map_screen.dart';

void main() {
  runApp(const MaterialApp(
    home: VITBhopalMapScreen(
      mapTilerApiKey: 'YOUR_MAPTILER_API_KEY',
    ),
  ));
}
```

Get a MapTiler key at https://www.maptiler.com/cloud/ (free tier: 100k tiles/mo).
Get an OpenRouteService key at https://openrouteservice.org/dev/#/signup (free tier: 2 000 requests/day).

## Turn-by-Turn Navigation (`VITNavigationScreen`)

```dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'screens/vit_navigation_screen.dart';

Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => VITNavigationScreen(
    destination: const LatLng(23.0787, 76.8528),
    destinationName: 'Sports Complex',
    orsApiKey: 'YOUR_ORS_API_KEY',        // https://openrouteservice.org
    // mapTilerApiKey is already wired to the key you provided
  ),
));
```

### What the widget does
- Locks the map to `CameraConstraint.contain(LatLngBounds(23.065,76.840)-(23.090,76.865))` and `minZoom: 16.0`
- Posts to `https://api.openrouteservice.org/v2/directions/foot-walking/geojson`, parses:
  * `features[0].geometry.coordinates` → route `PolylineLayer` (blue, white border)
  * `features[0].properties.segments[0].steps` → maneuvers (`instruction`, `distance`, `type`, `way_points`)
- Renders a floating Google-Maps-style banner at the top with a maneuver icon, remaining distance to the turn, the instruction text, and step counter
- Streams `Geolocator.getPositionStream(bestForNavigation, distanceFilter: 3)`, computes `Distance().as(LengthUnit.Meter, user, maneuverPoint)`, and auto-advances the queue when < 10 m
- Rotates + centres the map with `MapController.moveAndRotate(user, 18.0, -heading)` on every position update, so the user's heading is always "up"
- Bottom progress bar (total remaining + ETA) with an Exit button, and a "recentre" FAB

## Feature checklist
- [x] Campus centered at `23.0775, 76.8513` · zoom 16.5 (min 15 / max 19)
- [x] MapTiler `streets-v2` 256-px tiles
- [x] 6 gamified POIs (AB-1, AB-2, Boys Hostels, Girls Hostels, Central Mess, Sports Complex)
- [x] Interactive bottom sheet with quest info + XP badge + live distance chip
- [x] "Start Route" draws a `PolylineLayer` (blueAccent, width 5.0) from user → target
- [x] "Claim Check-in" enabled only when `Distance().as(LengthUnit.Meter, ...) < 30 m`
- [x] Live GPS via `Geolocator.getPositionStream` with a pulsating cyan marker
- [x] Graceful permission handling — inline banner with "Enable" → app settings
- [x] Rotation disabled (mobile-only interaction flags) + recenter FAB
