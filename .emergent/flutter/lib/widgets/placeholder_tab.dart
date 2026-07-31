import 'package:flutter/material.dart';
import '../i18n/app_translations.dart';

/// Shared placeholder used by Squad / Campus Hub / Opportunities / Profile tabs
/// while their real UIs are being built.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    super.key,
    required this.language,
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.accent,
  });

  final String language;
  final IconData icon;
  final String titleKey;
  final String descKey;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final title = AppTranslations.t(language, titleKey);
    final desc = AppTranslations.t(language, descKey);
    final soon = AppTranslations.t(language, 'placeholder_soon');

    return Container(
      color: const Color(0xFFF6F7FB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.35), width: 2),
                ),
                child: Icon(icon, size: 42, color: accent),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2A44),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF4A5468),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Text(
                  soon.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
