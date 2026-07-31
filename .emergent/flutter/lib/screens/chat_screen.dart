import 'package:flutter/material.dart';

/// WhatsApp-style 1:1 chat with a lightweight NSFW filter.
///
/// Any typed message that contains a word listed in [bannedWords] is
/// intercepted before submit and surfaced as a red SnackBar; clean messages
/// append a blue bubble to the log.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.friendName,
    required this.friendColor,
  });

  final String friendName;
  final Color friendColor;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// Words that will be blocked from being sent.
  final List<String> bannedWords = ['abuse', 'spam'];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_ChatMessage> _messages = [
    _ChatMessage(text: 'Hey! Are you coming to AdVITya tonight?', isMine: false),
    _ChatMessage(text: 'Yep, meet at Foodys around 7?', isMine: true),
    _ChatMessage(text: 'Perfect. I\'ll grab a table for the squad 🍟', isMine: false),
  ];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final lower = text.toLowerCase();
    final blocked = bannedWords.any((w) => lower.contains(w.toLowerCase()));
    if (blocked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text(
            '⚠️  Message blocked: Contains inappropriate language.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ));
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, isMine: true));
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7EBF0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.friendColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: widget.friendColor.withOpacity(0.5)),
              ),
              child: Text(
                widget.friendName.substring(0, 1),
                style: TextStyle(
                  color: widget.friendColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.friendName,
                    style: const TextStyle(
                        color: Color(0xFF1F2A44),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
                const Text('online',
                    style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.videocam_rounded, color: Color(0xFF6B7280)),
          ),
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.call_rounded, color: Color(0xFF6B7280)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.emoji_emotions_outlined,
                      color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: 3,
                        minLines: 1,
                        style: const TextStyle(
                            color: Color(0xFF1F2A44),
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: 'Message…',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFF1A73E8),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _send,
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.text, required this.isMine});
  final String text;
  final bool isMine;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color:
              message.isMine ? const Color(0xFF1A73E8) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMine ? 16 : 4),
            bottomRight: Radius.circular(message.isMine ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color:
                message.isMine ? Colors.white : const Color(0xFF1F2A44),
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
