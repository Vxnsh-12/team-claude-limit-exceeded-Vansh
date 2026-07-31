# VIT Bhopal Navigation — Flutter App

Turn-by-turn walking navigation for VIT Bhopal (Kotri Kalan) built with
`flutter_map` + MapTiler tiles + OpenRouteService directions.

## Layout

```
flutter/
├── pubspec.yaml
├── analysis_options.yaml
├── .gitignore
├── lib/
│   ├── main.dart                              # app entrypoint
│   └── screens/
│       ├── vit_bhopal_map_screen.dart         # gamified quest map (v1)
│       └── vit_navigation_screen.dart         # turn-by-turn walking nav
└── README.md
```

## Getting started

```bash
cd flutter
flutter pub get
flutter run
```

`main.dart` is already wired to launch straight into
`VITNavigationScreen(destination: LatLng(23.075, 76.852), destinationName: 'Academic Block 1', orsApiKey: '<ORS_KEY>')`.
Update `destination` / `destinationName` / `orsApiKey` in `lib/main.dart` when
you need a different target or a fresh key.

## Platform permissions

### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```
Also set `minSdkVersion` ≥ **21** and `compileSdkVersion` ≥ **34** in
`android/app/build.gradle`.

### iOS — `ios/Runner/Info.plist`
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>VIT Navigation uses your location to guide you across campus.</string>
```

## Third-party keys

| Service | Where it lives | How to get one |
|---|---|---|
| MapTiler (base tiles) | `mapTilerApiKey` param of `VITNavigationScreen` — defaults to the key provided in the spec | https://www.maptiler.com/cloud/ (free tier: 100k tiles/mo) |
| OpenRouteService (walking directions) | `orsApiKey` param of `VITNavigationScreen` — currently the test key in `main.dart` | https://openrouteservice.org/dev/#/signup (free tier: 2 000 requests/day) |

## What `VITNavigationScreen` does

- Renders MapTiler `streets-v2` raster tiles, locked to
  `CameraConstraint.contain(LatLngBounds(23.065, 76.840) → (23.090, 76.865))`
  with `minZoom: 16.0`
- POSTs to `https://api.openrouteservice.org/v2/directions/foot-walking/geojson`
  and parses both:
  * `features[0].geometry.coordinates` → `PolylineLayer` (blue, white border)
  * `features[0].properties.segments[0].steps` → maneuvers (`instruction`,
    `distance`, `type`, `way_points`)
- Google-Maps-style top banner with maneuver icon, live remaining distance to
  the turn, instruction, and step counter
- Streams `Geolocator.getPositionStream(bestForNavigation, distanceFilter: 3)`,
  computes `Distance().as(LengthUnit.Meter, user, maneuverPoint)` and
  auto-advances the step queue when < **10 m**
- Rotates + centres the map with `MapController.moveAndRotate(user, 18.0, -heading)`
  so the user's heading is always "up"
- Bottom progress bar (remaining distance + ETA) with Exit button + re-centre FAB
