import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final Map<String, String> userNicknames = {}; // кэш никнеймов

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatiX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
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
                  Text('Пока нет чатов\nНайдите пользователя через поиск'),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;

          // Загружаем никнеймы один раз
          _loadNicknamesIfNeeded(chats);

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final data = chats[index].data() as Map<String, dynamic>;
              final participants = data['participants'] as List<dynamic>;
              final otherUserId = participants.firstWhere((id) => id != currentUser.uid, orElse: () => currentUser.uid);
              final isSelfChat = data['isSelfChat'] == true;

              final displayName = isSelfChat ? 'Заметки' : (userNicknames[otherUserId] ?? otherUserId);

              return ListTile(
                leading: CircleAvatar(
                  child: isSelfChat ? const Icon(Icons.note_alt) : const Icon(Icons.person),
                ),
                title: Text(displayName),
                subtitle: Text(data['lastMessage'] ?? 'Нет сообщений'),
                trailing: data['lastMessageTime'] != null
                    ? Text(
                        (data['lastMessageTime'] as Timestamp)
                            .toDate()
                            .toString()
                            .substring(11, 16),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chats[index].id,
                        otherUserId: otherUserId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSelfNotes,
        child: const Icon(Icons.note_alt),
        tooltip: 'Заметки',
      ),
    );
  }

  Future<void> _loadNicknamesIfNeeded(List<QueryDocumentSnapshot> chats) async {
    final Set<String> uidsToLoad = {};

    for (var doc in chats) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = data['participants'] as List<dynamic>;
      for (var uid in participants) {
        final uidStr = uid.toString();
        if (uidStr != currentUser.uid && !userNicknames.containsKey(uidStr)) {
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
      }

      if (mounted) setState(() {});
    } catch (e) {
      print("Ошибка загрузки никнеймов: $e");
    }
  }

  void _showSearchDialog(BuildContext context) {
    String query = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Поиск по никнейму'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => query = value.trim().toLowerCase(),
          decoration: const InputDecoration(hintText: 'Введите никнейм'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (query.isEmpty) return;

              final result = await FirebaseFirestore.instance
                  .collection('users')
                  .where('nickname', isEqualTo: query)
                  .limit(1)
                  .get();

              if (result.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пользователь не найден')),
                );
                return;
              }

              final otherUserId = result.docs.first.id;
              if (otherUserId == currentUser.uid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Это вы сами')),
                );
                return;
              }

              _createOrOpenChat(otherUserId);
            },
            child: const Text('Найти'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSelfNotes() async {
    final chatId = '${currentUser.uid}_self';

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [currentUser.uid],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'isSelfChat': true,
    }, SetOptions(merge: true));

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, otherUserId: currentUser.uid),
        ),
      );
    }
  }

  Future<void> _createOrOpenChat(String otherUserId) async {
    final currentUid = currentUser.uid;
    final chatId = currentUid.compareTo(otherUserId) < 0
        ? '${currentUid}_$otherUserId'
        : '${otherUserId}_$currentUid';

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [currentUid, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, otherUserId: otherUserId),
        ),
      );
    }
  }
}