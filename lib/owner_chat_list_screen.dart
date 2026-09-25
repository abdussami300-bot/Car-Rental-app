import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'user_data.dart';
import 'firestore_service.dart';
import 'chat_screen.dart';

class OwnerConversation {
  final String key;
  final String customerName;
  final String customerEmail;
  final String customerId;
  final String ownerName;
  final String ownerEmail;
  final String ownerId;
  final String carName;
  final String carId;
  final String bookingId;
  final ChatMessage latestMessage;
  final int unreadCount;
  final List<ChatMessage> messages;

  const OwnerConversation({
    required this.key,
    required this.customerName,
    required this.customerEmail,
    required this.customerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerId,
    required this.carName,
    required this.carId,
    required this.bookingId,
    required this.latestMessage,
    required this.unreadCount,
    required this.messages,
  });

  bool get hasUnread => unreadCount > 0;
}

class OwnerChatListScreen extends StatefulWidget {
  const OwnerChatListScreen({super.key});

  @override
  State<OwnerChatListScreen> createState() => _OwnerChatListScreenState();
}

class _OwnerChatListScreenState extends State<OwnerChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String _myEmail = "";
  String _myUid = "";
  String _myName = "";

  late final Stream<List<ChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = FirestoreService.streamAllMessages();
    _loadOwnerInfo();
  }

  Future<void> _loadOwnerInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    final emailCandidate = (user?.email ?? activeUserEmail).trim().toLowerCase();
    final uidCandidate = user?.uid ?? (activeUserId.isNotEmpty ? activeUserId : "");
    String nameCandidate = (user?.displayName ?? activeUserName).trim();

    if (nameCandidate.isEmpty) {
      nameCandidate = (prefs.getString("app_user_active_name") ?? prefs.getString("app_user_name") ?? "").trim();
    }
    if (nameCandidate.isEmpty && name.isNotEmpty) {
      nameCandidate = name.trim();
    }

    if (mounted) {
      setState(() {
        _myEmail = emailCandidate;
        _myUid = uidCandidate;
        _myName = nameCandidate;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0 && now.day == time.day) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (diff.inDays < 2 && now.subtract(const Duration(days: 1)).day == time.day) {
      return 'Yesterday';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${time.day} ${months[time.month - 1]}';
    }
  }

  List<OwnerConversation> _groupMessagesIntoConversations(List<ChatMessage> allMessages) {
    final ownerEmailNorm = _myEmail.trim().toLowerCase();
    final ownerUidNorm = _myUid.trim();

    // Map: conversationKey -> List<ChatMessage>
    final Map<String, List<ChatMessage>> grouped = {};

    for (final msg in allMessages) {
      // Determine if message pertains to this owner
      final matchesOwnerEmail = ownerEmailNorm.isNotEmpty &&
          (msg.ownerEmail.trim().toLowerCase() == ownerEmailNorm ||
           (msg.isFromHost && msg.senderEmail.trim().toLowerCase() == ownerEmailNorm));
      final matchesOwnerUid = ownerUidNorm.isNotEmpty &&
          (msg.ownerId.trim() == ownerUidNorm ||
           (msg.isFromHost && msg.senderId.trim() == ownerUidNorm));
      final matchesOwnerFleet = allCarsList.any((c) {
        final sameCar = (msg.carId.isNotEmpty && c.id == msg.carId) ||
            (msg.carName.isNotEmpty && c.name.trim().toLowerCase() == msg.carName.trim().toLowerCase());
        return sameCar && (c.isOwnedBy(ownerEmailNorm) || c.isOwnedByActiveUser);
      });

      if (!matchesOwnerEmail && !matchesOwnerUid && !matchesOwnerFleet) {
        continue;
      }

      // Customer identifier
      String customerEmail = "";
      if (!msg.isFromHost && msg.senderEmail.isNotEmpty) {
        customerEmail = msg.senderEmail.trim().toLowerCase();
      } else if (msg.customerEmail.isNotEmpty) {
        customerEmail = msg.customerEmail.trim().toLowerCase();
      } else if (msg.senderEmail.trim().toLowerCase() != ownerEmailNorm) {
        customerEmail = msg.senderEmail.trim().toLowerCase();
      }

      final carKey = msg.carId.isNotEmpty ? msg.carId : msg.carName.trim().toLowerCase();
      final convKey = '${customerEmail}_$carKey';

      grouped.putIfAbsent(convKey, () => []).add(msg);
    }

    final List<OwnerConversation> convList = [];

    grouped.forEach((key, msgs) {
      if (msgs.isEmpty) return;

      // Sort chronological
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final latest = msgs.last;

      // Identify customer name
      String custName = "";
      for (final m in msgs.reversed) {
        if (!m.isFromHost && m.senderName.trim().isNotEmpty &&
            m.senderName.toLowerCase() != "host" &&
            m.senderName.toLowerCase() != "renter") {
          custName = m.senderName.trim();
          break;
        }
      }
      if (custName.isEmpty) {
        // Fallback from email
        final custEmail = msgs.firstWhere(
          (m) => m.customerEmail.isNotEmpty,
          orElse: () => latest,
        ).customerEmail;
        if (custEmail.isNotEmpty && custEmail.contains('@')) {
          custName = custEmail.split('@').first;
          custName = custName[0].toUpperCase() + custName.substring(1);
        } else {
          custName = "Customer";
        }
      }

      // Customer Email
      final custEmail = msgs.firstWhere(
        (m) => m.customerEmail.isNotEmpty,
        orElse: () => latest,
      ).customerEmail;

      // Customer ID
      final custId = msgs.firstWhere(
        (m) => m.customerId.isNotEmpty,
        orElse: () => latest,
      ).customerId;

      // Car Name & ID
      final carName = latest.carName.isNotEmpty ? latest.carName : "Vehicle";
      final carId = latest.carId;
      final bookingId = latest.bookingId;

      // Unread count: messages sent by customer that are not read yet
      final unreadCount = msgs.where((m) => !m.isFromHost && !m.isRead).length;

      convList.add(OwnerConversation(
        key: key,
        customerName: custName,
        customerEmail: custEmail.isNotEmpty ? custEmail : (latest.isFromHost ? "" : latest.senderEmail),
        customerId: custId,
        ownerName: _myName,
        ownerEmail: _myEmail,
        ownerId: _myUid,
        carName: carName,
        carId: carId,
        bookingId: bookingId,
        latestMessage: latest,
        unreadCount: unreadCount,
        messages: msgs,
      ));
    });

    // Sort by latest message descending
    convList.sort((a, b) => b.latestMessage.timestamp.compareTo(a.latestMessage.timestamp));
    return convList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          StreamBuilder<List<ChatMessage>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              final msgs = snapshot.hasData ? snapshot.data! : chatMessagesList;
              final convs = _groupMessagesIntoConversations(msgs);
              final totalUnread = convs.fold<int>(0, (sum, c) => sum + c.unreadCount);

              if (totalUnread == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary, width: 1),
                    ),
                    child: Text(
                      "$totalUnread Unread",
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search conversations by customer or car...",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Real-time Conversation List
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                final allMsgs = snapshot.hasData ? snapshot.data! : chatMessagesList;
                final allConvs = _groupMessagesIntoConversations(allMsgs);

                // Filter by search query
                final filtered = allConvs.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final matchCust = c.customerName.toLowerCase().contains(_searchQuery);
                  final matchCar = c.carName.toLowerCase().contains(_searchQuery);
                  final matchText = c.latestMessage.text.toLowerCase().contains(_searchQuery);
                  return matchCust || matchCar || matchText;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final conv = filtered[index];
                    return _buildConversationCard(conv);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 36,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? "No matching conversations" : "No messages yet",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try searching for a different customer name or car model."
                  : "Customer messages and inquiries about your vehicles will appear here in real time.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(OwnerConversation conv) {
    final initials = conv.customerName.isNotEmpty
        ? conv.customerName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
        : "C";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // 1. Mark unread messages in this conversation as read
          final unreadIds = conv.messages
              .where((m) => !m.isFromHost && !m.isRead)
              .map((m) => m.id)
              .toList();
          if (unreadIds.isNotEmpty) {
            markLocalMessagesAsRead(unreadIds);
            FirestoreService.markMessagesAsRead(unreadIds);
          }

          // 2. Open ChatScreen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                bookingId: conv.bookingId,
                carName: conv.carName,
                carId: conv.carId,
                otherPartyName: conv.customerName,
                isHostViewing: true,
                currentUserEmail: _myEmail,
                currentUserName: _myName,
                ownerEmail: _myEmail,
                ownerId: _myUid,
                customerEmail: conv.customerEmail,
                customerId: conv.customerId,
              ),
            ),
          );

          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: conv.hasUnread ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white10,
              width: conv.hasUnread ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Customer Avatar with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: conv.hasUnread
                        ? AppTheme.primary.withValues(alpha: 0.25)
                        : const Color(0xFF2A2A2A),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: conv.hasUnread ? AppTheme.primaryLight : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (conv.hasUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Conversation details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Customer Name + Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            conv.customerName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: conv.hasUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(conv.latestMessage.timestamp),
                          style: TextStyle(
                            color: conv.hasUnread ? AppTheme.primaryLight : Colors.grey,
                            fontSize: 11,
                            fontWeight: conv.hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Relevant Car Badge Row
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_car,
                          size: 13,
                          color: AppTheme.primaryLight,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            conv.carName,
                            style: const TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Latest message preview + unread counter
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.latestMessage.text,
                            style: TextStyle(
                              color: conv.hasUnread ? Colors.white : Colors.white60,
                              fontWeight: conv.hasUnread ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conv.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              conv.unreadCount > 9 ? '9+' : '${conv.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
