import 'package:ChatiX/screens/user_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
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
  void initState() {
    super.initState();
    // Создаём чат "Заметки" по умолчанию (если его ещё нет)
    _ensureSelfNotesChatExists();
  }

  Future<void> _ensureSelfNotesChatExists() async {
    final selfChatId = '${widget.currentUserId}_self';
    try {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(selfChatId).get();
      if (!chatDoc.exists) {
        await FirebaseFirestore.instance.collection('chats').doc(selfChatId).set({
          'participants': [widget.currentUserId],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'isSelfChat': true,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Ошибка создания чата Заметки по умолчанию: $e");
    }
  }

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

        // Сортировка: закреплённые всегда сверху
        List<QueryDocumentSnapshot> sortedChats = List.from(chats);
        sortedChats.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aPinned = aData['pinned'] ?? false;
          final bPinned = bData['pinned'] ?? false;
          if (aPinned != bPinned) return aPinned ? -1 : 1;
          final aTime = (aData['lastMessageTime'] as Timestamp?)?.seconds ?? 0;
          final bTime = (bData['lastMessageTime'] as Timestamp?)?.seconds ?? 0;
          return bTime.compareTo(aTime);
        });

        _loadUserInfoIfNeeded(sortedChats);

        // Фильтрация по поиску
        final filteredChats = sortedChats.where((doc) {
          if (widget.searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final participants = data['participants'] as List<dynamic>;
          final otherUserId = participants.firstWhere(
            (id) => id != widget.currentUserId,
            orElse: () => widget.currentUserId,
          );
          final displayName = userNicknames[otherUserId] ?? otherUserId;
          return displayName.toLowerCase().contains(widget.searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final doc = filteredChats[index];
            final data = doc.data() as Map<String, dynamic>;
            final participants = data['participants'] as List<dynamic>;
            final otherUserId = participants.firstWhere(
              (id) => id != widget.currentUserId,
              orElse: () => widget.currentUserId,
            );
             final isSelfChat = data['isSelfChat'] == true;
            final displayName = isSelfChat ? 'Заметки' : (userNicknames[otherUserId] ?? otherUserId);
            final photoUrl = userPhotoUrls[otherUserId];
            final isPinned = data['pinned'] ?? false;
            final lastMessage = data['lastMessage'] ?? 'Нет сообщений';

            return CupertinoContextMenu.builder(
              actions: _buildContextMenuActions(doc, otherUserId, isSelfChat, isPinned),
              builder: (BuildContext context, Animation<double> animation) {
                // Красивая iOS-анимация подъёма (как в сообщениях)
                final scale = 1.0 + (animation.value * 0.025);
                final lift = -6.0 * animation.value;

                return Transform.translate(
                  offset: Offset(0, lift),
                  child: Transform.scale(
                    scale: scale,
                    child: Material(
                      elevation: 12 * animation.value,
                      shadowColor: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                      child: ListTile(
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
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[400], fontSize: 15),
                        ),
                        trailing: isPinned
                            ? const Icon(Icons.push_pin, size: 20, color: Colors.blueAccent)
                            : null,
                        // ← ВОССТАНОВЛЕН onTap + CupertinoPageRoute (iOS-анимация)
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: doc.id,
                                otherUserId: otherUserId,
                              ),
                            ),
                          );
                        },
                      ),
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

  List<Widget> _buildContextMenuActions(
    QueryDocumentSnapshot doc,
    String otherUserId,
    bool isSelfChat,
    bool isPinned,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final isMuted = data['isMuted'] ?? false;

    return [
      CupertinoContextMenuAction(
        child: Text(isPinned ? 'Открепить' : 'Закрепить'),
        trailingIcon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
        onPressed: () {
          Navigator.pop(context);
          _togglePin(doc);
        },
      ),
      CupertinoContextMenuAction(
        child: Text(isMuted ? 'Включить уведомления' : 'Заглушить'),
        trailingIcon: isMuted ? Icons.notifications : Icons.notifications_off,
        onPressed: () {
          Navigator.pop(context);
          _toggleMute(doc);
        },
      ),
      CupertinoContextMenuAction(
        child: const Text('Пометить как непрочитанное'),
        trailingIcon: Icons.mark_chat_unread_outlined,
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Отмечено как непрочитанное')),
          );
        },
      ),
      if (!isSelfChat)
        CupertinoContextMenuAction(
          child: const Text('Открыть профиль'),
          trailingIcon: Icons.person_outline,
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              CupertinoPageRoute(                     // ← тоже iOS-анимация
                builder: (_) => UserProfileScreen(userId: otherUserId),
              ),
            );
          },
        ),
      CupertinoContextMenuAction(
        child: const Text('Поиск в чате'),
        trailingIcon: Icons.search,
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Поиск в чате (скоро)')),
          );
        },
      ),
      CupertinoContextMenuAction(
        child: const Text('Архивировать'),
        trailingIcon: Icons.archive_outlined,
        onPressed: () {
          Navigator.pop(context);
          _archiveChat(doc);
        },
      ),
      CupertinoContextMenuAction(
        isDestructiveAction: true,
        child: const Text('Удалить чат'),
        trailingIcon: Icons.delete_forever,
        onPressed: () {
          Navigator.pop(context);
          _deleteChat(doc);
        },
      ),
    ];
  }

  Future<void> _deleteChat(QueryDocumentSnapshot doc) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Удалить чат?'),
        content: const Text('Будут удалены все сообщения. Это действие нельзя отменить.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Отмена'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Удалить навсегда'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final chatRef = doc.reference;
      final messagesSnapshot = await chatRef.collection('messages').get();

      final batch = FirebaseFirestore.instance.batch();

      for (var messageDoc in messagesSnapshot.docs) {
        batch.delete(messageDoc.reference);
      }

      batch.delete(chatRef);

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Чат и все сообщения удалены')),
        );
      }
    } catch (e) {
      print('Ошибка при удалении чата: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при удалении чата')),
        );
      }
    }
  }

  Future<void> _togglePin(QueryDocumentSnapshot doc) async {
    final isPinned = (doc.data() as Map<String, dynamic>)['pinned'] ?? false;
    await doc.reference.update({
      'pinned': !isPinned,
      if (!isPinned) 'pinnedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleMute(QueryDocumentSnapshot doc) async {
    final isMuted = (doc.data() as Map<String, dynamic>)['isMuted'] ?? false;
    await doc.reference.update({'isMuted': !isMuted});
  }

  Future<void> _archiveChat(QueryDocumentSnapshot doc) async {
    await doc.reference.update({'isArchived': true});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чат архивирован')),
      );
    }
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