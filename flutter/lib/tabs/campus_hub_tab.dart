import 'package:flutter/material.dart';
import '../widgets/placeholder_tab.dart';

class CampusHubTab extends StatelessWidget {
  const CampusHubTab({super.key, required this.language});
  final String language;

  @override
  Widget build(BuildContext context) => PlaceholderTab(
        language: language,
        icon: Icons.event_note_rounded,
        titleKey: 'hub',
        descKey: 'hub_desc',
        accent: const Color(0xFF0EA5E9),
      );
}
