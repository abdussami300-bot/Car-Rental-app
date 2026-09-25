import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String carName;
  final String otherPartyName;
  final bool isHostViewing;
  final String currentUserEmail;
  final String currentUserName;
  final String carId;
  final String ownerEmail;
  final String customerEmail;
  final String ownerId;
  final String customerId;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.carName,
    this.otherPartyName = "Host",
    this.isHostViewing = false,
    this.currentUserEmail = "",
    this.currentUserName = "",
    this.carId = "",
    this.ownerEmail = "",
    this.customerEmail = "",
    this.ownerId = "",
    this.customerId = "",
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _effectiveUserName = "";
  String _effectiveOtherPartyName = "";
  late final Stream<List<ChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _effectiveOtherPartyName = widget.otherPartyName;
    _messagesStream = FirestoreService.streamMessagesForConversation(
      bookingId: widget.bookingId,
      carName: widget.carName,
      carId: widget.carId,
      customerEmail: widget.customerEmail,
      ownerEmail: widget.ownerEmail,
      customerId: widget.customerId,
      ownerId: widget.ownerId,
    );
    _resolveUserName();
  }

  Future<void> _resolveUserName() async {
    // 1. Resolve current user's display name
    String candidate = "";
    if (widget.currentUserName.trim().isNotEmpty &&
        widget.currentUserName.trim().toLowerCase() != "host" &&
        widget.currentUserName.trim().toLowerCase() != "renter") {
      candidate = widget.currentUserName.trim();
    } else if (activeUserName.trim().isNotEmpty &&
        activeUserName.trim().toLowerCase() != "host" &&
        activeUserName.trim().toLowerCase() != "renter") {
      candidate = activeUserName.trim();
    } else if (name.trim().isNotEmpty &&
        name.trim().toLowerCase() != "host" &&
        name.trim().toLowerCase() != "renter") {
      candidate = name.trim();
    }

    if (candidate.isEmpty) {
      final authName = FirebaseAuth.instance.currentUser?.displayName ?? "";
      if (authName.trim().isNotEmpty) {
        candidate = authName.trim();
      }
    }

    if (candidate.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = (prefs.getString("app_user_active_name") ?? prefs.getString("app_user_name") ?? "").trim();
        if (saved.isNotEmpty && saved.toLowerCase() != "host" && saved.toLowerCase() != "renter") {
          candidate = saved;
        }
      } catch (_) {}
    }

    if (candidate.isEmpty) {
      try {
        final uid = widget.isHostViewing
            ? (widget.ownerId.isNotEmpty ? widget.ownerId : (activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "")))
            : (widget.customerId.isNotEmpty ? widget.customerId : (activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "")));
        if (uid.isNotEmpty) {
          final profile = await AuthService().getUserProfileById(uid);
          if (profile != null && (profile['name'] ?? "").toString().trim().isNotEmpty) {
            candidate = profile['name'].toString().trim();
          }
        }
        if (candidate.isEmpty) {
          final emailToLookup = widget.currentUserEmail.trim().isNotEmpty
              ? widget.currentUserEmail.trim()
              : (activeUserEmail.trim().isNotEmpty
                  ? activeUserEmail.trim()
                  : (FirebaseAuth.instance.currentUser?.email ?? ""));
          if (emailToLookup.isNotEmpty) {
            final profile = await AuthService().getUserProfileByEmail(emailToLookup);
            if (profile != null && (profile['name'] ?? "").toString().trim().isNotEmpty) {
              candidate = profile['name'].toString().trim();
            }
          }
        }
      } catch (_) {}
    }

    if (candidate.isNotEmpty) {
      _effectiveUserName = candidate;
    } else {
      _effectiveUserName = widget.isHostViewing ? "Host" : "Renter";
    }

    // 2. Resolve other party's name if generic ("Host", "Renter", or starts with "Host (")
    final currentOther = _effectiveOtherPartyName.trim();
    if (currentOther.isEmpty ||
        currentOther.toLowerCase() == "host" ||
        currentOther.toLowerCase() == "renter" ||
        currentOther.startsWith("Host (")) {
      try {
        if (!widget.isHostViewing) {
          // Customer looking at host's profile
          if (widget.ownerId.isNotEmpty) {
            final p = await AuthService().getUserProfileById(widget.ownerId);
            if (p != null && (p['name'] ?? "").toString().trim().isNotEmpty) {
              _effectiveOtherPartyName = p['name'].toString().trim();
            }
          }
          if ((_effectiveOtherPartyName.isEmpty || _effectiveOtherPartyName == "Host" || _effectiveOtherPartyName.startsWith("Host (")) && widget.ownerEmail.isNotEmpty) {
            final p = await AuthService().getUserProfileByEmail(widget.ownerEmail);
            if (p != null && (p['name'] ?? "").toString().trim().isNotEmpty) {
              _effectiveOtherPartyName = p['name'].toString().trim();
            }
          }
        } else {
          // Host looking at renter's profile
          if (widget.customerId.isNotEmpty) {
            final p = await AuthService().getUserProfileById(widget.customerId);
            if (p != null && (p['name'] ?? "").toString().trim().isNotEmpty) {
              _effectiveOtherPartyName = p['name'].toString().trim();
            }
          }
          if ((_effectiveOtherPartyName.isEmpty || _effectiveOtherPartyName == "Renter") && widget.customerEmail.isNotEmpty) {
            final p = await AuthService().getUserProfileByEmail(widget.customerEmail);
            if (p != null && (p['name'] ?? "").toString().trim().isNotEmpty) {
              _effectiveOtherPartyName = p['name'].toString().trim();
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  List<String> get _quickChips {
    if (widget.isHostViewing) {
      return [
        "Vehicle is available for your dates!",
        "Key pickup is at the designated location.",
        "Please make sure to complete pre-trip inspection.",
        "Feel free to call me if you need directions.",
        "Safe travels! Let me know if you need anything.",
      ];
    }
    return [
      "Is airport delivery available?",
      "Can you share exact pickup location?",
      "Is the AC chilled?",
      "What is the security deposit policy?",
      "What time can I pick up the keys?",
    ];
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final existingMsgs = getMessagesForBooking(
      widget.bookingId,
      widget.carName,
      carId: widget.carId,
      customerId: widget.customerId,
      customerEmail: widget.customerEmail,
    );
    final isFirstMessage = existingMsgs.isEmpty;

    final senderId = widget.isHostViewing
        ? (widget.ownerId.isNotEmpty ? widget.ownerId : (activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "")))
        : (widget.customerId.isNotEmpty ? widget.customerId : (activeUserId.isNotEmpty ? activeUserId : (FirebaseAuth.instance.currentUser?.uid ?? "")));

    // Ensure we have a non-generic real sender name
    String resolvedSenderName = _effectiveUserName.trim();
    if (resolvedSenderName.isEmpty ||
        resolvedSenderName.toLowerCase() == "host" ||
        resolvedSenderName.toLowerCase() == "renter") {
      if (widget.currentUserName.trim().isNotEmpty &&
          widget.currentUserName.trim().toLowerCase() != "host" &&
          widget.currentUserName.trim().toLowerCase() != "renter") {
        resolvedSenderName = widget.currentUserName.trim();
      } else if (activeUserName.trim().isNotEmpty &&
          activeUserName.trim().toLowerCase() != "host" &&
          activeUserName.trim().toLowerCase() != "renter") {
        resolvedSenderName = activeUserName.trim();
      } else if (name.trim().isNotEmpty &&
          name.trim().toLowerCase() != "host" &&
          name.trim().toLowerCase() != "renter") {
        resolvedSenderName = name.trim();
      } else {
        final authName = FirebaseAuth.instance.currentUser?.displayName ?? "";
        if (authName.trim().isNotEmpty) {
          resolvedSenderName = authName.trim();
        } else {
          try {
            final prefs = await SharedPreferences.getInstance();
            final saved = (prefs.getString("app_user_active_name") ?? prefs.getString("app_user_name") ?? "").trim();
            if (saved.isNotEmpty && saved.toLowerCase() != "host" && saved.toLowerCase() != "renter") {
              resolvedSenderName = saved;
            } else {
              final uid = senderId.isNotEmpty ? senderId : (FirebaseAuth.instance.currentUser?.uid ?? "");
              if (uid.isNotEmpty) {
                final profile = await AuthService().getUserProfileById(uid);
                if (profile != null && (profile['name'] ?? "").toString().trim().isNotEmpty) {
                  resolvedSenderName = profile['name'].toString().trim();
                }
              }
              if (resolvedSenderName.isEmpty ||
                  resolvedSenderName.toLowerCase() == "host" ||
                  resolvedSenderName.toLowerCase() == "renter") {
                final emailToLookup = widget.currentUserEmail.trim().isNotEmpty
                    ? widget.currentUserEmail.trim()
                    : (activeUserEmail.trim().isNotEmpty
                        ? activeUserEmail.trim()
                        : (FirebaseAuth.instance.currentUser?.email ?? ""));
                if (emailToLookup.isNotEmpty) {
                  final profile = await AuthService().getUserProfileByEmail(emailToLookup);
                  if (profile != null && (profile['name'] ?? "").toString().trim().isNotEmpty) {
                    resolvedSenderName = profile['name'].toString().trim();
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    if (resolvedSenderName.isEmpty) {
      resolvedSenderName = widget.isHostViewing ? "Host" : "Renter";
    }
    _effectiveUserName = resolvedSenderName;

    final resolvedSenderEmail = widget.currentUserEmail.trim().isNotEmpty
        ? widget.currentUserEmail.trim()
        : (activeUserEmail.trim().isNotEmpty
            ? activeUserEmail.trim()
            : (FirebaseAuth.instance.currentUser?.email ?? email));

    final newMsg = ChatMessage(
      id: "msg_${DateTime.now().millisecondsSinceEpoch}",
      bookingId: widget.bookingId,
      carId: widget.carId,
      carName: widget.carName,
      senderId: senderId,
      senderEmail: resolvedSenderEmail,
      senderName: resolvedSenderName,
      ownerId: widget.ownerId,
      customerId: widget.customerId,
      ownerEmail: widget.ownerEmail,
      customerEmail: widget.customerEmail,
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

    // If this is the customer's first message to host, deliver automated greeting from host
    if (!widget.isHostViewing && isFirstMessage) {
      Future.delayed(const Duration(milliseconds: 600), () async {
        String hostDisplayName = _effectiveOtherPartyName.isNotEmpty ? _effectiveOtherPartyName : widget.otherPartyName;
        if (hostDisplayName.isEmpty || hostDisplayName.toLowerCase() == "host" || hostDisplayName.startsWith("Host (")) {
          if (widget.ownerId.isNotEmpty) {
            final profile = await AuthService().getUserProfileById(widget.ownerId);
            if (profile != null && (profile['name'] ?? "").toString().trim().isNotEmpty) {
              hostDisplayName = profile['name'].toString().trim();
            }
          }
          if (hostDisplayName.isEmpty || hostDisplayName.toLowerCase() == "host" || hostDisplayName.startsWith("Host (")) {
            final car = allCarsList.firstWhere(
              (c) => (widget.carId.isNotEmpty && c.id == widget.carId) || c.name == widget.carName,
              orElse: () => CarItem(id: "", name: "", brand: "", price: "", rating: 5.0, image: ""),
            );
            if (car.ownerEmail.isNotEmpty) {
              final profile = await AuthService().getUserProfileByEmail(car.ownerEmail);
              if (profile != null && (profile['name'] ?? "").toString().trim().isNotEmpty) {
                hostDisplayName = profile['name'].toString().trim();
              }
            }
          }
        }
        if (hostDisplayName.isEmpty) hostDisplayName = "Host";

        final autoReply = ChatMessage(
          id: "msg_auto_${DateTime.now().millisecondsSinceEpoch}",
          bookingId: widget.bookingId,
          carId: widget.carId,
          carName: widget.carName,
          senderId: widget.ownerId,
          senderEmail: widget.ownerEmail,
          senderName: hostDisplayName,
          ownerId: widget.ownerId,
          customerId: widget.customerId,
          ownerEmail: widget.ownerEmail,
          customerEmail: widget.customerEmail,
          text: "Hi! Thanks for your message. I'm the host of this vehicle. I'll get back to you shortly.",
          timestamp: DateTime.now(),
          isFromHost: true,
          isAutomated: true,
        );

        if (mounted) {
          setState(() {
            chatMessagesList.add(autoReply);
          });
        } else {
          chatMessagesList.add(autoReply);
        }

        await saveChatMessagesToLocalStorage();
        FirestoreService.saveChatMessageToFirestore(autoReply);

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }

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
  }

  @override
  Widget build(BuildContext context) {
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
                    _effectiveOtherPartyName.isNotEmpty ? _effectiveOtherPartyName : widget.otherPartyName,
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
              final partyName = _effectiveOtherPartyName.isNotEmpty ? _effectiveOtherPartyName : widget.otherPartyName;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Calling $partyName (+92 300 1234567)..."),
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
              stream: _messagesStream,
              builder: (context, snapshot) {
                final displayMessages = (snapshot.hasData && snapshot.data!.isNotEmpty)
                    ? snapshot.data!
                    : getMessagesForBooking(
                        widget.bookingId,
                        widget.carName,
                        carId: widget.carId,
                        customerId: widget.customerId,
                        customerEmail: widget.customerEmail,
                      );

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
