import 'package:flutter/material.dart';

class OpportunitiesTab extends StatefulWidget {
  const OpportunitiesTab({super.key, required this.language});
  final String language;

  @override
  State<OpportunitiesTab> createState() => _OpportunitiesTabState();
}

class _OpportunitiesTabState extends State<OpportunitiesTab> {
  static const List<String> _filters = [
    'All',
    'Python',
    'Flutter',
    'ML',
    'Competitions',
    'Research',
  ];

  String _selected = 'All';

  static const List<_Opportunity> _all = [
    _Opportunity(
      title: 'Smart India Hackathon Team',
      skills: ['Flutter', 'ML', 'Python'],
      posterName: 'Rhea Kapoor',
      posterYear: '3rd year · CSE',
      description:
          'Looking for two teammates to build a computer-vision solution for the SIH shortlist. Prototype due in 3 weeks.',
      accent: Color(0xFF1A73E8),
      icon: Icons.emoji_events_rounded,
      tag: 'Hackathon',
    ),
    _Opportunity(
      title: 'AdVITya Coding Contest',
      skills: ['Python', 'Competitions'],
      posterName: 'Coding Club',
      posterYear: 'Official',
      description:
          '3-hour algorithms sprint · ₹15,000 prize pool · beginners and pros both welcome. Team of 2 max.',
      accent: Color(0xFFDC2626),
      icon: Icons.speed_rounded,
      tag: 'Competition',
    ),
    _Opportunity(
      title: 'AI Research Study Group',
      skills: ['ML', 'Research'],
      posterName: 'Dr. Anand Iyer',
      posterYear: 'Faculty · AI Lab',
      description:
          'Weekly reading group on foundation models. Great fit for anyone eyeing MS applications.',
      accent: Color(0xFF7C3AED),
      icon: Icons.psychology_rounded,
      tag: 'Research',
    ),
    _Opportunity(
      title: 'Flutter Meetup — Design Systems',
      skills: ['Flutter'],
      posterName: 'ARON J.',
      posterYear: '2nd year · ECE',
      description:
          'Study group for building production-grade design systems in Flutter. Meets Wed 7 PM at AB-2.',
      accent: Color(0xFF16A34A),
      icon: Icons.group_work_rounded,
      tag: 'Study Group',
    ),
    _Opportunity(
      title: 'Kaggle Intramural Challenge',
      skills: ['Python', 'ML', 'Competitions'],
      posterName: 'Data Club',
      posterYear: 'Official',
      description:
          'Beat the campus baseline model — top 3 win Bluetooth headphones + certificates.',
      accent: Color(0xFF0EA5E9),
      icon: Icons.dataset_rounded,
      tag: 'Competition',
    ),
  ];

  List<_Opportunity> get _filtered {
    if (_selected == 'All') return _all;
    return _all
        .where((o) => o.skills.contains(_selected) || o.tag == _selected)
        .toList();
  }

  void _apply(_Opportunity o) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '🚀 Applied to “${o.title}” — poster will be notified.',
          style: const TextStyle(fontWeight: FontWeight.w800),
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
        child: Column(
          children: [
            // Filter chip row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final active = _selected == f;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF1A73E8)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF1A73E8)
                                : Colors.black.withOpacity(0.08),
                          ),
                          boxShadow: active
                              ? const [
                                  BoxShadow(
                                    color: Color(0x331A73E8),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : const Color(0xFF1F2A44),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: _filtered.length,
                itemBuilder: (_, i) =>
                    _OpportunityCard(o: _filtered[i], onApply: () => _apply(_filtered[i])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opportunity {
  const _Opportunity({
    required this.title,
    required this.skills,
    required this.posterName,
    required this.posterYear,
    required this.description,
    required this.accent,
    required this.icon,
    required this.tag,
  });

  final String title;
  final List<String> skills;
  final String posterName;
  final String posterYear;
  final String description;
  final Color accent;
  final IconData icon;
  final String tag;
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.o, required this.onApply});
  final _Opportunity o;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: o.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: o.accent.withOpacity(0.4)),
                ),
                child: Icon(o.icon, color: o.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o.title,
                        style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 2),
                    Text('${o.posterName} · ${o.posterYear}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: o.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(o.tag,
                    style: TextStyle(
                        color: o.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(o.description,
              style: const TextStyle(
                  color: Color(0xFF4B5563), fontSize: 12, height: 1.45)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in o.skills)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Text(s,
                      style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: o.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Apply / Connect',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
