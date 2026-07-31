import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';

class SquadTab extends StatelessWidget {
  const SquadTab({super.key, required this.language});
  final String language;

  static const List<_Friend> _friends = [
    _Friend(
      name: 'Dev',
      handle: '@dev.mishra',
      year: '3rd year · CSE',
      status: 'Near AB-1 · online now',
      color: Color(0xFF1A73E8),
      online: true,
    ),
    _Friend(
      name: 'ARON',
      handle: '@aron.j',
      year: '2nd year · ECE',
      status: 'At Foodys · 5 min ago',
      color: Color(0xFF16A34A),
      online: true,
    ),
    _Friend(
      name: 'Lakshay',
      handle: '@lakshay.s',
      year: '4th year · Mech',
      status: 'Cricket Ground · 12 min ago',
      color: Color(0xFF7C3AED),
      online: false,
    ),
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
            _SectionHeader(
              icon: Icons.bolt_rounded,
              accent: const Color(0xFF16A34A),
              title: 'Your Squad',
              subtitle: '${_friends.length} friends nearby',
            ),
            const SizedBox(height: 12),
            ..._friends.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FriendCard(friend: f),
                )),
            const SizedBox(height: 8),
            _SectionHeader(
              icon: Icons.chat_bubble_rounded,
              accent: const Color(0xFF1A73E8),
              title: 'Group Chats',
              subtitle: 'Squad-wide + club channels',
            ),
            const SizedBox(height: 12),
            _GroupTile(
              name: 'AB-1 Study Squad',
              lastMsg: 'Meet at the library at 6?',
              members: 8,
              color: const Color(0xFF1A73E8),
            ),
            const SizedBox(height: 8),
            _GroupTile(
              name: 'Hackathon Prep',
              lastMsg: 'ARON: idea drop tonight 🧠',
              members: 12,
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Friend model + card
// -----------------------------------------------------------------------------
class _Friend {
  const _Friend({
    required this.name,
    required this.handle,
    required this.year,
    required this.status,
    required this.color,
    required this.online,
  });

  final String name;
  final String handle;
  final String year;
  final String status;
  final Color color;
  final bool online;
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend});
  final _Friend friend;

  void _locate(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text('📍 Locating ${friend.name} on the campus map…',
                style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F2A44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      ));
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(friendName: friend.name, friendColor: friend.color),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: friend.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: friend.color.withOpacity(0.5), width: 2),
                ),
                child: Text(
                  friend.name.substring(0, 1),
                  style: TextStyle(
                    color: friend.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (friend.online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(friend.name,
                        style: const TextStyle(
                            color: Color(0xFF1F2A44),
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 6),
                    Text(friend.handle,
                        style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(friend.year,
                    style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle,
                        size: 6,
                        color:
                            friend.online ? const Color(0xFF16A34A) : Colors.grey),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(friend.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _IconAction(
            icon: Icons.location_on_rounded,
            color: const Color(0xFF1A73E8),
            tooltip: 'Locate',
            onTap: () => _locate(context),
          ),
          const SizedBox(width: 6),
          _IconAction(
            icon: Icons.chat_rounded,
            color: const Color(0xFF16A34A),
            tooltip: 'Chat',
            onTap: () => _openChat(context),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withOpacity(0.35)),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.name,
    required this.lastMsg,
    required this.members,
    required this.color,
  });

  final String name;
  final String lastMsg;
  final int members;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Icon(Icons.group_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                Text(lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$members',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
