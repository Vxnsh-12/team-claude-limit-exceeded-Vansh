import 'package:flutter/material.dart';
import '../i18n/app_translations.dart';
import '../tabs/campus_hub_tab.dart';
import '../tabs/navigate_tab.dart';
import '../tabs/opportunities_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/squad_tab.dart';
import '../widgets/report_disruption_sheet.dart';

/// Root shell of the VIT Quest super-app.
///
/// * Persistent AppBar with a language dropdown and a Report Disruption button
/// * `IndexedStack` body keeps every tab alive so the map's routing / GPS
///   state survives tab switches
/// * BottomNavigationBar (fixed, 5 tabs)
class VITSuperApp extends StatefulWidget {
  const VITSuperApp({
    super.key,
    required this.orsApiKey,
    required this.mapTilerApiKey,
  });

  final String orsApiKey;
  final String mapTilerApiKey;

  @override
  State<VITSuperApp> createState() => _VITSuperAppState();
}

class _VITSuperAppState extends State<VITSuperApp> {
  int _tab = 0;
  String _language = 'en';

  // Held so the AppBar's "Report Disruption" action can push data into the map.
  final GlobalKey<NavigateTabState> _navigateKey = GlobalKey<NavigateTabState>();

  String _t(String key) => AppTranslations.t(_language, key);

  Future<void> _openReportSheet() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReportDisruptionSheet(language: _language),
    );

    if (submitted != true || !mounted) return;

    final ok = await _navigateKey.currentState
            ?.reportDisruptionAtCurrentLocation() ??
        false;

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          ok ? _t('report_success') : _t('waiting_location'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        backgroundColor:
            ok ? const Color(0xFF16A34A) : const Color(0xFF4B5563),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
  }

  String get _currentTitle {
    switch (_tab) {
      case 0:
        return _t('navigate');
      case 1:
        return _t('squad');
      case 2:
        return _t('hub');
      case 3:
        return _t('opportunities');
      case 4:
        return _t('profile');
      default:
        return _t('app_title');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t('app_title'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _currentTitle,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2A44),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          _LanguageMenuButton(
            language: _language,
            onChanged: (v) => setState(() => _language = v),
          ),
          IconButton(
            tooltip: _t('report_disruption'),
            onPressed: _openReportSheet,
            icon: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.35)),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626), size: 20),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          NavigateTab(
            key: _navigateKey,
            language: _language,
            orsApiKey: widget.orsApiKey,
            mapTilerApiKey: widget.mapTilerApiKey,
          ),
          SquadTab(language: _language),
          CampusHubTab(language: _language),
          OpportunitiesTab(language: _language),
          ProfileTab(language: _language),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1A73E8),
        unselectedItemColor: const Color(0xFF6B7280),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        showUnselectedLabels: true,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map_rounded),
            label: _t('navigate'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.groups_outlined),
            activeIcon: const Icon(Icons.groups_2_rounded),
            label: _t('squad'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.event_note_outlined),
            activeIcon: const Icon(Icons.event_note_rounded),
            label: _t('hub'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.rocket_launch_outlined),
            activeIcon: const Icon(Icons.rocket_launch_rounded),
            label: _t('opportunities'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.emoji_events_outlined),
            activeIcon: const Icon(Icons.emoji_events_rounded),
            label: _t('profile'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// AppBar language dropdown (EN / HI / TE)
// -----------------------------------------------------------------------------
class _LanguageMenuButton extends StatelessWidget {
  const _LanguageMenuButton({required this.language, required this.onChanged});

  final String language;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: PopupMenuButton<String>(
        tooltip: 'Language',
        offset: const Offset(0, 40),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
        onSelected: onChanged,
        itemBuilder: (_) => [
          for (final code in AppTranslations.supported)
            PopupMenuItem<String>(
              value: code,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (code == language)
                    const Icon(Icons.check_rounded,
                        size: 16, color: Color(0xFF1A73E8))
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  Text(
                    AppTranslations.label(code),
                    style: TextStyle(
                      fontWeight:
                          code == language ? FontWeight.w800 : FontWeight.w600,
                      color: const Color(0xFF1F2A44),
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8).withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF1A73E8).withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded,
                  size: 16, color: Color(0xFF1A73E8)),
              const SizedBox(width: 6),
              Text(
                language.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF1A73E8),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Icon(Icons.expand_more_rounded,
                  size: 16, color: Color(0xFF1A73E8)),
            ],
          ),
        ),
      ),
    );
  }
}
