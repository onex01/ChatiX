import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'profile_screen.dart';
import 'settings_screen.dart';
import 'user_profile_screen.dart';
import 'contacts_screen.dart';
import 'chat_screen.dart';
import '../widgets/chat_list.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  
  int _selectedTab = 0;
  bool _updateAvailable = false;
  Map<String, dynamic>? _updateInfo;
  
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();
      _checkForUpdatesOnStart();
    });
  }

  Future<void> _checkForUpdatesOnStart() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    final updateInfo = await UpdateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      setState(() {
        _updateAvailable = true;
        _updateInfo = updateInfo;
      });
    }
  }

  void _showUpdateDialog() {
    if (_updateInfo != null) {
      UpdateService.showUpdateDialog(context, _updateInfo!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return Scaffold(
      body: Container(
        decoration: settingsProvider.wallpaperUrl != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(settingsProvider.wallpaperUrl!),
                  fit: BoxFit.cover,
                ),
              )
            : null,
        child: Stack(
          children: [
            // Основной контент
            IndexedStack(
              index: _selectedTab,
              children: [
                _buildChatsContent(),
                const ContactsScreen(),
                const ProfileScreen(),
                const SettingsScreen(),
              ],
            ),
            
            // Кнопка обновления (если доступно)
            if (_updateAvailable)
              Positioned(
                top: 60,
                right: 16,
                child: GestureDetector(
                  onTap: _showUpdateDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.system_update, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Обновление ${_updateInfo?['version']}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Нижняя навигация - компактная
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.white.withOpacity(0.85)
                            : Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isLight
                              ? Colors.black.withOpacity(0.08)
                              : Colors.white.withOpacity(0.12),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildNavItem(
                            icon: Icons.chat_bubble_outline,
                            selectedIcon: Icons.chat_bubble,
                            label: 'Чаты',
                            index: 0,
                            isLight: isLight,
                          ),
                          const SizedBox(width: 32),
                          _buildNavItem(
                            icon: Icons.contacts_outlined,
                            selectedIcon: Icons.contacts,
                            label: 'Контакты',
                            index: 1,
                            isLight: isLight,
                          ),
                          const SizedBox(width: 32),
                          _buildNavItem(
                            icon: Icons.person_outline,
                            selectedIcon: Icons.person,
                            label: 'Профиль',
                            index: 2,
                            isLight: isLight,
                          ),
                          const SizedBox(width: 32),
                          _buildNavItem(
                            icon: Icons.settings_outlined,
                            selectedIcon: Icons.settings,
                            label: 'Настройки',
                            index: 3,
                            isLight: isLight,
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
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isLight,
  }) {
    final isSelected = _selectedTab == index;
    final color = isSelected 
        ? (isLight ? Colors.blue : Colors.blue.shade400)
        : (isLight ? Colors.grey.shade700 : Colors.grey.shade500);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _searchFocusNode.unfocus();
          if (index != 0) _clearSearch();
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isLight ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.25))
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsContent() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, 
            MediaQuery.of(context).padding.top + 12, 
            16, 
            12),
          decoration: BoxDecoration(
            color: isLight 
                ? Colors.white.withOpacity(0.96)
                : const Color(0xFF0F0F0F).withOpacity(0.96),
            border: Border(
              bottom: BorderSide(
                color: isLight 
                    ? Colors.grey.shade200
                    : Colors.grey.shade800,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Чаты',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: isLight ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Поиск пользователей',
                  hintStyle: TextStyle(
                    color: isLight ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(Icons.search, size: 20, color: isLight ? Colors.grey.shade600 : Colors.grey.shade400),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 20, color: isLight ? Colors.grey.shade600 : Colors.grey.shade400),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isLight ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isLight ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  filled: true,
                  fillColor: isLight ? Colors.grey.shade50 : Colors.grey.shade900,
                ),
                style: TextStyle(
                  color: isLight ? Colors.black : Colors.white,
                  fontSize: 16,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                },
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _searchQuery.isEmpty
              ? ChatList(
                  currentUserId: currentUser.uid,
                  searchQuery: '',
                )
              : _buildUserSearchResults(),
        ),
      ],
    );
  }

  Widget _buildUserSearchResults() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isGreaterThanOrEqualTo: _searchQuery.toLowerCase())
          .where('nickname', isLessThanOrEqualTo: _searchQuery.toLowerCase() + '\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 70,
                  color: isLight ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'Пользователь «$_searchQuery» не найден',
                  style: TextStyle(
                    fontSize: 17,
                    color: isLight ? Colors.grey.shade600 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final nickname = userData['nickname'] ?? 'Без имени';
            final photoUrl = userData['photoUrl'];

            if (userId == currentUser.uid) {
              return const SizedBox.shrink();
            }

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
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Icon(Icons.person, size: 32, color: isLight ? Colors.grey : Colors.grey.shade400)
                      : null,
                ),
                title: Text(
                  nickname,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '@${userId.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isLight ? Colors.grey.shade600 : Colors.grey.shade500,
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    _startChat(userId, nickname);
                  },
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
        );
      },
    );
  }

  void _startChat(String otherUserId, String nickname) async {
    final chatId = [currentUser.uid, otherUserId]..sort();
    final chatDocId = '${chatId[0]}_${chatId[1]}';
    
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatDocId);
    final chatDoc = await chatRef.get();
    
    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [currentUser.uid, otherUserId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
            chatId: chatDocId,
            otherUserId: otherUserId,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        ),
      );
    }
  }
}