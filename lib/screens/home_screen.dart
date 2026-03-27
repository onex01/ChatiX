import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import '../widgets/chat_list.dart';   // ← новый импорт

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
            onPressed: () => _showSearchDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Stack(
        children: [
          // Основное содержимое
          Column(
            children: [
              // Поисковая строка
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value.trim().toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[850],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Список чатов
              Expanded(
                child: ChatList(
                  currentUserId: currentUser.uid,
                  searchQuery: _searchQuery,
                ),
              ),
            ],
          ),

          // ==================== LIQUID GLASS DOCK BAR ====================
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Кнопка профиля (Liquid Glass стиль)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Оставляем старый FAB для заметок (можно убрать, если хочешь)
      floatingActionButton: FloatingActionButton(
        onPressed: _createSelfNotes,
        child: const Icon(Icons.note_alt),
        tooltip: 'Заметки',
      ),
    );
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