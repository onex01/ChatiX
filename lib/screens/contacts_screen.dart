// contacts_screen.dart - полная переработка
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'chat_screen.dart';
import 'user_profile_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser!;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _phoneContacts = [];
  bool _isLoading = true;
  bool _contactsPermissionGranted = false;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _checkContactsPermission();
  }

  Future<void> _checkContactsPermission() async {
    final status = await Permission.contacts.status;
    setState(() {
      _contactsPermissionGranted = status.isGranted;
    });
    if (status.isGranted) {
      _loadPhoneContacts();
    }
  }

  Future<void> _loadData() async {
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
                  'avatarHex': friendData['avatarHex'],
                  'phoneNumber': friendData['phoneNumber'],
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

  Future<void> _loadPhoneContacts() async {
    if (!_contactsPermissionGranted) return;
    
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      
      final phones = <String>[];
      final contactMap = <String, Map<String, dynamic>>{};
      
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          if (phone.number.isNotEmpty) {
            String normalized = phone.number
                .replaceAll(RegExp(r'[^0-9+]'), '')
                .replaceAll(RegExp(r'^\+?7'), '7');
            phones.add(normalized);
            contactMap[normalized] = {
              'name': contact.displayName,
              'contact': contact,
            };
          }
        }
      }
      
      if (phones.isEmpty) {
        setState(() => _phoneContacts = []);
        return;
      }
      
      // Ищем пользователей с такими номерами
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', whereIn: phones.take(10).toList())
          .get();
      
      final foundUsers = <Map<String, dynamic>>[];
      for (var doc in usersQuery.docs) {
        final userData = doc.data();
        final phoneNumber = userData['phoneNumber'];
        final contactInfo = contactMap[phoneNumber];
        
        if (doc.id != currentUser.uid && !_friends.any((f) => f['uid'] == doc.id)) {
          foundUsers.add({
            'uid': doc.id,
            'nickname': userData['nickname'] ?? 'Пользователь',
            'photoUrl': userData['photoUrl'],
            'phoneNumber': phoneNumber,
            'contactName': contactInfo?['name'] ?? userData['nickname'],
          });
        }
      }
      
      setState(() {
        _phoneContacts = foundUsers;
      });
    } catch (e) {
      print('Error loading phone contacts: $e');
    }
  }

  Future<void> _addFriend(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'friends': FieldValue.arrayUnion([userId])
      });
      
      setState(() {
        _phoneContacts.removeWhere((c) => c['uid'] == userId);
      });
      
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь добавлен в друзья')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _removeFriend(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить из друзей?'),
        content: const Text('Пользователь будет удалён из списка друзей.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'friends': FieldValue.arrayRemove([userId])
      });
      
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь удалён из друзей')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Друзья'),
            Tab(text: 'Найти'),
          ],
          indicatorColor: Colors.blue,
          labelColor: isLight ? Colors.black : Colors.white,
          unselectedLabelColor: isLight ? Colors.grey.shade600 : Colors.grey.shade500,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadData();
              if (_contactsPermissionGranted) _loadPhoneContacts();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Друзья
                _friends.isEmpty
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
                              'Добавляйте друзей через поиск',
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
                          
                          return Dismissible(
                            key: Key(friend['uid']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              await _removeFriend(friend['uid']);
                              return false;
                            },
                            child: Card(
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.message, color: Colors.blue),
                                      onPressed: () => _startChat(friend['uid'], friend['nickname']),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.person_outline, color: isLight ? Colors.grey.shade600 : Colors.grey.shade500),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => UserProfileScreen(userId: friend['uid']),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                
                // Поиск по контактам
                _buildFindTab(isLight),
              ],
            ),
    );
  }

  Widget _buildFindTab(bool isLight) {
    if (!_contactsPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Нет доступа к контактам',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Разрешите доступ к контактам, чтобы найти друзей',
              style: TextStyle(color: isLight ? Colors.grey.shade600 : Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await Permission.contacts.request();
                _checkContactsPermission();
              },
              child: const Text('Разрешить доступ'),
            ),
          ],
        ),
      );
    }
    
    if (_phoneContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts_outlined, size: 80, color: isLight ? Colors.grey.shade400 : Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'Нет контактов в ChatiX',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isLight ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Пригласите друзей установить ChatiX',
              style: TextStyle(color: isLight ? Colors.grey.shade500 : Colors.grey.shade400),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _phoneContacts.length,
      itemBuilder: (context, index) {
        final contact = _phoneContacts[index];
        
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
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: contact['photoUrl'] != null
                  ? CachedNetworkImageProvider(contact['photoUrl'])
                  : null,
              child: contact['photoUrl'] == null
                  ? Icon(Icons.person, size: 32, color: isLight ? Colors.grey : Colors.grey.shade400)
                  : null,
            ),
            title: Text(
              contact['nickname'] ?? 'Пользователь',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              contact['contactName'] ?? contact['phoneNumber'] ?? '',
              style: TextStyle(
                fontSize: 13,
                color: isLight ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
            trailing: ElevatedButton(
              onPressed: () => _addFriend(contact['uid']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Добавить'),
            ),
          ),
        );
      },
    );
  }
}