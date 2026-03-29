import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  
  String? _nickname;
  String? _photoUrl;
  String? _phoneNumber;
  String? _email;
  String? _bio;
  bool? _isOnline;
  DateTime? _lastSeen;
  bool _isLoading = true;
  bool _isFriend = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkIfFriend();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nickname = data['nickname'] ?? 'Пользователь';
          _photoUrl = data['photoUrl'];
          _phoneNumber = data.containsKey('phoneNumber') ? data['phoneNumber'] : null;
          _email = data['email'] ?? widget.userId;
          _bio = data['bio'];
          _isOnline = data['isOnline'] ?? false;
          _lastSeen = data['lastSeen']?.toDate();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Ошибка загрузки профиля: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfFriend() async {
    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (currentUserDoc.exists) {
        final data = currentUserDoc.data()!;
        final friends = List<String>.from(data['friends'] ?? []);
        setState(() {
          _isFriend = friends.contains(widget.userId);
        });
      }
    } catch (e) {
      print('Error checking friend: $e');
    }
  }

  Future<void> _addFriend() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'friends': FieldValue.arrayUnion([widget.userId])
      });
      setState(() => _isFriend = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь добавлен в друзья')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _startChat() async {
    final chatId = [currentUser.uid, widget.userId]..sort();
    final chatDocId = '${chatId[0]}_${chatId[1]}';
    
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatDocId);
    final chatDoc = await chatRef.get();
    
    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [currentUser.uid, widget.userId],
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
            otherUserId: widget.userId,
          ),
        ),
      );
    }
  }

  String _getLastSeenText() {
    if (_isOnline == true) return 'В сети';
    if (_lastSeen == null) return 'Был(а) недавно';
    
    final now = DateTime.now();
    final difference = now.difference(_lastSeen!);
    
    if (difference.inMinutes < 5) return 'Был(а) только что';
    if (difference.inHours < 1) return 'Был(а) ${difference.inMinutes} мин назад';
    if (difference.inDays < 1) return 'Был(а) ${difference.inHours} ч назад';
    if (difference.inDays < 7) return 'Был(а) ${difference.inDays} дн назад';
    
    return 'Был(а) ${_lastSeen!.day}.${_lastSeen!.month}.${_lastSeen!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? Colors.grey.shade50 : const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Аватар и имя
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundImage: _photoUrl != null 
                              ? CachedNetworkImageProvider(_photoUrl!) 
                              : null,
                          child: _photoUrl == null
                              ? Icon(Icons.person, size: 70, color: isLight ? Colors.grey : Colors.grey.shade400)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _nickname ?? 'Пользователь',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isLight ? Colors.black : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_isOnline == true ? Colors.green : Colors.grey).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: _isOnline == true ? Colors.green : Colors.grey,
                                size: 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getLastSeenText(),
                                style: TextStyle(
                                  color: _isOnline == true ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Кнопки действий
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _startChat,
                            icon: const Icon(Icons.message, size: 20),
                            label: const Text('Написать'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isFriend ? null : _addFriend,
                            icon: Icon(
                              _isFriend ? Icons.check : Icons.person_add,
                              size: 20,
                            ),
                            label: Text(_isFriend ? 'В друзьях' : 'В друзья'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _isFriend ? Colors.green : Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Информация
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLight ? Colors.grey.shade200 : Colors.grey.shade800,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_bio != null && _bio!.isNotEmpty)
                          _buildInfoSection(
                            icon: Icons.description_outlined,
                            title: 'О себе',
                            content: _bio!,
                            isLight: isLight,
                          ),
                        if (_phoneNumber != null && _phoneNumber!.isNotEmpty)
                          _buildInfoSection(
                            icon: Icons.phone_outlined,
                            title: 'Телефон',
                            content: _phoneNumber!,
                            isLight: isLight,
                          ),
                        _buildInfoSection(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          content: _email ?? widget.userId,
                          isLight: isLight,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Общие контакты
                  _buildCommonContacts(isLight),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
    required bool isLight,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: isLight ? Colors.grey.shade600 : Colors.grey.shade400),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isLight ? Colors.grey.shade600 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    color: isLight ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonContacts(bool isLight) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('friends', arrayContains: widget.userId)
          .limit(5)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final commonFriends = snapshot.data!.docs.where((doc) {
          return doc.id != currentUser.uid;
        }).toList();

        if (commonFriends.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLight ? Colors.grey.shade200 : Colors.grey.shade800,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Общие контакты',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...commonFriends.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: data['photoUrl'] != null
                        ? CachedNetworkImageProvider(data['photoUrl'])
                        : null,
                    child: data['photoUrl'] == null
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  title: Text(data['nickname'] ?? 'Пользователь'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(userId: doc.id),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}