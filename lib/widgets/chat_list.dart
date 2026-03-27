import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ChatiX/screens/chat_screen.dart';

class ChatList extends StatefulWidget {
  final String currentUserId;
  final String searchQuery;

  const ChatList({
    super.key,
    required this.currentUserId,
    required this.searchQuery,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final Map<String, String> userNicknames = {};
  final Map<String, String> userPhotoUrls = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: widget.currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && userNicknames.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                SizedBox(height: 20),
                Text('Пока нет чатов', style: TextStyle(fontSize: 18)),
                Text('Найдите пользователя через поиск', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final chats = snapshot.data!.docs;

        _loadUserInfoIfNeeded(chats);

        // Фильтрация по поиску
        final filteredChats = chats.where((doc) {
          if (widget.searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final participants = data['participants'] as List<dynamic>;
          final otherUserId = participants.firstWhere(
            (id) => id != widget.currentUserId,
            orElse: () => widget.currentUserId,
          );
          final displayName = userNicknames[otherUserId] ?? otherUserId;
          return displayName.toLowerCase().contains(widget.searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final data = filteredChats[index].data() as Map<String, dynamic>;
            final participants = data['participants'] as List<dynamic>;
            final otherUserId = participants.firstWhere(
              (id) => id != widget.currentUserId,
              orElse: () => widget.currentUserId,
            );
            final isSelfChat = data['isSelfChat'] == true;

            final displayName = isSelfChat ? 'Заметки' : (userNicknames[otherUserId] ?? otherUserId);
            final photoUrl = userPhotoUrls[otherUserId];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? (isSelfChat
                        ? const Icon(Icons.note_alt, size: 28)
                        : const Icon(Icons.person, size: 28))
                    : null,
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
              ),
              subtitle: Text(
                data['lastMessage'] ?? 'Нет сообщений',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[400], fontSize: 15),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (data['lastMessageTime'] != null)
                    Text(
                      (data['lastMessageTime'] as Timestamp)
                          .toDate()
                          .toString()
                          .substring(11, 16),
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: filteredChats[index].id,
                      otherUserId: otherUserId,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadUserInfoIfNeeded(List<QueryDocumentSnapshot> chats) async {
    final Set<String> uidsToLoad = {};

    for (var doc in chats) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = data['participants'] as List<dynamic>;
      for (var uid in participants) {
        final uidStr = uid.toString();
        if (uidStr != widget.currentUserId && !userNicknames.containsKey(uidStr)) {
          uidsToLoad.add(uidStr);
        }
      }
    }

    if (uidsToLoad.isEmpty) return;

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: uidsToLoad.toList())
          .get();

      for (var doc in usersSnapshot.docs) {
        userNicknames[doc.id] = doc['nickname'] ?? doc.id;
        userPhotoUrls[doc.id] = doc['photoUrl'] ?? '';
      }

      if (mounted) setState(() {});
    } catch (e) {
      print("Ошибка загрузки информации пользователей: $e");
    }
  }
}