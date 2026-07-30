import 'dart:async';
import 'package:flutter/material.dart';

class CampusHubTab extends StatefulWidget {
  const CampusHubTab({super.key, required this.language});
  final String language;

  @override
  State<CampusHubTab> createState() => _CampusHubTabState();
}

class _CampusHubTabState extends State<CampusHubTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _classAlertTimer;
  bool _syncing = false;
  bool _alertShown = false;

  /// Mock next-class start time.  Set to ~15 min 20 s from mount so the
  /// "class starts in 15 mins" dialog is demoable within a minute.
  late final DateTime _mockClassStart;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _mockClassStart =
        DateTime.now().add(const Duration(minutes: 15, seconds: 20));
    _classAlertTimer =
        Timer.periodic(const Duration(seconds: 10), _checkClassAlert);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _classAlertTimer?.cancel();
    super.dispose();
  }

  void _checkClassAlert(Timer t) {
    if (_alertShown || !mounted) return;
    final minsUntil =
        _mockClassStart.difference(DateTime.now()).inSeconds / 60.0;
    if (minsUntil <= 15.0 && minsUntil > 14.5) {
      _alertShown = true;
      _showClassAlertDialog();
    }
  }

  void _showClassAlertDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.5)),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Class starts in 15 mins!',
                style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'OS Lab · AB-1 · Room 304\nLeave now to be on time — the walk is about 6 minutes from the Central Mess.',
          style: TextStyle(color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
            ),
            child: const Text('Got It',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _syncTimetable() async {
    setState(() => _syncing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text(
          '✅ VTOP Schedule Synced Successfully',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ScheduleCard(
              classTitle: 'OS Lab',
              venue: 'AB-1 · Room 304',
              time: _formatTime(_mockClassStart),
              teacher: 'Prof. Menon',
              onSync: _syncing ? null : _syncTimetable,
              syncing: _syncing,
            ),
            const SizedBox(height: 16),
            _EventsSection(controller: _tabController),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final hh = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString();
    final mm = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ap';
  }
}

// -----------------------------------------------------------------------------
// Schedule card
// -----------------------------------------------------------------------------
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.classTitle,
    required this.venue,
    required this.time,
    required this.teacher,
    required this.onSync,
    required this.syncing,
  });

  final String classTitle;
  final String venue;
  final String time;
  final String teacher;
  final VoidCallback? onSync;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A73E8), Color(0xFF1554B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x331A73E8), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              const Text(
                'VTOP · UP NEXT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(time,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            classTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(venue,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              const Icon(Icons.person_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(teacher,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSync,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    foregroundColor: Colors.white,
                  ),
                  icon: syncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(
                    syncing
                        ? 'Syncing VTOP…'
                        : 'Upload VTOP Timetable',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Events section (Live / Upcoming)
// -----------------------------------------------------------------------------
class _EventsSection extends StatelessWidget {
  const _EventsSection({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text('Campus Events',
                style: TextStyle(
                    color: Color(0xFF1F2A44),
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ),
          TabBar(
            controller: controller,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: const Color(0xFF1A73E8).withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: const Color(0xFF1A73E8).withOpacity(0.35)),
            ),
            dividerColor: Colors.transparent,
            labelColor: const Color(0xFF1A73E8),
            unselectedLabelColor: const Color(0xFF6B7280),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            padding: const EdgeInsets.symmetric(vertical: 6),
            tabs: const [
              Tab(text: '🔴  Live'),
              Tab(text: '📅  Upcoming'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: controller,
              children: [
                _LiveList(),
                _UpcomingList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _EventCard(
          title: 'AdVITya Main Stage',
          location: 'Open Auditorium',
          time: 'Live now',
          color: const Color(0xFFDC2626),
          isLive: true,
        ),
        _EventCard(
          title: 'Coding Club — Flutter Jam',
          location: 'AB-3 · Lab 5',
          time: '2 hr left',
          color: const Color(0xFF7C3AED),
          isLive: true,
        ),
      ],
    );
  }
}

class _UpcomingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _EventCard(
          title: 'Robotics Club Tryouts',
          location: 'Sports Complex',
          time: 'Tomorrow · 5:00 PM',
          color: const Color(0xFF16A34A),
          isLive: false,
        ),
        _EventCard(
          title: 'Startup Bhopal Meetup',
          location: 'Central Library',
          time: 'Fri · 6:30 PM',
          color: const Color(0xFF0EA5E9),
          isLive: false,
        ),
        _EventCard(
          title: 'Hostel Trivia Night',
          location: 'Boys Hostel · Common Room',
          time: 'Sat · 9:00 PM',
          color: const Color(0xFFF59E0B),
          isLive: false,
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.title,
    required this.location,
    required this.time,
    required this.color,
    required this.isLive,
  });

  final String title;
  final String location;
  final String time;
  final Color color;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLive
                  ? Icons.podcasts_rounded
                  : Icons.event_available_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place_rounded, color: color, size: 10),
                          const SizedBox(width: 4),
                          Text(location,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(time,
                        style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
