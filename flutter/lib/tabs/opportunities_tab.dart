import 'package:flutter/material.dart';
import '../widgets/placeholder_tab.dart';

class OpportunitiesTab extends StatelessWidget {
  const OpportunitiesTab({super.key, required this.language});
  final String language;

  @override
  Widget build(BuildContext context) => PlaceholderTab(
        language: language,
        icon: Icons.rocket_launch_rounded,
        titleKey: 'opportunities',
        descKey: 'opps_desc',
        accent: const Color(0xFF7C3AED),
      );
}
