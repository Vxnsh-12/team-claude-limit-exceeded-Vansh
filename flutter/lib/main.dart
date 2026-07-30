import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'screens/vit_navigation_screen.dart';

void main() {
  runApp(const VITQuestNavApp());
}

class VITQuestNavApp extends StatelessWidget {
  const VITQuestNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIT Bhopal Navigation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        useMaterial3: true,
      ),
      home: const VITNavigationScreen(
        destination: LatLng(23.075, 76.852),
        destinationName: 'Academic Block 1',
        orsApiKey:
            'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjE5Mzk0MmE2ZDVhMTRjMTY4YzVlNjMyYjVmMjFhMWY3IiwiaCI6Im11cm11cjY0In0=',
      ),
    );
  }
}
