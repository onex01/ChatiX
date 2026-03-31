import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final friendIds = List<String>.from(data['friends'] ?? []);
        
        if (friendIds.isNotEmpty) {
          // Загружаем данные друзей
          final friendsData = await Future.wait(
            friendIds.map((id) async {
              final friendDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(id)
                  .get();
              
              if (friendDoc.exists) {
                final friendData = friendDoc.data()!;
                return {
                  'uid': id,
                  'nickname': friendData['nickname'] ?? 'Пользователь',
                  'photoUrl': friendData['photoUrl'],
                  'isOnline': friendData['isOnline'] ?? false,
                  'lastSeen': friendData['lastSeen']?.toDate(),
                };
              }
              return null;
            }),
          );
          
          setState(() {
            _friends = friendsData.whereType<Map<String, dynamic>>().toList();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading friends: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat(String userId, String nickname) async {
    final chatId = [currentUser.uid, userId]..sort();
    final chatDocId = '${chatId[0]}_${chatId[1]}';
    
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatDocId);
    final chatDoc = await chatRef.get();
    
    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [currentUser.uid, userId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatDocId,
            otherUserId: userId,
          ),
        ),
      );
    }
  }

  String _getLastSeenText(DateTime? lastSeen, bool isOnline) {
    if (isOnline) return 'В сети';
    if (lastSeen == null) return 'Был(а) недавно';
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 5) return 'Был(а) только что';
    if (difference.inHours < 1) return 'Был(а) ${difference.inMinutes} мин назад';
    if (difference.inDays < 1) return 'Был(а) ${difference.inHours} ч назад';
    if (difference.inDays < 7) return 'Был(а) ${difference.inDays} дн назад';
    
    return 'Был(а) ${lastSeen.day}.${lastSeen.month}.${lastSeen.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? Colors.grey.shade50 : const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Контакты'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _loadFriends,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: isLight ? Colors.grey.shade400 : Colors.grey.shade600),
                      const SizedBox(height: 16),
                      Text(
                        'Нет друзей',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: isLight ? Colors.grey.shade600 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Добавляйте друзей через их профиль',
                        style: TextStyle(
                          color: isLight ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final isOnline = friend['isOnline'] ?? false;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 0,
                      color: isLight ? Colors.white : const Color(0xFF1C1C1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isLight ? Colors.grey.shade200 : Colors.grey.shade800,
                        ),
                      ),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: friend['photoUrl'] != null
                                  ? CachedNetworkImageProvider(friend['photoUrl'])
                                  : null,
                              child: friend['photoUrl'] == null
                                  ? Icon(Icons.person, size: 32, color: isLight ? Colors.grey : Colors.grey.shade400)
                                  : null,
                            ),
                            if (isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isLight ? Colors.white : const Color(0xFF1C1C1E),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          friend['nickname'] ?? 'Пользователь',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          _getLastSeenText(friend['lastSeen'], isOnline),
                          style: TextStyle(
                            fontSize: 13,
                            color: isOnline ? Colors.green : (isLight ? Colors.grey.shade600 : Colors.grey.shade500),
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _startChat(friend['uid'], friend['nickname']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(80, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Написать'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}