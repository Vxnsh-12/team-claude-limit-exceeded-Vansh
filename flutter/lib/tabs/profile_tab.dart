import 'package:flutter/material.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.language});
  final String language;

  static const List<_LeaderRow> _leaderboard = [
    _LeaderRow(rank: 1, name: 'Nova Chen',    year: '4th · CSE',  xp: 3120, avatarSeed: 'N', color: Color(0xFF16A34A)),
    _LeaderRow(rank: 2, name: 'You',          year: '3rd · CSE',  xp: 1250, avatarSeed: 'Y', color: Color(0xFF1A73E8), isYou: true),
    _LeaderRow(rank: 3, name: 'ARON',         year: '2nd · ECE',  xp: 1090, avatarSeed: 'A', color: Color(0xFF16A34A)),
    _LeaderRow(rank: 4, name: 'Lakshay',      year: '4th · Mech', xp:  980, avatarSeed: 'L', color: Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _IdentityCard(),
            const SizedBox(height: 14),
            _GamificationStats(),
            const SizedBox(height: 20),
            _LeaderboardCard(rows: _leaderboard),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Identity card
// -----------------------------------------------------------------------------
class _IdentityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A73E8), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
            ),
            child: const Text(
              'Y',
              style: TextStyle(
                color: Color(0xFF1A73E8),
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Yash Rajput',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.explore_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('Campus Explorer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text('VIT Bhopal · 3rd year',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Gamification stat grid
// -----------------------------------------------------------------------------
class _GamificationStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StatTile(
            icon: '⭐',
            value: '1250',
            label: 'XP',
            color: Color(0xFFF59E0B),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: '🏅',
            value: 'Lv 5',
            label: 'Level',
            color: Color(0xFF1A73E8),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: '🔥',
            value: '14',
            label: 'Day Streak',
            color: Color(0xFFDC2626),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final String icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              )),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Leaderboard
// -----------------------------------------------------------------------------
class _LeaderRow {
  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.year,
    required this.xp,
    required this.avatarSeed,
    required this.color,
    this.isYou = false,
  });

  final int rank;
  final String name;
  final String year;
  final int xp;
  final String avatarSeed;
  final Color color;
  final bool isYou;
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.rows});
  final List<_LeaderRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: const Icon(Icons.leaderboard_rounded,
                    color: Color(0xFFF59E0B), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Campus Top Explorers',
                  style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => _LeaderTile(row: r)),
        ],
      ),
    );
  }
}

class _LeaderTile extends StatelessWidget {
  const _LeaderTile({required this.row});
  final _LeaderRow row;

  @override
  Widget build(BuildContext context) {
    final youBg =
        row.isYou ? const Color(0xFF1A73E8).withOpacity(0.08) : Colors.transparent;
    final youBorder = row.isYou
        ? const Color(0xFF1A73E8).withOpacity(0.4)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: youBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: youBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('#${row.rank}',
                style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: row.color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: row.color.withOpacity(0.5), width: 2),
            ),
            child: Text(row.avatarSeed,
                style: TextStyle(
                    color: row.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(row.name,
                        style: const TextStyle(
                            color: Color(0xFF1F2A44),
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                    if (row.isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('YOU',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                Text(row.year,
                    style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${row.xp}',
                  style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3)),
              const Text('XP',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ],
          ),
        ],
      ),
    );
  }
}
