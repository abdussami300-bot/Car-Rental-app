import 'package:flutter/material.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String carName;
  final String otherPartyName;
  final bool isHostViewing;
  final String currentUserEmail;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.carName,
    this.otherPartyName = "Host",
    this.isHostViewing = false,
    this.currentUserEmail = "sami@example.com",
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickChips = [
    "Is airport delivery available?",
    "Can you share exact pickup location?",
    "Is the AC chilled?",
    "What is the security deposit policy?",
    "What time can I pick up the keys?",
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final newMsg = ChatMessage(
      id: "msg_${DateTime.now().millisecondsSinceEpoch}",
      bookingId: widget.bookingId,
      carName: widget.carName,
      senderEmail: widget.currentUserEmail,
      senderName: widget.isHostViewing ? "Host" : "Renter",
      text: text.trim(),
      timestamp: DateTime.now(),
      isFromHost: widget.isHostViewing,
    );

    setState(() {
      chatMessagesList.add(newMsg);
      _textController.clear();
    });

    await saveChatMessagesToLocalStorage();
    FirestoreService.saveChatMessageToFirestore(newMsg);

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    // Auto-reply simulation from host if renter sent a message
    if (!widget.isHostViewing) {
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        final reply = ChatMessage(
          id: "msg_reply_${DateTime.now().millisecondsSinceEpoch}",
          bookingId: widget.bookingId,
          carName: widget.carName,
          senderEmail: "host@example.com",
          senderName: widget.otherPartyName,
          text: "Walaikum as-salam! I have received your query regarding ${widget.carName}. Please wait a moment while I check and confirm this for you.",
          timestamp: DateTime.now(),
          isFromHost: true,
        );
        setState(() {
          chatMessagesList.add(reply);
        });
        await saveChatMessagesToLocalStorage();
        FirestoreService.saveChatMessageToFirestore(reply);

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = getMessagesForBooking(widget.bookingId, widget.carName);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.isHostViewing ? Colors.blueGrey : AppTheme.primary,
              child: Icon(
                widget.isHostViewing ? Icons.person : Icons.directions_car,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherPartyName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.carName,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: AppTheme.primary),
            tooltip: "Call",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Calling ${widget.otherPartyName} (+92 300 1234567)..."),
                  backgroundColor: AppTheme.primary,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [



          const Divider(color: Colors.white12, height: 1),

          // MESSAGES LIST
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: FirestoreService.streamMessagesForBooking(widget.bookingId, widget.carName),
              builder: (context, snapshot) {
                final displayMessages = (snapshot.hasData && snapshot.data!.isNotEmpty)
                    ? snapshot.data!
                    : getMessagesForBooking(widget.bookingId, widget.carName);

                if (displayMessages.isEmpty) {
                  return const Center(
                    child: Text("No messages yet. Say hello!", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    final msg = displayMessages[index];
                    final isMe = widget.isHostViewing ? msg.isFromHost : !msg.isFromHost;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primary : const Color(0xFF222222),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                          ),
                          border: isMe ? null : Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // QUICK CHIPS
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _quickChips.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chip = _quickChips[index];
                return ActionChip(
                  label: Text(chip, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  backgroundColor: const Color(0xFF1E1E1E),
                  side: const BorderSide(color: Colors.white12),
                  onPressed: () => _sendMessage(chip),
                );
              },
            ),
          ),

          // TEXT INPUT BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF181818),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF222222),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _sendMessage(_textController.text),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 18),
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
