import 'dart:ui';
import 'package:Rizz/features/settings/presentation/changelog_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../../core/settings/settings_provider.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../widgets/chat_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser!;

  int _selectedTab = 0;
  late final PageController _pageController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _chatsScrollController = ScrollController();

  bool _isBarVisible = true;
  bool _isTablet = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose(); 
    _chatsScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedTab = index;
      if (index != 0) _clearSearch();
    });
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.unfocus();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isTablet) return false;

    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      if (direction == ScrollDirection.reverse && _isBarVisible) {
        setState(() => _isBarVisible = false);
      } else if (direction == ScrollDirection.forward && !_isBarVisible) {
        setState(() => _isBarVisible = true);
      }
    }
    return false; // false = позволяем уведомлению продолжать всплывать (стандартно)
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    _isTablet = MediaQuery.of(context).size.width > 600; // обновляем каждый build

    if (_isTablet) {
      return _buildTabletLayout(settingsProvider, isLight);
    } else {
      return _buildMobileLayout(settingsProvider, isLight);
    }
  }

  // ==================== МОБИЛЬНАЯ ВЕРСИЯ (обновлённая) ====================
  Widget _buildMobileLayout(SettingsProvider settings, bool isLight) {
    return Scaffold(
      body: Container(
        decoration: settings.wallpaperUrl != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(settings.wallpaperUrl!),
                  fit: BoxFit.cover,
                ),
              )
            : null,
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const ClampingScrollPhysics(),
              children: [
                _buildChatsContentWithScroll(isLight),
                const ContactsScreen(),
                const ProfileScreen(),
                const SettingsScreen(),
              ],
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280), // плавнее, как в iOS
                curve: Curves.easeOutCubic,
                height: _isBarVisible ? 80 : 0, // ← увеличена высота
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10), // ← шире и больше отступ
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.white.withValues(alpha: 0.78)
                              : Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.09)
                                : Colors.white.withValues(alpha: 0.13),
                            width: 0.9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
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
                                accentColor: settings.accentColor),
                            const SizedBox(width: 28),
                            _buildNavItem(
                                icon: Icons.contacts_outlined,
                                selectedIcon: Icons.contacts,
                                label: 'Контакты',
                                index: 1,
                                isLight: isLight,
                                accentColor: settings.accentColor),
                            const SizedBox(width: 28),
                            _buildNavItem(
                                icon: Icons.person_outline,
                                selectedIcon: Icons.person,
                                label: 'Профиль',
                                index: 2,
                                isLight: isLight,
                                accentColor: settings.accentColor),
                            const SizedBox(width: 28),
                            _buildNavItem(
                                icon: Icons.settings_outlined,
                                selectedIcon: Icons.settings,
                                label: 'Настройки',
                                index: 3,
                                isLight: isLight,
                                accentColor: settings.accentColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // 5. Плавающая кнопка справа сверху над док-баром
      //floatingActionButton: FloatingActionButton(
        //heroTag: 'GroupChatAdd',
        //onPressed: () {
          //ScaffoldMessenger.of(context).showSnackBar(
            //const SnackBar(
              //content: Text('Создание групп и каналов — скоро'),
              //behavior: SnackBarBehavior.floating,
            //),
          //);
          // TODO: Navigator.push → NewGroupScreen() / NewChannelScreen()
        //},
        //backgroundColor: settings.accentColor,
        //elevation: 20,
        //child: const Icon(Icons.add_rounded, size: 30),
      //),
      //floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ==================== ПЛАНШЕТНАЯ ВЕРСИЯ ====================
  Widget _buildTabletLayout(SettingsProvider settings, bool isLight) {
    return Scaffold(
      body: Row(
        children: [
          // Левая панель навигации
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF1C1C1E),
              border: Border(
                right: BorderSide(
                  color: isLight ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabletNavItem(
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    label: 'Чаты',
                    index: 0,
                    isLight: isLight,
                    accentColor: settings.accentColor),
                const SizedBox(height: 24),
                _buildTabletNavItem(
                    icon: Icons.contacts_outlined,
                    selectedIcon: Icons.contacts,
                    label: 'Контакты',
                    index: 1,
                    isLight: isLight,
                    accentColor: settings.accentColor),
                const SizedBox(height: 24),
                _buildTabletNavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Профиль',
                    index: 2,
                    isLight: isLight,
                    accentColor: settings.accentColor),
                const SizedBox(height: 24),
                _buildTabletNavItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Настройки',
                    index: 3,
                    isLight: isLight,
                    accentColor: settings.accentColor),
              ],
            ),
          ),
          // Основная область контента
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildChatsContent(isLight, settings.accentColor),
                const ContactsScreen(),
                const ProfileScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Виджет элемента навигации для мобильных
  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isLight,
    required Color accentColor,
  }) {
    final isSelected = _selectedTab == index;
    final color = isSelected ? accentColor : (isLight ? Colors.grey.shade700 : Colors.grey.shade500);
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: isLight ? 0.15 : 0.25)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(isSelected ? selectedIcon : icon, color: color, size: 22),
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

  // Виджет элемента навигации для планшетов (боковая колонка)
  Widget _buildTabletNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isLight,
    required Color accentColor,
  }) {
    final isSelected = _selectedTab == index;
    final color = isSelected ? accentColor : (isLight ? Colors.grey.shade700 : Colors.grey.shade500);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: label,
          child: GestureDetector(
            onTap: () => _onNavTap(index),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(isSelected ? selectedIcon : icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // Контент вкладки Чаты с поиском и списком (с прокруткой)
  Widget _buildChatsContentWithScroll(bool isLight) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Column(
        children: [
          _buildChatsHeader(isLight),
          Expanded(
            child: _searchQuery.isEmpty
                ? ChatList(
                    currentUserId: _currentUser.uid,
                    searchQuery: '',
                    scrollController: _chatsScrollController,
                  )
                : _buildUserSearchResults(),
          ),
        ],
      ),
    );
  }

  // ==================== КОНТЕНТ ЧАТОВ (планшет) ====================
  Widget _buildChatsContent(bool isLight, Color accentColor) {
    return Column(
      children: [
        _buildChatsHeader(isLight),
        Expanded(
          child: _searchQuery.isEmpty
              ? ChatList(
                  currentUserId: _currentUser.uid,
                  searchQuery: '',
                  scrollController: null,
                )
              : _buildUserSearchResults(),
        ),
      ],
    );
  }

  Widget _buildChatsHeader(bool isLight) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.96) : const Color(0xFF0F0F0F).withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: isLight ? Colors.grey.shade200 : Colors.grey.shade800, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Чаты', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: isLight ? Colors.black : Colors.white)),
          const SizedBox(height: 12),
          TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChangelogScreen()));
                },
                child: const Text(
                  'Версия 0.1.95',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Поиск пользователей',
              hintStyle: TextStyle(color: isLight ? Colors.grey.shade500 : Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 20, color: isLight ? Colors.grey.shade600 : Colors.grey.shade400),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: Icon(Icons.clear, size: 20, color: isLight ? Colors.grey.shade600 : Colors.grey.shade400), onPressed: _clearSearch)
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isLight ? Colors.grey.shade300 : Colors.grey.shade700)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isLight ? Colors.grey.shade300 : Colors.grey.shade700)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 2)),
              filled: true,
              fillColor: isLight ? Colors.grey.shade50 : Colors.grey.shade900,
            ),
            style: TextStyle(color: isLight ? Colors.black : Colors.white, fontSize: 16),
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSearchResults() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isGreaterThanOrEqualTo: _searchQuery)
          .where('nickname', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
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
                Icon(Icons.search_off_rounded, size: 70, color: isLight ? Colors.grey.shade400 : Colors.grey.shade600),
                const SizedBox(height: 16),
                Text('Пользователь «$_searchQuery» не найден', style: TextStyle(fontSize: 17, color: isLight ? Colors.grey.shade600 : Colors.grey.shade500)),
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
            final username = userData['username'] ?? '';
            final photoUrl = userData['photoUrl'];
            final searchLower = _searchQuery.toLowerCase();
            if (!nickname.toLowerCase().contains(searchLower) && 
                !username.toLowerCase().contains(searchLower)) {
              return const SizedBox.shrink();
            }
            if (userId == _currentUser.uid) return const SizedBox.shrink();
            return Card( 
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              elevation: 0,
              color: isLight ? Colors.white : const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isLight ? Colors.grey.shade200 : Colors.grey.shade800),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? Icon(Icons.person, size: 32, color: isLight ? Colors.grey : Colors.grey.shade400) : null,
                ),
                title: Text(nickname, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  username.isNotEmpty ? nickname : '@${userId.substring(0, 8)}',
                  style: TextStyle(fontSize: 13, color: isLight ? Colors.grey.shade600 : Colors.grey.shade500),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _startChat(userId, nickname),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

  Future<void> _startChat(String otherUserId, String nickname) async {
    final chatId = [_currentUser.uid, otherUserId]..sort();
    final chatDocId = '${chatId[0]}_${chatId[1]}';
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatDocId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [_currentUser.uid, otherUserId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatDocId, otherUserId: otherUserId)));
    }
  }
}