import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  
  String? _nickname;
  String? _photoUrl;
  String? _phoneNumber;
  String? _bio;
  bool _isLoading = true;
  int _contactsCount = 0;
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkContactsPermission();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nickname = data['nickname'] ?? user.email?.split('@')[0];
          _photoUrl = data['photoUrl'];
          // Проверяем существование поля phoneNumber
          _phoneNumber = data.containsKey('phoneNumber') ? data['phoneNumber'] : null;
          _bio = data['bio'] ?? 'Привет! Я использую ChatiX';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        // Не показываем ошибку пользователю, просто используем значения по умолчанию
      }
    }
  }

  Future<void> _checkContactsPermission() async {
    final hasPermission = await FlutterContacts.requestPermission();
    if (hasPermission) {
      await _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      setState(() {
        _contacts = contacts;
        _contactsCount = contacts.length;
      });
      
      // Поиск пользователей по контактам
      await _findUsersFromContacts(contacts);
    } catch (e) {
      print('Error loading contacts: $e');
    }
  }

  Future<void> _findUsersFromContacts(List<Contact> contacts) async {
    final phones = <String>[];
    
    for (var contact in contacts) {
      for (var phone in contact.phones) {
        if (phone.number.isNotEmpty) {
          // Нормализуем номер телефона
          String normalized = phone.number
              .replaceAll(RegExp(r'[^0-9+]'), '')
              .replaceAll(RegExp(r'^\+?7'), '7');
          phones.add(normalized);
        }
      }
    }
    
    if (phones.isEmpty) return;
    
    // Убираем дубликаты
    final uniquePhones = phones.toSet().toList();
    
    try {
      // Ищем пользователей с такими номерами
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', whereIn: uniquePhones.take(10).toList())
          .get();
      
      if (usersQuery.docs.isNotEmpty && mounted) {
        final foundCount = usersQuery.docs.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Найдено $foundCount друзей в ChatiX!'),
            action: SnackBarAction(
              label: 'Показать',
              onPressed: () {
                _showFoundUsers(usersQuery.docs);
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error finding users: $e');
    }
  }

  void _showFoundUsers(List<QueryDocumentSnapshot> users) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final userData = users[index].data() as Map<String, dynamic>;
          final userId = users[index].id;
          final nickname = userData['nickname'] ?? 'Пользователь';
          final photoUrl = userData['photoUrl'];
          
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(nickname),
            subtitle: Text(userId),
            onTap: () {
              Navigator.pop(context);
              // TODO: Открыть диалог для начала чата
            },
          );
        },
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
      await ref.putFile(File(pickedFile.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': url});

      if (mounted) setState(() => _photoUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фото профиля обновлено')),
      );
    } catch (e) {
      print('Error uploading photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки фото. Попробуйте позже.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestContactsPermission() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      await _loadContacts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Доступ к контактам необходим для поиска друзей')),
      );
    }
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ).then((_) => _loadProfile());
            },
            child: const Text('Редактировать', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Аватар
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                          child: _photoUrl == null
                              ? Icon(Icons.person, size: 60, color: isLight ? Colors.grey : Colors.grey.shade400)
                              : null,
                        ),
                        GestureDetector(
                          onTap: _pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isLight ? Colors.white : const Color(0xFF0F0F0F),
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Имя пользователя
                  Text(
                    _nickname ?? 'Пользователь',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isLight ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Email
                  Text(
                    user.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Статус
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 8),
                        SizedBox(width: 4),
                        Text('В сети', style: TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Bio
                  if (_bio != null && _bio!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Card(
                        elevation: 0,
                        color: isLight ? Colors.grey.shade100 : Colors.grey.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _bio!,
                            style: TextStyle(
                              fontSize: 15,
                              color: isLight ? Colors.black87 : Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Информация
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildInfoTile(
                          icon: Icons.phone,
                          title: 'Телефон',
                          value: _phoneNumber ?? 'Не указан',
                          onTap: _phoneNumber == null ? _addPhoneNumber : null,
                          isLight: isLight,
                        ),
                        Divider(height: 1, color: isLight ? Colors.grey.shade200 : Colors.grey.shade800),
                        _buildInfoTile(
                          icon: Icons.people,
                          title: 'Контакты',
                          value: '$_contactsCount контактов',
                          onTap: _contactsCount == 0 ? _requestContactsPermission : null,
                          isLight: isLight,
                        ),
                        Divider(height: 1, color: isLight ? Colors.grey.shade200 : Colors.grey.shade800),
                        _buildInfoTile(
                          icon: Icons.qr_code,
                          title: 'QR-код',
                          value: 'Мой QR-код',
                          onTap: () {},
                          isLight: isLight,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    required bool isLight,
  }) {
    return ListTile(
      leading: Icon(icon, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
      title: Text(title, style: TextStyle(color: isLight ? Colors.black87 : Colors.white70)),
      subtitle: Text(value, style: TextStyle(color: isLight ? Colors.grey.shade600 : Colors.grey.shade500)),
      trailing: onTap != null ? const Icon(Icons.add, size: 20) : null,
      onTap: onTap,
    );
  }

  Future<void> _addPhoneNumber() async {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить номер телефона'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '+7 XXX XXX XX XX',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = controller.text.trim();
              if (phone.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'phoneNumber': phone,
                });
                setState(() => _phoneNumber = phone);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Номер телефона добавлен')),
                );
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}