import 'package:flutter/material.dart';
import '../widgets/placeholder_tab.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.language});
  final String language;

  @override
  Widget build(BuildContext context) => PlaceholderTab(
        language: language,
        icon: Icons.emoji_events_rounded,
        titleKey: 'profile',
        descKey: 'profile_desc',
        accent: const Color(0xFFF59E0B),
      );
}
