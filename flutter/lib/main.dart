import 'package:flutter/material.dart';
import 'app/vit_super_app.dart';

void main() {
  runApp(const VITQuestApp());
}

class VITQuestApp extends StatelessWidget {
  const VITQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIT Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const VITSuperApp(
        orsApiKey:
            'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjE5Mzk0MmE2ZDVhMTRjMTY4YzVlNjMyYjVmMjFhMWY3IiwiaCI6Im11cm11cjY0In0=',
        mapTilerApiKey: '0BNwrOGmOw4HXYKTGrot',
      ),
    );
  }
}
