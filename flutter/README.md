# VIT Bhopal Map — Flutter Widget

A high-detail, production-ready `flutter_map` widget for VIT Bhopal campus
navigation with quest-based gamification.

## Files
- `lib/screens/vit_bhopal_map_screen.dart` — the `VITBhopalMapScreen` widget

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
