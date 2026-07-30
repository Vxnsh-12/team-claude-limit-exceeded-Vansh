import 'package:flutter/material.dart';
import '../widgets/placeholder_tab.dart';

class SquadTab extends StatelessWidget {
  const SquadTab({super.key, required this.language});
  final String language;

  @override
  Widget build(BuildContext context) => PlaceholderTab(
        language: language,
        icon: Icons.groups_2_rounded,
        titleKey: 'squad',
        descKey: 'squad_desc',
        accent: const Color(0xFF16A34A),
      );
}
